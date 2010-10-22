# Runs make deploy in the root of the project if Makefile is found
# And uploads any files listed in Manifest.yml

Capistrano::Configuration.instance.load do
  after 'deploy:finalize_update' do

    # Makefiles
    if File.exist? 'Makefile'
      unless system 'make deploy'
        raise RuntimeError, 'make deploy failed'
      end
    end

    # ... and Manifests
    if File.exist? 'Manifest.yml'
      ManifestYML.new('Manifest.yml').each_file do |f|
        top.upload(f, "#{latest_release}/finalized/wp-content/#{f}")
      end
    end

  end
end
