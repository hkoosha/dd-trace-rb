require_relative '../integration'
require_relative 'configuration/settings'
require_relative 'patcher'

module Datadog
  module Tracing
    module Contrib
      module Pubsub
        # Description of PubSub integration
        class Integration
          include Contrib::Integration

          MINIMUM_VERSION = Gem::Version.new('2.14.0')

          # @public_api Changing the integration name or integration options can cause breaking changes
          register_as :pubsub

          def self.version
            v = Gem.loaded_specs['google-cloud-pubsub'] && Gem.loaded_specs['google-cloud-pubsub'].version
            puts "ver = #{v}"
            v
          end

          def self.loaded?
            v = !defined?(::Google::Cloud::PubSub).nil?
            puts "loaded = #{v}"
            v
          end

          def self.compatible?
            v = super && version >= MINIMUM_VERSION
            puts "compatible = #{v}"
            v
          end

          def new_configuration
            Configuration::Settings.new
          end

          def patcher
            Patcher
          end
        end
      end
    end
  end
end
