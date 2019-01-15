require "faraday/middleware"

module Tintsearch
  class Middleware < Faraday::Middleware
    def call(env)
      if env[:method] == :get && env[:url].path.to_s.end_with?("/_search")
        env[:request][:timeout] = Tintsearch.search_timeout
      end
      @app.call(env)
    end
  end
end
