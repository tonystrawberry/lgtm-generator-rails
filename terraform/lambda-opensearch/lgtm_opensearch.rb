require 'opensearch-aws-sigv4'
require 'json'

# OpenSearch client for interacting with Amazon OpenSearch Service
# It uses the OpenSearch AWS SigV4 gem to sign the requests
# See:
# https://zenn.dev/match8969/articles/ef89c1b9451e03
class OpenSearchClient
  require 'aws-sdk-opensearchservice'

  def self.request(http_method, url, body)
    uri = URI(url)

    case http_method
    when 'GET' then
      request = Net::HTTP::Get.new(uri)
    when 'POST' then
      request = Net::HTTP::Post.new(uri)
    when 'PUT' then
      request = Net::HTTP::Put.new(uri)
    when 'DELETE' then
      request = Net::HTTP::Delete.new(uri)
    else
      request = Net::HTTP::Post.new(uri)
    end

    # Signature Version 4
    signature = Aws::Sigv4::Signer.new(
      service: 'es',
      region: 'ap-northeast-1',
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
      session_token: ENV['AWS_SESSION_TOKEN']
    ).sign_request(
      http_method: http_method,
      url: url,
      body: body
    )

    # Set the request body and headers
    request.body = body
    request['Host'] = signature.headers['host']
    request['X-Amz-Date'] = signature.headers['x-amz-date']
    request['X-Amz-Security-Token'] = signature.headers['x-amz-security-token']
    request['X-Amz-Content-Sha256']= signature.headers['x-amz-content-sha256']
    request['Authorization'] = signature.headers['authorization']
    request['Content-Type'] = 'application/json'

    begin
      Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
        http.request(request)
      end
    rescue => e
      puts "[#OpenSearchClient.request] Error: #{e}"
    end
  end
end

def lambda_handler(event:, context:)
  count = 0
  opensearch_host = "https://search-lgtm-tonystrawberry-codes-7wakghxg7b6vvsfwyfkarv7htm.ap-northeast-1.es.amazonaws.com"
  index_name = "lgtm-images"

  event['Records'].each do |record|
    # Get the primary key for use as the OpenSearch ID
    id = record['dynamodb']['Keys']['id']['S']

    if record['eventName'] == 'REMOVE'
      url = "#{opensearch_host}/#{index_name}/_doc/#{id}"
      response = OpenSearchClient.request('DELETE', url, {}.to_json)
    else
      document = record['dynamodb']['NewImage']
      url = "#{opensearch_host}/#{index_name}/_doc/#{id}"
      response = OpenSearchClient.request('PUT', url, document.to_json)
    end

    count += 1
  end

  "[#lambda_handler] #{count} records processed."
end
