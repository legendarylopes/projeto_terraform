# import psycopg2
import mysql.connector
import re
import boto3
import csv

def lambda_metodo(event, context):

    # establishing the connection
    conn = mysql.connector.connect(
        database='db_sql', 
        user='your_user', 
        password='your_password', 
        host='dbprojeto.ccbvkpoefirj.us-east-1.rds.amazonaws.com', 
        port='3306'
        )
    
    # Creating a cursor object using the cursor() method
    # cursor = conn.cursor()

    with conn.cursor() as cursor:
        cursor.execute("CREATE TABLE IF NOT EXISTS TB_CPF(VALOR_CPF VARCHAR(14) NOT NULL, IS_VALID BOOLEAN NOT NULL, VALIDATION VARCHAR(50) NOT NULL);")
        conn.commit()
  
    # cursor.execute("SHOW TABLES LIKE 'TB_CPF'")
    # result = cursor.fetchone()
    # if not result:
    #     cursor.execute("CREATE TABLE TB_CPF(VALOR_CPF VARCHAR(14) NOT NULL, IS_VALID BOOLEAN NOT NULL, VALIDATION VARCHAR(50) NOT NULL);")

    validation=True
    # validation_list =[]
    validation_rule = 'Todas as regras ok'
    # validation_rule_list=[]
    bucket = "data-file-s3-projeto-grupo2"
    file_name = "arquivo.csv"

    s3 = boto3.client('s3') 
# 's3' is a key word. create connection to S3 using default config and all buckets within S3

    csvfile = s3.get_object(Bucket= bucket, Key= file_name)
    data = csvfile['Body'].read().decode('utf-8').splitlines()
    records = csv.reader(data)
    headers = next(records)
    for cpf in records:
        print("CPF:", cpf)
        if not re.match(r'\d{3}\.\d{3}\.\d{3}-\d{2}', cpf[0]):
            validation=False
            validation_rule = 'Formato incorreto'
            
        numbers = [int(digit) for digit in cpf[0] if digit.isdigit()]
        
        if len(numbers) != 11 or len(set(numbers)) == 1:
            validation=False
            validation_rule = 'O cpf não possui 11 dígitos'
        
        # Validação do primeiro dígito verificador:
        sum_of_products = sum(a*b for a, b in zip(numbers[0:9], range(10, 1, -1)))
        expected_digit = (sum_of_products * 10 % 11) % 10
        if numbers[9] != expected_digit:
         validation=False
         validation_rule = 'Primeiro digito verificador inválido'
         
        # Validação do segundo dígito verificador:
        sum_of_products = sum(a*b for a, b in zip(numbers[0:10], range(11, 1, -1)))
        expected_digit = (sum_of_products * 10 % 11) % 10
        if numbers[10] != expected_digit:
            validation=False
            validation_rule = 'Segundo dígito verificador inválido'
            
        # validation_list.append(validation)
        # validation_rule_list.append(validation_rule)
        print("validation:",validation)
        print("validation_rule:",validation_rule)
        
        with conn.cursor() as cursor:
            cursor.execute(f"INSERT INTO TB_CPF VALUES ({cpf},{validation},{validation_rule});")
            conn.commit()


