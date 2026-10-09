# AGENTS.md

Guidance for coding agents (and humans) working in this repository.

## What this is

Ruby bindings for the **IronCalc** spreadsheet engine (Rust), built with **magnus** + **rb-sys** and packaged as the `ironcalc` gem. It depends on the **published `ironcalc` crate from crates.io** (currently `0.8.3`), not a local IronCalc checkout.

## Working rules

**1. No incidental changes.** A diff contains what the task needs and nothing else. Don't reformat, rename, reword or restructure code you are not otherwise changing — no repo-wide `cargo fmt`, no tidying an adjacent comment, no rewriting a paragraph of README that merely sits near the edit. If something unrelated looks wrong, say so instead of fixing it.

**2. Comments must earn their place.** Every word load-bearing; if a comment restates the code, delete it. Be descriptive, present tense, about how things *are* — no chronology, no narrative, no bookkeeping, nothing about what changed or why it was added. Three rules that decide most cases:

- **API documentation lives in exactly one place.** For anything callable from Ruby that is `lib/ironcalc/native_methods.rb` (native methods) or the inline YARD comment (Ruby-layer methods). **A `///` on a bound Rust function is read by nobody** — magnus does not surface it, unlike pyo3, which is why the Python bindings document on the Rust side and we do not. Writing one duplicates the stub and the two then drift.
- **Don't explain what IronCalc does.** That is the engine's documentation. Describe engine behaviour only where it makes *our* code look wrong otherwise — the duplicate-`sheet_id` guard, `is_valid_defined_name` taking `&mut self`.
- **Do document our API contract**, including how a call fails. "Raises if the name is already taken in that scope" is contract, not engine trivia.

What survives in `ext/`: section banners, and notes that stop a plausible "fix" — `tt` not `literal` for the arity capture, `#[rustfmt::skip]` on the grouped registrations, symbols interned outside an O(cells) loop.

**3. Follow the Rust codebase; conveniences get their own names.** Structure, naming and terminology track `ironcalc_base` so the two read alike and engine knowledge transfers. For 0.x the API tracks the engine closely, without Ruby-only niceties. The rule:

- **A method sharing a name with an engine method takes the engine's signature**: same parameters, same order, all positional. `rake parity` enforces this.
- **Types map mechanically**: `Option<T>` → a required argument that accepts `nil` (no keyword arguments, no defaults); a struct (`Area`, `CellIndex`, `SheetProperties`, …) → a Hash keyed by its field names as Symbols, never spread into separate arguments; a tuple → an Array; `Result<T, String>` → returns `T`, raises `IronCalc::Error` with the message; enums → Strings/Symbols as below; `Style` → a string-keyed Hash via JSON.
- **Where the engine signature causes real friction, add a helper under a different name** in the Ruby layer, on top of the engine-named method (`valid_defined_name?` over `is_valid_defined_name`). Don't reshape the engine-named one.

**Where fidelity and ergonomics genuinely clash, that is the maintainer's call, not the agent's** — surface the choice rather than deciding it. Existing resolutions are recorded under "Idiomatic-Ruby divergences" below.

The upstream **Python bindings** are a useful cross-check — we should never expose *less* than they do — but they are not the ceiling: exposing more than Python is expected. `rake parity` encodes all of this.

## Build & test

Needs Ruby 3.0+ with development headers, Bundler, and a Rust toolchain.

```sh
bundle install
bundle exec rake compile
bundle exec rake test
bundle exec rake test TEST=test/defined_names_test.rb
bundle exec ruby -Itest test/surface_test.rb -n test_NAME
```

`rake compile` builds `lib/ironcalc/ironcalc_ruby.{so,bundle}` (gitignored); `rake test` runs all suites (minitest).

