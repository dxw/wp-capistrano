require 'wp_config'
require 'erb'
require 'digest'
require 'digest/sha1'
Capistrano::Configuration.instance.load do
  default_run_options[:pty] = true

  def set_target target
    tt = WPConfig.instance.h['deploy'][target]
    if tt
      t = OpenStruct.new(tt)
      set :domain, t.ssh_domain
      set :user, t.ssh_user
      set :deploy_to, t.path
      set :wordpress_domain, t.vhost
      set :wordpress_db_name, t.database.name
      set :wordpress_db_user, t.database.user
      set :wordpress_db_password, t.database.password
      set :wordpress_db_host, t.database.host
      set :use_sudo, t.use_sudo

      @roles = {}
      role :app, domain
      role :web, domain
      role :db,  domain, :primary => true
    end
  end

  WPConfig.instance.h['deploy'].each_pair do |k,v|
    set_target k if v['default']
  end

  task :testing do
    set_target 'testing'
  end
  task :staging do
    set_target 'staging'
  end
  task :production do
    set_target 'production'
  end

  # Load from config
  set :wordpress_version, WPConfig.wordpress.version
  set :wordpress_git_url, WPConfig.wordpress.repository
  set :repository, WPConfig.application.repository

  # Everything else
  set :scm, "git"
  set :deploy_via, :remote_cache
  set :branch, "master"
  set :git_shallow_clone, 1
  set :git_enable_submodules, 1
  set :wordpress_db_host, "localhost"
  set :wordpress_auth_key, Digest::SHA1.hexdigest(rand.to_s)
  set :wordpress_secure_auth_key, Digest::SHA1.hexdigest(rand.to_s)
  set :wordpress_logged_in_key, Digest::SHA1.hexdigest(rand.to_s)
  set :wordpress_nonce_key, Digest::SHA1.hexdigest(rand.to_s)

  #allow deploys w/o having git installed locally
  set(:real_revision) do
    output = ""
    invoke_command("git ls-remote #{repository} #{branch} | cut -f 1", :once => true) do |ch, stream, data|
      case stream
      when :out
        if data =~ /\(yes\/no\)\?/ # first time connecting via ssh, add to known_hosts?
          ch.send_data "yes\n"
        elsif data =~ /Warning/
        elsif data =~ /yes/
          #
        else
          output << data
        end
      when :err then warn "[err :: #{ch[:server]}] #{data}"
      end
    end
    output.gsub(/\\/, '').chomp
  end

  #no need for log and pids directory
  set :shared_children, %w(system)

  namespace :deploy do

    desc "Override deploy restart to not do anything"
    task :restart do
      #
    end

    task :finalize_update, :except => { :no_release => true } do
      run "chmod -R g+w #{latest_release}"

      # I've got submodules in my submodules
      #run "cd #{latest_release} && git submodule foreach --recursive git submodule update --init"
      # Git 1.5-compatability:
      run "cd #{latest_release} && DIR=`pwd` && for D in `grep '^\\[submodule' .git/config | cut -d\\\" -f2`; do cd $DIR/$D && git submodule init && git submodule update; done"

      # SASS
      Dir.glob("themes/*/*/sass_output.php").map {|d| d.match(%r&/([^/]+)/([^/]+)/sass_output.php$&)[1,2]}[0..0].each do |theme_dir,sass_dir|
        p theme_dir
        p sass_dir
        system("cd themes/#{theme_dir}/#{sass_dir} && php sass_output.php > sass_output.css")
        top.upload("themes/#{theme_dir}/#{sass_dir}/sass_output.css", "#{latest_release}/themes/#{theme_dir}/#{sass_dir}/" , :via => :scp)
        run("sed -i 's/\.php/\.css/' #{latest_release}/themes/#{theme_dir}/style.css")
      end

      run <<-CMD
        mkdir -p #{latest_release}/finalized &&
        cp -rv   #{shared_path}/wordpress/*     #{latest_release}/finalized/ &&
        cp -rv   #{shared_path}/wp-config.php   #{latest_release}/finalized/wp-config.php &&
        cp -rv   #{shared_path}/htaccess        #{latest_release}/finalized/.htaccess &&
        rm -rf   #{latest_release}/finalized/wp-content &&
        mkdir    #{latest_release}/finalized/wp-content &&
        rm -rf #{latest_release}/**/.git &&
        cp -rv #{latest_release}/themes  #{latest_release}/finalized/wp-content/ &&
        cp -rv #{latest_release}/plugins #{latest_release}/finalized/wp-content/ &&
        ln -s #{shared_path}/uploads   #{latest_release}/finalized/wp-content/ &&
        mkdir -p #{latest_release}/finalized/wp-content/cache/ ;
        chmod -R 777 #{latest_release}/finalized/wp-content/cache/ ;
        true
      CMD
    end

    task :symlink, :except => { :no_release => true } do
      on_rollback do
        if previous_release
          run "rm -f #{current_path}; ln -s #{previous_release}/finalized #{current_path}; true"
        else
          logger.important "no previous release to rollback to, rollback of symlink skipped"
        end
      end

      run "rm -f #{current_path} && ln -s #{latest_release}/finalized #{current_path}"
    end

    namespace :revision do
      task :revision do
        puts 'hhh'
      end
    end
  end

  namespace :setup do

    desc "Setup this server for a new wordpress site."
    task :wordpress do
      "mkdir -p #{deploy_to}"
      deploy.setup
      wp.config
      wp.htaccess
      wp.checkout
      setup.uploads
      setup.mysql
    end

    desc "Creates the DB, and loads the dump"
    task :mysql do
      upload("data/dump.sql.gz", shared_path, :via => :scp)
      run <<-CMD
        test #{wordpress_db_name}X != `echo 'show databases' | mysql -u root | grep '^#{wordpress_db_name}$'`X &&
        echo 'create database if not exists `#{wordpress_db_name}`' | mysql -u root &&
        zcat #{shared_path}/dump.sql.gz | sed 's/localhost/#{wordpress_domain}/g' | mysql -u root #{wordpress_db_name} || true
      CMD
    end

    desc "Creates uploads dir"
    task :uploads do
      chmod = true
      if File.exist? 'uploads'
        begin
          upload("uploads", shared_path, :recursive => true, :via => :scp)
        rescue
          STDERR.puts '*** uploads dir already exists and does not belong to us. Not re-uploading.'
          chmod = false
        end
      else
        run "mkdir -p #{shared_path}/uploads"
      end
      run "chmod -R 777 #{shared_path}/uploads" if chmod
    end

  end

  namespace :wp do

    desc "Checks out a copy of wordpress to a shared location"
    task :checkout do
      run "rm -rf #{shared_path}/wordpress || true"
      raise Exception, 'wordpress.repository must be set in config.yml' if wordpress_git_url.nil?
      run "git clone --depth 1 #{wordpress_git_url} #{shared_path}/wordpress"
      run "cd #{shared_path}/wordpress && git fetch --tags && git checkout #{wordpress_version}"
    end

    desc "Sets up wp-config.php"
    task :config do
      file = File.join(File.dirname(__FILE__), "wp-config.php.erb")
      template = File.read(file)
      buffer = ERB.new(template).result(binding)

      put buffer, "#{shared_path}/wp-config.php"
      puts "New wp-config.php uploaded! Please run cap:deploy to activate these changes."
    end

    desc "Sets up .htaccess"
    task :htaccess do
      run 'env echo -e \'<IfModule mod_rewrite.c>\nRewriteEngine On\nRewriteBase /\nRewriteCond %{REQUEST_FILENAME} !-f\nRewriteCond %{REQUEST_FILENAME} !-d\nRewriteRule . /index.php [L]\n</IfModule>\' > '"#{shared_path}/htaccess"
    end

  end

end
