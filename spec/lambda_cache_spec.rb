require 'uri'
require 'net/http'
require 'spec_helper'
require_relative  '../lib/cache_proxy'

describe 'Lambda function' do
  describe '#origin_response' do
    let(:uri) { URI('https://www.example.com/path?query=string') }
    let(:request) do
      {
        'uri' => '/path',
        'querystring' => 'query=string',
        'headers' => { 'Host' => [{ 'value' => 'www.example.com' }] }
      }
    end

    before do
      allow(URI).to receive(:parse).with("#{request['uri']}?#{request['querystring']}").and_return(uri)
    end

    subject { CacheProxy.new }

    it 'returns a Net::HTTPResponse object' do
      expect(subject.origin_response(request)).to be_a(Net::HTTPResponse)
    end

    it 'sets the headers of the origin request' do
      expect_any_instance_of(Net::HTTP::Get).to receive(:[]=).with('Host', 'www.example.com')
      subject.origin_response(request)
    end

    it 'makes a request to the correct URL' do
      expect(Net::HTTP).to receive(:start).with(uri.hostname, uri.port, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_PEER)
      subject.origin_response(request)
    end
  end
end
