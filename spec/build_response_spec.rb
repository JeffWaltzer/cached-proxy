require 'uri'
require 'net/http'
require 'spec_helper'
require_relative  '../lib/cache_proxy'


RSpec.describe 'Lambda function' do
  describe '#build_response' do
    subject {CacheProxy.new}
    it 'returns a Hash with the expected keys' do
      response = subject.build_response(200, 'OK', cached: true)
      expect(response).to include(:status, :statusDescription, :headers, :body)
      expect(response[:headers].keys).to include(:'cache-hit')
      expect(response[:headers][:'cache-hit'][0]).to include(key: 'Cache-Hit', value: 'true')
    end
  end
end
