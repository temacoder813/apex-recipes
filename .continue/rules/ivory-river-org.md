---
name: Ivory River Org Context
description: Facts about the target Salesforce org and this project's deploy workflow
alwaysApply: true
---

This project (Apex Recipes, 255 components deployed) targets the **Ivory River** Developer Edition org:
- CLI alias: `irOrg` (also resolves as `irorg`; it is this project's default org via .sf/config.json). API version **67.0**.
- The org is multi-app: Apex Recipes + E-Bikes (Product2/Order customizations, `Product_Family__c`-style custom fields) + custom trading objects (`Trade__c`, `Bot__c`, `Daily_PL__c`). Do not assume a field exists — check the object in `force-app` or describe it via `sf sobject describe -o irOrg -s <Object>`.
- An `AccountTrigger on Account` exists (Apex Recipes trigger framework). Any new Account automation must go through that handler chain, not a second trigger.
- Org quirks: State & Country picklists are ENABLED (plain-text `BillingState`/`BillingCountry` values fail validation — use valid ISO codes in test data and data loads); Campaigns feature is off; the `Walkthroughs` permset does not exist in this org.
- Deploy/test commands (sf CLI v2 — never use retired `sfdx force:*` syntax):
  - Deploy: `sf project deploy start -d force-app -o irOrg`
  - Run tests: `sf apex run test --tests <TestClass> --result-format human --code-coverage -o irOrg --wait 10`
  - Static analysis: `sf code-analyzer run --workspace force-app --view detail` (PMD ruleset at ./ruleset.xml)
- Windows machine, PowerShell terminal — generate PowerShell-compatible commands (no bash heredocs, no `&&` chaining for PS 5.1).
