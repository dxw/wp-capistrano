class WpGenerate::Generator::Capify < WpGenerate::Generator
  def initialize args, options
    @options = options
    @templates = {"Capfile" => "Capfile", "config.yml" => "lib/config.yml"}
    @vars = {}
  end
  def templates_dir
    File.join(File.dirname(__FILE__), '../templates')
  end
end
