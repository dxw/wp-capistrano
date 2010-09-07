# WP Super Cache

Capistrano::Configuration.instance.load do

  before 'deploy:wp_config_configure' do
    if deploy_profile.modules.include? 'wp-super-cache'
      preconfig['WP_CACHE'] = "'true'"
    end
  end

  after 'deploy:finalize_update' do

    if File.exist? 'plugins/wp-super-cache/advanced-cache.php'
      top.upload("plugins/wp-super-cache/advanced-cache.php", "#{latest_release}/finalized/wp-content/" , :via => :scp)
      sedable_path = "#{latest_release}/finalized/wp-content/plugins/wp-super-cache/".gsub(/\//,'\/')
      run("sed -i 's/CACHEHOME/#{sedable_path}/g' #{latest_release}/finalized/wp-content/advanced-cache.php")
    elsif deploy_profile.modules.include? 'wp-super-cache'
      raise IOError, 'Are you sure you have the WP Super Cache plugin? Could not find advanced-cache.php'
    end

    if File.exist? 'wp-cache-config.php'
      top.upload("wp-cache-config.php", "#{latest_release}/finalized/wp-content/" , :via => :scp)
    elsif File.exist? 'plugins/wp-super-cache/wp-cache-config-sample.php'
      top.upload("plugins/wp-super-cache/wp-cache-config-sample.php", "#{latest_release}/finalized/wp-content/wp-cache-config.php" , :via => :scp)
    elsif deploy_profile.modules.include? 'wp-super-cache'
      raise IOError, 'Are you sure you have the WP Super Cache plugin? Could not find wp-cache-config.php'
    end

    # Keep writable directories to a bare minimum
    if deploy_profile.modules.include? 'wp-super-cache'
      run("mkdir -p #{latest_release}/finalized/wp-content/cache/blogs &&
           mkdir -p #{latest_release}/finalized/wp-content/cache/meta")

      run("chmod -R 777 #{latest_release}/finalized/wp-content/cache &&
           chmod -R 777 #{latest_release}/finalized/wp-content/wp-cache-config.php")
    end
  end

end
