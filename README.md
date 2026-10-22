# Smart Inventory — Cloud & DevOps Project

A hands-on Cloud and DevOps project that combines a containerised inventory API, PostgreSQL, Infrastructure as Code, and a GitHub Actions CI/CD workflow using AWS.

The goal is to build a practical, reproducible deployment workflow, from local development to container image publishing and, eventually, a fully deployed AWS application.

## Project Overview

Smart Inventory is a REST API built with Node.js and Express, backed by PostgreSQL. The application runs locally using Docker Compose, while Terraform defines the AWS infrastructure required for a future cloud deployment.

GitHub Actions automates application checks, Terraform validation, Docker image builds, and publishing to Amazon Elastic Container Registry (ECR).

**Current milestone:** The CI/CD workflow successfully builds and publishes the Docker image to ECR. The wider AWS application infrastructure has been defined in Terraform but has not yet been fully deployed. Full deployment will follow after the CD workflow is completed and verified.

## Technology Stack

| Category | Technologies |
|---|---|
| Application | Node.js, Express.js |
| Database | PostgreSQL |
| Containerisation | Docker, Docker Compose |
| Infrastructure as Code | Terraform |
| Cloud Platform | Amazon Web Services (AWS) |
| Container Registry | Amazon ECR |
| CI/CD | GitHub Actions |
| AWS Authentication | IAM, GitHub Actions OIDC |
| Operating System | Linux / Ubuntu |
| Version Control | Git, GitHub |

## Architecture

### 1. Local Development Architecture

The application and database run as separate containers connected through a Docker Compose network.

```text
Developer
    |
    v
Smart Inventory API
(Node.js + Express)
    |
    v
PostgreSQL Database
```

Docker Compose manages the application, database, networking, environment configuration, and service dependencies.

### 2. CI/CD Architecture

GitHub Actions automates the validation, image build, and image-publishing process.

```text
GitHub Repository
        |
        v
   GitHub Actions
        |
        +----------------------+
        |                      |
        v                      v
 Application Checks     Terraform Checks
        |                      |
        +----------+-----------+
                   |
                   v
             Docker Build
                   |
                   v
        GitHub Actions OIDC
                   |
                   v
             AWS IAM Role
                   |
                   v
           Amazon ECR
                   |
                   v
        Versioned Docker Image
```

The workflow publishes images to Amazon ECR using both the full Git commit SHA and the `latest` tag.

The current pipeline does not deploy the application to EC2 or another runtime environment. That deployment stage remains part of the next milestone.

### 3. Planned AWS Application Architecture

Terraform defines the wider AWS architecture intended for the eventual deployment.

```text
                 Internet
                    |
                    v
       Application Load Balancer
                    |
                    v
              EC2 Instance
          Smart Inventory API
                    |
                    v
             RDS PostgreSQL
             Private Subnets
```

The planned infrastructure also includes:

- A VPC with public and private subnets across two Availability Zones.
- An Internet Gateway and public routing.
- Route tables and subnet associations.
- Separate security groups for the load balancer, API, and database.
- An RDS PostgreSQL database in private subnets.
- An Application Load Balancer and target group.
- An EC2 instance with an IAM instance profile.
- IAM permissions for retrieving database credentials from AWS Systems Manager Parameter Store or the configured secret source, as implemented in Terraform.
- GitHub Actions OIDC authentication and permissions for publishing Docker images to ECR.

**Deployment status:** These are the resources defined for the intended architecture, not a claim that the complete application infrastructure is already running in AWS.

## Application Features

The Smart Inventory API provides endpoints for interacting with inventory data.

### Root endpoint

```http
GET /
```

Returns a message confirming that the API is running.

### Health check

```http
GET /health
```

Provides a health-check endpoint for checking application availability and supporting the planned load balancer health check.

### Product listing

```http
GET /products
```

Supports product listing with query parameters for search, low-stock filtering, and pagination.

Examples:

```http
GET /products
GET /products?search=rice
GET /products?low_stock=true
GET /products?page=1&limit=10
```

The database connection is configured through environment variables rather than hard-coded application settings.

## Docker Compose

Docker Compose is used to run the application and PostgreSQL locally.

The Compose configuration has been validated successfully.

### Run locally

From the repository root:

```bash
docker compose up --build -d
```

Check container status:

```bash
docker compose ps
```

View application logs:

```bash
docker compose logs -f api
```

View database logs:

```bash
docker compose logs -f postgres
```

Stop the services:

```bash
docker compose down
```

These commands assume the Compose file is located at the repository root and the services are named `api` and `postgres`.

## Infrastructure as Code with Terraform

