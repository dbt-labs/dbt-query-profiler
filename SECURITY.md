# Security policy

## Reporting a vulnerability

Please do not open a public issue for a security vulnerability.

Report it privately through [GitHub's private vulnerability reporting](https://github.com/dbt-labs/dbt-query-profiler/security/advisories/new) on this repository, or email security@dbtlabs.com.

Include what you need to describe the problem: affected version or commit, the adapter involved if it is adapter-specific, and how to reproduce it. We will acknowledge your report and keep you updated as we assess it.

## Scope

This package is dbt macros. It generates SQL that runs against your warehouse under your own credentials — it stores nothing, and ships no service. The things most worth reporting are therefore:

- SQL injection through a macro argument. Arguments are interpolated into generated SQL, so a value that escapes its literal and alters the surrounding statement is a vulnerability.
- A macro that reads or exposes data beyond what the caller's warehouse role already permits.
- Credentials or query text leaking somewhere unexpected, for example into logs.

Out of scope: anything requiring the reporter to already control the dbt project (macros execute arbitrary SQL by design), and the behaviour of the warehouses themselves.

## Supported versions

This project is pre-1.0 and maintained on a best-effort basis. Fixes land on `main`; there are no backports to earlier tags.
