
# Secure Storage for Azure Files and Azure Blob Storage (Terraform)

This repository contains the Terraform Infrastructure as Code (IaC) implementation for the Microsoft Learn module **"Secure storage for Azure Files and Azure Blob Storage."**

Instead of provisioning the resources manually via the Azure Portal, this project automates the deployment of various Azure Storage architectures, focusing on security, networking, data protection, and access management.

## 🏗️ Project Architecture & Scenarios

This project is divided into five distinct scenarios, mapped to individual `.tf` files:

1. **Simple Storage (`storage_accounts.tf`)**

   - **Goal:** A simple, low-cost storage account for testing and training.
   - **Key Features:** Locally Redundant Storage (LRS), Shared Access Keys disabled (forcing Entra ID authentication), TLS 1.2 enforced, and Secure Transfer (HTTPS) required.
2. **Public Website Content (`public_website.tf`)**

   - **Goal:** High-availability storage for mission-critical, public-facing web assets.
   - **Key Features:** Read-Access Geo-Redundant Storage (RA-GRS), anonymous blob read access, 21-day soft delete, blob versioning, and Change Feed enabled.
3. **Private Company Documents (`private_documents.tf`)**

   - **Goal:** Secure, highly available internal storage with automated tiering and backups.
   - **Key Features:** Geo-Redundant Storage (GRS), private containers, automated Object Replication (syncing data from the public website storage), and a Lifecycle Management policy (moving blobs to the "Cool" tier after 30 days).
4. **Corporate File Shares (`file_shares.tf`)**

   - **Goal:** Fast, secure SMB file shares restricted to internal corporate networks.
   - **Key Features:** Premium File Storage (ZRS), Azure Virtual Network (VNet) with Service Endpoints, Storage Firewall rules blocking public access, and automated File Share/Directory creation.
5. **Secure Application Storage (`secure_app.tf`)**

   - **Goal:** Highly secure storage utilizing Managed Identities, Customer-Managed Keys (CMK), and immutable data.
   - **Key Features:** User-Assigned Managed Identity, Azure Key Vault (with RBAC and Purge Protection), CMK Storage Encryption, Infrastructure Encryption (double encryption), and a 5-day time-based Immutability Policy (WORM storage).

## 📋 Prerequisites

To deploy this infrastructure, you need:

- [Terraform](https://developer.hashicorp.com/terraform/downloads) installed (v1.0+).
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed and authenticated (`az login`).
- An active Azure Subscription.
- **Permissions:** Your Azure user account must have `Owner` or `Role Based Access Control Administrator` permissions on the subscription or resource group to assign the RBAC roles required in Scenario 5.

## 🚀 Deployment Instructions

1. **Clone the repository and initialize Terraform:**
   This downloads the required AzureRM, Random, Http, and Time providers.
   ```bash
   terraform init
   ```

2. **Review the execution plan:**

```bash
terraform plan

```

3. **Deploy the infrastructure:**

```bash
terraform apply

```

*(Type `yes` when prompted to confirm the deployment).*

## ⚠️ Important Configuration Notes & Workarounds

During the development of this Terraform code, several advanced Azure features required specific handling:

* **Data-Plane Authentication:** The provider is configured with `storage_use_azuread = true`. To upload files or manage directories via Terraform (or locally via CLI), your user account must have the **Storage Blob Data Contributor** and **Storage File Data Privileged Contributor** roles assigned.
* **Object Replication Race Conditions:** Object replication requires the `Change Feed` to be enabled on the source storage account. Because Azure's backend takes a few minutes to activate this feature, you may need to run `terraform apply` twice if the replication rule fails on the first pass.
* **Storage Firewalls & Terraform:** In `file_shares.tf`, the storage account firewall blocks all traffic except from the specified Azure VNet. To allow Terraform to create the file share from your local machine, an HTTP data source dynamically fetches your local public IP and temporarily whitelists it in the storage network rules.
* **RBAC Propagation Delays:** In `secure_app.tf`, Terraform assigns Key Vault access to a Managed Identity. Because Entra ID role assignments take time to propagate, a `time_sleep` resource is used to pause execution for 90 seconds before attempting to create the Customer Managed Key.

## 🧹 Cleanup

To prevent ongoing Azure charges, tear down the infrastructure when you are finished testing:

```bash
terraform destroy

```

*(Type `yes` when prompted).*

---

*Disclaimer: This project was built for educational purposes following the Microsoft Learn AZ-104 / AZ-500 curriculum.*
