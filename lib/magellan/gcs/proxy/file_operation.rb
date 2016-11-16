require "magellan/gcs/proxy"

require 'uri'
require "google/cloud/storage"

module Magellan
  module Gcs
    module Proxy
      module FileOperation
        def storage
          @storage ||= Google::Cloud::Storage.new(
            project: ENV['GOOGLE_PROJECT'] || 'dummy-project-id',
            keyfile: ENV['GOOGLE_KEY_JSON_FILE'],
          )
        end

        def download(definitions)
          (definitions || []).each do |obj|
            logger.info("Downloading: #{obj.inspect}")
            uri = parse_uri(obj['src'])
            bucket = storage.bucket(uri.host)
            file = bucket.file uri.path.sub(/\A\//, '')
            file.download obj['dest']
          end
        end

        def upload(definitions)
          (definitions || []).each do |obj|
            logger.info("Uploading: #{obj.inspect}")
            uri = parse_uri(obj['dest'])
            bucket = storage.bucket(uri.host)
            bucket.create_file obj['src'], uri.path.sub(/\A\//, '')
          end
        end

        def parse_uri(str)
          uri = URI.parse(str)
          raise "Unsupported scheme #{uri.scheme.inspect} of #{str}" unless uri.scheme == 'gs'
          uri
        end

      end
    end
  end
end