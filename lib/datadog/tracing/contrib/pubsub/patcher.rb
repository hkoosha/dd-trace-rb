require_relative '../patcher'
require_relative 'ext'

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
                ::Google::Cloud::PubSub::Topic.include(Instrumentation::Publisher)
              rescue StandardError => e
                Datadog.logger.error("Unable to apply Presto integration: #{e}")
              end
            end
          end
        end
      end
    end
  end
end
