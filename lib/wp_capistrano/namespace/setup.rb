Capistrano::Configuration.instance.load do
  namespace :setup do

    desc "Alias for wordpress"
    task :default do
      setup.wordpress
    end

    desc "Setup this server for a new wordpress site."
    task :wordpress do
      "mkdir -p #{deploy_to}"
      deploy.setup
      wp.config
      wp.htaccess
      wp.checkout
      setup.shared_dirs
      setup.mysql
    end

    desc "Creates shared dirs"
    task :shared_dirs do

      def try_upload dir
        stop = false

        # If it already exists, stop
        run("ls -d #{shared_path}/#{dir} ; true") do |channel,stream,data|
          if data.strip=="#{shared_path}/#{dir}"
            STDERR.puts "*** #{dir} dir already exists. Not re-uploading."
            stop = true
          end
        end

        unless stop
          # If we have it, upload it
          if File.exist?(dir)
            begin
              upload(dir, shared_path, :recursive => true, :via => :scp)
            rescue
              STDERR.puts "*** #{dir} dir already exists and does not belong to us. Can't re-upload."
              stop = true
            end
          else
            run "mkdir -p #{shared_path}/#{dir}"
          end

          unless stop
            # Let our Web server write to it
            run "chmod -R 777 #{shared_path}/#{dir}"
          end
        end
      end

      ## Plugins

      if deploy_profile.modules.include? 'shared-plugins'
        try_upload('plugins')
      end

      ## Uploads

      try_upload('uploads')
    end

    desc "Creates the DB, and loads the dump"
    task :mysql do
      if File.exist? 'data/dump.sql.gz'
        upload("data/dump.sql.gz", shared_path, :via => :scp)
        run <<-CMD
        test #{wordpress_db_name}X != `echo 'show databases' | mysql | grep '^#{wordpress_db_name}$'`X &&
        echo 'create database if not exists `#{wordpress_db_name}`' | mysql &&
        zcat #{shared_path}/dump.sql.gz | sed 's/localhost/#{wordpress_domain}/g' | mysql #{wordpress_db_name} || true
        CMD
      end
    end

  end
end
