# Custom htaccess

Capistrano::Configuration.instance.load do
  after 'deploy:finalize_update' do
    if File.exist? 'htaccess'
      top.upload("htaccess", "#{latest_release}/finalized/.htaccess" , :via => :scp)
    end
  end
end
