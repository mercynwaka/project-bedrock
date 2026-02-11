Bedrock Retail Storefront
Capstone Project: barakat-2025-capstone
This project demonstrates a fully functional, microservices-based retail application deployed on Amazon EKS (Elastic Kubernetes Service). The infrastructure is managed entirely via Terraform and follows a GitOps workflow.

System Architecture
The application is built using a microservices architecture to ensure scalability and fault tolerance.

UI (Frontend): A Spring Boot application that serves the web interface.

Catalog Service: Manages product information (watches) backed by a MySQL database.

Carts Service: Manages user shopping carts using Amazon DynamoDB.

Orders Service: Processes customer checkouts using a PostgreSQL database and RabbitMQ for messaging

Cloud Native Features
1. Automated Asset Processing
The project includes a serverless component for handling store assets. When an image or file is uploaded to the project's S3 bucket, a Lambda function (bedrock-asset-processor) is automatically triggered to process the metadata.

2. Global Infrastructure Tagging
Every resource in this deployment—from the EKS cluster to the S3 buckets—is strictly tagged for cost tracking and project management.

Tag Key: Project

Tag Value: barakat-2025-capstone

3. Infrastructure as Code (IaC)
The entire environment is defined in Terraform, allowing for:

Reproducibility: One command to spin up or tear down the entire stack.

Security: IAM roles and policies are defined with "Least Privilege" for service-to-service communication.

Components Summary

Component,Technology,Description
Orchestration,Kubernetes (EKS),Manages container lifecycles and scaling.
Compute,AWS Lambda,Serverless asset processing logic.
Storage,S3 & DynamoDB,Object storage for assets and NoSQL for carts.
Networking,AWS ALB,High-availability Load Balancer for the UI.
Database,MySQL & Postgres,Relational data for products and orders.

How to Verify the Integration
Access the Store: Visit the Load Balancer URL to browse the watch catalog.

Test the Lambda: * Upload a file to the S3 bucket: barakat-2025-capstone-assets-...

Check CloudWatch Logs for the bedrock-asset-processor function.

Confirm the log entry: "Image received: [your-filename]".

Check Tags: View any resource in the AWS Console to see the barakat-2025-capstone project tag applied via the provider's default_tags.
