require "active_model"
require "elasticsearch"
require "hashie"
require "tintsearch/version"
require "tintsearch/index"
require "tintsearch/results"
require "tintsearch/query"
require "tintsearch/reindex_job"
require "tintsearch/model"
require "tintsearch/tasks"
require "tintsearch/middleware"
require "tintsearch/logging" if defined?(ActiveSupport::Notifications)

# background jobs
begin
  require "active_job"
rescue LoadError
  # do nothing
end
require "tintsearch/reindex_v2_job" if defined?(ActiveJob)

module Tintsearch
  class Error < StandardError; end
  class MissingIndexError < Error; end
  class UnsupportedVersionError < Error; end
  class InvalidQueryError < Elasticsearch::Transport::Transport::Errors::BadRequest; end
  class DangerousOperation < Error; end
  class ImportError < Error; end

  class << self
    attr_accessor :search_method_name, :wordnet_path, :timeout, :models
    attr_writer :client, :env, :search_timeout
  end
  self.search_method_name = :tint_search
  self.wordnet_path = "/var/lib/wn_s.pl"
  self.timeout = 10
  self.models = []

  def self.client
    @client ||=
      Elasticsearch::Client.new(
        url: ENV["TINTSEARCH_URL"],
        transport_options: {request: {timeout: timeout}}
      ) do |f|
        f.use Tintsearch::Middleware
      end
  end

  def self.env
    @env ||= ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
  end

  def self.search_timeout
    @search_timeout || timeout
  end

  def self.server_version
    @server_version ||= client.info["version"]["number"]
  end

  def self.enable_callbacks
    self.callbacks_value = nil
  end

  def self.disable_callbacks
    self.callbacks_value = false
  end

  def self.callbacks?
    Thread.current[:tintsearch_callbacks_enabled].nil? || Thread.current[:tintsearch_callbacks_enabled]
  end

  def self.callbacks(value)
    if block_given?
      previous_value = callbacks_value
      begin
        self.callbacks_value = value
        yield
        perform_bulk if callbacks_value == :bulk
      ensure
        self.callbacks_value = previous_value
      end
    else
      self.callbacks_value = value
    end
  end

  # private
  def self.queue_items(items)
    queued_items.concat(items)
    perform_bulk unless callbacks_value == :bulk
  end

  # private
  def self.perform_bulk
    items = queued_items
    clear_queued_items
    perform_items(items)
  end

  # private
  def self.perform_items(items)
    if items.any?
      response = client.bulk(body: items)
      if response["errors"]
        first_item = response["items"].first
        raise Tintsearch::ImportError, (first_item["index"] || first_item["delete"])["error"]
      end
    end
  end

  # private
  def self.queued_items
    Thread.current[:tintsearch_queued_items] ||= []
  end

  # private
  def self.clear_queued_items
    Thread.current[:tintsearch_queued_items] = []
  end

  # private
  def self.callbacks_value
    Thread.current[:tintsearch_callbacks_enabled]
  end

  # private
  def self.callbacks_value=(value)
    Thread.current[:tintsearch_callbacks_enabled] = value
  end

  def self.search(term = nil, options = {}, &block)
    query = Tintsearch::Query.new(nil, term, options)
    block.call(query.body) if block
    if options[:execute] == false
      query
    else
      query.execute
    end
  end

  def self.multi_search(queries)
    if queries.any?
      responses = client.msearch(body: queries.flat_map { |q| [q.params.except(:body), q.body] })["responses"]
      queries.each_with_index do |query, i|
        query.handle_response(responses[i])
      end
    end
    nil
  end
end

# TODO find better ActiveModel hook
ActiveModel::Callbacks.send(:include, Tintsearch::Model)
ActiveRecord::Base.send(:extend, Tintsearch::Model) if defined?(ActiveRecord)
