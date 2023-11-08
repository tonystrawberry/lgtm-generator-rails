<p align="center">
  <a href="https://lgtmarvelous.vercel.app">
    <img src="/logo.png" width="60" />
  </a>
</p>
<h1 align="center">
  lgtm.
</h1>

**lgtm** is a LGTM (Looks Good To Me) image collection application. Users can browse images and copy the URL of the image they like to the clipboard with a single click.

We need some **fun** in the world of software development. Let's make the world a more pleasant and friendly place with LGTM images!

## 📚 Technologies
```
Terraform
Cloudfront CDN with S3 (Origin Access Identity)
API Gateway + Lambda (Serverless)
EventBridge (Scheduled Event)
DynamoDB (NoSQL)
ImageMagick (Image Processing)
```

## 🔍 Structure
This repository contains the following directories.
- `terraform` contains the Terraform configuration files for the infrastructure.
  - We use API Gateway + Lambda for the serverless backend.
  - We use Cloudfront CDN with S3 for distributing the GIF images.
  - We use DynamoDB for storing the metadata of the GIF images and allowing the search feature.
  - We use EventBridge to schedule the Lambda function in `lambda-jobs` to fetch the latest LGTM images from the Giphy API every 5 minutes.
- `lambda-jobs` contains the Lambda function source code for the scheduled job that runs every 5 minutes to fetch the latest LGTM images from the Giphy API and then do some image processing to generate the thumbnail and preview images.

## 🛠 Local development

1. To test the `lambda-jobs` Lambda function locally, build the Docker image and run the container with the following commands.
```
$ docker build -t lgtm:latest .
$ docker run -p 9000:8080 -e AWS_ACCESS_KEY_ID=xxx -e AWS_SECRET_ACCESS_KEY=xxx -e GIPHY_API=xxx lgtm:latest
```

2. Create a DynamoDB table and a S3 bucket called `lgtm-tonystrawberry-codes`.
Make sure the DynamoDB has the same structure as the one defined in `terraform/modules/storage/main.tf`.

3. Call the local Lambda function with the following command.
```
$ curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{"source": "giphy", "keyword": "lgtm"}'
```

4. Check the DynamoDB table and the S3 bucket to see if the data is correctly stored.

## ⚙️ Deployment

The application is deployed to AWS with Terraform via Github Actions. The Github Actions workflow is triggered on every push to the `main` branch.

1. First, we deploy to ECR the Docker image for the `lambda-jobs` Lambda function (the one that is used to fetch the latest LGTM images from the Giphy API and then do some image processing to generate the thumbnail and preview images).
2. Then, we deploy the infrastructure with Terraform and use the Docker image from ECR as the Lambda function source code. It will also deploy the Cloudfront CDN with S3, API Gateway + Lambda, DynamoDB, and EventBridge.

## 🧐 Related Links
- https://stackoverflow.com/questions/77446420/how-to-give-permission-to-a-local-running-docker-container-lambda-function-acces?noredirect=1#comment136533460_77446420
