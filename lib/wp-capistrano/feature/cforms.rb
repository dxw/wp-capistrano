# Make the cforms plugin work

Capistrano::Configuration.instance.load do
  after 'deploy:finalize_update' do
    cforms_dir = "#{latest_release}/finalized/wp-content/plugins/cforms"
    run(%Q%[ -e #{cforms_dir} ] && echo '<?php $abspath="#{latest_release}/finalized/" ?>' > #{cforms_dir}/abspath.php ; true%)
  end
end
