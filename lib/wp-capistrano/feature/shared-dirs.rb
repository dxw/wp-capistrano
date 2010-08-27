# Shared directories get uploaded at setup-time and don't change

Capistrano::Configuration.instance.load do
  after 'setup:checkout' do

    dirs = []

    # Uploads
    dirs << 'uploads'

    # Plugins
    if deploy_profile.modules.include? 'shared-plugins'
      dirs << 'plugins'
    end

    # Upload them
    dirs.each do |dir|
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

  end

  before 'deploy:wp_config_configure' do

    if deploy_profile.modules.include? 'shared-plugins'
      preconfig['WP_PLUGIN_DIR'] = "'"+"#{shared_path}/plugins".gsub(/'/,"\\'")+"'"
    end

  end
end