- **On Ruby 4.0, bindgen runs** (rb-sys 0.9.x ships pre-generated bindings only for older Rubies) and needs libclang. If it fails with `fatal error: 'stdarg.h' file not found`, point it at your compiler's builtin headers, e.g. `BINDGEN_EXTRA_CLANG_ARGS="-I/usr/lib/gcc/x86_64-linux-gnu/13/include"` on Debian/Ubuntu.
- **Standalone `cargo clippy` / `cargo build` don't work** — they lack the Ruby include and link paths that rb-sys's generated Makefile supplies. Build through `rake compile`. `cargo fmt --check` runs fine, but the repo is **not** fmt-clean historically (pre-existing violations in `lib.rs` and `model.rs`); keep new code fmt-consistent rather than reformatting wholesale. CI enforces neither.
- **magnus must be 0.8+** — 0.7.x does not compile against Ruby 4.0's C API.
- First compile builds the whole engine dependency tree from crates.io (several minutes). Incremental binding-only rebuilds take seconds.
- After editing Rust, always `rake compile` before `rake test` — tests load the compiled extension. With a released `ironcalc` gem also installed, run Ruby through `bundle exec`, or `require "ironcalc"` may load the installed gem's extension instead of the local build.
- `ext/ironcalc/Cargo.toml` deliberately has **no `version` field**, so Cargo resolves it to `0.0.0`. If `Cargo.lock` says anything else for `ironcalc_ruby`, it's stale.

### Test layout

`rake test` runs `test/**/*_test.rb`:
- `ironcalc_test.rb` — hand-written unit tests.
- `surface_test.rb` — the binding's *own* surface on the raw `Model` (style Hash, symbol cell types, mutation, sheet management, save/load round-trips including xlsx bytes), using the engine's sample files as inputs.
- `user_model_test.rb` — behaviours unique to `UserModel`: auto-recalculation, undo/redo, per-property styling, pause/resume evaluation.
- `cell_access_test.rb` — typed setters and readers (`update_cell_with_*`, `get_cell_value_by_index`/`_by_ref`, `get_cell_formula`, `is_empty_cell`, `get_all_cells`) and the clear-cell variants.
- `styles_test.rb` — row/column default styles and `copy_cell_style`.
- `sheets_test.rb` — `insert_sheet` positioning and `set_sheet_state` visibility.
- `defined_names_test.rb` — defined names on both APIs, including xlsx and icalc round-trips and undo coverage.
- `utils_test.rb` — the module-level utility functions.
- `calc_tests_test.rb` — formula-evaluation regression guard: one test per `calc_tests/**/*.xlsx` fixture, loaded once unevaluated (Excel's cached values) vs once evaluated (IronCalc's recompute), compared cell-by-cell with the engine's relative epsilon (and per-file `METADATA!A1` epsilon/locale overrides, read as cell *content* — the formatted value shows `#VALUE!`). This re-validates the *engine* through the binding on every dependency bump.

`test/fixtures_helper.rb` resolves those fixtures from the **published crate's `tests/` dir** (not vendored copies) via `cargo metadata` → the `ironcalc` package's `manifest_path`, so they stay pinned to the engine version we depend on. If the crate source isn't in the Cargo registry yet, the fixture-backed tests **skip** rather than fail.

### Checking API surface drift (`rake parity`)

The principle the task encodes: **follow the shape of the engine** — expose what it offers, don't invent names, and record every omission rather than let one happen by accident. Every constant in `tasks/parity.rake` is one of those records, so adding a name to a list is a decision, not a way to quiet the report. `rake parity` introspects the Ruby classes at runtime and diffs them three ways:

1. **The engine (authoritative)**, version-pinned via `cargo metadata` on `ironcalc_base`. For both `Model` and `UserModel` it reports engine methods we don't expose, split into `ENGINE_DEFERRED` (known, listed explicitly so they stay visible — this doubles as **the backlog**) and unreviewed (a hard gap). It also flags **invented names**: anything we expose that has no engine counterpart, which catches typos and stale renames. And it checks **signatures**: a Ruby method sharing an engine method's name (on its own engine class, else the other one) must take the same number of parameters, all positional and required. Deliberate name changes go in `MODEL_RENAMES` / `USERMODEL_RENAMES`; things we assemble ourselves go in `RUBY_COMPOSED`; engine methods the scan can't see (the export crate, reads borrowed through `get_model`) go in `ENGINE_ELSEWHERE`.

   What remains deliberately unexposed (in `ENGINE_OMIT_SHARED` / `ENGINE_OMIT` / `ENGINE_OMIT_PATTERNS`): selection / scroll / window / clipboard / keyboard UI state, drag-fill and `paste_*`, locale / timezone / language (set at construction), grid lines, `hide_sheet`, style-index internals, and the **named-style family** (`set_sheet_style`, `set_sheet_row_style`, `set_sheet_column_style`, `set_cell_style_by_name`) — those resolve a style by name from the workbook's named-styles table, so they stay unusable from Ruby until the named-styles cluster is exposed.
