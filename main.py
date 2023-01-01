import os

from azure.keyvault.secrets import SecretClient
from token_credential import MyClientAssertionCredential

from flask import Flask

app = Flask(__name__)

@app.route('/')
def main():
    azure_authority_host = os.getenv('AZURE_AUTHORITY_HOST', '')
    azure_client_id = os.getenv('AZURE_CLIENT_ID', '')
    azure_federated_token_file = os.getenv('AZURE_FEDERATED_TOKEN_FILE', '')
    azure_tenant_id = os.getenv('AZURE_TENANT_ID', '')
    keyvault_url = os.getenv('KEYVAULT_URL', '')

    #Create a token credential object, which has a get_token method that returns a token
    token_credential = MyClientAssertionCredential(azure_client_id, azure_tenant_id, azure_authority_host, azure_federated_token_file)

    if not keyvault_url:
        keyvault_name = os.getenv('KEYVAULT_NAME', '')
        keyvault_url='https://{}.vault.azure.net'.format(keyvault_name)
    
    secret_name = os.getenv('SECRET_NAME', '')
    if not secret_name:
        raise Exception('SECRET_NAME environment variable is not set')

    #Create a secret client with the the token credential
    keyvault_client = SecretClient(vault_url=keyvault_url, credential=token_credential)
    get_secret = keyvault_client.get_secret(secret_name)
    print('successfully got SECRET_NAME, secret={}'.format(get_secret.value))
    
    return (f'Hello! mySecret value from the Key Vault is: {get_secret.value}')

if __name__ == '__main__':
     #main()
     app.run(debug=True,host='0.0.0.0',port=8080)
app.run(host='0.0.0.0')