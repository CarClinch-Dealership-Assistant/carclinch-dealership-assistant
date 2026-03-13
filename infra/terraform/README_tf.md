# Terraform Setup

## Variables

1. Name whatever prefix, ie 'carclinch'
2. Set your public IP for Key Vault Access

## Push Zip Backend Function

Cannot use Docker images for Consumption. In practice we will use GitHub Actions.
This requires you to navigate to cloned local repo for `form-backend-service` which may be a diff file path from below, and assumes that it is on `main`.
```
cd ../../../form-backend-service
func azure functionapp publish testcc-backend-dev --python
```

## Push Zip Email Function

Cannot use Docker images for Consumption. In practice we will use GitHub Actions.
This requires you to navigate to cloned local repo for `email-processing-service` which may be a diff file path from below, and assumes that it is on `main`.
```
cd ../../../email-processing-service
func azure functionapp publish testcc-email-dev --python
```