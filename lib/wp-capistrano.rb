# encoding: utf-8

require 'erb'
require 'digest'
require 'digest/sha1'

require 'manifest-yml'
require 'wp-config'
require 'wp-capistrano/deploy'
require 'wp-capistrano/setup'

# Features
require 'wp-capistrano/feature/cforms'
require 'wp-capistrano/feature/compass'
require 'wp-capistrano/feature/htaccess'
require 'wp-capistrano/feature/makefile-manifest'
require 'wp-capistrano/feature/plugin-install'
require 'wp-capistrano/feature/sass'
require 'wp-capistrano/feature/shared-dirs'
require 'wp-capistrano/feature/wp-super-cache'

Capistrano::Configuration.instance.load do
  default_run_options[:pty] = true

  # Dummy task
  task :set_target_ do
  end

  def set_target target
    tt = WPConfig.instance.h['deploy'][target]
    if tt
      set :deploy_target, target
      t = OpenStruct.new(tt)
      set :domain, t.ssh_domain
      set :user, t.ssh_user
      set :deploy_to, t.path
      set :wordpress_domain, t.vhost
      set :wordpress_domain, 'localhost' if wordpress_domain.nil?
      set :wordpress_db_name, t.database.name
      set :wordpress_db_user, t.database.user
      set :wordpress_db_user, 'root' if wordpress_db_user.nil?
      set :wordpress_db_password, t.database.password
      set :wordpress_db_host, t.database.host
      set :wordpress_db_host, 'localhost' if wordpress_db_host.nil?
      set :use_sudo, t.use_sudo
      set :deploy_profile, t
      deploy_profile.modules = [] unless deploy_profile.modules

      @roles = {}
      role :app, domain
      role :web, domain
      role :db,  domain, :primary => true
    end

    # Allow features to plug in here
    set_target_
  end

  WPConfig.instance.h['deploy'].each_pair do |k,v|
    task k do
      set_target k
    end
    set_target k if v['default']
  end

  # Load from config
  set :wordpress_version, WPConfig.wordpress.version
  set :wordpress_git_url, WPConfig.wordpress.repository
  set :repository, WPConfig.application.repository
  set :branch, WPConfig.application.version

  # Everything else
  set :scm, "git"
  set :deploy_via, :remote_cache
  set :git_shallow_clone, 1
  set :git_enable_submodules, 1
  set :wordpress_db_host, "localhost"
  set :wordpress_auth_key, Digest::SHA1.hexdigest(rand.to_s)
  set :wordpress_secure_auth_key, Digest::SHA1.hexdigest(rand.to_s)
  set :wordpress_logged_in_key, Digest::SHA1.hexdigest(rand.to_s)
  set :wordpress_nonce_key, Digest::SHA1.hexdigest(rand.to_s)

  #allow deploys w/o having git installed locally
  set(:real_revision) do
    output = ""
    invoke_command("git ls-remote #{repository} #{branch} | cut -f 1", :once => true) do |ch, stream, data|
      case stream
      when :out
        if data =~ /\(yes\/no\)\?/ # first time connecting via ssh, add to known_hosts?
          ch.send_data "yes\n"
        elsif data =~ /Warning/
        elsif data =~ /yes/
          #
        else
          output << data
        end
      when :err then warn "[err :: #{ch[:server]}] #{data}"
      end
    end
    output.gsub(/\\/, '').chomp
  end

  #no need for log and pids directory
  set :shared_children, %w(system)

end
