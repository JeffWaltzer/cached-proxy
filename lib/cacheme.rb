require 'json'
require 'net/http'
require 'openssl'
require 'aws-sdk-dynamodb'

# Set up a cache using AWS DynamoDB
dynamodb = Aws::DynamoDB::Client.new
cache_table_name = "cache-table"
cache_table = Aws::DynamoDB::Table.new(cache_table_name)

def lambda_handler(event:, context:)
  # Extract the request parameters from the event
  request = event['Records'][0]['cf']['request']
  headers = request['headers']
  query_string = request['querystring']
  uri = request['uri']

  # Generate a cache key for this request
  cache_key = Digest::MD5.hexdigest(uri + query_string)

  # Check if the response is already in the cache
  begin
    response = cache_table.get_item(key: { cache_key: cache_key })
    if response.item
      # If the response is in the cache, return it
      return {
        status: '200',
        statusDescription: 'OK',
        headers: {
          'cache-hit': [{
                          key: 'Cache-Hit',
                          value: 'true'
                        }]
        },
        body: response.item['response_body']
      }
    end
  rescue Aws::DynamoDB::Errors::ServiceError => e
    puts "Error getting item from cache: #{e}"
  end

  # If the response is not in the cache, make the request to the origin
  begin
    origin_url = "#{uri}?#{query_string}"
    origin_uri = URI(origin_url)
    origin_request = Net::HTTP::Get.new(origin_uri)
    headers.each do |name, value|
      origin_request[name] = value[0]['value']
    end
    origin_response = Net::HTTP.start(origin_uri.hostname, origin_uri.port, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_PEER) {|http| http.request(origin_request)}
    origin_response_body = origin_response.body
    origin_status_code = origin_response.code

    # Add the response to the cache
    cache_table.put_item(item: {
      cache_key: cache_key,
      response_body: origin_response_body
    })

    # Return the response from the origin
    return {
      status: origin_status_code,
      statusDescription: 'OK',
      headers: {
        'cache-hit': [{
                        key: 'Cache-Hit',
                        value: 'false'
                      }]
      },
      body: origin_response_body
    }

  rescue StandardError => e
    return {
      status: '500',
      statusDescription: 'Error',
      body: "Error: #{e}"
    }
  end
end
