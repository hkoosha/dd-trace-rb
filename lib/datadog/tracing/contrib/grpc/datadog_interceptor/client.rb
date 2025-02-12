require_relative '../../../../tracing'
require_relative '../../../metadata/ext'
require_relative '../distributed/propagation'
require_relative '../../analytics'
require_relative '../ext'
require_relative '../../ext'
require_relative '../formatting'

module Datadog
  module Tracing
    module Contrib
      module GRPC
        module DatadogInterceptor
          # The DatadogInterceptor::Client implements the tracing strategy
          # for gRPC client-side endpoints. This middleware component will
          # inject trace context information into gRPC metadata prior to
          # sending the request to the server.
          class Client < Base
            def trace(keywords)
              formatter = GRPC::Formatting::FullMethodStringFormatter.new(keywords[:method])

              options = {
                span_type: Tracing::Metadata::Ext::HTTP::TYPE_OUTBOUND,
                service: service_name, # Maintain client-side service name configuration
                resource: formatter.resource_name
              }

              Tracing.trace(Ext::SPAN_CLIENT, **options) do |span, trace|
                # PubSub is traced by contrib::pubsub.
                if keywords[:method].start_with? '/google.pubsub.'
                  yield
                else
                  annotate!(trace, span, keywords, formatter)

                  begin
                    yield
                  rescue StandardError => e
                    code = e.is_a?(::GRPC::BadStatus) ? e.code : ::GRPC::Core::StatusCodes::UNKNOWN
                    span.set_tag(Contrib::Ext::RPC::GRPC::TAG_STATUS_CODE, code)

                    raise
                  else
                    span.set_tag(Contrib::Ext::RPC::GRPC::TAG_STATUS_CODE, ::GRPC::Core::StatusCodes::OK)
                  end
                end
              end
            end

            private

            def annotate!(trace, span, keywords, formatter)
              metadata = keywords[:metadata] || {}
              call = keywords[:call]

              span.set_tags(metadata)

              span.set_tag(Tracing::Metadata::Ext::TAG_KIND, Tracing::Metadata::Ext::SpanKind::TAG_CLIENT)
              span.set_tag(Tracing::Metadata::Ext::TAG_COMPONENT, Ext::TAG_COMPONENT)
              span.set_tag(Tracing::Metadata::Ext::TAG_OPERATION, Ext::TAG_OPERATION_CLIENT)

              if Contrib::SpanAttributeSchema.default_span_attribute_schema?
                # Tag as an external peer service
                span.set_tag(Tracing::Metadata::Ext::TAG_PEER_SERVICE, span.service)
              end

              span.set_tag(Contrib::Ext::RPC::TAG_SYSTEM, Ext::TAG_SYSTEM)
              span.set_tag(Contrib::Ext::RPC::GRPC::TAG_FULL_METHOD, formatter.grpc_full_method)

              host, _port = find_host_port(call)
              span.set_tag(Tracing::Metadata::Ext::TAG_PEER_HOSTNAME, host) if host

              deadline = find_deadline(call)
              span.set_tag(Ext::TAG_CLIENT_DEADLINE, deadline) if deadline

              # Set analytics sample rate
              Contrib::Analytics.set_sample_rate(span, analytics_sample_rate) if analytics_enabled?

              Distributed::Propagation::INSTANCE.inject!(trace, metadata) if distributed_tracing?
            rescue StandardError => e
              Datadog.logger.debug("GRPC client trace failed: #{e}")
            end

            def find_deadline(call)
              return unless call.respond_to?(:deadline) && call.deadline.is_a?(Time)

              call.deadline.utc.iso8601(3)
            end

            def find_host_port(call)
              return unless call

              peer_address = if call.respond_to?(:peer)
                               call.peer
                             else
                               # call is a "view" class with restricted method visibility.
                               # We reach into it to find our data source anyway.
                               call.instance_variable_get(:@wrapped).peer
                             end

              Core::Utils.extract_host_port(peer_address)
            rescue => e
              Datadog.logger.debug { "Could not parse host:port from #{call}: #{e}" }
              nil
            end
          end
        end
      end
    end
  end
end
