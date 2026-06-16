# Documentation-only stubs for the methods implemented in the native extension
# (ext/ironcalc, via magnus). YARD cannot see Rust source, so the public native
# API is described here with `@!method` directives. This file is NOT required at
# runtime — the real methods are defined by the compiled extension. Keep these
# stubs in sync with the Rust sources in ext/ironcalc/src (and `rake parity`).
#
# Coordinate convention everywhere: +sheet+ is a 0-based index; +row+ and
# +column+ are 1-based.

module IronCalc
  # @!method create(name, locale, tz, language_id)
  #   @!scope class
  #   Creates an empty workbook using the raw {Model} API.
  #   @param name [String] workbook name
  #   @param locale [String] e.g. "en"
  #   @param tz [String] IANA timezone, e.g. "UTC"
  #   @param language_id [String] e.g. "en"
  #   @return [IronCalc::Model]
  #   @raise [IronCalc::Error]

  # @!method load_from_xlsx(file_path, locale, tz, language_id)
  #   @!scope class
  #   Loads a workbook from an xlsx file into the raw {Model} API.
  #   @param file_path [String]
  #   @param locale [String]
  #   @param tz [String]
  #   @param language_id [String]
  #   @return [IronCalc::Model]
  #   @raise [IronCalc::Error]

  # @!method load_from_icalc(file_name, language_id)
  #   @!scope class
  #   Loads a workbook from the internal binary icalc format.
  #   @param file_name [String]
  #   @param language_id [String]
  #   @return [IronCalc::Model]
  #   @raise [IronCalc::Error]

  # @!method load_from_bytes(bytes, language_id)
  #   @!scope class
  #   Loads a workbook from icalc bytes (as produced by {Model#to_bytes}).
  #   @param bytes [String] binary icalc bytes
  #   @param language_id [String]
  #   @return [IronCalc::Model]
  #   @raise [IronCalc::Error]

  # @!method create_user_model(name, locale, tz, language_id)
  #   @!scope class
  #   Creates an empty workbook using the recommended {UserModel} API.
  #   @param name [String]
  #   @param locale [String]
  #   @param tz [String]
  #   @param language_id [String]
  #   @return [IronCalc::UserModel]
  #   @raise [IronCalc::Error]

  # @!method create_user_model_from_xlsx(file_path, locale, tz, language_id)
  #   @!scope class
  #   Loads an xlsx file into the {UserModel} API.
  #   @param file_path [String]
  #   @param locale [String]
  #   @param tz [String]
  #   @param language_id [String]
  #   @return [IronCalc::UserModel]
  #   @raise [IronCalc::Error]

  # @!method create_user_model_from_icalc(file_name, language_id)
  #   @!scope class
  #   Loads an icalc file into the {UserModel} API.
  #   @param file_name [String]
  #   @param language_id [String]
  #   @return [IronCalc::UserModel]
  #   @raise [IronCalc::Error]

  # @!method create_user_model_from_bytes(bytes, language_id)
  #   @!scope class
  #   Loads icalc bytes into the {UserModel} API.
  #   @param bytes [String] binary icalc bytes
  #   @param language_id [String]
  #   @return [IronCalc::UserModel]
  #   @raise [IronCalc::Error]

  # The raw IronCalc API. You must call {#evaluate} yourself after changing
  # inputs; misuse can leave the workbook in an inconsistent state. This mirrors
  # the Python binding's `Model`. For most uses prefer {UserModel}, which
  # auto-evaluates.
  class Model
    # @!method save_to_xlsx(file)
    #   Saves the workbook to an xlsx file. Fails if the file already exists.
    #   @param file [String]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method save_to_icalc(file)
    #   Saves the workbook to the internal binary icalc format.
    #   @param file [String]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method to_bytes
    #   Serializes the workbook to icalc bytes (load with {IronCalc.load_from_bytes}).
    #   @return [String] binary string

    # @!method evaluate
    #   Recalculates the whole workbook. Call after {#set_user_input}.
    #   @return [void]

    # @!method set_user_input(sheet, row, column, value)
    #   Sets a cell's raw input (a literal or a formula like "=A1+1").
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param column [Integer]
    #   @param value [String]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method clear_cell_contents(sheet, row, column)
    #   Clears a cell's contents (not its style).
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param column [Integer]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method get_cell_content(sheet, row, column)
    #   Returns the cell's content: the formula (e.g. "=A1+1") or literal text.
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param column [Integer]
    #   @return [String]
    #   @raise [IronCalc::Error]

    # @!method get_cell_type(sheet, row, column)
    #   Returns the cell type as a Symbol: +:number+, +:text+, +:logical_value+,
    #   +:error_value+, +:array+ or +:compound_data+.
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param column [Integer]
    #   @return [Symbol]
    #   @raise [IronCalc::Error]

    # @!method get_formatted_cell_value(sheet, row, column)
    #   Returns the cell's value formatted as displayed (number format applied).
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param column [Integer]
    #   @return [String]
    #   @raise [IronCalc::Error]

    # @!method get_cell_style_json(sheet, row, column)
    #   @api private
    #   JSON backing for `get_cell_style`. Prefer the Hash-returning wrapper.
    #   @return [String]

    # @!method set_cell_style_json(sheet, row, column, style_json)
    #   @api private
    #   JSON backing for `set_cell_style`. Prefer the Hash-accepting wrapper.
    #   @return [void]

    # @!method insert_rows(sheet, row, row_count)
    #   Inserts +row_count+ rows before +row+.
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param row_count [Integer]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method insert_columns(sheet, column, column_count)
    #   Inserts +column_count+ columns before +column+.
    #   @param sheet [Integer]
    #   @param column [Integer]
    #   @param column_count [Integer]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method delete_rows(sheet, row, row_count)
    #   Deletes +row_count+ rows starting at +row+.
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param row_count [Integer]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method delete_columns(sheet, column, column_count)
    #   Deletes +column_count+ columns starting at +column+.
    #   @param sheet [Integer]
    #   @param column [Integer]
    #   @param column_count [Integer]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method get_column_width(sheet, column)
    #   @param sheet [Integer]
    #   @param column [Integer]
    #   @return [Float] width in pixels
    #   @raise [IronCalc::Error]

    # @!method get_row_height(sheet, row)
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @return [Float] height in pixels
    #   @raise [IronCalc::Error]

    # @!method set_column_width(sheet, column, width)
    #   @param sheet [Integer]
    #   @param column [Integer]
    #   @param width [Float]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method set_row_height(sheet, row, height)
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param height [Float]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method get_frozen_columns_count(sheet)
    #   @param sheet [Integer]
    #   @return [Integer]
    #   @raise [IronCalc::Error]

    # @!method get_frozen_rows_count(sheet)
    #   @param sheet [Integer]
    #   @return [Integer]
    #   @raise [IronCalc::Error]

    # @!method set_frozen_columns_count(sheet, count)
    #   @param sheet [Integer]
    #   @param count [Integer]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method set_frozen_rows_count(sheet, count)
    #   @param sheet [Integer]
    #   @param count [Integer]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method get_worksheets_properties
    #   Returns one Hash per sheet with symbol keys +:name+, +:state+,
    #   +:sheet_id+ and +:color+.
    #   @return [Array<Hash>]

    # @!method set_sheet_color(sheet, color)
    #   @param sheet [Integer]
    #   @param color [String] hex color, e.g. "#FF0000"
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method add_sheet(name)
    #   Adds a new sheet with the given name.
    #   @param name [String]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method new_sheet
    #   Adds a new sheet with an auto-generated name.
    #   @return [void]

    # @!method delete_sheet(sheet)
    #   @param sheet [Integer]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method rename_sheet(sheet, new_name)
    #   @param sheet [Integer]
    #   @param new_name [String]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method get_sheet_dimensions(sheet)
    #   Returns +[min_row, max_row, min_column, max_column]+ over non-empty cells
    #   (an empty sheet returns +[1, 1, 1, 1]+).
    #   @param sheet [Integer]
    #   @return [Array(Integer, Integer, Integer, Integer)]
    #   @raise [IronCalc::Error]
  end

  # The recommended, higher-level IronCalc API. Auto-evaluates after every action
  # and records diffs for collaboration ({#flush_send_queue} /
  # {#apply_external_diffs}). Mirrors IronCalc's WebAssembly binding and is a
  # superset of the Python binding's `UserModel`. Styling is per-property via
  # {UserModel#update_range_style} (the Hash convenience {UserModel#set_cell_style}
  # is layered on top).
  class UserModel
    # @!method save_to_xlsx(file)
    #   Saves the workbook to an xlsx file. Fails if the file already exists.
    #   @param file [String]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method save_to_icalc(file)
    #   Saves the workbook to the internal binary icalc format.
    #   @param file [String]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method to_bytes
    #   Serializes the workbook to icalc bytes.
    #   @return [String] binary string

    # @!method apply_external_diffs(diffs)
    #   Applies a peer's diff blob (from {#flush_send_queue}) for collaboration.
    #   @param diffs [String] binary diff blob
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method flush_send_queue
    #   Returns and clears the queued diffs to broadcast to collaborators.
    #   @return [String] binary diff blob

    # @!method evaluate
    #   Forces a recalculation. Usually unnecessary — the user model
    #   auto-evaluates after each action; exposed for parity.
    #   @return [void]

    # @!method undo
    #   Undoes the last change.
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method redo
    #   Redoes the last undone change.
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method can_undo
    #   @return [Boolean]

    # @!method can_redo
    #   @return [Boolean]

    # @!method set_user_input(sheet, row, column, value)
    #   Sets a cell's raw input (literal or formula). Triggers recalculation.
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param column [Integer]
    #   @param value [String]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method clear_cell_contents(sheet, row, column)
    #   Clears a cell's contents (not its style).
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param column [Integer]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method get_cell_content(sheet, row, column)
    #   Returns the cell's content: formula or literal text.
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param column [Integer]
    #   @return [String]
    #   @raise [IronCalc::Error]

    # @!method get_cell_type(sheet, row, column)
    #   Returns the cell type as a Symbol (see {Model#get_cell_type}).
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param column [Integer]
    #   @return [Symbol]
    #   @raise [IronCalc::Error]

    # @!method get_formatted_cell_value(sheet, row, column)
    #   Returns the cell's value formatted as displayed.
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param column [Integer]
    #   @return [String]
    #   @raise [IronCalc::Error]

    # @!method get_cell_style_json(sheet, row, column)
    #   @api private
    #   JSON backing for `get_cell_style`. Prefer the Hash-returning wrapper.
    #   @return [String]

    # @!method update_range_style(sheet, row, column, style_path, value)
    #   Sets a single style property on a cell, e.g. +update_range_style(0, 1, 1,
    #   "font.b", "true")+. This is the user model's styling primitive (mirrors
    #   the WASM binding); `set_cell_style` wraps it for whole-Hash convenience.
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param column [Integer]
    #   @param style_path [String] dotted path, e.g. "font.b", "fill.fg_color"
    #   @param value [String]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method insert_rows(sheet, row, row_count)
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param row_count [Integer]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method insert_columns(sheet, column, column_count)
    #   @param sheet [Integer]
    #   @param column [Integer]
    #   @param column_count [Integer]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method delete_rows(sheet, row, row_count)
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param row_count [Integer]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method delete_columns(sheet, column, column_count)
    #   @param sheet [Integer]
    #   @param column [Integer]
    #   @param column_count [Integer]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method get_column_width(sheet, column)
    #   @param sheet [Integer]
    #   @param column [Integer]
    #   @return [Float] width in pixels
    #   @raise [IronCalc::Error]

    # @!method get_row_height(sheet, row)
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @return [Float] height in pixels
    #   @raise [IronCalc::Error]

    # @!method set_column_width(sheet, column, width)
    #   @param sheet [Integer]
    #   @param column [Integer]
    #   @param width [Float]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method set_row_height(sheet, row, height)
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param height [Float]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method get_frozen_columns_count(sheet)
    #   @param sheet [Integer]
    #   @return [Integer]
    #   @raise [IronCalc::Error]

    # @!method get_frozen_rows_count(sheet)
    #   @param sheet [Integer]
    #   @return [Integer]
    #   @raise [IronCalc::Error]

    # @!method set_frozen_columns_count(sheet, count)
    #   @param sheet [Integer]
    #   @param count [Integer]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method set_frozen_rows_count(sheet, count)
    #   @param sheet [Integer]
    #   @param count [Integer]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method get_worksheets_properties
    #   Returns one Hash per sheet with symbol keys +:name+, +:state+,
    #   +:sheet_id+ and +:color+.
    #   @return [Array<Hash>]

    # @!method set_sheet_color(sheet, color)
    #   @param sheet [Integer]
    #   @param color [String] hex color, e.g. "#FF0000"
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method new_sheet
    #   Adds a new sheet with an auto-generated name.
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method delete_sheet(sheet)
    #   @param sheet [Integer]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method rename_sheet(sheet, new_name)
    #   @param sheet [Integer]
    #   @param new_name [String]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method get_sheet_dimensions(sheet)
    #   Returns +[min_row, max_row, min_column, max_column]+ over non-empty cells.
    #   @param sheet [Integer]
    #   @return [Array(Integer, Integer, Integer, Integer)]
    #   @raise [IronCalc::Error]
  end
end
