terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
}
###################################################################### Bucket ####################################################################################

resource "aws_s3_bucket" "b" {
  bucket = "data-file-s3-projeto-${var.bucket_user}"
  force_destroy = var.force_destroy

  tags = {
    Name  = "Bucket para armazenar input e executar lambda"
    Turma = "terraform0-009-983"
  }
}
######################################################################## VPC #####################################################################################


resource "aws_vpc" "dev-vpc" {
  cidr_block = "172.16.1.0/25" # o /25 indica a quantidade de IPs disponíveis para máquinas na rede

  tags = {
    Name = "VPC 1 - Projeto Terraform"
  }
}

# Cria uma subnet que pertence àquela rede privada 
resource "aws_subnet" "private-subnet" {
  count             = var.subnet_count
  vpc_id            = aws_vpc.dev-vpc.id
  cidr_block        = var.subnet_cidr_block[count.index] # "172.16.1.0/25" 172.16.1.48 até 172.16.1.64 
  availability_zone = var.subnet_availability_zone[count.index]

  tags = {
    Name = "Subnet ${count.index + 1} - Projeto Terraform"
  }
}

resource "aws_db_subnet_group" "db-subnet" {
  name       = "db_subnet_group"
  subnet_ids = [aws_subnet.private-subnet[0].id, aws_subnet.private-subnet[1].id]
}

# Cria um grupo de segurança contendo regras de entrada e saída de rede. 
# Idealmente, apenas abra o que for necessário e preciso.
resource "aws_security_group" "allow_db" {
  name        = "permite_conexao_rds"
  description = "Grupo de seguranca para permitir conexao ao db"
  vpc_id      = aws_vpc.dev-vpc.id

ingress {
    description = "Porta de conexao ao Postgres"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.dev-vpc.cidr_block] # aws_vpc.dev-vpc.cidr_blocks
  }
  egress {
    description = "HTTPS"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # aws_vpc.dev-vpc.cidr_blocks
  }

  tags = {
    Name = "DE-OP-009"
  }
}
################################################################################################### Lambda ########################################################################################

# Cria uma politica de acesso ao lambda

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"] 
  }
}

# Criando  uma role p/ o lambda.
resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_para_o_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# Copy da permissão de log-stream da aula para validar funcionamento da lambda no cloudwatch
resource "aws_iam_policy" "function_logging_policy" {
  name   = "function-logging-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Action : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect : "Allow",
        Resource : "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Permissão para leitura do bucket
resource "aws_iam_policy" "function_lambda_policy" {
  name = "function_lambda_policy"

  policy = jsonencode({
    Version = "2012-10-17",
    "Statement" = [
      {
        Action   = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.b.arn}",
          "${aws_s3_bucket.b.arn}/*"
        ]
      }
    ]
  })
}

# Adicionando a policy anterior do log-stream
resource "aws_iam_role_policy_attachment" "function_logging_policy_attachment" {
  role = aws_iam_role.iam_for_lambda.id
  policy_arn = aws_iam_policy.function_logging_policy.arn
}

# Adicionando a policy anterior da leitura do bucket
resource "aws_iam_role_policy_attachment" "function_lambda_policy_attachment" {
  role = aws_iam_role.iam_for_lambda.id
  policy_arn = aws_iam_policy.function_lambda_policy.arn
}

# Zipar 1 arquivo .py para subir no lambda
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "lambda_function.py" 
  output_path = "lambda_function_payload.zip"
}
# Subindo o arquivo zip na lambda
resource "aws_lambda_function" "lambda_func" {
  function_name = var.nome_lambda
  filename      = "lambda_function_payload.zip"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_function.lambda_metodo"

  source_code_hash = "${data.archive_file.lambda.output_base64sha256}"
  runtime = var.versao_python
}

# Permitir nitificações entre s3 e lambda
resource "aws_s3_bucket_notification" "aws_lambda_trigger" {
  bucket = aws_s3_bucket.b.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda_func.arn
    events              = var.eventos_lambda_s3
  }

  # O depends_on aqui garante que esse recurso "aws_s3_bucket_notification" 
  # só será criado APÓS  "aws_lambda_permission" "invoke_function", que é um "pré requisito"
  depends_on = [aws_lambda_permission.invoke_function] 
}

# Log no cloud watch
resource "aws_cloudwatch_log_group" "function_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_func.function_name}"
  retention_in_days = var.retencao_logs
  lifecycle {
    prevent_destroy = false
  }
}

# Adiciono permissões ao meu bucket s3 para invocar (fazer trigger) à minha função lambda.
resource "aws_lambda_permission" "invoke_function" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_func.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${aws_s3_bucket.b.id}"
}

