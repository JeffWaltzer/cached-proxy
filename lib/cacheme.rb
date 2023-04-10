# frozen_string_literal: true

require 'cache_proxy'

def call(event:, context:)
  cache_proxy = CacheProxy.new
  request = event['Records'][0]['cf']['request']
  response = cache_proxy.cached_response(request) || origin_response(request)
  cache_proxy.build_response(response.code, response.body, cached: !!cached_response)
rescue StandardError => e
  cache_proxy.build_response(500, "Error: #{e}", cached: false)
end