2. **Doc stubs**: every native method must have a `@!method` stub whose arity matches the registration, and no stub may outlive its method. This is the one check that catches doc drift; `DOCUMENTED_IN_RUBY` lists the methods documented inline in `model.rb` instead. It also flags, advisorily, stubs with no prose where Python has a description to borrow.
3. **The Python bindings**, whose Rust sources ship inside the **PyPI sdist** — `ironcalc` on PyPI is versioned in step with the engine, so fetching the sdist for the version we build against pins the comparison with no IronCalc checkout to keep in sync. Cached under `tmp/parity/` (gitignored); only `bindings/python/src/` is extracted. Offline, the check is skipped and the others still run. Exceeding Python is expected and not reported.

   Read `✓ nothing unaccounted` precisely: it subtracts `ENGINE_DEFERRED` before comparing, so it means *every difference is recorded*, **not** that we match Python.

Report-only by default; `STRICT=1 rake parity` exits non-zero on hard gaps. Run it after bumping the `ironcalc` dependency and whenever adding methods. `Model` methods live across several engine files (`model.rs`, `actions.rs`, `styles.rs`, `units.rs`, `new_empty.rs`), so the scan covers `src/*.rs` at top level only — `functions/` also has `impl Model` blocks, but those are formula implementations.

**The backlog** (`ENGINE_DEFERRED`) is worked one cluster per commit, ascending by how much new type surface each needs: sheet ops (`duplicate_sheet`, `move_sheet`) → themes → named styles → conditional formatting → array formulas. Every type involved derives serde `Serialize`/`Deserialize`, so all of it can cross the boundary as JSON, the same way styles already do.

### API docs (`rake doc`, YARD, GitHub Pages)

`rake doc` generates HTML into `doc/` via YARD (config in `.yardopts`). Because the public API is defined in Rust, YARD can't see it — so native methods are documented with `@!method` **stubs** in `lib/ironcalc/native_methods.rb`, a doc-only file never required at runtime. Ruby-layer wrappers in `lib/ironcalc/model.rb` are documented inline as normal. **When you add or rename a native method, update its stub** — `rake parity` catches surface drift but not doc drift.

`--hide-api private` (not just `--no-private`) is what actually hides `@api private` objects such as the `*_json` style accessors.

Published by `.github/workflows/docs.yml` to **GitHub Pages**. Validation (`yard doc --no-output`) runs on every push and PR; the build+deploy only runs on `v*` tag pushes or manual dispatch. Docs are grouped by **engine version** (first three version segments, so `0.8.3.0` → `/0.8.3/`), newest mirrored at the root, with a `versions.html` index. `documentation_uri` in the gemspec is computed from the same three segments.

## Architecture

- **`ext/ironcalc/src/`** — the magnus extension:
  - `lib.rs` — `#[magnus::init]`, top-level module functions, class/method registration.
  - `model.rs` — `IronCalc::Model`, the raw API, plus shared conversions (`area_from_ruby`, `cell_area`, colors, defined names).
  - `user_model.rs` — `IronCalc::UserModel`, the user API.
  - `error.rs` — `IronCalc::Error` exception (`Lazy<ExceptionClass>`), via `workbook_error`.
- **`lib/ironcalc.rb`** — version-aware require of the native extension (built gems put it under a Ruby-version subdir; a local compile sits directly in `lib/ironcalc/`), then `model.rb`.
- **`lib/ironcalc/model.rb`** — the Ruby convenience layer: Hash↔JSON style conversion, `UserModel#set_cell_style`, and helpers under their own names (`defined_names`, `valid_defined_name?`, `batch`).
- **`tasks/`** — `parity.rake`, `yard.rake`, `changelog.rake`, `release.rake`.

**Coordinates everywhere:** `sheet` is a 0-based `u32`; `row`/`column` are 1-based.

### Critical naming constraint

The Cargo package/lib is **`ironcalc_ruby`**, NOT `ironcalc`, because the engine dependency's own Cargo package is named `ironcalc`, and `RbSys::ExtensionTask` resolves the extension by **Cargo package name** — a same-named ext crate would resolve to the engine and break the build. The engine dep is therefore renamed in `Cargo.toml`: `xlsx = { package = "ironcalc", version = "0.8.3" }`, so Rust source refers to it as `xlsx::base`, `xlsx::import`, `xlsx::export` (matching the Python binding). The compiled artifact is `ironcalc_ruby`; `require "ironcalc"` and the gem name are unaffected.

