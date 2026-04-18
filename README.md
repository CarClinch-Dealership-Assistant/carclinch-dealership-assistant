# CarClinch Dealership Assistant

## Overview

This repository is the central hub of the dealership assistant project. It contains infrastructure configuration, and supporting materials for the dealership assistant POC.  
The primary written documentation (architecture, workflows, sprint notes, decisions, etc.) is maintained in a shared Google Docs workspace for easier collaboration.

**[Full Documentation (Google Docs)](https://docs.google.com/document/d/1wHahfUJDdmyAKJxrRkTXH2aZyR6RQWlMjBsrmCD3_W8/edit?usp=sharing)**

The `/docs` directory in this repository contains uploaded files that are important to the project but not authored directly in the repo such as class presentations, reports, diagrams, exported documents, and other reference materials.

---

## Repository Structure
```
infra/              # Local infra (Docker Compose) & Terraform modules
docs/               # Uploaded files (presentations, reports, diagrams, etc.)
```
---

## Service Repositories

| Service                  | Purpose                                                                                                                                                             | GitHub                                                                             |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| Form frontend service    | HTML/CSS/JS frontend view for a basic lead inquiry intake form.                                                                                                     | [Link](https://github.com/CarClinch-Dealership-Assistant/form-frontend-service)    |
| Form backend service     | Python-based Azure Function to validate lead inquiry intake form payloads to enqueue for downstream processing.                                                     | [Link](https://github.com/CarClinch-Dealership-Assistant/form-backend-service)     |
| Email processing service | Python-based Azure Durable Function to handle AI-powered dealership-lead email conversations, including informing, appointment booking, follow-ups, and escalation. | [Link](https://github.com/CarClinch-Dealership-Assistant/email-processing-service) |

## Development Tools Repositories

| Service               | Purpose                                                                                                                                                  | GitHub                                                                          |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| Lead intake worker    | Worker to automatically generate lead form submissions straight into Service Bus for downstream processing; stress tester for `email-processing-service` | [Link](https://github.com/CarClinch-Dealership-Assistant/lead-intake-worker)    |
| Log dashboard service | Log dashboard that connects to live Azure resources' Application Insights to view Function App logs side by side. (has some lag)                         | [Link](https://github.com/CarClinch-Dealership-Assistant/log-dashboard-service) |

## Contributing

- Open issues in the Github Projects board for new features & milestones
- Use feature branches to develop on in the respective service repo
- Keep `/docs` for uploaded files mainly; write documentation in Google Docs link above
