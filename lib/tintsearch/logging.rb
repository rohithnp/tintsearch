# based on https://gist.github.com/mnutt/566725
require "active_support/core_ext/module/attr_internal"

module Tintsearch
  module QueryWithInstrumentation
    def execute_search
      name = tintsearch_klass ? "#{tintsearch_klass.name} Search" : "Search"
      event = {
        name: name,
        query: params
      }
      ActiveSupport::Notifications.instrument("search.tintsearch", event) do
        super
      end
    end
  end

  module IndexWithInstrumentation
    def store(record)
      event = {
        name: "#{record.tintsearch_klass.name} Store",
        id: search_id(record)
      }
      if Tintsearch.callbacks_value == :bulk
        super
      else
        ActiveSupport::Notifications.instrument("request.tintsearch", event) do
          super
        end
      end
    end

    def remove(record)
      name = record && record.tintsearch_klass ? "#{record.tintsearch_klass.name} Remove" : "Remove"
      event = {
        name: name,
        id: search_id(record)
      }
      if Tintsearch.callbacks_value == :bulk
        super
      else
        ActiveSupport::Notifications.instrument("request.tintsearch", event) do
          super
        end
      end
    end

    def import(records)
      if records.any?
        event = {
          name: "#{records.first.tintsearch_klass.name} Import",
          count: records.size
        }
        ActiveSupport::Notifications.instrument("request.tintsearch", event) do
          super(records)
        end
      end
    end
  end

  module TintsearchWithInstrumentation
    def multi_search(searches)
      event = {
        name: "Multi Search",
        body: searches.flat_map { |q| [q.params.except(:body).to_json, q.body.to_json] }.map { |v| "#{v}\n" }.join
      }
      ActiveSupport::Notifications.instrument("multi_search.tintsearch", event) do
        super
      end
    end

    def perform_items(items)
      if callbacks_value == :bulk
        event = {
          name: "Bulk",
          count: items.size
        }
        ActiveSupport::Notifications.instrument("request.tintsearch", event) do
          super
        end
      else
        super
      end
    end
  end

  # https://github.com/rails/rails/blob/master/activerecord/lib/active_record/log_subscriber.rb
  class LogSubscriber < ActiveSupport::LogSubscriber
    def self.runtime=(value)
      Thread.current[:tintsearch_runtime] = value
    end

    def self.runtime
      Thread.current[:tintsearch_runtime] ||= 0
    end

    def self.reset_runtime
      rt = runtime
      self.runtime = 0
      rt
    end

    def search(event)
      self.class.runtime += event.duration
      return unless logger.debug?

      payload = event.payload
      name = "#{payload[:name]} (#{event.duration.round(1)}ms)"
      type = payload[:query][:type]
      index = payload[:query][:index].is_a?(Array) ? payload[:query][:index].join(",") : payload[:query][:index]

      # no easy way to tell which host the client will use
      host = Tintsearch.client.transport.hosts.first
      debug "  #{color(name, YELLOW, true)}  curl #{host[:protocol]}://#{host[:host]}:#{host[:port]}/#{CGI.escape(index)}#{type ? "/#{type.map { |t| CGI.escape(t) }.join(',')}" : ''}/_search?pretty -d '#{payload[:query][:body].to_json}'"
    end

    def request(event)
      self.class.runtime += event.duration
      return unless logger.debug?

      payload = event.payload
      name = "#{payload[:name]} (#{event.duration.round(1)}ms)"

      debug "  #{color(name, YELLOW, true)}  #{payload.except(:name).to_json}"
    end

    def multi_search(event)
      self.class.runtime += event.duration
      return unless logger.debug?

      payload = event.payload
      name = "#{payload[:name]} (#{event.duration.round(1)}ms)"

      # no easy way to tell which host the client will use
      host = Tintsearch.client.transport.hosts.first
      debug "  #{color(name, YELLOW, true)}  curl #{host[:protocol]}://#{host[:host]}:#{host[:port]}/_msearch?pretty -d '#{payload[:body]}'"
    end
  end

  # https://github.com/rails/rails/blob/master/activerecord/lib/active_record/railties/controller_runtime.rb
  module ControllerRuntime
    extend ActiveSupport::Concern

    protected

    attr_internal :tintsearch_runtime

    def process_action(action, *args)
      # We also need to reset the runtime before each action
      # because of queries in middleware or in cases we are streaming
      # and it won't be cleaned up by the method below.
      Tintsearch::LogSubscriber.reset_runtime
      super
    end

    def cleanup_view_runtime
      tintsearch_rt_before_render = Tintsearch::LogSubscriber.reset_runtime
      runtime = super
      tintsearch_rt_after_render = Tintsearch::LogSubscriber.reset_runtime
      self.tintsearch_runtime = tintsearch_rt_before_render + tintsearch_rt_after_render
      runtime - tintsearch_rt_after_render
    end

    def append_info_to_payload(payload)
      super
      payload[:tintsearch_runtime] = (tintsearch_runtime || 0) + Tintsearch::LogSubscriber.reset_runtime
    end

    module ClassMethods
      def log_process_action(payload)
        messages = super
        runtime = payload[:tintsearch_runtime]
        messages << ("Tintsearch: %.1fms" % runtime.to_f) if runtime.to_f > 0
        messages
      end
    end
  end
end
Tintsearch::Query.send(:prepend, Tintsearch::QueryWithInstrumentation)
Tintsearch::Index.send(:prepend, Tintsearch::IndexWithInstrumentation)
Tintsearch.singleton_class.send(:prepend, Tintsearch::TintsearchWithInstrumentation)
Tintsearch::LogSubscriber.attach_to :tintsearch
ActiveSupport.on_load(:action_controller) do
  include Tintsearch::ControllerRuntime
end
