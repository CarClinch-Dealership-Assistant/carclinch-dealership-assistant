# Terraform Setup

## Run Terraform

1. Run:
```
terraform init
```
2. Copy `terraform.tfvars.example` and set `gmail_app_password`, `gmail_user`, and `github_token`. Adjust the other tfvars as needed, like region if your student sub doesn't use the default `eastus2`. Keep in mind that SWA can only deploy in regions `'westus2,centralus,eastus2,westeurope,eastasia'`
3. Run:
```
terraform apply
```
4. Set your public IP for CosmosDB seeding as instructed.
5. Type 'yes' when asked.
6. To deploy frontend to Static Web App, run:
```
gh workflow run azure-static-web-apps.yml \
  --repo CarClinch-Dealership-Assistant/form-frontend-service \
  --ref task/extVariables
```

(depending on when you look at this, ref may be `main`; that task branch should be a safe up to date bet though)

## Azure Functions

Cannot use Docker images for Consumption. In practice we will likely use GitHub Actions. For now, manually zip and push them to the remote Function App.

### Push Zip Backend Function

This requires you to navigate to cloned local repo for `form-backend-service` and assumes that it is on `main` branch.

```
git fetch
git checkout main
func azure functionapp publish carclinch-backend-dev --python
```

### Push Zip Email Function

This requires you to navigate to cloned local repo for `email-processing-service` and assumes that it is on `feature/replying-email-prompt` branch.

```
git fetch
git checkout feature/replying-email-prompt
func azure functionapp publish carclinch-email-dev --python
```

I also rec if you want to track logs to turn off noise:

```
az functionapp config appsettings set \
  --name carclinch-email-dev \
  --resource-group carclinch-func-rg-dev \
  --settings \
    "AzureFunctionsJobHost__logging__logLevel__Host.Triggers.DurableTask=Error" \
    "AzureFunctionsJobHost__logging__logLevel__Azure.Data.Tables=Error" \
    "AzureFunctionsJobHost__logging__logLevel__Azure.Messaging.ServiceBus=Error" \
    "AzureFunctionsJobHost__logging__logLevel__Default=Warning" \
    "AzureFunctionsJobHost__logging__logLevel__Azure.Storage.Blobs=Error" \
    "AzureFunctionsJobHost__logging__logLevel__Azure.Storage.Queues=Error" \
    "AzureFunctionsJobHost__logging__logLevel__Azure.Storage.Common=Error"
```

## Test

Navigate to the provided `frontend-url` in the Terraform outputs.