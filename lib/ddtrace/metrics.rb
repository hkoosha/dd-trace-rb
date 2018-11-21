require 'ddtrace/ext/meta'
require 'ddtrace/ext/metrics'

require 'ddtrace/utils/time'

module Datadog
  # Behavior for sending statistics to Statsd
  module Metrics
    def self.included(base)
      base.send(:include, Options)
    end

    attr_accessor :statsd

    protected

    def send_stats?
      !statsd.nil?
    end

    def distribution(stat, value, options = nil)
      return unless send_stats? && statsd.respond_to?(:distribution)
      statsd.distribution(stat, value, metric_options(options))
    rescue StandardError => e
      Datadog::Tracer.log.error("Failed to send distribution stat. Cause: #{e.message} Source: #{e.backtrace.first}")
    end

    def increment(stat, options = nil)
      return unless send_stats? && statsd.respond_to?(:increment)
      statsd.increment(stat, metric_options(options))
    rescue StandardError => e
      Datadog::Tracer.log.error("Failed to send increment stat. Cause: #{e.message} Source: #{e.backtrace.first}")
    end

    def time(stat, options = nil)
      return yield unless send_stats?

      # Calculate time, send it as a distribution.
      start = Utils::Time.get_time
      return yield
    ensure
      begin
        if send_stats? && !start.nil?
          finished = Utils::Time.get_time
          distribution(stat, ((finished - start) * 1000), options)
        end
      rescue StandardError => e
        Datadog::Tracer.log.error("Failed to send time stat. Cause: #{e.message} Source: #{e.backtrace.first}")
      end
    end

    # For defining and adding default options to metrics
    module Options
      DEFAULT = {
        tags: DEFAULT_TAGS = [
          "#{Ext::Metrics::TAG_LANG}:#{Ext::Meta::LANG}".freeze,
          "#{Ext::Metrics::TAG_LANG_INTERPRETER}:#{Ext::Meta::LANG_INTERPRETER}".freeze,
          "#{Ext::Metrics::TAG_LANG_VERSION}:#{Ext::Meta::LANG_VERSION}".freeze,
          "#{Ext::Metrics::TAG_TRACER_VERSION}:#{Ext::Meta::TRACER_VERSION}".freeze
        ].freeze
      }.freeze

      def metric_options(options = nil)
        return default_metric_options if options.nil?

        default_metric_options.merge(options) do |key, old_value, new_value|
          case key
          when :tags
            old_value.dup.concat(new_value).uniq
          else
            new_value
          end
        end
      end

      def default_metric_options
        # Return dupes, so that the constant isn't modified,
        # and defaults are unfrozen for mutation in Statsd.
        DEFAULT.dup.tap do |options|
          options[:tags] = options[:tags].dup
        end
      end
    end

    extend(Options)
  end
end
