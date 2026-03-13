# Terraform Setup

## Variables

1. Name whatever prefix, ie 'carclinch'
2. Set your public IP for Key Vault Access

## Run Terraform

1. Run:
```
terraform apply
```
2. Name whatever prefix, ie 'carclinch'
3. Set your public IP for Key Vault Access as instructed.
4. Type 'yes' when asked.

## Azure Functions

Cannot use Docker images for Consumption. In practice we will likely use GitHub Actions.
This requires you to navigate to cloned local repo for `form-backend-service` which may be a diff file path from below, and assumes that it is on `main`.

### Push Zip Backend Function

```
cd ../../../form-backend-service
func azure functionapp publish carclinch-backend-dev --python
```

### Push Zip Email Function

```
cd ../../../email-processing-service
func azure functionapp publish carclinch-email-dev --python
```

## Test

Navigate to the provided `frontend-url` in the Terraform outputs.