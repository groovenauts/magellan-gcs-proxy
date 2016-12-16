require 'magellan/gcs/proxy'

require 'logger'
require 'json'

module Magellan
  module Gcs
    module Proxy
      class PubsubSustainer
        include Log

        class << self
          def run(message)
            raise "#{name}.run requires block" unless block_given?
            if c = Proxy.config[:sustainer]
              t = Thread.new(message, c['delay'], c['interval']) do |msg, delay, interval|
                Thread.current[:processing_message] = true
                new(msg, delay: delay, interval: interval).run
              end
              begin
                yield
              ensure
                t[:processing_message] = false
                t.join
              end
            else
              yield
            end
          end
        end

        attr_reader :message, :delay, :interval
        def initialize(message, delay: 10, interval: nil)
          @message = message
          @delay = delay.to_i
          @interval = (interval || @delay * 0.9).to_f
        end

        def run
          reset_next_limit
          loop do
            debug("is sleeping #{interval} sec.")
            unless wait_while_processing
              debug('is stopping.')
              break
            end
            send_delay
            reset_next_limit
          end
          debug('stopped.')
        rescue => e
          logger.error(e)
        end

        attr_reader :next_limit, :next_deadline
        def reset_next_limit
          now = Time.now.to_f
          @next_limit = now + interval
          @next_deadline = now + delay
        end

        def send_delay
          debug("is sending delay!(#{delay})")
          message.delay! delay
          debug("sent delay!(#{delay}) successfully")
        rescue Google::Cloud::UnavailableError => e
          if Time.now.to_f < next_deadline
            sleep(1) # retry interval
            debug("is retrying to send delay! cause of [#{e.class.name}] #{e.message}")
            retry
          end
          raise e
        end

        def debug(msg)
          logger.debug("#{self.class.name} #{msg}")
        end

        def wait_while_processing
          while Time.now.to_f < next_limit
            return false unless Thread.current[:processing_message]
            sleep(0.1)
          end
          true
        end
      end
    end
  end
end
