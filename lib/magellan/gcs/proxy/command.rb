require "magellan/gcs/proxy"

require 'json'
require 'uri'
require "google/cloud/pubsub"
require "google/cloud/storage"

module Magellan
  module Gcs
    module Proxy
      class Command

        attr_reader :base_cmd
        def initialize(*args)
          @base_cmd = args.join(' ')
        end

        def storage
          @storage ||= Google::Cloud::Storage.new(
            project: ENV['GOOGLE_PROJECT'] || 'dummy-project-id',
            keyfile: ENV['GOOGLE_KEY_JSON_FILE'],
          )
        end

        def run
          pubsub = Google::Cloud::Pubsub.new(
            project: ENV['GOOGLE_PROJECT'] || 'dummy-project-id',
            keyfile: ENV['GOOGLE_KEY_JSON_FILE'],
          )

          topic_name = ENV['BATCH_TOPIC_NAME'] || 'test-topic'
          topic = pubsub.topic(topic_name) || pubsub.create_topic(topic_name)
          p topic

          sub_name = ENV['BATCH_SUBSCRIPTION_NAME'] || 'test-subscription'
          sub = topic.subscription(sub_name) || topic.subscribe(sub_name)
          p sub

          sub.listen do |msg|
            p msg

            gcs = msg.attributes['gcs']
            gcs = JSON.parse(gcs) if gcs

            if gcs
              (gcs['download_files'] || []).each do |obj|
                p obj
                uri = URI.parse(obj['src'])
                raise "Unsupported scheme #{uri.scheme.inspect} in #{obj.inspect}" unless uri.scheme == 'gs'
                bucket = storage.bucket(uri.host)
                file = bucket.file uri.path.sub(/\A\//, '')
                file.download obj['dest']
              end
            end

            cmd = base_cmd.dup
            cmd << ' ' << msg.data unless msg.data.nil?
            p cmd

            if system(cmd)
              if gcs
                (gcs['upload_files'] || []).each do |obj|
                  p obj
                  uri = URI.parse(obj['dest'])
                  raise "Unsupported scheme #{uri.scheme.inspect} in #{obj.inspect}" unless uri.scheme == 'gs'
                  bucket = storage.bucket(uri.host)
                  bucket.create_file obj['src'], uri.path.sub(/\A\//, '')
                end
              end

              sub.acknowledge msg
              puts "acknowledge!"
            else
              puts "Error: #{cmd.inspect}"
            end

            if gcs
              deleted_files =
                gcs['download_files'].map{|obj| obj['dest']} +
                gcs['upload_files'  ].map{|obj| obj['src']}
              puts "Deleting..."
              p deleted_files
              deleted_files.each{|f| File.delete(f)}
            end
          end
        end

      end
    end
  end
end
