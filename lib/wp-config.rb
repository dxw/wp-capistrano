# encoding: utf-8

require 'singleton'

class OpenStruct
  def method_missing(method)
    method = method.to_s
    if @hsh[method].is_a? Hash
      OpenStruct.new(@hsh[method])
    else
      @hsh[method]
    end
  end
  def initialize(hsh)
    @hsh = hsh
  end
end

class WPConfig
  include Singleton

  def self.method_missing(method, *args)
    self.instance.config.send(method, *args)
  end

  attr_reader :config, :h

  def initialize
    @h = YAML.load(open(File.join(Dir.pwd,'lib','config.yml')).read)
    @config = OpenStruct.new(@h)
  end
end
