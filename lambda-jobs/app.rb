require 'rmagick'
require 'net/http'
require 'json'
require 'aws-sdk-dynamodb'
require 'aws-sdk-s3'
require 'fastimage'
require 'aws-sdk-rekognition'

include Magick

module LambdaFunction
  class Handler
    def self.process(event:, context:)
      # Create a DynamoDB client
      dynamodb = Aws::DynamoDB::Client.new(region: 'ap-northeast-1')
      s3 = Aws::S3::Client.new(region: 'ap-northeast-1')

      url = case event['source']
      when 'unsplash'
        # Get an random photo from Unsplash API
        # URL: https://api.unsplash.com/photos/random?query=anime
        URI("https://api.unsplash.com/search/photos?query=#{event['keyword']}&order_by=latest&per_page=100&client_id=#{ENV["UNSPLASH_API_KEY"]}")
      when 'giphy'
        # Get random GIFs from Giphy API
        # URL: https://api.giphy.com/v1/gifs/search?api_key=&q=lgtm&limit=50&offset=0&rating=g&lang=en&bundle=messaging_non_clips
        URI("https://api.giphy.com/v1/gifs/random?api_key=#{ENV["GIPHY_API_KEY"]}&tag=#{event['keyword']}")
      else
        puts "[#process] Error: Invalid source"
        return { "success": false }
      end

      puts "[#process] Sending request to URL: #{url}"

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

      formatted_results = case event['source']
                        when 'giphy'
                          # Parse the JSON response
                          json_data = JSON.parse(response.body)

                          result = json_data["data"]

                          [{
                            'id' => result["id"],
                            'url' => result["images"]["original"]["url"],
                            'source' => 'giphy',
                          }]
                        when 'unsplash'
                          # Parse the JSON response
                          json_data = JSON.parse(response.body)

                          results = json_data["results"]

                          results.map do |result|
                            {
                              'id' => result["id"],
                              'url' => result["urls"]["full"],
                              'source' => 'unsplash'
                            }
                          end
                        else
                          puts "[#process] Error: Invalid source"
                          return { "success": false }
                        end

      formatted_results.each do |result|
        id = result["id"]
        url = result["url"]
        source = result["source"]

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
        img, original_img_first_frame = case image_type
        when :gif
          img = Magick::ImageList.new(url)

          # Resize the image
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

          [img, img.first]
        when :jpeg, :png, :jpg
          # Read the image
          img = Magick::Image.read(url).first

          # Resize the image to ratio (landscape)
          img = img.resize_to_fill(800, 600)

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

          [img, img]
        else
          puts "[#process] Error: Invalid image type #{image_type}. Skipping..."
          next
        end

        # Upload the images (original and processed) to S3
        puts "[#process] Uploading image to S3"
        s3.put_object({
          bucket: "lgtm-tonystrawberry-codes",
          key: "lgtm/#{id}.#{image_type}",
          body: img.to_blob,
          content_type: "image/#{image_type}"
        })

        s3.put_object({
          bucket: "lgtm-tonystrawberry-codes",
          key: "lgtm/#{id}-original.jpg",
          body: original_img_first_frame.to_blob,
          content_type: "image/jpeg"
        })

        # Analyze the image using Rekognition
        puts "[#process] Analyzing image using Rekognition"
        rekognition = Aws::Rekognition::Client.new(region: 'ap-northeast-1')

        response = rekognition.detect_labels({
          image: {
            s3_object: {
              bucket: "lgtm-tonystrawberry-codes",
              name: "lgtm/#{id}-original.jpg"
            }
          },
        })

        # Get the labels from the response (whose confidence is greater than 80%)
        labels = response.labels.map do |label|
          if label.confidence > 80
            label.name
          end
        end.compact

        puts "[#process] Saving image info to DynamoDB"
        # Save the image info to DynamoDB
        dynamodb.put_item({
          table_name: "lgtm-tonystrawberry-codes",
          item: {
            'id' => id,
            'source' => source,
            'url' => url,
            's3_key' => "lgtm/#{id}.#{image_type}",
            'keyword' => event['keyword'],
            'labels' => labels,
            'status' => "processed",
            'created_at' => Time.now.to_i.to_s
          }
        })
      end

      { "success": true }
    end
  end
end
