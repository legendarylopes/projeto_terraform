import pandas as pd
def lambda_metodo(event, context):
 list_cpf= ['358.269.668-58']
validation = True
validation_rule = 'Todas as regras ok'
cpf_df=pd.DataFrame({'cpf':'','Regra_de_validacao':'','validado':''})
for cpf in list_cpf :
  # Verifica a formatação do CPF
    if not re.match(r'\d{3}\.\d{3}\.\d{3}-\d{2}', cpf):
        validation=False
        validation_rule = 'Formato incorreto'

    # Obtém apenas os números do CPF, ignorando pontuações
    numbers = [int(digit) for digit in cpf if digit.isdigit()]

    # Verifica se o CPF possui 11 números ou se todos são iguais:
    if len(numbers) != 11 or len(set(numbers)) == 1:
        validation=False
        validation_rule = 'O cpf não possui 11 dígitos'

    # Validação do primeiro dígito verificador:
    sum_of_products = sum(a*b for a, b in zip(numbers[0:9], range(10, 1, -1)))
    expected_digit = (sum_of_products * 10 % 11) % 10
    if numbers[9] != expected_digit:
        validation=False
        validation_rule = 'Primeiro digito verificador errado'

    # Validação do segundo dígito verificador:
    sum_of_products = sum(a*b for a, b in zip(numbers[0:10], range(11, 1, -1)))
    expected_digit = (sum_of_products * 10 % 11) % 10
    if numbers[10] != expected_digit:
        validation=False
        validation_rule = 'regundo dígito verificador'

    df