require 'aws-sdk-dynamodb'
require 'opensearch-aws-sigv4'

# Lambda handler for the API Gateway endpoint
# It returns the list of processed images from DynamoDB (cursor-based pagination)
# It also returns the next cursor_created_at value for the next page
def lambda_handler(event:, context:)
  opensearch_host = "https://search-lgtm-tonystrawberry-codes-7wakghxg7b6vvsfwyfkarv7htm.ap-northeast-1.es.amazonaws.com"
  opensearch_index_name = "lgtm-images"
  table_name = 'lgtm-tonystrawberry-codes' # Table containing the metadata of the processed images
  page_size = 12 # Number of items per page

  begin
    # Whitelisted origins
    allowed_origins = [
      'http://localhost:3001',
      'https://lgtmarvelous.vercel.app'
    ]

    cursor_created_at = event.dig('queryStringParameters', 'cursor_created_at') # Cursor value for the next page (nullable)
    origin = event.dig('headers', 'origin') # Origin of the request
    ids = event.dig('queryStringParameters', 'ids') # IDs of the images to fetch
    keywords = event.dig('queryStringParameters', 'keywords') # Keywords to search for

    dynamodb = Aws::DynamoDB::Client.new(region: 'ap-northeast-1')

    # If IDs are provided, fetch the images by IDs
    if ids
      request_items = {
        table_name => {
          keys: ids.split(',').map do |id|
            {
              id: id,
              source: 'giphy'
            }
          end
        }
      }

      response = dynamodb.batch_get_item(request_items: request_items)

      items = response.responses[table_name].map do |item|
        {
          id: item['id'],
          keyword: item['keyword'],
          image_url: "https://#{ENV["CLOUDFRONT_DISTRIBUTION_URL"]}/#{item['s3_key']}"
        }
      end

      return {
        statusCode: 200,
        headers: {
          "Access-Control-Allow-Headers": "Content-Type",
          "Access-Control-Allow-Origin": allowed_origins.include?(origin) ? origin : allowed_origins[0],
          "Access-Control-Allow-Methods": "GET,OPTIONS",
        },
        body: {
          items: items
        }.to_json
      }
    elsif keywords
      # Fetch the images by keywords with ElasticSearch
      url = "#{opensearch_host}/#{opensearch_index_name}/_search"
      uri = URI(url)
      request = Net::HTTP::POST.new(uri)

      body = {
        "query": {
          "fuzzy": {
            "keywords": {
              "value": keywords,
              "fuzziness": 2
            }
          }
        }
      }.to_json

      # Signature Version 4
      signature = Aws::Sigv4::Signer.new(
        service: 'es',
        region: 'ap-northeast-1',
        access_key_id: ENV['AWS_ACCESS_KEY_ID'],
        secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
        # session_token: ENV['AWS_SESSION_TOKEN']
      ).sign_request(
        http_method: 'POST',
        url: url,
        body: body
      )

      request.body = body

      response = Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
        http.request(request)
      end

      hits_ids = JSON.parse(response.body)['hits']['hits'].map { |hit| hit['_id'] }

      # Fetch the images by IDs
      request_items = {
        table_name => {
          keys: hits_ids.map do |id|
            {
              id: id,
              source: 'giphy'
            }
          end
        }
      }

      response = dynamodb.batch_get_item(request_items: request_items)

      items = response.responses[table_name].map do |item|
        {
          id: item['id'],
          keyword: item['keyword'],
          image_url: "https://#{ENV["CLOUDFRONT_DISTRIBUTION_URL"]}/#{item['s3_key']}"
        }
      end

      return {
        statusCode: 200,
        headers: {
          "Access-Control-Allow-Headers": "Content-Type",
          "Access-Control-Allow-Origin": allowed_origins.include?(origin) ? origin : allowed_origins[0],
          "Access-Control-Allow-Methods": "GET,OPTIONS",
        },
        body: {
          items: items
        }.to_json
      }
    else
      # Fetch the images by cursor
      params = {
        table_name: table_name,
        index_name: 'status-created_at-index', # Replace with your GSI name
        key_condition_expression: '#status = :status',
        expression_attribute_names: {'#status' => 'status'},
        expression_attribute_values: {':status' => 'processed'}, # Replace with the desired status value
        limit: page_size,
        scan_index_forward: false # Sort by descending order (newest first)
      }

      # If a cursor is provided, add a condition for created_at
      if cursor_created_at
        params[:key_condition_expression] += ' AND #created_at < :created_at'
        params[:expression_attribute_names]['#created_at'] = 'created_at'
        params[:expression_attribute_values][':created_at'] = cursor_created_at
      end

      response = dynamodb.query(params)
      items = response.items.map do |item|
        {
          id: item['id'],
          keyword: item['keyword'],
          image_url: "https://#{ENV["CLOUDFRONT_DISTRIBUTION_URL"]}/#{item['s3_key']}"
        }
      end

      last_evaluated_key = response.last_evaluated_key

      return {
        statusCode: 200,
        headers: {
          "Access-Control-Allow-Headers": "Content-Type",
          "Access-Control-Allow-Origin": allowed_origins.include?(origin) ? origin : allowed_origins[0],
          "Access-Control-Allow-Methods": "GET,OPTIONS",
        },
        body: {
          items: items,
          has_more: !last_evaluated_key.nil?,
          next_cursor_created_at: last_evaluated_key ? last_evaluated_key&.[]('created_at') : nil
        }.to_json
      }
    end
  rescue StandardError => error
    puts "[#lambda_handler] #{error}"

    return {
      statusCode: 500,
      headers: {
        "Access-Control-Allow-Headers": "Content-Type",
        "Access-Control-Allow-Origin": allowed_origins.include?(origin) ? origin : allowed_origins[0],
        "Access-Control-Allow-Methods": "GET,OPTIONS",
      },
      body: {
        message: error.message
      }.to_json
    }
  end
end
