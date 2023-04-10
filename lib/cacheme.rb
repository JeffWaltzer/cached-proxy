# frozen_string_literal: true

def call(event:, context:)
  request = event['Records'][0]['cf']['request']
  response = cached_response(request) || origin_response(request)
  build_response(response.code, response.body, cached: !!cached_response)
rescue StandardError => e
  build_response(500, "Error: #{e}", cached: false)
end

private

def cached_response(request)
  cache_key = generate_cache_key(request['uri'], request['querystring'])
  response_body = dynamodb.get_item(key: { cache_key: }).item&.[]('response_body')
  return nil unless response_body

  build_response(200, response_body, cached: true)
rescue Aws::DynamoDB::Errors::ServiceError => e
  puts "Error getting item from cache: #{e}"
  nil
end

def origin_response(request)
  origin_url = "#{request['uri']}?#{request['querystring']}"
  origin_uri = URI(origin_url)
  origin_request = Net::HTTP::Get.new(origin_uri)

  request['headers'].each do |name, value|
    origin_request[name] = value[0]['value']
  end

  response = Net::HTTP.start(
    origin_uri.hostname,
    origin_uri.port,
    use_ssl: true,
    verify_mode: OpenSSL::SSL::VERIFY_PEER
  ) do |http|
    http.request(origin_request)
  end

  if response.code == '200'
    cache_key = generate_cache_key(request['uri'], request['querystring'])
    cache_response(cache_key, response.body)
  end

  response
end

def build_response(status_code,
                   body,
                   cached:)
  {
    status: status_code.to_s,
    statusDescription: 'OK',
    headers: {
      'cache-hit': [
        {
          key: 'Cache-Hit',
          value: cached.to_s
        }
      ]
    },
    body:
  }
end
