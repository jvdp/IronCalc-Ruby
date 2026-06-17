# IronCalc Ruby

Ruby bindings for [IronCalc](https://www.ironcalc.com/), a modern spreadsheet
engine written in Rust. Create, read and manipulate xlsx files — manage sheets,
set and read cell values, and evaluate formulas.

Built with [magnus](https://github.com/matsadler/magnus) /
[rb-sys](https://github.com/oxidize-rb/rb-sys), and modeled on the
[IronCalc Python bindings](https://github.com/ironcalc/ironcalc/tree/main/bindings/python).

## Installation

Add this line to your application's Gemfile:

```ruby
gem "ironcalc"
```

On common platforms (Linux, macOS, Windows) a precompiled gem is installed, so
no Rust toolchain is required. On other platforms the gem builds the IronCalc
engine from source, which requires a Rust toolchain.

## Usage

```ruby
require "ironcalc"

# Raw API — call evaluate yourself.
model = IronCalc.create("model", "en", "UTC", "en")
model.set_user_input(0, 1, 1, "=21*2")
model.evaluate
model.get_formatted_cell_value(0, 1, 1) # => "42"
model.save_to_xlsx("out.xlsx")

# User API — auto-evaluates and tracks diffs for collaboration.
um = IronCalc.create_user_model("model", "en", "UTC", "en")
um.set_user_input(0, 1, 1, "=1+2")
um.get_formatted_cell_value(0, 1, 1)    # => "3"
diffs = um.flush_send_queue             # binary diff to send to peers
```

Coordinates: `sheet` is a 0-based index; `row` and `column` are 1-based. Styles
are exchanged as plain Ruby hashes via `get_cell_style` / `set_cell_style`.

### Top-level methods

`create`, `load_from_xlsx`, `load_from_icalc`, `load_from_bytes`,
`create_user_model`, `create_user_model_from_xlsx`,
`create_user_model_from_icalc`, `create_user_model_from_bytes`.

Errors raised by the engine surface as `IronCalc::Error`.

## Relationship to the Python bindings

`ironcalc-ruby` is a thin binding over the same Rust engine as the
[IronCalc Python bindings](https://github.com/ironcalc/ironcalc/tree/main/bindings/python),
and deliberately mirrors their API. Both are compiled native extensions (Python
via **pyo3**, Ruby via **magnus** / **rb-sys**) exposing a module named
`ironcalc` backed by the IronCalc engine.

### What's identical

- **Two APIs**: a raw `Model` (you call `evaluate` yourself) and a higher-level
  `UserModel` (auto-evaluates and tracks diffs).
- **Top-level constructors**, same names and argument order
  `(name_or_path, locale, tz, language_id)`: `create`, `load_from_xlsx`,
  `load_from_icalc`, `load_from_bytes`, `create_user_model`,
  `create_user_model_from_xlsx`, `create_user_model_from_icalc`,
  `create_user_model_from_bytes`.
- **Method names and signatures** on `Model` / `UserModel` — `set_user_input`,
  `get_formatted_cell_value`, `evaluate`, `insert_rows`, `set_column_width`,
  `add_sheet`, `save_to_xlsx`, `to_bytes`, … (Python's `snake_case` is also
  Ruby's convention, so they match exactly).
- **Coordinates**: `sheet` is a 0-based index; `row` and `column` are 1-based.
- **Semantics**: the same engine, so the same inputs produce the same results.

```python
# Python
import ironcalc as ic
model = ic.create("model", "en", "UTC", "en")
model.set_user_input(0, 1, 1, "=21*2")
model.evaluate()
model.get_formatted_cell_value(0, 1, 1)   # "42"
```

```ruby
# Ruby
require "ironcalc"
model = IronCalc.create("model", "en", "UTC", "en")
model.set_user_input(0, 1, 1, "=21*2")
model.evaluate
model.get_formatted_cell_value(0, 1, 1)   # "42"
```

### Idiomatic Ruby adaptations

A few return and argument types follow Ruby conventions instead of being literal
ports:

| Concern | Python | Ruby |
|---|---|---|
| Module access | `ic.create(...)` | `IronCalc.create(...)` |
| Error type | `WorkbookError` | `IronCalc::Error` |
| Cell style | typed `Style` / `Font` / … objects | plain `Hash` (`get_cell_style` / `set_cell_style`) |
| Cell type | `CellType` enum | `Symbol` (`:number`, `:text`, …) |
| Worksheet properties | list of `SheetProperty` objects | array of `Hash`es (`:name`, `:state`, `:sheet_id`, `:color`) |
| Sheet dimensions | tuple `(min_row, max_row, min_col, max_col)` | 4-element `Array` |
| Binary blobs | `bytes` | binary `String` |
| Version | `ironcalc.__version__` | `IronCalc::VERSION` |

Rather than reconstruct Python's per-field style classes, Ruby exchanges styles
as plain hashes (serialized as JSON across the boundary). Everything else is kept
as close to the Python bindings as the two languages allow.

## Development

```sh
bundle install
bundle exec rake compile
bundle exec rake test
```

## License

Dual-licensed under [MIT](LICENSE-MIT.md) or [Apache-2.0](LICENSE-Apache-2.0.md),
matching IronCalc.
