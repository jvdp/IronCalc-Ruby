# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Ruby bindings for the **IronCalc** spreadsheet engine (Rust), built with **magnus** + **rb-sys** and packaged as the `ironcalc` gem. It depends on the **published `ironcalc` crate from crates.io** (currently `0.7.1`), not a local IronCalc checkout. The binding deliberately **mirrors the upstream IronCalc Python bindings** (`ironcalc/ironcalc` → `bindings/python`, a pyo3 layer) — keep Python parity as the guiding principle when adding methods.

`HANDOFF.md` (untracked, not part of the gem) holds deeper working notes; consult it for magnus patterns and engine-API-drift details.

## Build & test

This environment's system Ruby (3.2.3) lacks dev headers and bundler. Use rbenv Ruby 4.0.5 and point bindgen at gcc's builtin headers:

```sh
export RBENV_VERSION=4.0.5
export BINDGEN_EXTRA_CLANG_ARGS="-I/usr/lib/gcc/x86_64-linux-gnu/13/include"
bundle install                                   # first time only
bundle exec rake compile                         # builds lib/ironcalc/ironcalc_ruby.so (gitignored)
bundle exec rake test                            # runs test/ironcalc_test.rb (minitest)
bundle exec ruby -Itest test/ironcalc_test.rb -n test_NAME   # run a single test
```

- **`BINDGEN_EXTRA_CLANG_ARGS` is only needed here on Ruby 4.0.5**: rb-sys 0.9.x ships no pre-generated bindings for 4.0, so bindgen runs (libclang-18's resource dir / `stdarg.h` is missing). On Ruby 3.3/3.4 and in CI, pre-generated bindings are used and no workaround is needed.
- **magnus must be 0.8+** — 0.7.x does not compile against Ruby 4.0's C API.
- First compile rebuilds the whole engine dep tree from crates.io (~4 min). Incremental binding-only rebuilds are ~5–10 s (no LTO in this workspace).
- After editing Rust, always `rake compile` before `rake test` — tests load the compiled `.so`.

### Test layout

`rake test` runs `test/**/*_test.rb`. Three suites:
- `ironcalc_test.rb` — hand-written unit tests.
- `surface_test.rb` — covers the binding's *own* surface (style Hash, symbol cell types, mutation, sheet management, save/load round-trips), using the engine's sample files as inputs.
- `calc_tests_test.rb` — formula-evaluation regression guard: one test per `calc_tests/*.xlsx` fixture, loaded once unevaluated (Excel's cached values) vs once evaluated (IronCalc's recompute), compared cell-by-cell with the engine's relative epsilon (and per-file `METADATA!A1` epsilon/locale overrides). This re-validates the *engine* through the binding on every dependency bump.

`test/fixtures_helper.rb` resolves those fixtures from the **published crate's `tests/` dir** (not vendored copies) via `cargo metadata` → the `ironcalc` package's `manifest_path`. So fixtures stay pinned to whatever engine version we depend on. If the crate source isn't in the Cargo registry yet (no prior `rake compile`/fetch), the fixture-backed tests **skip** with a message rather than fail.

## Architecture

Standard Rust-extension gem with a thin Ruby wrapper layer on top:

- **`ext/ironcalc/src/`** — the magnus extension:
  - `lib.rs` — `#[magnus::init]`, top-level module functions, class/method registration.
  - `model.rs` — `IronCalc::Model`, the raw API (you call `evaluate` yourself).
  - `user_model.rs` — `IronCalc::UserModel`, the user API (auto-evaluates, tracks diffs).
  - `error.rs` — `IronCalc::Error` exception (`Lazy<ExceptionClass>`).
- **`lib/ironcalc.rb`** — version-aware require of the native `.so` (built gem puts it under a Ruby-version subdir; local compile sits directly in `lib/ironcalc/`), then `model.rb`.
- **`lib/ironcalc/model.rb`** — Ruby-side wrappers that convert styles between a Ruby `Hash` and the native `get_cell_style_json`/`set_cell_style_json` JSON methods.

**Coordinates everywhere:** `sheet` is a 0-based `u32`; `row`/`column` are 1-based.

### Critical naming constraint

The Cargo package/lib is **`ironcalc_ruby`**, NOT `ironcalc`, because the engine dependency's own Cargo package is named `ironcalc`, and `RbSys::ExtensionTask` resolves the extension by **Cargo package name** — a same-named ext crate would resolve to the engine and break the build. The engine dep is therefore renamed in `Cargo.toml`: `xlsx = { package = "ironcalc", version = "0.7.1" }`, so Rust source refers to it as `xlsx::base`, `xlsx::import`, `xlsx::export` (matching the Python binding). The compiled artifact is `ironcalc_ruby.so`; `require "ironcalc"` and the gem name are unaffected.

### Idiomatic-Ruby divergences from Python (keep these consistent)

- Errors → `IronCalc::Error` (Python: `WorkbookError`).
- Styles → plain Ruby `Hash` (snake_case keys, serde field names), via `get_cell_style`/`set_cell_style`, serialized as JSON across the boundary. Python uses typed `Style`/`Font`/`Border` objects.
- `get_cell_type` → Ruby **Symbol** (`:number`, `:text`, `:logical_value`, `:error_value`, `:array`, `:compound_data`).
- `get_worksheets_properties` → array of Hashes with symbol keys (`:name`, `:state`, `:sheet_id`, `:color`).
- `get_sheet_dimensions` → 4-element Array `[min_row, max_row, min_col, max_col]`.
- Binary blobs (`to_bytes`, `flush_send_queue`; `load_from_bytes`, `apply_external_diffs`) are binary Ruby `String`s.

## Published-crate API drift (0.7.1 vs IronCalc HEAD)

The Python binding targets IronCalc HEAD; this repo targets published 0.7.1. Differences already handled in `model.rs` — **re-check these when bumping the `ironcalc` dependency** (inspect `~/.cargo/registry/src/*/ironcalc_base-<ver>/src/`):

- HEAD `range_clear_contents(&Area)` → 0.7.1 `cell_clear_contents(sheet, row, column)`.
- HEAD `Color` enum + `SheetProperties.color: Color` → 0.7.1 has no public `Color`; `SheetProperties.color` is already `Option<String>` and `set_sheet_color` takes `&str`.
- `set_cell_style(sheet, row, column, &Style)` does exist in 0.7.1.
