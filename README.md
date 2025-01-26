# Service-A-B-AKS Project

This project demonstrates the deployment of two microservices (Service A and Service B) on Azure Kubernetes Service (AKS).
Service A retrieves the Bitcoin price in USD every minute and calculates the average price over the last 10 minutes.
Service B echoes http requests.
The project also incorporates key Kubernetes features like readiness and liveness probes, RBAC (Role-Based Access Control), network policies, and high availability with replicated pods.
Infrastructure provisioning and deployment are automated using Terraform.

Prerequisites:

Before running this project, ensure the following tools are installed on your machine:
1. Azure CLI: For authentication and management of Azure resources.
2. Docker: Ensure Docker is installed and running.
3. Terraform: Used for infrastructure provisioning.

Setup and Deployment:

Step 1: Clone the Repository
Clone this repository to your local machine:
git clone https://github.com/guyedv/service-a-b-aks.git
cd service-a-b-aks

Step 2: Initialize And Apply Terraform

Initialize Terraform to set up the working directory:
terraform init
terraform apply
After applying successfully, Terraform will prompt for 3 inputs: 
1. Prefix that will be used for names of resource group, azure container registry, and kubernetes cluster. (4 or more characters)
2. Subscription ID
3. Tag name for your soon to be built docker image. (v1.0,lastest)

Step 3: Using kubectl commands / Azure portal to view the created services

To connect to Services A/B we will enter the following command to view nginx LoadBalancer external IP address:
kubectl get svc -n ingress-nginx
And then we can use it to view our services application via URL: http://[External-IP]/service-A and http://[External-IP]/service-B

   




