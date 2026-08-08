---
name: terraform-standards
description: Standards for writing and reviewing Terraform or OpenTofu. Use when creating, editing, or reviewing .tf/.tfvars files, designing module or environment layout, configuring remote state and providers, or auditing IaC for security and drift.
---

# Terraform standards

Apply these when authoring or reviewing Terraform/OpenTofu. Where a repository already has a documented convention that conflicts, follow the repository and say which rule you deviated from.

## Repository layout

Root modules are deployable units; everything else is a reusable module.

```
terraform/
├── modules/<module-name>/     # reusable, no provider or backend blocks
│   ├── terraform.tf
│   ├── variables.tf
│   ├── local.tf
│   ├── data.tf
│   ├── ec2.tf
│   ├── kms.tf
│   ├── outputs.tf
│   └── README.md
└── environments/<env>/        # root modules, one per environment
    ├── terraform.tf
    ├── providers.tf
    ├── variables.tf
    ├── local.tf
    ├── data.tf
    ├── main.tf
    ├── outputs.tf
    └── terraform.tfvars
```

## File naming

File names are fixed by what the file contains, not by author preference. This is the first thing to check in a review, because a misplaced block is the reason people cannot find anything.

| File | Contents |
| :--- | :------- |
| `terraform.tf` | The `terraform` block: `required_version`, `required_providers`, and the `backend` block in a root module |
| `providers.tf` | `provider` blocks, including aliases. Root modules only |
| `variables.tf` | Every `variable` block |
| `local.tf` | Every `locals` block |
| `data.tf` | Every `data` source |
| `outputs.tf` | Every `output` block |
| `moved.tf` | Every `moved` block, always. Never inline one next to the resource it refers to |
| `import.tf` | Every `import` block, always. Never inline one next to the resource it refers to |
| `<service>.tf` | Resources, grouped by the cloud service they belong to |
| `main.tf` | Module calls in a root module. In a reusable module, only resources that genuinely belong to no single service |

Resource files are named after the service, one file per service: `ec2.tf`, `kms.tf`, `s3.tf`, `iam.tf`, `rds.tf`, `route53.tf`. Not by lifecycle, not by layer, and not by an abstraction like `network.tf` that spans several services. Strip the provider prefix to get the file name, so `aws_kms_key` and `aws_kms_alias` both live in `kms.tf`.

A resource file holds only `resource` blocks. Its data sources go in `data.tf`, its locals in `local.tf`, its `moved` blocks in `moved.tf` and its `import` blocks in `import.tf`, even when they exist purely to serve that one file.

`moved.tf` and `import.tf` are transitional by nature. Collecting the blocks in one place each is what makes a refactor or an adoption reviewable, and it means the whole file can be deleted in one step once every consumer has applied. Leaving them scattered through the service files is how they survive for years after they stopped doing anything.

Split a service file only when the service itself is large enough to have distinct sub-services, and then keep the service prefix: `iam-roles.tf`, `iam-policies.tf`.

Never nest an environment inside another environment, and never let a reusable module declare `provider` or `backend` blocks: they are inherited from the root module. A module may declare `required_providers` with configuration aliases.

## Versions and providers

Pin in `terraform.tf` of every module and root module:

```hcl
terraform {
  required_version = "~> 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}
```

- Reusable modules use permissive-but-bounded constraints (`~> 5.0`); root modules pin tighter and commit `.terraform.lock.hcl`.
- Always commit `.terraform.lock.hcl` for root modules. Never commit it for reusable modules.
- Third-party module sources are pinned to a tag or commit, never a branch.

## State

- Remote state only. Local state is acceptable only in throwaway experiments that are not committed.
- One state file per environment per component. A single state spanning all environments is a defect.
- Enable state locking (DynamoDB for S3, native locking for Terraform Cloud/GCS/AzureRM) and versioning plus encryption on the state bucket.
- Backend config that varies per environment goes in a `backend.hcl` passed with `-backend-config`, not interpolated (backends cannot use variables).
- Reading another stack's state with `terraform_remote_state` creates a hard coupling. Prefer a provider data source or a published parameter (SSM, ESC, etc.) when one exists.

