require 'rmagick'
require 'net/http'
require 'json'
require 'aws-sdk-dynamodb'
require 'aws-sdk-s3'
require 'fastimage'

include Magick

dynamodb = Aws::DynamoDB::Client.new(region: 'ap-northeast-1')
s3 = Aws::S3::Client.new(region: 'ap-northeast-1')

keywords = [
  "lgtm",
  "funny",
  "good job",
  "congratulations",
  "well done",
  "nice",
  "great",
  "awesome",
  "amazing",
  "bravo",
  "outstanding",
  "impressive",
  "exceptional",
  "superb",
  "splendid",
  "marvelous",
  "terrific",
  "phenomenal",
  "stellar"
]

offset = 0
limit = 50

while offset < 5000 do
  images = []

  keywords.each do |keyword|
    url = URI("https://api.giphy.com/v1/gifs/search?api_key=#{ENV["GIPHY_API_KEY"]}&q=#{keyword}&limit=#{limit}&offset=#{offset}&rating=g&lang=en&bundle=messaging_non_clips&sort=newest")

    # Create an HTTP client
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = (url.scheme == 'https')

    # Create the GET request with the specified headers
    request = Net::HTTP::Get.new(url)

    # Send the request and get the response
    response = http.request(request)

    puts "[#process] Received response from API: #{response}"

    # Check if the response is successful (HTTP status 200)
    if !response.is_a?(Net::HTTPSuccess)
      puts "Error: #{response.code} - #{response.message}"
      return
    end

    puts "[#process] Parsing response from API"

    # Parse the JSON response
    json_data = JSON.parse(response.body)

    results = json_data["data"]
    formatted_results = results.map do |result|
      {
        'id' => result["id"],
        'url' => result["images"]["original"]["url"],
        'source' => 'giphy',
        'keyword' => keyword
      }
    end

    # Append the formatted results to the images array
    images += formatted_results
  end

  # Shuffle the images array
  images.shuffle!

  images.each do |image|
    id = image["id"]
    url = image["url"]
    source = image["source"]
    keyword = image["keyword"]

    # Check if the image is already processed before (in DynamoDB)
    response = dynamodb.get_item({
      table_name: "lgtm-tonystrawberry-codes",
      key: {
        'id' => id,
        'source' => source
      }
    })

    if !response.item.nil?
      puts "[#process] Image #{id} is already processed before, skipping..."
      next
    end

    puts "[#process] Reading image from URL: #{url}"

    image_type = FastImage.type(url)
    img = case image_type
    when :gif
      img = Magick::ImageList.new(url)

      img = img.coalesce

      img.each do |x|
        x.resize_to_fill!(400, 300)
      end

      img = img.optimize_layers( Magick::OptimizeLayer )

      # Create a drawing object
      draw = Magick::Draw.new
      draw.font_family = "Georgia"
      draw.pointsize = 100
      draw.gravity = Magick::CenterGravity

      # Annotate the image with the provided text
      img.each do |frame|
        frame.annotate(draw, 0, 0, 0, 60, "LGTM") { |options|
          options.fill = "white"
          options.font_weight = 350
        }
      end

      draw = Magick::Draw.new
      draw.font_family = "Georgia"
      draw.pointsize = 25
      draw.gravity = Magick::CenterGravity
      draw.font_stretch = Magick::UltraExpandedStretch

      img.each do |frame|
        frame.annotate(draw, 0, 0, 0, 115, "Looks Great To Me") { |options|
          options.fill = "white"
        }
      end

      img
    when :jpeg, :png, :jpg
      # Read the image
      img = Magick::Image.read(url).first

      # Create a drawing canvas
      draw = Magick::Draw.new
      draw.font_family = "Georgia"
      draw.pointsize = 200
      draw.gravity = Magick::CenterGravity

      # Annotate the image
      draw.annotate(img, 0, 0, 0, 40, "LGTM") { |options|
        options.fill = "white"
        options.font_weight = 700
      }

      draw = Magick::Draw.new
      draw.font_family = "Georgia"
      draw.pointsize = 50
      draw.gravity = Magick::CenterGravity
      draw.font_stretch = Magick::UltraExpandedStretch

      draw.annotate(img, 0, 0, 0, 150, "Looks Great To Me") { |options|
        options.fill = "white"
      }

      img
    else
      puts "[#process] Error: Invalid image type #{image_type}. Skipping..."
      next
    end

    # Upload the image to S3
    puts "[#process] Uploading image to S3"
    s3.put_object({
      bucket: "lgtm-tonystrawberry-codes",
      key: "lgtm/#{id}.#{image_type}",
      body: img.to_blob
    })

    puts "[#process] Saving image info to DynamoDB"
    # Save the image info to DynamoDB
    dynamodb.put_item({
      table_name: "lgtm-tonystrawberry-codes",
      item: {
        'id' => id,
        'source' => source,
        'url' => url,
        's3_key' => "lgtm/#{id}.#{image_type}",
        'keyword' => keyword,
        'status' => "processed",
        'created_at' => Time.now.to_i.to_s
      }
    })
  end

  offset += limit
end

{ success: true }