### Two APIs: `UserModel` (recommended) vs `Model` (raw)

The engine exposes two surfaces and the split matters:

- **`IronCalc::UserModel`** — **auto-evaluates after every action** and records diffs for collaboration (`flush_send_queue` / `apply_external_diffs`) and for undo. This is the recommended path and mirrors the **WASM binding**, which is the engine's canonical, best-maintained user-facing surface. Because every mutation is a tracked diff, `undo` / `redo` / `can_undo` / `can_redo` work across everything, including defined names.
- **`IronCalc::Model`** — the **raw** API: you must call `evaluate` yourself, and misuse can leave the workbook in an inconsistent state. It is what `IronCalc.create` / `load_from_xlsx` / `load_from_bytes` return, so plenty of consumer code uses it, and it is *not* frozen at Python parity — add to it when the engine has something useful.

Styling differs between the two: `Model` round-trips a whole-`Style` JSON Hash (`set_cell_style_json` / `get_cell_style_json` under `get_cell_style` / `set_cell_style`); the engine's `UserModel` has **no whole-Style setter**, so `UserModel#set_cell_style` flattens the Hash to dotted paths and applies each leaf via `update_range_style`.

When adding a method, prefer adding it to **both** classes unless the engine only has it on one.

### Idiomatic-Ruby divergences (keep these consistent)

