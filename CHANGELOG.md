## 0.9.0.0

- update the IronCalc engine to 0.9.0

## 0.8.3.0

- update the IronCalc engine to 0.8.3
- **breaking**: `fill` styles use a single `color` key; `fg_color` and
  `bg_color` are gone
- **breaking**: the default font is now Inter 12, was Calibri 13
- **breaking**: `UserModel#update_range_style` takes the engine's area as a
  Hash, `update_range_style({sheet:, row:, column:, width:, height:}, path,
  value)`, and styles the whole range; it took a single cell before
- **breaking**: every native method has the engine's name and signature, with
  `nil` for an optional parameter and Hashes for engine structs. Renamed:
  - `Model`: `clear_cell_contents(sheet, row, column)` →
    `range_clear_contents(range)`, `get_cell_content` →
    `get_localized_cell_content`, `get_cell_style` → `get_style_for_cell`,
    `set_frozen_rows_count` / `set_frozen_columns_count` → `set_frozen_rows` /
    `set_frozen_columns`, `rename_sheet(sheet, name)` →
    `rename_sheet_by_index`; `rename_sheet(old_name, new_name)` renames by name
  - `UserModel`: `clear_cell_contents(sheet, row, column)` →
    `range_clear_contents(range)`, `set_column_width(sheet, column, width)` →
    `set_columns_width(sheet, column_start, column_end, width)`, and likewise
    `set_rows_height`
- **breaking**: style Hashes have Symbol keys (`style[:font][:b]`); setters
  accept Symbol or String keys, but no longer a JSON String
- **breaking**: `UserModel#set_cell_style` is removed; style a `UserModel` per
  property with `update_range_style`. It could not write back a style read with
  `get_cell_style`, and failed part-way through.
- `set_sheet_color` accepts nil to clear a sheet's color
- sheet colors read back as nil rather than absent when unset
- defined names on `Model` and `UserModel`: `defined_names`,
  `new_defined_name`, `update_defined_name`, `delete_defined_name`,
  `is_valid_defined_name` (raises with the reason) and `valid_defined_name?`
- typed cell setters on `Model`: `update_cell_with_text`, `_number`, `_bool`,
  `_formula`
- typed cell readers on `Model`: `get_cell_value_by_index`,
  `get_cell_value_by_ref`, `get_cell_formula`, `is_empty_cell`, `get_all_cells`
- row and column default styles on `Model`: `get`/`set`/`delete_column_style`,
  `get`/`set`/`delete_row_style`, plus `copy_cell_style`
- `range_clear_all` on both APIs, `range_clear_formatting` on `UserModel`
- `insert_sheet` and `set_sheet_state` on `Model`
- `pause_evaluation` / `resume_evaluation` on `UserModel`, and `batch` to
  recalculate once after a block
- hidden rows and columns: `is_column_hidden` / `is_row_hidden` on both APIs,
  `set_column_hidden` / `set_row_hidden` on `Model`, `set_columns_hidden` /
  `set_rows_hidden` on `UserModel`
- xlsx in memory: `to_xlsx_bytes` on both APIs, `load_from_xlsx_bytes` and
  `create_user_model_from_xlsx_bytes`
- fix a memory leak: every constructor leaked its string arguments on each call
- package only README, CHANGELOG and licenses instead of every `*.md`

## 0.7.1.5

- link to changelog and documentation in gemspec
- update actions
- work-around for yard bug

## 0.7.1.4

- build for Ruby 4.0
- push with attestation
- include .yardopts

## 0.7.1.3

- fix build-provenance and setup github releases

## 0.7.1.2

- Ship precompiled native gems for common platforms (Linux, macOS, Windows),
  so installing no longer rebuilds the IronCalc engine from source
- Publish via RubyGems Trusted Publishing with SigStore build provenance

## 0.7.1.1

- Fix build: remove internal crate version

## 0.7.1.0

- First release
- Ruby bindings for the IronCalc spreadsheet engine (engine 0.7.1)
- Raw API (`IronCalc::Model`) and user API (`IronCalc::UserModel`)
- Load/save xlsx and the internal icalc binary format
