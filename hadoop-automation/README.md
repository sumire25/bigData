# Automated Hadoop Cluster Deployment (Terraform & Ansible)

This repository contains Infrastructure as Code (IaC) to automatically provision, configure, and tune a fully functional Apache Hadoop cluster (HDFS & YARN) on AWS. 

It uses **Terraform** to provision the EC2 infrastructure and network security groups, and **Ansible** to dynamically configure the nodes, handle SSH loopbacks, inject memory constraints, and start the Big Data daemons.

## Prerequisites (MX Linux / Debian / Ubuntu)

Before running the deployment, ensure your local machine has Git, Ansible (>= 2.9), and Terraform (>= v1.0) installed. You can install them using the following commands:

### 1. Install Git and Ansible
```bash
sudo apt-get update
sudo apt-get install -y git ansible
```

### 2. Install Terraform
Do not use the default system repository for Terraform, as it is often outdated. Add the official HashiCorp repository:
```bash
# Install required tools
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl

# Download the HashiCorp security key
curl -fsSL [https://apt.releases.hashicorp.com/gpg](https://apt.releases.hashicorp.com/gpg) | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Add the official repository
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] [https://apt.releases.hashicorp.com](https://apt.releases.hashicorp.com) $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Update package list and install Terraform
sudo apt-get update
sudo apt-get install -y terraform
```

### 3. Verify Installations
Ensure everything installed correctly by checking their versions:
```bash
git --version
ansible --version
terraform -v
```

---

## Phase 1: The AWS Learner Lab "Quirk" (Credentials)

AWS Academy Learner Labs are special. You do not have permanent administrative accounts; you get temporary credentials that expire every few hours. Here is how you link your local machine to the lab:

1. Go to your browser, start your AWS Learner Lab, and wait for the status dot to turn green.
2. Click the **AWS Details** button at the top of the page.
3. Click the **Show** button next to **AWS CLI**.
4. You will see a block of text starting with `[default]` that contains your `aws_access_key_id`, `aws_secret_access_key`, and `aws_session_token`. **Copy this entire block.**
5. Back in your local terminal, create the AWS credentials file and open it in your text editor:
   ```bash
   mkdir -p ~/.aws
   nano ~/.aws/credentials
   
```
6. Paste the block into the file, save, and exit.

> **CRUCIAL NOTE:** You must repeat steps 2-6 every single time you restart the lab on a new day, as those security tokens expire!

---

## Phase 2: SSH Key Setup

Your AWS Learner Lab uses a specific SSH key pair by default. You need to download it and secure it so Terraform and Ansible can communicate with your new servers.

1. From that same **AWS Details** menu in the Learner Lab, download the `labsuser.pem` SSH key.
2. Move it to your local hidden SSH folder and lock down the permissions:
   ```bash
   mkdir -p ~/.ssh
   mv ~/Downloads/labsuser.pem ~/.ssh/
   chmod 400 ~/.ssh/labsuser.pem
   
```

---

## Phase 3: Deploying the Cluster

Once your credentials and SSH keys are in place, you can deploy the entire infrastructure.

1. Clone this repository and navigate into the directory.
2. Execute the deployment script:
   ```bash
   ./deploy.sh
   
```
   *(This script initializes Terraform, builds the EC2 instances, dynamically generates the host inventory, and hands the execution over to Ansible for software configuration).*

---

## Phase 4: Accessing the Cluster & Starting Services

Once Ansible finishes with a green output, your cluster is built. 

To connect to your Master node, copy the Master's Public IP address from your AWS console (or Terraform output) and run:
```bash
ssh -i ~/.ssh/labsuser.pem ubuntu@<MASTER_PUBLIC_IP>
```

### Starting the Hadoop Daemons
If you ever need to manually restart the cluster (or if the EC2 instances are rebooted), run these exact commands directly on the Master node terminal:

```bash
# 1. Start the Hadoop Distributed File System (NameNode & DataNodes)
/usr/local/hadoop/sbin/start-dfs.sh

# 2. Start the Yet Another Resource Negotiator (ResourceManager & NodeManagers)
/usr/local/hadoop/sbin/start-yarn.sh
```

To verify that all services are running correctly, type `jps` on the Master node. You should see `NameNode`, `SecondaryNameNode`, and `ResourceManager`.
