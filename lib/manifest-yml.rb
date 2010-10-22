class ManifestYML
  attr_accessor :files

  def initialize f
    @files = []
    y = YAML.load_file f

    if y['Files']
      @files += glob(y['Files'])
    end

    if y['Manifests']
      glob(y['Manifests']).each do |m|
        pwd = File.dirname(m)
        Dir.chdir pwd do
          newfiles = ManifestYML.new(File.basename(m)).files
          @files += newfiles.map{|f|File.join(pwd, f)}
        end
      end
    end
  end

  def each_file &block
    @files.each &block
  end

  def glob patterns
    fi = []
    patterns.each do |pat|
      f = Dir.glob pat

      if f.length < 1
        raise RuntimeError, "Pattern #{pat} returned no matches"
      end
      fi += f
    end

    fi
  end
end
