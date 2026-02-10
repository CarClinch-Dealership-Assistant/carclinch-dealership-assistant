# CI/CD Overview

## Branching Strategy

- **main**: production-ready code.
- **dev**: integration branch for sprint work.
- **feature/***: short-lived branches for individual issues.

`feature/* → dev → main`

1. Create a new feature branch

```bash
git checkout -b feature/<name>
```

2. Merge feature branch into dev

```bash
git checkout dev
git pull
git merge feature/<name>
git push
```

3. Make pull request into main

```bash
git push -u origin feature/<name>
```

4. Open a PR in GitHub from feature branch to main

5. Delete the feature branch after merge

```bash
git branch -d feature/<name>
git push origin --delete feature/<name>
```

---

## Pipeline Stages

1. **Unit test job(s)**  
2. **Build job**  
3. **PR checks for dev & main**  
4. **Secrets structure defined (WIP)**
5. **Deployment jobs (re. Terraform & Azure later)**

---

## Future Integration

- Terraform provisioning of Azure resources  
- Automated deployments to dev environment  
- Integration tests against real/non-emulated Azure Service Bus, Postgres, and ACS  
- Environment-specific configs via GitHub Environments  

---

## Repository Standards

- `.gitignore` for Python/infra/secret files  
- PR reviews for dev → main merges  

---

## Next Steps

- Init GitHub Actions workflow file  
- Placeholder test directory  
