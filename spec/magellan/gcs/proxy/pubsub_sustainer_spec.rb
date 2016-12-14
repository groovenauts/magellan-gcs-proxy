require 'spec_helper'

describe Magellan::Gcs::Proxy::PubsubSustainer do
  describe '.run' do
    context 'with sustainer' do
      let(:delay) { 2 }
      let(:config_data) do
        {
          'loggers' => [{ 'type' => 'stdout' }],
          'sustainer' => {
            'delay' => delay,
          },
        }
      end
      let(:msg) { double(:msg) }

      before do
        Magellan::Gcs::Proxy.config.reset
        allow(Magellan::Gcs::Proxy.config).to receive(:load_file).and_return(config_data)
      end

      it do
        expect(msg).to receive(:delay!).with(delay).exactly(2).times
        Timeout.timeout 6 do
          Magellan::Gcs::Proxy::PubsubSustainer.run(msg) do
            sleep(5)
          end
        end
      end

      let(:error_message) { 'Unexpected Error' }
      it 'logging error on delay!' do
        Thread.current[:processing_message] = true
        sustainer = Magellan::Gcs::Proxy::PubsubSustainer.new(msg, delay: delay)
        logger = sustainer.send(:logger)
        expect(logger).to receive(:error).with(instance_of(RuntimeError))
        expect(msg).to receive(:delay!).with(delay).and_raise(error_message)
        Timeout.timeout 4 do
          sustainer.run do
            sleep(3)
          end
        end
      end
    end

    context 'without sustainer' do
      let(:config_data) do
        {
          'loggers' => [{ 'type' => 'stdout' }],
        }
      end
      let(:msg) { double(:msg) }

      before do
        Magellan::Gcs::Proxy.config.reset
        allow(Magellan::Gcs::Proxy.config).to receive(:load_file).and_return(config_data)
      end

      it do
        expect(msg).not_to receive(:delay!)
        Timeout.timeout 6 do
          Magellan::Gcs::Proxy::PubsubSustainer.run(msg) do
            sleep(5)
          end
        end
      end
    end
  end
end