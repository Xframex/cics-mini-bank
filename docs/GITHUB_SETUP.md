# Publish CICS Mini Bank to GitHub

These steps publish **source code and documentation**, not a running CICS application.

## Step 1 — Repository

The project is hosted at [Xframex/cics-mini-bank](https://github.com/Xframex/cics-mini-bank). It contains the complete README, COBOL, BMS, JCL and setup documents.

## Step 2 — Clone

```powershell
git clone https://github.com/Xframex/cics-mini-bank.git
cd cics-mini-bank
```

Edit project files locally, then commit and push:

```powershell
git add .
git commit -m "Update CICS banking demo"
git push origin main
```

Git may open an interactive browser for credential-manager authorization. Never commit real passwords, personal access tokens, RACF credentials, or z/OS host secrets.

## Step 3 — Validate

- Check that the root README renders architecture and transaction Mermaid diagrams.
- Confirm `src/`, `jcl/`, and `docs/` are all present.
- Inspect all files for actual secrets before any public publication.
- The files are training examples, **not verified to compile or run** in a z/OS system.

## Step 4 — Install to a mainframe (separate task)

Follow [INSTALL.md](INSTALL.md) using an authorized IBM z/OS / CICS environment. All JCL procs and library names must be adapted to that system. Publishing to GitHub does not install into CICS.