Terraform is used to define the AWS infrastructure required for the planned cloud deployment.

The configuration in `infrastructure/terraform/main.tf` declares resources and data sources for:

- VPC and subnet networking.
- Internet Gateway and route tables.
- Security groups.
- RDS PostgreSQL and its subnet group.
- EC2 compute and its IAM instance profile.
- Application Load Balancer, listener, target group, and target attachment.
- GitHub Actions OIDC federation and IAM permissions.
- The existing Amazon ECR repository used by the CI/CD workflow.

Terraform validation is part of the GitHub Actions pipeline.

### Deployment approach

The infrastructure will be deployed when the CD workflow is ready and the project is prepared for full AWS deployment.

Until then, the wider application infrastructure remains defined in code rather than fully deployed.

This approach allows the configuration and automation to be developed and validated before provisioning the complete application environment.

## Continuous Integration and Delivery

The GitHub Actions workflow is located at:

```text
.github/workflows/ci.yml
```

### Current pipeline stages

**1. Application checks**

- Checks out the repository.
- Sets up Node.js.
- Installs dependencies using `npm ci`.
- Checks JavaScript syntax.

**2. Terraform checks**

- Checks out the repository.
- Sets up Terraform.
- Checks Terraform formatting.
- Initialises Terraform without a backend.
- Validates the Terraform configuration.

**3. Docker build and image publishing**

- Builds the application Docker image on the GitHub-hosted runner.
- Uses GitHub Actions OIDC to authenticate with AWS on pushes to `main`.
- Assumes the configured AWS IAM role.
- Authenticates with Amazon ECR.
- Tags the image with the full commit SHA and `latest`.
- Pushes both tags to ECR.

The workflow runs application and Terraform checks for pushes and pull requests targeting `main`. Publishing to ECR is restricted to pushes to `main`.

### Current CD limitation

The existing workflow delivers the container image to ECR but does not yet deploy or update the running application infrastructure.

The next phase is to complete and verify the deployment workflow before provisioning the full AWS application environment.

## AWS Resources and Current Status

The following table distinguishes confirmed setup from planned deployment.

| Component | Current status |
|---|---|
| VPC | Created in AWS |
| GitHub Actions OIDC provider | Created in AWS |
| GitHub Actions IAM role and ECR policy | Created in AWS |
| Amazon ECR repository | Existing repository; image publishing verified |
| Docker image | Successfully published with `latest` and commit-SHA tags |
| Local Docker Compose | Configuration validation passed |
| Application EC2 instance | Defined in Terraform; full deployment pending |
| RDS PostgreSQL | Defined in Terraform; full deployment pending |
| Application Load Balancer | Defined in Terraform; full deployment pending |
| Remaining application networking and security resources | Defined in Terraform; full deployment pending |
| Automatic AWS application deployment | Not yet completed |

The current Terraform state tracks the VPC, GitHub OIDC provider, GitHub Actions IAM role and ECR policy, and the ECR repository data source. The wider infrastructure configuration has not yet been fully deployed.

## Repository Structure

```text
Smart-Inventory-DevOps/
├── application/
│   ├── server.js
│   ├── package.json
│   ├── package-lock.json
│   └── src/
│       └── db.js
├── infrastructure/
│   └── terraform/
│       └── main.tf
├── .github/
│   └── workflows/
│       └── ci.yml
├── docker-compose.yml
└── README.md
```

The exact Terraform and Compose file names should match the files present in the repository.

## Skills Demonstrated

- Building a REST API with Node.js and Express.
- Connecting an application to PostgreSQL.
- Containerising an application with Docker.
- Orchestrating local services with Docker Compose.
- Defining AWS infrastructure with Terraform.
- Working with VPCs, subnets, route tables, security groups, EC2, RDS, and load balancing.
- Configuring IAM roles and GitHub Actions OIDC federation.
- Building and publishing Docker images to Amazon ECR.
- Automating application checks and Terraform validation with GitHub Actions.
- Using Git and GitHub for version control and workflow automation.

## Next Steps

- Complete the CD workflow for deploying and updating the application.
- Verify deployment configuration, permissions, and health checks.
- Review the Terraform plan and expected AWS costs before full provisioning.
- Deploy the remaining application infrastructure when ready.
- Verify the live API through the load balancer.
- Document deployment, troubleshooting, and rollback procedures.

## Author

**Jesse Adaramoye Olasunbo**

GitHub: [@Geevfted](https://github.com/Geevfted)

Project repository: [Smart-Inventory-DevOps](https://github.com/Geevfted/Smart-Inventory-DevOps)
