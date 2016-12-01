# coding: utf-8
require 'magellan/gcs/proxy'

require 'yaml'
require 'erb'

module Magellan
  module Gcs
    module Proxy
      class Config

        attr_reader :path, :data
        def initialize(path = './config.yml')
          @path = path
          @data = load_file
        end

        def load_file
          erb = ERB.new(File.read(path), nil, '-')
          erb.filename = path
          t = erb.result
          puts "=" * 100
          puts t
          puts "-" * 100
          YAML.load(t)
        end

        def [](key)
          data[key.to_s]
        end

      end
    end
  end
end