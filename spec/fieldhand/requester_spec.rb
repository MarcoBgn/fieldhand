require 'fieldhand/requester'

module Fieldhand
  RSpec.describe Requester do
    describe '#request' do
      it 'returns successful responses' do
        stub_oai_request('http://www.example.com/oai', 'list_identifiers.xml')

        http = ::Net::HTTP.new('www.example.com', 80)
        requester = described_class.new(http, URI('http://www.example.com/oai'))

        expect(requester.request).to be_a(::Net::HTTPSuccess)
      end

      it 'raises an error if the request fails' do
        stub_request(:get, 'http://www.example.com/oai').
          to_return(:status => 503)

        http = ::Net::HTTP.new('www.example.com', 80)
        requester = described_class.new(http, URI('http://www.example.com/oai'))

        expect { requester.request }.to raise_error(ResponseError)
      end

      it 'retries failing requests when configured to do so' do
        stub_request(:get, 'http://www.example.com/oai').
          to_return({ :status => 503 }, { :status => 200 })

        http = ::Net::HTTP.new('www.example.com', 80)
        requester = described_class.new(http, URI('http://www.example.com/oai'), :retries => 1, :interval => 0)

        expect(requester.request).to be_a(::Net::HTTPSuccess)
      end

      it 'raises an error if the maximum number of retries is exceeded' do
        stub_request(:get, 'http://www.example.com/oai').
          to_return({ :status => 503 }, { :status => 503 })

        http = ::Net::HTTP.new('www.example.com', 80)
        requester = described_class.new(http, URI('http://www.example.com/oai'), :retries => 1, :interval => 0)

        expect { requester.request }.to raise_error(ResponseError)
      end
    end
  end
end
