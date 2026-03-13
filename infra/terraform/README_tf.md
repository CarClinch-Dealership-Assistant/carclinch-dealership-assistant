# Terraform Setup

## Run Terraform

1. Run:
```
terraform init
terraform apply
```
2. Set your Gmail app password & email address.
3. Set the prefix ie "carclinch"
4. Set your public IP for Key Vault Access as instructed.
5. Type 'yes' when asked.

## Azure Functions

Cannot use Docker images for Consumption. In practice we will likely use GitHub Actions. For now, manually zip and push them to the remote Function App.

### Push Zip Backend Function

This requires you to navigate to cloned local repo for `form-backend-service` which may be a diff file path from below, and assumes that it is on `feature/managedIdentities`.

```
cd ../../../form-backend-service
func azure functionapp publish carclinch-backend-dev --python
```

### Push Zip Email Function

This requires you to navigate to cloned local repo for `email-processing-service` which may be a diff file path from below, and assumes that it is on `feature/replying-email`.

```
cd ../../../email-processing-service
func azure functionapp publish carclinch-email-dev --python
```

## Test

Navigate to the provided `frontend-url` in the Terraform outputs.