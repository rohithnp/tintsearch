require "rake"

namespace :tintsearch do
  desc "reindex model"
  task reindex: :environment do
    if ENV["CLASS"]
      klass = ENV["CLASS"].constantize rescue nil
      if klass
        klass.reindex
      else
        abort "Could not find class: #{ENV['CLASS']}"
      end
    else
      abort "USAGE: rake tintsearch:reindex CLASS=Product"
    end
  end

  if defined?(Rails)

    namespace :reindex do
      desc "reindex all models"
      task all: :environment do
        Rails.application.eager_load!
        Tintsearch.models.each do |model|
          puts "Reindexing #{model.name}..."
          model.reindex
        end
        puts "Reindex complete"
      end
    end

  end
end
