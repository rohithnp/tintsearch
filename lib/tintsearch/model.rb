module Tintsearch
  module Reindex; end # legacy for Searchjoy

  module Model
    def tintsearch(options = {})
      raise "Only call tintsearch once per model" if respond_to?(:tintsearch_index)

      Tintsearch.models << self

      class_eval do
        cattr_reader :tintsearch_options, :tintsearch_klass

        callbacks = options.key?(:callbacks) ? options[:callbacks] : true

        class_variable_set :@@tintsearch_options, options.dup
        class_variable_set :@@tintsearch_klass, self
        class_variable_set :@@tintsearch_callbacks, callbacks
        class_variable_set :@@tintsearch_index, options[:index_name] || [options[:index_prefix], model_name.plural, Tintsearch.env].compact.join("_")

        class << self
          def tintsearch_search(term = nil, options = {}, &block)
            tintsearch_index.search_model(self, term, options, &block)
          end
          alias_method Tintsearch.search_method_name, :tintsearch_search if Tintsearch.search_method_name

          def tintsearch_index
            index = class_variable_get :@@tintsearch_index
            index = index.call if index.respond_to? :call
            Tintsearch::Index.new(index, tintsearch_options)
          end

          def enable_search_callbacks
            class_variable_set :@@tintsearch_callbacks, true
          end

          def disable_search_callbacks
            class_variable_set :@@tintsearch_callbacks, false
          end

          def search_callbacks?
            class_variable_get(:@@tintsearch_callbacks) && Tintsearch.callbacks?
          end

          def tintsearch_reindex(options = {})
            unless options[:accept_danger]
              if (respond_to?(:current_scope) && respond_to?(:default_scoped) && current_scope && current_scope.to_sql != default_scoped.to_sql) ||
                (respond_to?(:queryable) && queryable != unscoped.with_default_scope)
                raise Tintsearch::DangerousOperation, "Only call reindex on models, not relations. Pass `accept_danger: true` if this is your intention."
              end
            end
            tintsearch_index.reindex_scope(tintsearch_klass, options)
          end
          alias_method :reindex, :tintsearch_reindex unless method_defined?(:reindex)

          def clean_indices
            tintsearch_index.clean_indices
          end

          def tintsearch_import(options = {})
            (options[:index] || tintsearch_index).import_scope(tintsearch_klass)
          end

          def tintsearch_create_index
            tintsearch_index.create_index
          end

          def tintsearch_index_options
            tintsearch_index.index_options
          end
        end
        extend Tintsearch::Reindex # legacy for Searchjoy

        callback_name = callbacks == :async ? :reindex_async : :reindex
        if respond_to?(:after_commit)
          after_commit callback_name, if: proc { self.class.search_callbacks? }
        elsif respond_to?(:after_save)
          after_save callback_name, if: proc { self.class.search_callbacks? }
          after_destroy callback_name, if: proc { self.class.search_callbacks? }
        end

        def reindex
          self.class.tintsearch_index.reindex_record(self)
        end unless method_defined?(:reindex)

        def reindex_async
          self.class.tintsearch_index.reindex_record_async(self)
        end unless method_defined?(:reindex_async)

        def similar(options = {})
          self.class.tintsearch_index.similar_record(self, options)
        end unless method_defined?(:similar)

        def search_data
          respond_to?(:to_hash) ? to_hash : serializable_hash
        end unless method_defined?(:search_data)

        def should_index?
          true
        end unless method_defined?(:should_index?)
      end
    end
  end
end
