# Shared directories get uploaded at setup-time and don't change

Capistrano::Configuration.instance.load do
  after 'setup:checkout' do

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
end
