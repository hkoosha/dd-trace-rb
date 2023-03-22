require_relative '../../metadata/ext'
require_relative 'ext'

module Datadog
  module Tracing
    module Contrib
      module Pubsub
        # Instrumentation for PubSub integration
        module Instrumentation
          # Instrumentation for Google::Cloud::PubSub::Topic
          module Publisher
            def self.included(base)
              base.prepend(InstanceMethods)
            end

            # Instance methods for PubSub::Topic
            module InstanceMethods
              def publish(data = nil, attributes = nil, ordering_key: nil, compress: nil, compression_bytes_threshold: nil,
                          **extra_attrs, &block)
                Tracing.trace(
                  Ext::SPAN_SEND_MESSAGES,
                  service: datadog_configuration[:service_name]
                ) do |span|
                  attributes = decorate!(span, attributes)
                  Datadog.logger.error "final publish attrs: #{attributes}"

                  super(data, attributes, ordering_key: ordering_key, compress: compress, compression_bytes_threshold: compression_bytes_threshold,
                        **extra_attrs, &block)
                end
              end

              private

              DD = ::Datadog::Tracing::Distributed::Datadog.new(fetcher: ::Datadog::Tracing::Distributed::Fetcher)

              def datadog_configuration
                Datadog.configuration.tracing[:pubsub]
              end

              def decorate!(span, attributes)
                span.set_tag(Tracing::Metadata::Ext::TAG_COMPONENT, Ext::TAG_MESSAGING_SYSTEM)
                span.set_tag(Tracing::Metadata::Ext::TAG_KIND, Tracing::Metadata::Ext::SpanKind::TAG_PRODUCER)

                # Set analytics sample rate
                if Contrib::Analytics.enabled?(datadog_configuration[:analytics_enabled])
                  Contrib::Analytics.set_sample_rate(span, datadog_configuration[:analytics_sample_rate])
                end

                attributes = {} if attributes.nil?
                DD.inject!(::Datadog::Tracing::active_trace&.to_digest, attributes)
                attributes
              end
            end
          end

          module Consumer
            def self.included(base)
              base.prepend(InstanceMethods)
            end

            # Instance methods for PubSub::Topic
            module InstanceMethods
              def listen(deadline: nil, message_ordering: nil, streams: nil, inventory: nil, threads: {}, &block)
                traced_block = proc do |msg|
                  digest = DD.extract(msg.attributes)
                  Datadog.logger.error "final consume attrs: #{msg.attributes} :: #{digest}"
                  ::Datadog::Tracing.continue_trace!(digest) do
                    yield msg
                  end
                end

                super(deadline: deadline, message_ordering: message_ordering, streams: streams, inventory: inventory, threads: threads, &traced_block)
              end

              def passthrough(deadline: nil, message_ordering: nil, streams: nil, inventory: nil, threads: {}, &block)
                super(deadline: deadline, message_ordering: message_ordering, streams: streams, inventory: inventory, threads: threads, &block)
              end

              private

              DD = ::Datadog::Tracing::Distributed::Datadog.new(fetcher: ::Datadog::Tracing::Distributed::Fetcher)
            end
          end
        end
      end
    end
  end
end
