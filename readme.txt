Projet Bigdata : Deploiement infrastructure terraform, ansible et spark

Structure : 
- terraform/: Terraform config
- ansible/: Ansible playbooks and roles
- wordcount/: Java file + filesample data
- deploy.ps1: PowerShell automation

Requirements
- gcloud CLI
- Terraform
- Docker

How to use
1. Place service account JSON in `keys/sa.json`
2. Run `.\deploy.ps1`
3. To close the project : terraform destroy