- Errors → `IronCalc::Error` (Python: `WorkbookError`).
- Styles → plain Ruby `Hash` (snake_case keys, serde field names), serialized as JSON across the boundary. Python uses typed `Style`/`Font`/`Border` objects.
- `get_cell_type` → Ruby **Symbol** (`:number`, `:text`, `:logical_value`, `:error_value`, `:array`, `:compound_data`).
- `get_worksheets_properties` → array of Hashes with **symbol** keys (`:name`, `:state`, `:sheet_id`, `:color`). Same convention for `get_defined_name_list` (`:name`, `:scope`, `:formula`).
- `get_sheet_dimensions` → 4-element Array `[min_row, max_row, min_col, max_col]`.
- Binary blobs (`to_bytes`, `to_xlsx_bytes`, `flush_send_queue`; `load_from_bytes`, `load_from_xlsx_bytes`, `apply_external_diffs`) are binary Ruby `String`s. `to_bytes` / `load_from_bytes` are IronCalc's internal icalc format, not xlsx.
- Optional engine args (`Option<u32>` scope, `insert_sheet`'s sheet id) are **positional and required**; pass `nil`. Engine structs are Hashes keyed by field name: `update_range_style` takes an `Area` as `{sheet:, row:, column:, width:, height:}` (read by `area_from_ruby`, which rejects missing or extra keys), `get_all_cells` returns `CellIndex` as `{index:, row:, column:}`. Tuples are Arrays: `copy_cell_style([sheet, row, column], [sheet, row, column])`.
- Ruby-layer helpers live in **prepended** modules (`IronCalc::DefinedNames`, `IronCalc::Batch`) so they count as class surface. Prepended methods don't show up in `instance_methods(false)`, so `rake parity` walks the ancestors to collect them.
- One deliberate behavioural divergence: `Model#insert_sheet` rejects a `sheet_id` already in use, which the engine doesn't check (a duplicate makes sheet-scoped defined names resolve to the wrong sheet).
- Engine args typed as a Rust enum become a **String** matching the engine's own spelling, so they round-trip with the reader: `set_sheet_state(sheet, "veryHidden")` pairs with the `:state` value from `get_worksheets_properties`. (snake_case is accepted too.)
- `Style` is a complete serde struct with no field defaults, so **every style setter needs a full style** — `set_cell_style`, `set_column_style`, `set_row_style`. The usage pattern is read one, mutate, write back; a partial Hash raises `missing field ...`.

### Defined names

Exposed on both classes: `get_defined_name_list` (also `defined_names`), `new_defined_name`, `update_defined_name`, `delete_defined_name`, `is_valid_defined_name` (raises with the reason; `valid_defined_name?` is the boolean helper). `scope` is a 0-based sheet index or `nil` for workbook scope. The engine imports and exports `<definedName>` in xlsx, and formula evaluation resolves names, so these survive a round trip *and* a user editing the file in Excel — which makes them a good slot for durable metadata about a sheet. Custom doc properties, custom XML parts and Tables don't survive one or both. Python exposes none of this.

## Engine API drift

**Re-check on every `ironcalc` dependency bump**: read the engine source in the Cargo registry (`~/.cargo/registry/src/*/ironcalc_base-<ver>/src/`), and let `rake compile`, `rake parity` and `rake test` enumerate the rest. Things that have moved before and are worth checking first:

- Range-based methods (`range_clear_contents(&Area)` and friends) vs per-cell ones; `cell_area` in `model.rs` builds the 1×1 area both classes use for the per-cell Ruby methods.
- `Color` (`Rgb(String)` / `Theme(i32, f64)` / `None`, `#[serde(untagged)]`, so RGB serializes as a hex String and a theme color as a `[theme, tint]` pair), used by `SheetProperties.color` and `set_sheet_color`.
- The `Style` struct, which is the public style Hash: renamed fields (0.8.3 replaced `Fill`'s `fg_color` / `bg_color` with `color`) and defaults (0.8.3 moved the default font from Calibri 13 to Inter 12) are breaking changes for users.
- The layout of the crate's `tests/calc_tests` fixtures: they sit in per-category subdirectories, so `fixtures_helper.rb` globs `**`. A fixture count that drops without failures or skips means the glob missed them.
- `UserModel` spells some operations as ranges (`set_columns_width` / `set_rows_height`) where `Model` has per-item ones (`set_column_width` / `set_row_height`); the Ruby names are singular on both.

## Workflow

Changes reach `main` through pull requests, not direct pushes; the one exception is the `prepare version` commit (below). Work on a branch off `main`, keep one logical change per commit, and open a PR for review. Each commit should build and pass `rake test` on its own, so the PR can be reviewed commit by commit. Before opening it, run `rake test`, `STRICT=1 rake parity`, `rake doc` and `standardrb`. Agents commit, push and open PRs only when asked.

## Release

Versioning is `<engine version>.<binding patch>` — e.g. `0.8.3.1` would be the 2nd binding release against engine 0.8.3. The first three segments track the engine dependency and the docs site groups on them, so don't move them for binding-only work.

Maintainers run releases, tagging `main` after the PR merges; **agents don't tag.**

### Version bumps live in their own commit

`lib/ironcalc/version.rb` and the `CHANGELOG.md` section are **not** touched by feature commits. They go in a single `prepare version <x>` commit that the maintainer makes directly on `main` once the release's PRs have merged, holding exactly those two files — the convention every release here has followed. The CHANGELOG section is written *there*, describing everything since the last release, rather than accumulated bullet-by-bullet.

This matters more than it looks when bumping the engine, because our version encodes the engine version: it is tempting to fold `version.rb` into the engine-bump commit. Don't — a release usually spans several commits, and dating it at the first one makes the CHANGELOG describe code that does not exist yet at that point.

Between releases `version.rb` therefore holds the *last released* version, even when the tree already targets a newer engine.

### Flow

Bump `lib/ironcalc/version.rb`, add a terse `## <version>` CHANGELOG section (what changed, not what will happen), `rake changelog:check`, then `rake release`. `rake changelog:unreleased` drafts bullets from git log. Publishing happens in CI on tag push (`tags: ["v*"]`, Trusted Publishing + provenance), never from a workstation — there is no API key in the repo or in CI.

### Prereleases

A version with a letter in it is a RubyGems prerelease: `0.8.3.0.pre` sorts after `0.7.1.5` and before `0.8.3.0`, groups to `0.8.3` for the docs, and is skipped by `gem install` unless `--pre` is passed. Prefer `0.8.3.0.pre` over `0.8.3.pre` so the binding-patch segment stays in place. `rake changelog:check` matches the section heading exactly, so a prerelease needs its own `## <x>.pre` heading. Worth doing when a release carries breaking changes that consumers should verify against real workbooks first; the `v*` tag glob publishes it through the normal path.

### Packaging

`spec.files` is an allowlist, not a `*.md` glob, so working notes (and this file) stay out of the gem. Keep it explicit when adding files.
