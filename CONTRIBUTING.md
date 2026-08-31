# Contributing

## Getting set up

This repo pins its toolchain with [mise](https://mise.jdx.dev/) (`.python-version`
+ `mise.toml`) and manages Python dependencies with [uv](https://docs.astral.sh/uv/)
(`pyproject.toml` + `uv.lock`). Python 3.11 is the supported version.

The integration tests live in `integration_tests/` and run against a real warehouse.
DuckDB needs no credentials and is the fastest loop:

```bash
mise install         # installs Python 3.11 and uv
mise run setup        # creates .venv and installs the dev dependencies
mise run test:duckdb  # dbt deps, build, test, run-operations against DuckDB
```

Once you have credentials for a cloud adapter, install its dependency group and run
its own task the same way, e.g. `uv sync --group snowflake` then `mise run
test:snowflake`. To run every adapter one after another, use `mise run test:all` -
it runs `uv sync --all-groups` for you, then every `test:<adapter>` task in
sequence. `integration_tests/profiles/profiles.yml` reads every credential from
environment variables; see `profiles.yml.example` for the full list.

If your local `profiles.yml` target for an adapter is named differently than the
adapter itself (e.g. a personal `snowflake_dev` target), or you keep your own
`profiles.yml` outside this repo entirely, override it per run instead of renaming
the target CI expects:

```bash
DBT_PROFILES_DIR=~/.dbt DBT_TARGET_SNOWFLAKE=snowflake_dev mise run test:snowflake
```

To avoid repeating that on every run, put the same variables in a `.mise.local.toml`
at the repo root (gitignored, never committed) instead:

```toml
[env]
DBT_PROFILES_DIR = "/absolute/path/to/your/.dbt"   # ~ is not expanded, use an absolute path
DBT_TARGET_SNOWFLAKE = "snowflake_dev"
```

mise merges it on top of `mise.toml` automatically, so `mise run test:snowflake`
alone then picks up your target with no env vars on the command line.

For a quick parse-only check of one adapter (no credentials, no full build), use
`mise run compile snowflake`.

The `test:<adapter>` task names match the `test_runner: "mise"` contract from
[dbt-labs/dbt-package-testing](https://github.com/dbt-labs/dbt-package-testing) — the
same tasks are what CI will call once `.github/workflows_wip/ci.yml` is promoted to
an active workflow.

## Testing against dbt Fusion

`test:fusion-<adapter>` tasks (e.g. `mise run test:fusion-snowflake`) run the same
loop against the [dbt Fusion](https://github.com/dbt-labs/fs) engine instead of dbt
Core, matching dbt-package-testing's `run_tox_fusion.yml` mise contract. They expect
a Fusion `dbt` binary already on your machine — install it with:

```bash
curl -fsSL https://public.cdn.getdbt.com/fs/install/install.sh | sh
```

which installs to `~/.local/bin/dbt`. The same `DBT_TARGET_<ADAPTER>` and
`DBT_PROFILES_DIR` overrides (including via `.mise.local.toml`) apply to the Fusion
tasks too. If your Fusion binary lives somewhere else, set `DBT_FUSION_BIN_DIR`.

## Submitting a change

1. Fork and create a feature branch.
2. Add or update tests. A change to adapter SQL needs a test that fails without it.
3. Run the suite on DuckDB, plus any adapter you changed.
4. Open a pull request describing what you verified and on which adapters.

## Things worth knowing before you change macro code

**Every adapter must accept every dispatched argument.** `adapter.dispatch` forwards keyword arguments to all implementations, so adding one to a core macro without adding it to all five raises `macro ... takes no keyword argument` at runtime. The five are `snowflake`, `bigquery`, `databricks`, `redshift`, `duckdb`.

**Resolve before dispatch.** `model_name`/`node_id` are resolved to a `query_id` in `macros/_core/` before `adapter.dispatch` is called, which is why adapter macros take only `query_id`. Keep it that way — it avoids widening five signatures for every new argument.

**Never use `LIKE` for substring matching.** `_` is a single-character wildcard, so `stg_orders` also matches `stgXorders`. Use `dbt_query_profiler.contains_text(column, needle)`, which handles BigQuery needing `strpos` where the others use `position(x in y)`.

**Escape interpolated values** with `dbt_query_profiler._escape_literal()`. An unescaped apostrophe is a syntax error.

**`raise_compiler_error` aborts the whole invocation**, not one node. Guard anything that runs at parse time with `{% if execute %}`.

**Assert on content, not exit status.** `test_run_operations.sh` uses `set -e`, and an assertion that matches any non-empty output has previously let a completely broken macro pass. Check for a string that only appears when the behaviour is correct.

## Adding an adapter

`.claude/skills/adding-new-adapters-support-for-dbt-query-profiling/` documents the macro set to implement and the naming pattern. In short: implement `{adapter}__` versions of the macros in `macros/_core/`, add the adapter to `supported_adapters.env`, add a target to `integration_tests/profiles/profiles.yml`, add a `dbt-{adapter}` dependency group to `pyproject.toml`, and add a `test:{adapter}` task to `mise.toml`.
