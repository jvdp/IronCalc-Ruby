# IronCalc for Ruby

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
model.set_user_input(0, 1, 1, "=6*7")
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

### Typed cell access

`set_user_input` parses what you give it, the way typing into a cell does — so
`"007"` becomes the number 7 and `"=1+1"` becomes a formula. The typed setters
skip that, and the typed reader gives you a Ruby object instead of a String:

```ruby
model.update_cell_with_text(0, 1, 1, "007")     # stays the string "007"
model.update_cell_with_number(0, 1, 2, 42.5)
model.update_cell_with_bool(0, 1, 3, true)
model.update_cell_with_formula(0, 1, 4, "=B1*2")
model.evaluate

model.get_cell_value_by_index(0, 1, 2)  # => 42.5 (Float, not "42.5")
model.get_cell_value_by_ref("Sheet1!D1")  # => 85.0
model.get_cell_formula(0, 1, 4)         # => "=B1*2", or nil if not a formula
model.is_empty_cell(0, 9, 9)            # => true
model.get_all_cells                     # => [{ sheet:, row:, column: }, ...]
```

`get_all_cells` lists every cell the workbook has a record for. Clearing a
cell's contents keeps its record, so filter with `is_empty_cell` if you want
only cells that still hold a value.

`clear_cell_contents` keeps the cell's style; `clear_cell_all` removes both.
On `UserModel`, `clear_cell_formatting` does the opposite — style only.

### Rows, columns and sheets

Rows and columns can carry a default style. As with `set_cell_style`, a style is
a complete structure, so read one, change a field, and pass it back:

```ruby
style = model.get_cell_style(0, 1, 1)
style["num_fmt"] = "0.00"
model.set_column_style(0, 2, style)
model.get_column_style(0, 2)    # => Hash, or nil if the column has no style
model.delete_column_style(0, 2)

model.copy_cell_style(0, 1, 1, 0, 5, 5)   # style only, works across sheets

model.insert_sheet("Summary", 0)          # position, rather than appending
model.set_sheet_state(1, "hidden")        # or "visible" / "veryHidden"
```

### Bulk loading

`UserModel` recalculates after every action. When writing many cells, suspend
that and evaluate once:

```ruby
um.batch do |m|
  rows.each { |r, c, v| m.set_user_input(0, r, c, v) }
end                             # recalculated once, here
```

`batch` nests, and recalculates even if the block raises. The underlying
`pause_evaluation` / `resume_evaluation` pair is still available if you need to
manage it yourself.

### Defined names

Named ranges, on both APIs. `scope` is a 0-based sheet index, or `nil` (the
default) for a workbook-scoped name. They survive both an xlsx round trip and
editing in Excel/LibreOffice, so they are also a place to keep your own
metadata about a sheet.

```ruby
model.new_defined_name("answer", "Sheet1!$C$1")
model.set_user_input(0, 1, 1, "=answer")
model.evaluate
model.get_formatted_cell_value(0, 1, 1)  # => the value of C1

model.defined_names
# => [{ name: "answer", scope: nil, formula: "Sheet1!$C$1" }]

model.update_defined_name("answer", "result", "Sheet1!$D$1")
model.delete_defined_name("result")
```

`is_valid_defined_name(name, formula, scope: nil)` reports whether
`new_defined_name` would succeed; the name must be an identifier (`"A1"` is
rejected — it parses as a cell reference), unused in that scope, and the formula
must parse. On `UserModel` all four mutations are undoable.

### Top-level methods

`create`, `load_from_xlsx`, `load_from_icalc`, `load_from_bytes`,
`create_user_model`, `create_user_model_from_xlsx`,
`create_user_model_from_icalc`, `create_user_model_from_bytes`.

Errors raised by the engine surface as `IronCalc::Error`.

## Relationship to the Python bindings

`ironcalc-ruby` is a thin binding over the same Rust engine as the
[IronCalc Python bindings](https://github.com/ironcalc/ironcalc/tree/main/bindings/python).
Both are compiled native extensions (Python via **pyo3**, Ruby via **magnus** /
**rb-sys**) exposing a module named `ironcalc` backed by the IronCalc engine.

Both follow the shape of the engine, so the two APIs line up closely and Python
examples usually translate directly. They do not cover the same amount of it —
see [Coverage compared to the Python bindings](#coverage-compared-to-the-python-bindings).

### What's identical

- **Two APIs**: a raw `Model` (you call `evaluate` yourself) and a higher-level
  `UserModel` (auto-evaluates and tracks diffs).
- **Top-level constructors**, same names and argument order
  `(name_or_path, locale, tz, language_id)`: `create`, `load_from_xlsx`,
  `load_from_icalc`, `load_from_bytes`, `create_user_model`,
  `create_user_model_from_xlsx`, `create_user_model_from_icalc`,
  `create_user_model_from_bytes`.
- **Method names and signatures** for everything both expose — `set_user_input`,
  `get_formatted_cell_value`, `evaluate`, `insert_rows`, `set_column_width`,
  `new_sheet`, `save_to_xlsx`, `to_bytes`, … (Python's `snake_case` is also
  Ruby's convention, so they match exactly).
- **Coordinates**: `sheet` is a 0-based index; `row` and `column` are 1-based.
- **Semantics**: the same engine, so the same inputs produce the same results.

```python
# Python
import ironcalc as ic
model = ic.create("model", "en", "UTC", "en")
model.set_user_input(0, 1, 1, "=6*7")
model.evaluate()
model.get_formatted_cell_value(0, 1, 1)   # "42"
```

```ruby
# Ruby
require "ironcalc"
model = IronCalc.create("model", "en", "UTC", "en")
model.set_user_input(0, 1, 1, "=6*7")
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
| Binary data | `bytes` | binary `String` |
| Version | `ironcalc.__version__` | `IronCalc::VERSION` |

Rather than reconstruct Python's per-field style classes, Ruby exchanges styles
as plain hashes (serialized as JSON across the boundary). Everything else is kept
as close to the Python bindings as the two languages allow.

### Coverage compared to the Python bindings

Both bindings wrap the same engine, so anything both expose behaves the same.
They do not expose the same amount of it. Counted against **IronCalc 0.8.3**,
the version this gem tracks, and accurate at the time of writing:

| | Python | Ruby |
|---|---|---|
| `Model` | 69 | 62 |
| `UserModel` | 103 | 48 |

Most of the difference is deliberate. Selection, scrolling, clipboard and
keyboard state belong to a UI rather than to a library, and are not exposed
here. Conditional formatting, named styles, themes and hidden rows/columns are
a known backlog, listed explicitly in `rake parity`'s `ENGINE_DEFERRED` so they
stay visible.

What Ruby adds is layering rather than extra engine coverage: Hash-based
styles, keyword arguments for optional trailing parameters, and `batch`.

These numbers move with every engine release; `rake parity` reports the
current picture.

## License

Dual-licensed under [MIT](LICENSE-MIT.md) or [Apache-2.0](LICENSE-Apache-2.0.md),
matching IronCalc.
