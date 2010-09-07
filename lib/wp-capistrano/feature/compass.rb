# Assumes you're using DXW's sass_output.php convention
# A sample can be found in dxw/wp-generate:
# http://github.com/dxw/wp-generate/blob/master/lib/wp_generate/templates/theme/sass/sass_output.php

begin
  require 'compass'

  Capistrano::Configuration.instance.load do
    after 'deploy:finalize_update' do

      Dir.glob("themes/*").each do |theme_dir|

        # Config
        cfg_file = Compass.detect_configuration_file(theme_dir)

        if cfg_file
          cfg = Compass.add_project_configuration(cfg_file)
          abs_css = File.expand_path(File.join(theme_dir, cfg.css_path))

          # Compile
          compiled = system("compass compile --force --output-style compressed #{theme_dir}")
          #TODO: do this instead
          #Compass.compiler.options[:style] = :compressed
          #Compass.compiler.run

          if compiled

            # Path fiddling

            pwd = File.expand_path(Dir.pwd)

            unless pwd == abs_css[0...pwd.length]
              raise RuntimeError, 'opps'
            end

            relative_css = abs_css[pwd.length+1..-1]

            remote_css = "#{latest_release}/finalized/wp-content/#{relative_css}"

            # Upload
            top.upload(abs_css, remote_css, :via => :scp, :recursive => true)

          end
        end
      end
    end
  end

rescue LoadError
  # Don't die horribly
end
