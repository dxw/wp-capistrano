Capistrano::Configuration.instance.load do
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

      deploy.sass

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

      ## WP Super Cache

      if deploy_profile.modules and deploy_profile.modules.include? 'wp-super-cache'

        if File.exist? 'plugins/wp-super-cache/advanced-cache.php'
          top.upload("plugins/wp-super-cache/advanced-cache.php", "#{latest_release}/finalized/wp-content/" , :via => :scp)
          sedable_path = "#{latest_release}/finalized/wp-content/plugins/wp-super-cache/".gsub(/\//,'\/')
          run("sed -i 's/CACHEHOME/#{sedable_path}/g' #{latest_release}/finalized/wp-content/advanced-cache.php")
        else
          raise IOError, 'Are you sure you have the WP Super Cache plugin?'
        end

        if File.exist? 'wp-cache-config.php'
          top.upload("wp-cache-config.php", "#{latest_release}/finalized/wp-content/" , :via => :scp)
        elsif File.exist? 'plugins/wp-super-cache/wp-cache-config-sample.php'
          top.upload("plugins/wp-super-cache/wp-cache-config-sample.php", "#{latest_release}/finalized/wp-content/wp-cache-config.php" , :via => :scp)
        else
          raise IOError, 'Are you sure you have the WP Super Cache plugin?'
        end

        #TODO
        if File.exist? 'htaccess'
          top.upload("htaccess", "#{latest_release}/finalized/.htaccess" , :via => :scp)
        end

        run("mkdir -p #{latest_release}/finalized/wp-content/cache/blogs &&
         mkdir -p #{latest_release}/finalized/wp-content/cache/meta &&
         chmod -R 777 #{latest_release}/finalized/wp-content/cache &&
         chmod -R 777 #{latest_release}/finalized/wp-content/wp-cache-config.php")

      end
    end

    desc "Compile SASS locally and upload it"
    task :sass do
      Dir.glob("themes/*/*/sass_output.php").map {|d| d.match(%r&/([^/]+)/([^/]+)/sass_output.php$&)[1,2]}[0..0].each do |theme_dir,sass_dir|
        p theme_dir
        p sass_dir
        system("cd themes/#{theme_dir}/#{sass_dir} && php sass_output.php > sass_output.css")
        top.upload("themes/#{theme_dir}/#{sass_dir}/sass_output.css", "#{latest_release}/themes/#{theme_dir}/#{sass_dir}/" , :via => :scp)
        run("sed -i 's/\.php/\.css/' #{latest_release}/themes/#{theme_dir}/style.css")
      end
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
end
