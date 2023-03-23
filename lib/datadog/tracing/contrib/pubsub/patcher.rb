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

          PATCH_ONLY_ONCE = Core::Utils::OnlyOnce.new

          module_function

          def patched?
            PATCH_ONLY_ONCE.ran?
          end

          def target_version
            Integration.version
          end

          def patch
            PATCH_ONLY_ONCE.run do
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
end
