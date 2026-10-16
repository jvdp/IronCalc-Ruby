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

  # @!method load_from_xlsx_bytes(bytes, name, locale, tz, language_id)
  #   @!scope class
  #   Loads a workbook from the bytes of an xlsx file into the raw {Model} API
  #   (as produced by {Model#to_xlsx_bytes}).
  #   @param bytes [String] binary xlsx bytes
  #   @param name [String] workbook name
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

  # @!method create_user_model_from_xlsx_bytes(bytes, name, locale, tz, language_id)
  #   @!scope class
  #   Loads the bytes of an xlsx file into the {UserModel} API.
  #   @param bytes [String] binary xlsx bytes
  #   @param name [String] workbook name
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

  # @!method column_to_number(column)
  #   @!scope class
  #   Column identifier to 1-based number: +"AA"+ becomes 27.
  #   @param column [String] uppercase A-Z letters
  #   @return [Integer]
  #   @raise [IronCalc::Error] if it is not a valid column identifier

  # @!method number_to_column(column)
  #   @!scope class
  #   1-based number to column identifier: 27 becomes +"AA"+.
  #   @param column [Integer]
  #   @return [String, nil] nil when outside the sheet's columns

  # @!method is_valid_column(column)
  #   @!scope class
  #   Whether +column+ is a column identifier within the sheet, e.g. +"AA"+.
  #   @param column [String]
  #   @return [Boolean]

  # @!method is_valid_column_number(column)
  #   @!scope class
  #   Whether +column+ is a 1-based column number within the sheet.
  #   @param column [Integer]
  #   @return [Boolean]

  # @!method is_valid_row(row)
  #   @!scope class
  #   Whether +row+ is a 1-based row number within the sheet.
  #   @param row [Integer]
  #   @return [Boolean]

  # @!method is_valid_identifier(name)
  #   Whether +name+ can be a defined name. This is {is_valid_a1_identifier}
  #   minus the four single letters +"R"+, +"r"+, +"C"+ and +"c"+, which
  #   spreadsheets reserve for R1C1 notation — they stay usable as LAMBDA
  #   parameters and LET variables, so the A1 form accepts them.
  #
  #     IronCalc.is_valid_identifier("total")  # => true
  #     IronCalc.is_valid_identifier("R")      # => false, the only difference
  #     IronCalc.is_valid_identifier("A1")     # => false, a cell reference
  #
  #   @!scope class
  #   @param name [String]
  #   @return [Boolean]

  # @!method is_valid_a1_identifier(name)
  #   @!scope class
  #   Whether +name+ can be a name in an A1-style formula. Anything that reads
  #   as a cell reference is not one.
  #
  #     IronCalc.is_valid_a1_identifier("total")  # => true
  #     IronCalc.is_valid_a1_identifier("R")      # => true
  #     IronCalc.is_valid_a1_identifier("A1")     # => false, a cell reference
  #
  #   @param name [String]
  #   @return [Boolean]

  # @!method quote_name(name)
  #   @!scope class
  #   Quotes a sheet name if a formula reference would need it:
  #   +"My Sheet"+ becomes +"'My Sheet'"+, +"Sheet1"+ is returned unchanged.
  #   @param name [String]
  #   @return [String]

  # @!method parse_reference_a1(reference)
  #   @!scope class
  #   Parses A1 notation into +{ row:, column:, absolute_row:, absolute_column: }+,
  #   with 1-based coordinates. +"$B$2"+ reports both absolute flags.
  #   @param reference [String]
  #   @return [Hash, nil] nil if it does not parse

  # @!method parse_reference_r1c1(reference)
  #   @!scope class
  #   As {parse_reference_a1}, for R1C1 notation such as +"R2C3"+.
  #   @param reference [String]
  #   @return [Hash, nil] nil if it does not parse

  # @!method get_supported_locales
  #   @!scope class
  #   Locale identifiers accepted by the constructors.
  #   @return [Array<String>]

  # @!method get_all_timezones
  #   @!scope class
  #   Timezone names accepted by the constructors.
  #   @return [Array<String>]

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

    # @!method to_xlsx_bytes
    #   Serializes the workbook to xlsx bytes (load with {IronCalc.load_from_xlsx_bytes}).
    #   @return [String] binary string
    #   @raise [IronCalc::Error]

    # @!method save_to_icalc(file)
    #   Saves the workbook to the internal binary icalc format.
    #   @param file [String]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method to_bytes
    #   Serializes the workbook to icalc bytes (load with {IronCalc.load_from_bytes}).
    #   This is IronCalc's internal format, not xlsx; see {#to_xlsx_bytes}.
    #   @return [String] binary string

    # @!method evaluate
    #   Recalculates the whole workbook. Call after {#set_user_input}.
    #   @return [void]

    # @!method set_user_input(sheet, row, column, value)
    #   Sets a cell's input, parsed as a user typing it would be: +"3.5"+ is a
    #   number, +"Hello"+ a string, +"=A1*2"+ a formula.
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param column [Integer]
    #   @param value [String]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method range_clear_contents(range)
    #   Clears the contents (not the style) of every cell in a range.
    #   @param range [Hash] the engine's +Area+: +{sheet:, row:, column:, width:,
    #     height:}+
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method get_localized_cell_content(sheet, row, column)
    #   Returns the cell's content in the model's locale: the formula (e.g.
    #   "=A1+1") or literal text.
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
    #   The cell's value with its number format applied, as displayed — e.g.
    #   +"$ 5.75"+.
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param column [Integer]
    #   @return [String]
    #   @raise [IronCalc::Error]

    # @!method get_style_for_cell(sheet, row, column)
    #   Returns the cell style as a Hash with Symbol keys, e.g.
    #   +{num_fmt: "general", font: {b: false, ...}, ...}+.
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param column [Integer]
    #   @return [Hash]
    #   @raise [IronCalc::Error]

    # @!method set_cell_style(sheet, row, column, style)
    #   Sets the cell style. Takes a *complete* style, as returned by
    #   {#get_style_for_cell}: read one, change it, pass it back. Keys may be
    #   Symbols or Strings.
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param column [Integer]
    #   @param style [Hash]
    #   @return [void]
    #   @raise [IronCalc::Error] also if the style is incomplete

    # @!method get_column_style(sheet, column)
    #   The default style for a whole column, as a Hash, or nil if the column
    #   carries no style of its own.
    #   @param sheet [Integer]
    #   @param column [Integer]
    #   @return [Hash, nil]
    #   @raise [IronCalc::Error]

    # @!method get_row_style(sheet, row)
    #   The default style for a whole row, as a Hash, or nil if the sheet holds
    #   no record for that row. A row whose style was deleted reads back as the
    #   default style rather than nil; the column equivalent returns nil.
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @return [Hash, nil]
    #   @raise [IronCalc::Error]

    # @!method set_column_style(sheet, column, style)
    #   Sets the default style for a whole column. Takes a complete style, as
    #   {#set_cell_style} does.
    #   @param sheet [Integer]
    #   @param column [Integer]
    #   @param style [Hash]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method set_row_style(sheet, row, style)
    #   Sets the default style for a whole row. Takes a complete style, as
    #   {#set_cell_style} does.
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param style [Hash]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method copy_cell_style(source_cell, destination_cell)
    #   Copies one cell's style (and nothing else) onto another cell, in any sheet.
    #   @param source_cell [Array(Integer, Integer, Integer)] +[sheet, row, column]+
    #   @param destination_cell [Array(Integer, Integer, Integer)] +[sheet, row, column]+
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method delete_column_style(sheet, column)
    #   Removes a column's default style.
    #   @param sheet [Integer]
    #   @param column [Integer]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method delete_row_style(sheet, row)
    #   Removes a row's default style.
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @return [void]
    #   @raise [IronCalc::Error]

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

    # @!method is_column_hidden(sheet, column)
    #   @param sheet [Integer]
    #   @param column [Integer]
    #   @return [Boolean]
    #   @raise [IronCalc::Error]

    # @!method set_column_hidden(sheet, column, hidden)
    #   @param sheet [Integer]
    #   @param column [Integer]
    #   @param hidden [Boolean]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method is_row_hidden(sheet, row)
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @return [Boolean]
    #   @raise [IronCalc::Error]

    # @!method set_row_hidden(sheet, row, hidden)
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param hidden [Boolean]
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

    # @!method set_frozen_columns(sheet, frozen_columns)
    #   @param sheet [Integer]
    #   @param frozen_columns [Integer]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method set_frozen_rows(sheet, frozen_rows)
    #   @param sheet [Integer]
    #   @param frozen_rows [Integer]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method get_worksheets_properties
    #   Returns one Hash per sheet with symbol keys +:name+, +:state+,
    #   +:sheet_id+ and +:color+.
    #   @return [Array<Hash>]

    # @!method set_sheet_color(sheet, color)
    #   Sets the sheet tab color.
    #   @param sheet [Integer]
    #   @param color [String, Array, nil] +"#RRGGBB"+, a +[theme, tint]+ pair,
    #     or nil to clear
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

    # @!method rename_sheet(old_name, new_name)
    #   Renames the sheet called +old_name+.
    #   @param old_name [String]
    #   @param new_name [String]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method rename_sheet_by_index(sheet_index, new_name)
    #   @param sheet_index [Integer]
    #   @param new_name [String]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method get_sheet_dimensions(sheet)
    #   Returns +[min_row, max_row, min_column, max_column]+ over non-empty cells
    #   (an empty sheet returns +[1, 1, 1, 1]+).
    #   @param sheet [Integer]
    #   @return [Array(Integer, Integer, Integer, Integer)]
    #   @raise [IronCalc::Error]

    # Without a real def, the @!method stubs above leak to the IronCalc module
    # @!method get_defined_name_list
    #   Defined names as one Hash per name, with symbol keys +:name+, +:scope+
    #   (0-based sheet index, or nil for workbook scope) and +:formula+.
    #   Also available as {DefinedNames#defined_names}.
    #   @return [Array<Hash>]

    # @!method new_defined_name(name, scope, formula)
    #   Adds a defined name. Fails if the name is not a valid identifier (+"A1"+
    #   is not: it parses as a cell reference), if it is already taken in that
    #   scope, or if the formula does not parse.
    #   @param name [String]
    #   @param scope [Integer, nil] 0-based sheet index, or nil for workbook scope
    #   @param formula [String] e.g. +"Sheet1!$C$1"+
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method update_defined_name(name, scope, new_name, new_scope, new_formula)
    #   Renames, re-scopes and/or repoints an existing defined name.
    #   @param name [String] the current name
    #   @param scope [Integer, nil] the current scope
    #   @param new_name [String]
    #   @param new_scope [Integer, nil]
    #   @param new_formula [String]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method delete_defined_name(name, scope)
    #   Deletes a defined name. Fails if no name matches in that scope.
    #   @param name [String]
    #   @param scope [Integer, nil]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method is_valid_defined_name(name, scope, formula)
    #   Checks whether {#new_defined_name} would succeed for these arguments,
    #   raising with the reason if not. {DefinedNames#valid_defined_name?}
    #   answers the same question as a boolean.
    #   @param name [String]
    #   @param scope [Integer, nil]
    #   @param formula [String]
    #   @return [Integer, nil] the +sheet_id+ of the scope's sheet (as in
    #     +get_worksheets_properties+), or nil for workbook scope
    #   @raise [IronCalc::Error] with the reason, e.g. the name is already taken
    #     in that scope

    # @!method range_clear_all(area)
    #   Clears the contents *and* style of every cell in a range, removing the
    #   cells entirely. Compare +range_clear_contents+, which keeps the style.
    #   @param area [Hash] the engine's +Area+: +{sheet:, row:, column:, width:,
    #     height:}+
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method update_cell_with_text(sheet, row, column, value)
    #   Stores +value+ as text without parsing it, so +"007"+ stays +"007"+ and
    #   +"=1+1"+ stays a string. Compare +set_user_input+, which parses.
    #   @param value [String]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method update_cell_with_number(sheet, row, column, value)
    #   Sets a number without input parsing.
    #   @param value [Float]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method update_cell_with_bool(sheet, row, column, value)
    #   Sets a boolean without input parsing.
    #   @param value [Boolean]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method update_cell_with_formula(sheet, row, column, formula)
    #   Stores a formula directly. Call +evaluate+ afterwards.
    #   @param formula [String] including the leading +=+
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method set_user_array_formula(sheet, row, column, width, height, value)
    #   Sets an array (CSE) formula over a range anchored at +row+/+column+.
    #   Call +evaluate+ afterwards.
    #   @param width [Integer] number of columns
    #   @param height [Integer] number of rows
    #   @param value [String] the formula, including the leading +=+
    #   @return [void]
    #   @raise [IronCalc::Error] if the range overlaps merged cells or a cell
    #     that is part of another array formula or dynamic spill

    # @!method get_cell_value_by_index(sheet, row, column)
    #   The cell's value as a Ruby object — nil, String, Float or true/false —
    #   unformatted. Compare +get_formatted_cell_value+, which always returns a
    #   String, and +get_localized_cell_content+, which returns what the user typed.
    #
    #   The engine has no error variant here, so an error cell comes back as the
    #   String +"#DIV/0!"+ and is indistinguishable from that literal text. Use
    #   +get_cell_type+, which reports +:error_value+, to tell them apart.
    #   @return [nil, String, Float, Boolean]
    #   @raise [IronCalc::Error]

    # @!method get_cell_value_by_ref(cell_ref)
    #   Like +get_cell_value_by_index+, addressed by an A1-style reference that
    #   includes the sheet, e.g. +"Sheet1!C4"+.
    #   @param cell_ref [String]
    #   @return [nil, String, Float, Boolean]
    #   @raise [IronCalc::Error]

    # @!method get_cell_formula(sheet, row, column)
    #   The cell's formula including the leading +=+, or nil if it is not a
    #   formula cell.
    #   @return [String, nil]
    #   @raise [IronCalc::Error]

    # @!method is_empty_cell(sheet, row, column)
    #   Whether the cell holds no content.
    #   @return [Boolean]
    #   @raise [IronCalc::Error]

    # @!method get_all_cells
    #   Every cell the workbook holds a record for, as +{ index:, row:, column: }+
    #   hashes (+index+ is the 0-based sheet index), ordered by sheet, then row,
    #   then column. A cell emptied with +range_clear_contents+ keeps its record
    #   and is still listed; combine with +is_empty_cell+ if you only want cells
    #   that have a value.
    #   @return [Array<Hash>]

    # @!method insert_sheet(sheet_name, sheet_index, sheet_id)
    #   Adds a sheet at +sheet_index+ rather than appending it.
    #   @param sheet_name [String]
    #   @param sheet_index [Integer] 0-based position to insert at
    #   @param sheet_id [Integer, nil] normally nil, so the engine allocates one
    #   @return [void]
    #   @raise [IronCalc::Error] also if +sheet_id+ is already in use, which the
    #     engine itself does not check

    # @!method set_sheet_state(sheet, state)
    #   Sets a sheet's visibility. Matches the +:state+ value reported by
    #   +get_worksheets_properties+.
    #   @param sheet [Integer]
    #   @param state [String] +"visible"+, +"hidden"+ or +"veryHidden"+
    #     (+"very_hidden"+ is also accepted)
    #   @return [void]
    #   @raise [IronCalc::Error]

    # (yardoc bug lsegal/yard#1207). Doc-only file, never loaded at runtime.
    # @!visibility private
    def __yard_anchor__
    end
  end

  # The recommended, higher-level IronCalc API. Auto-evaluates after every action
  # and records diffs for collaboration ({#flush_send_queue} /
  # {#apply_external_diffs}). Mirrors IronCalc's WebAssembly binding and is a
  # superset of the Python binding's `UserModel`. Styling is per-property via
  # {UserModel#update_range_style}.
  class UserModel
    # @!method save_to_xlsx(file)
    #   Saves the workbook to an xlsx file. Fails if the file already exists.
    #   @param file [String]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method to_xlsx_bytes
    #   Serializes the workbook to xlsx bytes (load with
    #   {IronCalc.create_user_model_from_xlsx_bytes}).
    #   @return [String] binary string
    #   @raise [IronCalc::Error]

    # @!method save_to_icalc(file)
    #   Saves the workbook to the internal binary icalc format.
    #   @param file [String]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method to_bytes
    #   Serializes the workbook to icalc bytes.
    #   This is IronCalc's internal format, not xlsx; see {#to_xlsx_bytes}.
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
    #   Sets a cell's input, parsed as a user typing it would be: +"3.5"+ is a
    #   number, +"Hello"+ a string, +"=A1*2"+ a formula. Triggers recalculation.
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param column [Integer]
    #   @param value [String]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method range_clear_contents(range)
    #   Clears the contents (not the style) of every cell in a range. Undoable.
    #   @param range [Hash] the engine's +Area+: +{sheet:, row:, column:, width:,
    #     height:}+
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
    #   The cell's value with its number format applied, as displayed — e.g.
    #   +"$ 5.75"+.
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param column [Integer]
    #   @return [String]
    #   @raise [IronCalc::Error]

    # @!method set_user_array_formula(sheet, row, column, width, height, formula)
    #   Sets an array (CSE) formula over a range anchored at +row+/+column+.
    #   Undoable.
    #   @param width [Integer] number of columns
    #   @param height [Integer] number of rows
    #   @param formula [String] including the leading +=+
    #   @return [void]
    #   @raise [IronCalc::Error] if the range overlaps merged cells or a cell
    #     that is part of another array formula or dynamic spill

    # @!method get_cell_array_structure(sheet, row, column)
    #   Whether a cell belongs to an array formula or a dynamic spill, in the
    #   engine's +CellArrayStructure+ serde form: +"SingleCell"+, or a
    #   one-entry Hash keyed by the variant as a Symbol —
    #   +{ArrayAnchor: [width, height]}+,
    #   +{ArrayChild: [anchor_row, anchor_column, width, height]}+, and
    #   likewise +:DynamicAnchor+ / +:DynamicChild+ for a spill.
    #   @example The area to clear to remove the formula a cell shows
    #     area = case user_model.get_cell_array_structure(sheet, row, column)
    #     in "SingleCell" | {DynamicAnchor: _}
    #       {sheet: sheet, row: row, column: column, width: 1, height: 1}
    #     in {DynamicChild: [anchor_row, anchor_column, _, _]}
    #       {sheet: sheet, row: anchor_row, column: anchor_column, width: 1, height: 1}
    #     in {ArrayAnchor: [width, height]}
    #       {sheet: sheet, row: row, column: column, width: width, height: height}
    #     in {ArrayChild: [anchor_row, anchor_column, width, height]}
    #       {sheet: sheet, row: anchor_row, column: anchor_column, width: width, height: height}
    #     end
    #     user_model.range_clear_contents(area)
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param column [Integer]
    #   @return [String, Hash{Symbol => Array<Integer>}]
    #   @raise [IronCalc::Error]

    # @!method get_cell_style(sheet, row, column)
    #   Returns the cell style as a Hash with Symbol keys, like
    #   {Model#get_style_for_cell}.
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @param column [Integer]
    #   @return [Hash]
    #   @raise [IronCalc::Error]

    # @!method update_range_style(range, style_path, value)
    #   Sets a single style property on every cell of a range, e.g. bold for
    #   B2:C10: +update_range_style({sheet: 0, row: 2, column: 2, width: 2,
    #   height: 9}, "font.b", "true")+. This is the user model's styling
    #   primitive: the engine's UserModel has no whole-style setter.
    #   @param range [Hash] the engine's +Area+: +{sheet:, row:, column:, width:,
    #     height:}+
    #   @param style_path [String] dotted path, e.g. "font.b", "fill.color"
    #   @param value [String]
    #   @return [void]
    #   @raise [IronCalc::Error] also if +range+ is missing a key

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

    # @!method set_columns_width(sheet, column_start, column_end, width)
    #   Sets the width of columns +column_start+ to +column_end+, inclusive.
    #   @param sheet [Integer]
    #   @param column_start [Integer]
    #   @param column_end [Integer]
    #   @param width [Float]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method set_rows_height(sheet, row_start, row_end, height)
    #   Sets the height of rows +row_start+ to +row_end+, inclusive.
    #   @param sheet [Integer]
    #   @param row_start [Integer]
    #   @param row_end [Integer]
    #   @param height [Float]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method is_column_hidden(sheet, column)
    #   @param sheet [Integer]
    #   @param column [Integer]
    #   @return [Boolean]
    #   @raise [IronCalc::Error]

    # @!method set_columns_hidden(sheet, column_start, column_end, hidden)
    #   Hides or shows columns +column_start+ to +column_end+, inclusive. Undoable.
    #   @param sheet [Integer]
    #   @param column_start [Integer]
    #   @param column_end [Integer]
    #   @param hidden [Boolean]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method is_row_hidden(sheet, row)
    #   @param sheet [Integer]
    #   @param row [Integer]
    #   @return [Boolean]
    #   @raise [IronCalc::Error]

    # @!method set_rows_hidden(sheet, row_start, row_end, hidden)
    #   Hides or shows rows +row_start+ to +row_end+, inclusive. Undoable.
    #   @param sheet [Integer]
    #   @param row_start [Integer]
    #   @param row_end [Integer]
    #   @param hidden [Boolean]
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
    #   Sets the sheet tab color.
    #   @param sheet [Integer]
    #   @param color [String, Array, nil] +"#RRGGBB"+, a +[theme, tint]+ pair,
    #     or nil to clear
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

    # @!method get_defined_name_list
    #   Defined names as one Hash per name, with symbol keys +:name+, +:scope+
    #   (0-based sheet index, or nil for workbook scope) and +:formula+.
    #   Also available as {DefinedNames#defined_names}.
    #   @return [Array<Hash>]

    # @!method new_defined_name(name, scope, formula)
    #   Adds a defined name. Fails if the name is not a valid identifier (+"A1"+
    #   is not: it parses as a cell reference), if it is already taken in that
    #   scope, or if the formula does not parse.
    #   @param name [String]
    #   @param scope [Integer, nil] 0-based sheet index, or nil for workbook scope
    #   @param formula [String] e.g. +"Sheet1!$C$1"+
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method update_defined_name(name, scope, new_name, new_scope, new_formula)
    #   Renames, re-scopes and/or repoints an existing defined name.
    #   @param name [String] the current name
    #   @param scope [Integer, nil] the current scope
    #   @param new_name [String]
    #   @param new_scope [Integer, nil]
    #   @param new_formula [String]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method delete_defined_name(name, scope)
    #   Deletes a defined name. Fails if no name matches in that scope.
    #   @param name [String]
    #   @param scope [Integer, nil]
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method is_valid_defined_name(name, scope, formula)
    #   Checks whether {#new_defined_name} would succeed for these arguments,
    #   raising with the reason if not. {DefinedNames#valid_defined_name?}
    #   answers the same question as a boolean.
    #   @param name [String]
    #   @param scope [Integer, nil]
    #   @param formula [String]
    #   @return [Integer, nil] the +sheet_id+ of the scope's sheet (as in
    #     +get_worksheets_properties+), or nil for workbook scope
    #   @raise [IronCalc::Error] with the reason, e.g. the name is already taken
    #     in that scope

    # @!method range_clear_all(range)
    #   Clears the contents *and* style of every cell in a range. Undoable.
    #   @param range [Hash] the engine's +Area+: +{sheet:, row:, column:, width:,
    #     height:}+
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method range_clear_formatting(range)
    #   Clears the style of every cell in a range, keeping the contents. Undoable.
    #   @param range [Hash] the engine's +Area+: +{sheet:, row:, column:, width:,
    #     height:}+
    #   @return [void]
    #   @raise [IronCalc::Error]

    # @!method pause_evaluation
    #   Suspends the automatic recalculation this API does after every action —
    #   useful when writing many cells at once. While paused, formula cells read
    #   back as +#ERROR!+ until evaluated.
    #   @return [void]

    # @!method resume_evaluation
    #   Re-enables automatic recalculation. Does not recalculate by itself; call
    #   +evaluate+ afterwards to bring the workbook up to date.
    #   @return [void]

    # Anchors the @!method stubs above — see {Model}.
    # @!visibility private
    def __yard_anchor__
    end
  end
end
