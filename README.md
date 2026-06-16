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

A Rust toolchain is required to build from source.

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

## Development

```sh
bundle install
bundle exec rake compile
bundle exec rake test
```

## License

Dual-licensed under [MIT](LICENSE-MIT.md) or [Apache-2.0](LICENSE-Apache-2.0.md),
matching IronCalc.
