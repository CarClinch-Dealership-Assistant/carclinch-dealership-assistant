# Terraform Setup

## Run Terraform

1. Run:
```
terraform init
```
2. Create a **Personal access token (classic)** on GitHub via Settings -> Developer Tools -> Tokens. Ensure you enable `repo` and `workflow` scope.
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

This requires you to navigate to cloned local repo for `email-processing-service` and assumes that it is on `feature/appointments-og` branch.

```
git fetch
git checkout feature/appointments-og
func azure functionapp publish carclinch-email-dev --python
```

## Test

Navigate to the provided `frontend-url` in the Terraform outputs.