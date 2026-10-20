# EBS deliverable -> dependencies -> where each file goes

Default save destinations (the user can rename/add them in Settings > Folders; always prefer the live
`(Get-SnMeta).saveTargets` names):

| Destination | Folder | Numbered |
|---|---|---|
| Task script (API test / dev / analysis) | `<ticket>\03_Dev\API` | yes |
| Deployment script (install / rollback / data fix) | `<ticket>\05_Deploy` | yes |
| Production code (Git repo) | `02_Repos\xxcust_ebs\<sub-folder>` | no |
| Reusable snippet (Knowledge base) | `04_Knowledge\SQL_Snippets\<module>` | no |
| Requirements (MD050, emails, mockups) | `<ticket>\01_Requirements` | no |
| Design (MD070, mapping sheets) | `<ticket>\02_Design` | no |
| Test evidence (TE040, screenshots, outputs) | `<ticket>\04_Test` | yes |

## Repo sub-folders (Production code)

| Object | Sub-folder | File name pattern |
|---|---|---|
| Table / staging / error table | `db\tables` | `XXCUST_<MOD>_<CODE>_STG.sql` |
| Sequence | `db\sequences` | `XXCUST_<MOD>_<CODE>_S.sql` |
| Synonym (APPS) | `db\synonyms` | `XXCUST_<...>_syn.sql` |
| Grants | `db\grants` | `XXCUST_<...>_grants.sql` |
| Index | `db\indexes` | `XXCUST_<...>_N1.sql` |
| View | `db\views` | `XXCUST_<...>_V.sql` |
| Package spec / body | `db\packages` | `<PKG>.pks` / `<PKG>.pkb` |
| Trigger | `db\triggers` | `<TRG>.sql` |
| Concurrent program, executable, value set, request group, lookup, profile, message, menu, function, responsibility, forms personalization, DFF, BIP data definition | `fndload` | `<NAME>_<entity>.ldt` (e.g. `XXCUST_GL_SEC_RULE_CP.ldt`) |
| BIP data template + layouts | `bip` | `<CODE>.xml`, `<CODE>.rtf`, `<CODE>.xls` |
| Oracle Reports | `reports` | `<NAME>.rdf` |
| Custom form / CUSTOM.pll | `forms` | `.fmb` / `.pll` |
| OAF personalization / extension | `oaf` | `.xml`, `.java` |
| Workflow | `workflow` | `.wft` |
| SQL*Loader control file | `sqlldr` | `<NAME>.ctl` |
| Host program | `shell` | `<NAME>.prog` |
| Master install script for a release | `install` | `install_<ID>.sql` |

## Dependencies per kind of work (list all of them in the Files table)

**API upload / data load via PL/SQL API** (e.g. GL security rules, account aliases, suppliers, items)
1. Staging table (+ sequence, synonym, grants) -> repo `db\...`
2. Package spec + body that validates and calls the API -> repo `db\packages`
3. Concurrent program + executable (+ parameters value sets) -> repo `fndload` (*to create - extract with FNDLOAD afcpprog.lct / afffload.lct*)
4. Add program to request group -> repo `fndload` (afcpreqg.lct)
5. SQL*Loader ctl or upload template if the data comes from a file -> repo `sqlldr`; sample data file -> Task script
6. Test call / anonymous block for one record -> Task script
7. Install script (runs 1-4 in order) + rollback script -> Deployment script
8. Output/log of a successful test run, screenshots -> Test evidence
9. Clean API call example -> Reusable snippet

**Report (BIP)**: data template / package -> repo `bip` / `db\packages`; RTF/Excel layout -> repo `bip`;
concurrent program + data definition + template ldt -> repo `fndload`; request group -> `fndload`;
mockup -> Requirements; sample output -> Test evidence; install script -> Deployment.

**Interface (inbound/outbound)**: staging + error tables, sequences -> repo `db`; package -> `db\packages`;
ctl -> `sqlldr`; host/shell for file transfer -> `shell`; concurrent program + request set + schedule -> `fndload`;
sample file / payload / Postman collection -> Task script; error report -> repo; mapping sheet -> Design; install + rollback -> Deployment.

**Conversion**: same as interface plus reconciliation queries -> Task script, mock load results -> Test evidence.

**Forms personalization / extension**: personalization ldt (affrmcus.lct) -> repo `fndload`; helper package -> `db\packages`;
CUSTOM.pll -> `forms`; screenshots before/after -> Test evidence.

**OAF**: personalization XML / extension Java -> repo `oaf`; jpximport command -> Deployment script.

**Workflow**: `.wft` -> repo `workflow`; WF package -> `db\packages`; WFLOAD command -> Deployment script.

**Data fix / support**: investigation queries -> Task script; backup + fix + verify scripts -> Deployment script
(numbered: 01 backup, 02 fix, 03 verify, 04 rollback); before/after query output -> Test evidence;
root cause -> card note.

**Analysis / design only**: queries -> Task script; findings doc -> Design.
