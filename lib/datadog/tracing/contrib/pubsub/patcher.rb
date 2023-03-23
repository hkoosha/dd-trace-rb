require_relative '../patcher'
require_relative 'ext'
require_relative 'instrumentation'

module Datadog
  module Tracing
    module Contrib
      module Pubsub
        # Patcher enables patching of 'pubsub' module.
        module Patcher
          include Contrib::Patcher

          module_function

          def target_version
            v = Integration.version
            Datadog.logger.error("ASKING VERSION: #{v}")
            v
          end

          def patch
            Datadog.logger.error('============> PATCHING')
            begin
              Datadog.logger.error('Patching Pubsub publisher')
              ::Google::Cloud::PubSub::Topic.include(Instrumentation::Publisher)
              Datadog.logger.error('Patching Pubsub consumer')
              ::Google::Cloud::PubSub::Subscription.include(Instrumentation::Consumer)
            rescue StandardError => e
              Datadog.logger.error("Unable to apply PubSub integration: #{e}")
            end
          end
        end
      end
    end
  end
end
