# Prefect Worker on Amazon ECS Fargate

This project uses Terraform to deploy a Prefect worker on Amazon ECS using the Fargate launch type.

The setup includes a VPC, ECS cluster, IAM roles, and necessary networking components, connected to a Prefect Cloud work pool.

## Purpose

The purpose of this setup is to create a serverless infrastructure for running Prefect workflows. By using ECS Fargate, we eliminate the need to manage EC2 instances while gaining the benefits of container orchestration. The worker connects to Prefect Cloud to execute workflows that are scheduled or triggered through the Prefect platform.

## Infrastructure Components

- **VPC**: A custom VPC with CIDR block 10.0.0.0/16
- **Subnets**: 3 public and 3 private subnets across multiple availability zones
- **NAT Gateway**: A single NAT gateway for outbound traffic from private subnets
- **ECS Cluster**: A Fargate cluster for running containerized Prefect workers
- **IAM Roles**: Properly configured execution roles with necessary permissions
- **Service Discovery**: Private DNS namespace for service discovery
- **Secrets Management**: Securely storing the Prefect API key in AWS Secrets Manager

## Prerequisites

Before deploying this infrastructure, you need:

1. An AWS account with appropriate permissions
2. AWS CLI configured with credentials
3. Terraform (version >= 1.2.0) installed
4. A Prefect Cloud account and API key
5. Prefect account ID and workspace ID from Prefect Cloud

## Deployment Instructions

### 1. Clone this repository

```bash
git clone https://github.com/jagrit007/aip_tf_project
cd aip_tf_project
```

### 2. Configure variables

Copy the example variables file and update it with your own values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` to set your:
- AWS region
- Availability zones
- Prefect API key
- Prefect account ID
- Prefect workspace ID

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Create an execution plan

```bash
terraform plan
```

Review the plan to ensure it will create the expected resources.

### 5. Apply the configuration

```bash
terraform apply
```

Type `yes` when prompted to confirm the creation of resources.

### 6. Verify the deployment

After the deployment completes, Terraform will output:
- The ECS cluster ARN
- VPC ID
- Private subnet IDs
- Prefect worker service name
- Service discovery namespace

## Verification Steps

### 1. Verify ECS Cluster and Service

1. Open the AWS Management Console
2. Navigate to the ECS service
3. Select the "prefect-cluster"
4. Verify that the "prefect-worker-service" service is running
5. Check the tasks tab to ensure the worker task is in a **RUNNING** state

### 2. Verify Prefect Connection

1. Log in to your Prefect Cloud account
2. Navigate to Work Pools
3. Verify that the "ecs-work-pool" is active and has a worker connected


### 3. Verify Logs

Check CloudWatch Logs for worker logs:

1. Navigate to CloudWatch in the AWS Console
2. Go to Log Groups
3. Find the "/ecs/prefect-worker" log group
4. Examine the logs to verify the worker is properly configured and connected

## Resource Cleanup

To avoid incurring unnecessary costs, clean up the resources when they are no longer needed:

```bash
terraform destroy
```

Type `yes` when prompted to confirm the deletion of resources.

## Security Considerations

This configuration includes:

- Private subnets for task execution
- IAM roles with least privilege principle
- Secrets Manager for sensitive information
- Security groups with minimal required access

## Troubleshooting

If the worker fails to connect to Prefect Cloud:

1. Check that the Prefect API key is correctly stored in Secrets Manager
2. Verify that the account ID and workspace ID are correct
3. Ensure the ECS task has proper outbound network access
4. Check the CloudWatch logs for any error messages

If the task fails to start:

1. Check the ECS task definition for any configuration errors
2. Verify that the VPC and subnets are correctly configured
3. Ensure the security groups allow necessary traffic
4. Check that the IAM roles have the required permissions