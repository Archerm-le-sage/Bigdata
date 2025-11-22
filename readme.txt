Projet Bigdata : Deploiement infrastructure terraform, ansible et spark

Structure : 
- terraform/ : terraform config
- ansible/: ansible playbooks and roles
- wordcount/: java file + filesample data
- deploy.ps1 : powershell automation

Requirements
- gcloud CLI
- Terraform
- Docker

How to use
1 Place service account JSON in `keys/sa.json`
2 Run `.\deploy.ps1`
3 To close the project : terraform destroy

