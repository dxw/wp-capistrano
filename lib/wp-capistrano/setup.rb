# encoding: utf-8

Capistrano::Configuration.instance.load do
  namespace :setup do

    desc "Setup this server for a new wordpress site."
    task :default do
      # Capistrano's setup script
      deploy.setup

      # Our setup scripts
      setup.config
      setup.checkout
    end

    desc "Checks out a copy of wordpress to a shared location"
    task :checkout do
      run "rm -rf #{shared_path}/wordpress || true"
      raise Exception, 'wordpress.repository must be set in config.yml' if wordpress_git_url.nil?
      run "git clone --depth 1 #{wordpress_git_url} #{shared_path}/wordpress"
      run "cd #{shared_path}/wordpress && git fetch --tags && git checkout #{wordpress_version}"
    end

    desc "Sets up shared wp-config.php"
    task :config do
      file = File.join(File.dirname(__FILE__), "wp-config.php.erb")
      template = File.read(file)

      buffer = ERB.new(template).result(binding)

      put buffer, "#{shared_path}/wp-config.php"
      puts "New wp-config.php uploaded! Please run cap:deploy to activate these changes."
    end

  end
end
