# CICS Mini Bank — installation guide

## Important limitations

This is an **original educational sample**, not the code used in the AWS
CardDemo video. The logic has been reviewed here but **not compiled or
executed on z/OS**. Mainframe libraries, PROC names, SMS defaults, JCL job
card and authorization must be adjusted. Never use these demo credentials
or this simplistic authentication/session model for real banking.

The purpose is to reproduce the major architecture patterns:
3270 -> BMS -> CICS pseudo-conversational COBOL -> recoverable VSAM KSDS,
then a controlled offline snapshot -> end-of-day COBOL report.
This project does **not** use IMS.

## Step 0 — project resources

Assumed CICS region from your lab: `CXZ63170`.
Assumed z/OS high-level qualifier: `Z63170`.
The region names and HLQ are examples based on your lab and must be verified.

| Resource | Name |
|---|---|
| CICS transaction | BK01 |
| CICS program | BKONL |
| BMS mapset | BKMAP |
| BMS maps | BKLGIN, BKMAIN |
| CICS file | BKACCT |
| VSAM KSDS | Z63170.BANK.ACCT.KSDS |
| COBOL source PDS | Z63170.BANK.SRC |
| BMS source PDS | Z63170.BANK.BMS |
| Symbolic BMS copy PDS | Z63170.BANK.COPY |
| JCL PDS | Z63170.BANK.JCL |
| Load PDSE | Z63170.BANK.LOAD |
| CSD group | BKDEMO |

Before beginning, find out which COBOL compiler and CICS procedures are
available. Check `DFHMAPS` and `DFHZITCL` in the site CICS SDFHPROC
or system PROCLIB. For batch COBOL, check whether `IGYWCL` is present.
`CICSTS62.CICS.SDFHCOB` in the sample is **a placeholder** and
must be replaced with the site's actual library containing `DFHAID`.

## Step 1 — create libraries

Run `jcl/00_LIBS.jcl` only for libraries that do not exist.
Alternatively create the data sets from ISPF 3.2.
`BANK.LOAD` is a PDSE; sources/BMS/JCL/COPY are FB/80 PDS.
Inspect SDSF for `CC 0000` and dataset allocation problems.

## Step 2 — upload source members with Zowe Explorer

Create these PDS members. Do not upload filenames including extensions
as the member names; PDS member names must be 1–8 characters.

- `src/BKONL.cbl` -> `Z63170.BANK.SRC(BKONL)`
- `src/BKSEED.cbl` -> `Z63170.BANK.SRC(BKSEED)`
- `src/BKDAY.cbl` -> `Z63170.BANK.SRC(BKDAY)`
- `src/BKMAP.bms` -> `Z63170.BANK.BMS(BKMAP)`
- `jcl/*.jcl` -> corresponding members in `Z63170.BANK.JCL`

Use Zowe Explorer upload with text conversion appropriate for EBCDIC
and inspect the uploaded member in ISPF `VIEW`. BMS is HLASM-style
fixed source: continuation `X` is in column 72.
COBOL is free-format (`>>SOURCE FORMAT FREE`) but stored as FB/80.
Do not use tabs in BMS.

## Step 3 — define VSAM KSDS

Submit `01_DEFINE.jcl` (first run only), then in SDSF verify IDCAMS
`MAXCC=0` and cataloged cluster.

```
IDCAMS DEFINE CLUSTER
  INDEXED KEYS(8 0) RECORDSIZE(40 40)
```

The account layout is **exactly 40 bytes**:

| Offset | Size | Data | Meaning |
|---|---|---|---|
| 0 | 8 | X(8) | Account ID, primary key |
| 8 | 20 | X(20) | Authorized owner/user |
| 28 | 11 | 9(11) | Unsigned cents |
| 39 | 1 | X | A = active |

Amount is stored in cents (e.g. 100000 = 1000.00).
This avoids binary layout mismatches between CICS and batch programs.

## Step 4 — compile and run initial seed

Submit `06_BATCH_COMPILE.jcl` with BKSEED as the source/member.
It assumes an `IGYWCL` procedure with `COBOL` and `LKED` steps.
If the procedure differs, adapt the JCL from your site's compile example.

Verify `Z63170.BANK.LOAD(BKSEED)` exists, then submit `02_SEED.jcl`.
Seeded accounts (training-only):

| Account | Owner | Balance |
|---|---|---:|
| ACC00001 | DEMO | 1000.00 |
| ACC00002 | DEMO | 500.00 |
| ACC00003 | GUEST | 250.00 |

`BKSEED` uses `OPEN OUTPUT` to initialize the file. Do not run on
an existing account data set with data you need to preserve.
CICS must not be using the file while this job runs.

## Step 5 — assemble the BMS map

Inspect `03_MAP.jcl`. Adapt MAPLIB/DSCTLIB and confirm `DFHMAPS`
is accessible to the job. Submit the job; inspect assembly/binder results.
It should generate both:

- `Z63170.BANK.LOAD(BKMAP)` — physical 3270 map
- `Z63170.BANK.COPY(BKMAP)` — COBOL symbolic map