## Naming and tagging

- Resource and variable names are `snake_case`. Cloud-visible names are `kebab-case`.
- Do not repeat the resource type in the label: `resource "aws_s3_bucket" "artifacts"`, not `"artifacts_bucket"`.
- Use `this` as the label only when a module manages exactly one resource of that type.
- Cloud-visible names carry environment and purpose: `<project>-<env>-<purpose>`.
- Apply tags once via provider `default_tags` (or the equivalent) and set only resource-specific tags inline. Every managed resource must be attributable to owner, environment, and the repository that manages it.

## Variables and outputs

- Every variable has a `type` and a `description`. Omit `default` when the value is genuinely required, so a missing value fails at plan time instead of silently applying a wrong default.
- Use `validation` blocks for constrained values (allowed environments, CIDR shapes, name length) rather than discovering the failure mid-apply.
- Mark secrets `sensitive = true`, and mark outputs that carry them sensitive too.
- Prefer rich object types over many scalars, but do not model a single flat resource as a deeply nested object just to reduce the variable count.
- Outputs expose what callers need to compose with: IDs, ARNs, endpoints. Do not output an entire resource object.

## Resource design

- `for_each` over `count` whenever the collection is keyed by something meaningful; `count` is only for a genuine 0-or-1 toggle. `count` over a list makes every index shift a destroy/recreate.
- Never use `depends_on` where an attribute reference would express the dependency.
- No `provisioner "local-exec"` or `remote-exec` unless there is no provider or data source path; when unavoidable, state why in a comment.
- `lifecycle { prevent_destroy = true }` on stateful resources: databases, state buckets, KMS keys.
- Keep `ignore_changes` narrow and justified. A blanket `ignore_changes = all` hides drift.
- Move resources with `moved` blocks in `moved.tf` rather than `terraform state mv`, and adopt existing resources with `import` blocks in `import.tf` rather than `terraform import`, so both are reviewable and reproducible.
- Delete `moved.tf` and `import.tf` once every consumer of the configuration has applied. They are migration scaffolding, not permanent configuration.

## Security

- No secrets in `.tf` or `.tfvars` files, and no plaintext secrets committed anywhere. Source them from the platform's secret store at plan time.
- `.gitignore` must cover `.terraform/`, `*.tfstate`, `*.tfstate.*`, `crash.log`, and `*.tfvars` files holding secrets.
- No `0.0.0.0/0` ingress except on deliberately public load balancers, and never on SSH/RDP.
- Encryption at rest on every storage resource; TLS in transit.
- IAM policies are least privilege. A wildcard action or resource needs a comment explaining why it cannot be narrowed.
- CI runs `tflint` and a security scanner (`tfsec`, `trivy config`, or `checkov`). Findings are fixed or explicitly suppressed with a reason, never left unreviewed.

## Workflow expectations

Formatting and validation are non-negotiable before any change is proposed:

```sh
terraform fmt -recursive
terraform validate
terraform plan
```

- Review the plan output. Any destroy or replace in an environment holding data is called out explicitly before applying.
- Applies to shared environments run in CI from the default branch, not from a laptop.
- Pre-commit hooks: `terraform_fmt`, `terraform_validate`, `terraform_tflint`, `terraform_docs`.
- Module `README.md` is generated by `terraform-docs`, not written by hand.

## Reviewing existing code

When asked to review, report findings in this order: state and backend problems, security exposure, destroy-causing constructs (`count` over lists, missing `prevent_destroy`, unpinned providers), file naming and placement, then style. Say which rule each finding breaks and what the fix is.

For file naming, do not propose a repository-wide reshuffle as a review finding on an unrelated change. Note the misplacement, and move blocks as you touch them.
