# Install the aks-preview Azure CLI extension
az extension add --name aks-preview
 
# Update to the latest version of the extension (aks-preview)
az extension update --name aks-preview

# Register the 'EnableWorkloadIdentityPreview' feature flag
az feature register --namespace "Microsoft.ContainerService" --name "EnableWorkloadIdentityPreview"

# After a couple of minutes run the cmd below to verify the State Registered:
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/EnableWorkloadIdentityPreview')].{Name:name,State:properties.state}"

# Refresh the registration of the Microsoft.ContainerService
az provider register --namespace Microsoft.ContainerServicen

# I'm using Azure CLI in this example:
$aksName = "aks-cluster-test-we-01"
$aksResourceGroup = "rg-cluster-test-we"
$ficid = "fic-batman-test-we-01"
$idName = "id-batman-test-we-01"
$kvResourceGroup = "rg-secrets-test-we"
$kvName = "kv-mysecrets-test-we-01"
$location = "westeurope"
$mySecretName = "mySecret"
$mySecretValue = "superSecret"
$namespace = "hero"
$serviceAccountName = "workload-identity-batman"

# Create resource group for the AKS:
az group create --name $aksResourceGroup --location $location

# Create AKS:
az aks create --resource-group $aksResourceGroup --name $aksName --node-count 1 --enable-oidc-issuer --enable-workload-identity --network-plugin azure --kubernetes-version 1.24.6 --location $location
 
# Create resource group for the Key Vault:
az group create --name $kvResourceGroup --location $location

# Create Key Vault:
az keyvault create --name $kvName --resource-group $kvResourceGroup --location $location 

# Create secret:
az keyvault secret set --vault-name $kvName --name $mySecretName --value $mySecretValue

# Create Azure Managed Identity:
az identity create -g $aksResourceGroup -n $idName

# Get Client Id for the Managed Identity:
$idClientId = (az identity show --name $idName --resource-group $aksResourceGroup| ConvertFrom-Json).clientId
 
# Give User Managed Identity rights to get secret from the Key Vault:
az keyvault set-policy -n $kvName --secret-permissions get --spn $idClientId

az aks get-credentials -n $aksName -g $aksResourceGroup

# Create namespace:
kubectl create namespace hero

echo @"
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: $idClientId
  labels:
    azure.workload.identity/use: "true"
  name: $serviceAccountName
  namespace: $namespace
"@ > serviceaccount.yml | kubectl apply -f serviceaccount.yml

# Get the OIDC Issuer URL:
$aks_oidc_issuer = "$(az aks show -n $aksName -g $aksResourceGroup --query "oidcIssuerProfile.issuerUrl" -otsv)"

# Establish federated identity credential:
az identity federated-credential create --name $ficid --identity-name $idName --resource-group $aksResourceGroup --issuer $aks_oidc_issuer --subject system:serviceaccount:${namespace}:${serviceAccountName}

echo @"
apiVersion: v1
kind: Service
metadata:
  name: secret-service
  namespace: $namespace
spec:
  type: LoadBalancer
  ports:
    - name: secret-port
      protocol: TCP
      port: 8080
      targetPort: 8080
  selector:
    name: secret-pod
"@ > service.yml | kubectl apply -f service.yml

echo @"
apiVersion: v1
kind: Pod
metadata:
  name: secret-app
  namespace: $namespace
  labels:
    name: secret-pod
spec:
  serviceAccountName: $serviceAccountName
  containers:
    - image: docker.io/aranaescobedo/workload-id-app-aks:1.0
      name: secret-container
      env:
        - name: KEYVAULT_NAME
          value: $kvName
        - name: SECRET_NAME
          value: $mySecretName
"@ > pod.yml | kubectl apply -f pod.yml

kubectl get service -n hero