Look at the generated symbolic map to verify the field names
`USERIDI`, `PINI`, `FROMAI`, `TOAI`, `AMTI`, `ACTI`, `WHOO`,
`BALO`, `MSGO`, `LMSGO`, plus map groups `BKLGINI/O`, `BKMAINI/O`.
If generated fields differ, adjust `BKONL.cbl` to match.

## Step 6 — compile online CICS COBOL

Inspect `04_ONLINE.jcl`, replace CICS library placeholder, and
check the `DFHZITCL` procedure. Its integrated translator should
compile/translate `EXEC CICS` statements and link `BKONL`.
The `COBOL.SYSLIB` must make both the generated `BKMAP` and
IBM `DFHAID` copybooks visible.

Verify binder output `Z63170.BANK.LOAD(BKONL)`.
The region must include this library in `DFHRPL` or an authorized
CICS `LIBRARY` resource. Avoid changing region startup JCL without
permission; in a shared lab, ask the operator/admin.

## Step 7 — define CICS resources

Open your CICS 3270 terminal and use the CEDA commands shown in
`docs/CEDA.txt`. If a long CEDA command does not fit the 3270 entry
line, enter `CEDA DEFINE FILE(BKACCT) GROUP(BKDEMO)` and fill the
interactive panels field by field. Set `RECOVERY=BACKOUTONLY` to
make the two REWRITE operations part of a recoverable unit of work.
`RECOVERY` can be overridden by ICF-catalog recovery settings.
Confirm recovery/logging facilities are correctly installed.

Use `CEDA INSTALL GROUP(BKDEMO)` and `CEMT I FILE(BKACCT)`.
`CEMT SET FILE(BKACCT) OPEN` if not yet opened.
If CICS cannot open the KSDS, check dataset name, disposition,
region security permissions, VSAM recovery policy, and SDSF logs.

## Step 8 — exercise the 3270 app

At a blank CICS terminal type `BK01` and press ENTER.

**Logon:** User `DEMO` and PIN `1234`.

**Inquiry:** `I`, FROM `ACC00001` -> `1000.00` shown.

**Transfer:** `T`, FROM `ACC00001`, TO `ACC00002`,
AMOUNT `0000012.50`. Format is **exactly** 7 integer digits,
a decimal point, and 2 decimal digits.
Expected after successful commit:

- `ACC00001`: 987.50
- `ACC00002`: 512.50
- `ACC00003`: 250.00

Also test zero amount, insufficient funds, unknown account, same
source/destination, source account not owned by DEMO, and F3 logoff.
For a rejected transfer, both balances must remain unchanged.

## Step 9 — compile and execute end-of-day report

Change `06_BATCH_COMPILE.jcl` source and output member `BKSEED`
to `BKDAY` and submit. Verify executable BKDAY in BANK.LOAD.

Stop new BK01 transactions, allow outstanding tasks to complete,
and close the BKACCT file through `CEMT SET FILE(BKACCT) CLOSED`.
Submit `05_DAY.jcl`, then reopen the file with
`CEMT SET FILE(BKACCT) OPEN`.

`COPY` uses IDCAMS REPRO to produce an FB40 `DAY.SNAP` data set.
`REPORT` reads the snapshot and prints account lines and a total.
`Z63170.BANK.DAY.SNAP` must be absent before the job is rerun,
or change the dataset to a new day-qualified name.

This is an account **balance snapshot report**, not a true accounting
settlement or posting system. No audit ledger, journal report or
transaction reconciliation is included in this starter version.

## Troubleshooting

| Symptom | Likely check |
|---|---|
| JCL error | job card, procedure library, DD statements |
| IDCAMS maxcc 8/12 | cluster exists, SMS space/volume, catalog |
| BMS assemble error | macros, continuation column 72, length/position |
| COBOL COPY not found | COBOL.SYSLIB / generated BKMAP / DFHAID |
| COBOL translator error | correct DFHZITCL and CICS compiler options |
| CICS PGMIDERR | BKONL not in region DFHRPL or LIBRARY |
| CICS MAPFAIL | input empty/not modified; check 3270 map |
| CICS MAPSET unavailable | BKMAP physical module not installed/visible |
| CICS FILENOTFOUND | FILE BKACCT not installed |
| CICS NOTOPEN / DISABLED | inspect CEMT I FILE and region logs |
| Unauthorized transfer | FROM account owner is not DEMO |
| Failed second REWRITE | both updates must be backed out |
| snapshot job fails | BKACCT still open/allocated, snapshot exists |

## Safety and production-hardening checklist

- Replace hard-coded PIN with enterprise-authenticated CICS identity;
  no hard-coded, reversible or clear-text production passwords.
- Apply RACF/SAF resource permissions and per-account authorization.
- Persist transactions in a recoverable ledger, add unique request IDs,
  duplicate prevention, reconciliation, limits and audit logging.
- Review proper backout, recovery logs, locking/deadlock retry policy,
  and money precision/overflow with a banking systems engineer.
- Remove destructive reseeding paths from any shared/prod deployment.
- Use controlled batch quiesce and safe snapshots/image copies.
- This is educational code and has not had mainframe compilation,
  concurrency, penetration or recovery testing.