# encoding: utf-8

# Assumes you're using DXW's sass_output.php convention
# A sample can be found in dxw/wp-generate:
# http://github.com/dxw/wp-generate/blob/master/lib/wp_generate/templates/theme/sass/sass_output.php

Capistrano::Configuration.instance.load do
  after 'deploy:finalize_update' do
    Dir.glob("themes/*/*/sass_output.php").map {|d| d.match(%r&/([^/]+)/([^/]+)/sass_output.php$&)[1,2]}[0..0].each do |theme_dir,sass_dir|

      # Run sass_output.php
      f = IO.popen("cd themes/#{theme_dir}/#{sass_dir} && php sass_output.php 2>/dev/null")
      sass_output = f.readlines.join
      remote_sass = "#{latest_release}/finalized/wp-content/themes/#{theme_dir}/#{sass_dir}/sass_output.css"

      # Upload it
      put(sass_output, remote_sass, :via => :scp)

      # sed style.css to point to it
      run("sed -i 's/\.php/\.css/' #{latest_release}/finalized/wp-content/themes/#{theme_dir}/style.css &&
            chmod a+r #{remote_sass}")
    end
  end
end
