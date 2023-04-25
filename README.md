# Seções

- [Objetivo](#objetivo)
- [O que é criado pelo repositório](#o-que-é-criado-pelo-script)
- [Como correr o script](#como-correr-o-script)

# Objetivo

Esse repositório tem como objetivo implementar um script em Terraform capaz de criar uma pipeline de análise e processamento de dados.
Esta startup chamada de D-Tech possui uma aplicação do tipo monolito em Java, com backend e frontend que é executada em 1 máquina virtual. Essa aplicação é responsável por fazer upload de um arquivo para um bucket S3 para ser analisado, formatado e tratado por uma pipeline de análise e processamento de dados.

# O que é criado pelo script

- Um Bucket S3;
- Uma Lambda Function com trigger de bucket S3;
- Um banco de dados RDS para armazenar os dados provenientes do arquivo que é adicionado ao bucket S3.
  ![stack-script](images\stack_script.png)

Essa aplicação é responsável por fazer upload de um arquivo para um bucket S3 para ser analisado, formatado e tratado por uma pipeline de análise e processamento de dados.

# Como correr o script

Existe na raiz do projeto um script chamado `main.tf`, basta acessar o diretorio via prompt e executar os comandos terraform:

- terraform init
- terraform plan
- terraform apply

Para destruir toda a infraestrutura, basta executar `terraform destroy`
