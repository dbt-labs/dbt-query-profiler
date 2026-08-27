# Contributing

## Getting set up

This repo pins its toolchain with [mise](https://mise.jdx.dev/) (`.python-version`
+ `mise.toml`) and manages Python dependencies with [uv](https://docs.astral.sh/uv/)
(`pyproject.toml` + `uv.lock`). Python 3.11 is the supported version.

Install the pinned Python and uv, then sync the dev dependencies (dbt-duckdb, tox):

```bash
mise install   # optional — installs Python 3.11 and uv; skip if you manage these yourself
uv sync        # creates .venv and installs the default (dev) dependency group
```

The integration tests live in `integration_tests/` and run against a real warehouse.
DuckDB needs no credentials and is the fastest loop. Prefix commands with `uv run` so
they use the project virtualenv:

```bash
cd integration_tests
export DBT_PROFILES_DIR="$PWD/profiles" DUCKDB_PATH=target/t.duckdb
uv run dbt deps --target duckdb
uv run dbt build --select tag:setup --full-refresh --target duckdb
uv run dbt test --target duckdb
uv run bash scripts/test_run_operations.sh duckdb
```

Or run the whole DuckDB loop in one step with `mise run test`.

`integration_tests/profiles/profiles.yml` reads every credential from environment variables; see `profiles.yml.example` for the full list.

Cloud adapters are optional dependency groups — install one on demand, e.g.
`uv sync --group snowflake`, then run its compile or integration env with
`uv run tox -e compile_snowflake` / `uv run tox -e dbt_integration_snowflake`.

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

`.claude/skills/adding-new-adapters-support-for-dbt-query-profiling/` documents the macro set to implement and the naming pattern. In short: implement `{adapter}__` versions of the macros in `macros/_core/`, add the adapter to `supported_adapters.env`, add a target to `integration_tests/profiles/profiles.yml`, add a `dbt-{adapter}` dependency group to `pyproject.toml`, and add `compile_{adapter}` / `dbt_integration_{adapter}` envs to `tox.ini`.
