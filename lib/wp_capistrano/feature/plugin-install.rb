# Allow plugin installation by end-users

Capistrano::Configuration.instance.load do
  after 'deploy:finalize_update' do

    if deploy_profile.modules.include? 'plugin-install'

      run("mkdir -p #{latest_release}/finalized/wp-content/upgrade &&
          chmod -R 777 #{latest_release}/finalized/wp-content/upgrade &&
          chmod -R 777 #{latest_release}/finalized/wp-content/plugins ; true")
    end

  end
end
