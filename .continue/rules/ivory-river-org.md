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

## Unit of Work (vendored fflib — use it for multi-record / multi-object DML)
This repo vendors fflib's Unit of Work (BSD-3-Clause, from apex-enterprise-patterns/fflib-apex-common) at `force-app/main/default/classes/UnitOfWork/` — only 3 `fflib_*` files plus a minimal `Application` factory. Do NOT install the fflib managed package and do NOT edit the `fflib_*` files (they're vendored, keep them upstream-clean).
- One UoW per transaction: `fflib_ISObjectUnitOfWork uow = Application.UnitOfWork.newInstance();`
- Register intent instead of inline DML: `uow.registerNew(rec)`; `uow.registerNew(child, Child__c.Parent__c, parentRec)` (fills the child's lookup AFTER the parent inserts); `uow.registerDirty(rec)`; `uow.registerDeleted(rec)`. Then call `uow.commitWork();` ONCE — it inserts parents before children, one DML per object type, all inside a single savepoint (atomic rollback on any failure).
- Every SObject you register MUST be listed, in parent→child order, in `Application.UnitOfWork`'s type list — otherwise commitWork throws "SObject type X is not supported by this unit of work". Add custom objects there.
- The **service** owns the UoW: the service creates it, registers the work, and calls `commitWork()`. Controllers and trigger handlers marshal data and call the service; they do NOT scatter DML around the call. This is the concrete form of the "service owns the transaction boundary" rule.
- For user-mode DML (CRUD/FLS enforced on commit, per the security rules) pass `new fflib_SObjectUnitOfWork.UserModeDML()` to `newInstance(...)`; the default is system-mode.
- If org automation must be suppressed in a test that only exercises the UoW, use the repo's `TriggerHandler.bypass('SomeTriggerHandler')` / `clearBypass(...)`.
- Working reference/template: `UnitOfWorkSmokeTest.cls` (bulk parent+child insert with lookup resolution; atomic rollback).
