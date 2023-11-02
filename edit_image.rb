require 'rmagick'
require 'net/http'
require 'json'

def add_text_to_image(keyword)
  # Get an random photo from Unsplash API
  # URL: https://api.unsplash.com/photos/random?query=anime
  url = URI("https://api.unsplash.com/search/photos?query=#{keyword}&order_by=latest&per_page=100&client_id=pxFQo3NQxrw4iuK_NasOCls0bACZ9sRCTqqj7zrsK2E")

  # Create an HTTP client
  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = (url.scheme == 'https')

  # Create the GET request with the specified headers
  request = Net::HTTP::Get.new(url)

  # Send the request and get the response
  response = http.request(request)

  # Check if the response is successful (HTTP status 200)
  if !response.is_a?(Net::HTTPSuccess)
    puts "Error: #{response.code} - #{response.message}"
    return
  end

  # Parse the JSON response
  json_data = JSON.parse(response.body)

  results = json_data["results"]
  results.each do |result|
    id = result["id"]
    url = result["urls"]["full"]

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

    # TODO: Upload the image to S3
  end
end
