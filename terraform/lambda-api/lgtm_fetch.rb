require 'aws-sdk-dynamodb'

# Lambda handler for the API Gateway endpoint
# It returns the list of processed images from DynamoDB (cursor-based pagination)
# It also returns the next cursor_created_at value for the next page
def lambda_handler(event:, context:)
  # Whitelisted origins
  allowed_origins = [
    'http://localhost:3001',
    'https://lgtmarvelous.vercel.app'
  ]

  table_name = 'lgtm-tonystrawberry-codes' # Table containing the metadata of the processed images
  page_size = 12 # Number of items per page
  cursor_created_at = event.dig('queryStringParameters', 'cursor_created_at') # Cursor value for the next page (nullable)
  origin = event.dig('headers', 'origin') # Origin of the request

  dynamodb = Aws::DynamoDB::Client.new(region: 'ap-northeast-1')

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

  begin
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
  rescue Aws::DynamoDB::Errors::ServiceError => error
    return {
      error: error.message
    }
  end
end