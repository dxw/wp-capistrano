require 'wp_capistrano' # Compatability

Capistrano::Configuration.instance.load do
  namespace :deploy do

    desc "Override deploy restart to not do anything"
    task :restart do
    end

    task :finalize_update, :except => { :no_release => true } do
      run "chmod -R g+w #{latest_release}"

      # I've got submodules in my submodules
      #run "cd #{latest_release} && git submodule foreach --recursive git submodule update --init"
      # Git 1.5-compatability:
      run "cd #{latest_release} && DIR=`pwd` && for D in `grep '^\\[submodule' .git/config | cut -d\\\" -f2`; do cd $DIR/$D && git submodule init && git submodule update; done"

      run <<-CMD
        mkdir -p #{latest_release}/finalized &&
        cp -rv   #{shared_path}/wordpress/*     #{latest_release}/finalized/ &&
        rm -rf   #{latest_release}/finalized/wp-content &&
        mkdir    #{latest_release}/finalized/wp-content &&
        rm -rf #{latest_release}/**/.git &&
        cp -rv #{latest_release}/themes  #{latest_release}/finalized/wp-content/ &&
        ln -s #{shared_path}/uploads   #{latest_release}/finalized/wp-content/ &&
        mkdir -p #{latest_release}/finalized/wp-content/cache/ ;
        chmod -R 777 #{latest_release}/finalized/wp-content/cache/ ;
        true
      CMD

      if deploy_profile.modules.include? 'shared-plugins'
        run("ln -s #{shared_path}/plugins #{latest_release}/finalized/wp-content/")
      else
        run("cp -rv #{latest_release}/plugins #{latest_release}/finalized/wp-content/")
      end

      deploy.wp_config

      ## WP Super Cache

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

      run("mkdir -p #{latest_release}/finalized/wp-content/cache/blogs &&
           mkdir -p #{latest_release}/finalized/wp-content/cache/meta")

      # Keep writables to a bare minimum
      if deploy_profile.modules.include? 'wp-super-cache'
        run("chmod -R 777 #{latest_release}/finalized/wp-content/cache &&
             chmod -R 777 #{latest_release}/finalized/wp-content/wp-cache-config.php")
      end

      ## Allow plugin installation

      if deploy_profile.modules.include? 'plugin-install'

        run("mkdir -p #{latest_release}/finalized/wp-content/upgrade &&
            chmod -R 777 #{latest_release}/finalized/wp-content/upgrade &&
            chmod -R 777 #{latest_release}/finalized/wp-content/plugins ; true")

      end

    end

    desc "Copy shared wp-config into place, adding per-deploy constants"
    task :wp_config do
      ## Generate a couple of PHP fragments

      # nb:
      # - in a string=>string pair, the value represents a PHP literal (i.e. it includes the quotes)
      #   the key, however, is a string
      # - the convention is to put things into preconfig unless there's a reason not to
      preconfig = {}
      postconfig = {}
      # For certain cases we may allow the user write access (i.e. module plugin-install)
      # it should always be direct filesystem access (and WordPress' autodetection is pants)
      preconfig['FS_METHOD'] = "'direct'"

      # Modules
      if deploy_profile.modules.include? 'wp-super-cache'
        preconfig['WP_CACHE'] = "'true'"
      end
      if deploy_profile.modules.include? 'shared-plugins'
        preconfig['WP_PLUGIN_DIR'] = "'"+"#{shared_path}/plugins".gsub(/'/,"\\'")+"'"
      end

      def phpize(h)
        s = []
        h.each_pair do |k,v|
          s << "define('#{k}', #{v});"
        end
        s.join("\n")
      end

      prestring = phpize(preconfig)
      poststring = phpize(postconfig)

      ## Upload fragments

      run "mkdir -p #{latest_release}/build"
      put prestring, "#{latest_release}/build/pre-config"
      put poststring, "#{latest_release}/build/post-config"

      ## sed them into wp-config (using perl)
      r = "cp -rv #{shared_path}/wp-config.php #{latest_release}/wp-config.php &&"

      %w[pre post].each do |pp|
        f = "#{latest_release}/build/#{pp}-config"
        r += %Q`perl -i -pe 'BEGIN{undef $/;open(F,"<#{f}");@f=<F>;$f=join("",@f);}s/## #{pp.upcase}CONFIG BEGIN.*## #{pp.upcase}CONFIG END./$f/ms' #{latest_release}/wp-config.php &&`
      end

      r += "cp -rv #{latest_release}/wp-config.php #{latest_release}/finalized/wp-config.php"

      run r

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
