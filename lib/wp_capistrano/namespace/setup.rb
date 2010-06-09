Capistrano::Configuration.instance.load do
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
