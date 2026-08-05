require "json"

# Ruby-side conveniences over the native classes: Hash-based styles, and
# keyword arguments for the engine's optional trailing parameters.
module IronCalc
  # Styles cross the native boundary as JSON.
  module StyleCoercion
    private

    # @api private
    def style_json(style)
      style.is_a?(String) ? style : JSON.generate(style)
    end

    # Parses a JSON string; passes anything else through, so nil stays nil.
    # @api private
    def style_hash(style)
      style.is_a?(String) ? JSON.parse(style) : style
    end
  end

  # Defined names. Prepended to {Model} and {UserModel} so `super` reaches the
  # native methods, which take `scope` positionally in engine order.
  #
  # A `scope` of `nil` is workbook-scoped; an Integer is a 0-based sheet index.
  module DefinedNames
    # Defined names as an Array of Hashes with Symbol keys:
    #   [{ name: "_key", scope: nil, formula: "Sheet1!$C$1" }, ...]
    #
    # @return [Array<Hash>]
    def defined_names
      get_defined_name_list
    end

    # Adds a defined name. Fails if the name is not a valid identifier (`"A1"`
    # is not — it parses as a cell reference), if it is already taken in that
    # scope, or if the formula does not parse.
    #
    # @param name [String]
    # @param formula [String] e.g. `"Sheet1!$C$1"`
    # @param scope [Integer, nil] 0-based sheet index, or nil for workbook scope
    # @return [void]
    # @raise [IronCalc::Error]
    def new_defined_name(name, formula, scope: nil)
      super(name, scope, formula)
    end

    # Renames, re-scopes and/or repoints an existing defined name.
    #
    # @param name [String] the current name
    # @param new_name [String]
    # @param new_formula [String]
    # @param scope [Integer, nil] the current scope
    # @param new_scope [Integer, nil]
    # @return [void]
    # @raise [IronCalc::Error]
    def update_defined_name(name, new_name, new_formula, scope: nil, new_scope: nil)
      super(name, scope, new_name, new_scope, new_formula)
    end

    # Whether {#new_defined_name} would succeed for these arguments.
    #
    # @param name [String]
    # @param formula [String]
    # @param scope [Integer, nil]
    # @return [Boolean]
    def is_valid_defined_name(name, formula, scope: nil)
      super(name, scope, formula)
    end

    # Deletes a defined name. Fails if no name matches in that scope.
    #
    # @param name [String]
    # @param scope [Integer, nil]
    # @return [void]
    # @raise [IronCalc::Error]
    def delete_defined_name(name, scope: nil)
      super(name, scope)
    end
  end

  # Prepended rather than included, so `batch` counts as part of the class
  # surface.
  module Batch
    # Suspends automatic recalculation, recalculating once when the block exits.
    # Nested calls resume only when the outermost block returns, and the
    # recalculation runs even if the block raises — a resumed model that was
    # never recalculated would report stale values indefinitely.
    #
    #   user_model.batch do |m|
    #     rows.each { |row, column, value| m.set_user_input(0, row, column, value) }
    #   end
    #
    # @yieldparam model [UserModel] self
    # @return [Object] the block's value
    def batch
      @batch_depth = (@batch_depth || 0) + 1
      pause_evaluation if @batch_depth == 1
      begin
        yield self
      ensure
        @batch_depth -= 1
        if @batch_depth.zero?
          resume_evaluation
          evaluate
        end
      end
    end
  end

  # Prepended to {Model}, so `super` reaches the native `insert_sheet`.
  module Sheets
    # Adds a sheet at `sheet_index` rather than appending it.
    #
    # @param name [String]
    # @param sheet_index [Integer] 0-based position to insert at
    # @param sheet_id [Integer, nil] normally nil — the engine allocates one
    # @return [void]
    # @raise [IronCalc::Error]
    def insert_sheet(name, sheet_index, sheet_id: nil)
      super(name, sheet_index, sheet_id)
    end
  end

  class Model
    # Returns the cell style as a Hash with snake_case string keys, e.g.
    #   { "num_fmt" => "general", "font" => { "b" => false, ... }, ... }
    #
    # @param sheet [Integer] 0-based sheet index
    # @param row [Integer] 1-based row
    # @param column [Integer] 1-based column
    # @return [Hash]
    # @raise [IronCalc::Error]
    def get_cell_style(sheet, row, column)
      style_hash(get_cell_style_json(sheet, row, column))
    end

    # Sets the cell style from a Hash (snake_case keys) or a JSON string.
    #
    # @param sheet [Integer] 0-based sheet index
    # @param row [Integer] 1-based row
    # @param column [Integer] 1-based column
    # @param style [Hash, String] the full style as a Hash or JSON string
    # @return [void]
    # @raise [IronCalc::Error]
    def set_cell_style(sheet, row, column, style)
      set_cell_style_json(sheet, row, column, style_json(style))
    end

    # The default style for a whole column, as a Hash, or nil if the column
    # carries no style of its own.
    #
    # @param sheet [Integer] 0-based sheet index
    # @param column [Integer] 1-based column
    # @return [Hash, nil]
    # @raise [IronCalc::Error]
    def get_column_style(sheet, column)
      style_hash(get_column_style_json(sheet, column))
    end

    # The default style for a whole row, as a Hash, or nil if the sheet holds
    # no record for that row. A row whose style was deleted reads back as the
    # default style rather than nil; the column equivalent returns nil.
    #
    # @param sheet [Integer] 0-based sheet index
    # @param row [Integer] 1-based row
    # @return [Hash, nil]
    # @raise [IronCalc::Error]
    def get_row_style(sheet, row)
      style_hash(get_row_style_json(sheet, row))
    end

    # Sets the default style for a whole column. Takes a *complete* style, like
    # {#set_cell_style}: read one, change it, pass it back.
    #
    # @param sheet [Integer] 0-based sheet index
    # @param column [Integer] 1-based column
    # @param style [Hash, String] the full style as a Hash or JSON string
    # @return [void]
    # @raise [IronCalc::Error]
    def set_column_style(sheet, column, style)
      set_column_style_json(sheet, column, style_json(style))
    end

    # Sets the default style for a whole row. Takes a complete style, as
    # {#set_column_style} does.
    #
    # @param sheet [Integer] 0-based sheet index
    # @param row [Integer] 1-based row
    # @param style [Hash, String] the full style as a Hash or JSON string
    # @return [void]
    # @raise [IronCalc::Error]
    def set_row_style(sheet, row, style)
      set_row_style_json(sheet, row, style_json(style))
    end
  end

  class UserModel
    # Returns the cell style as a Hash with string keys, like {Model#get_cell_style}.
    #
    # @param sheet [Integer] 0-based sheet index
    # @param row [Integer] 1-based row
    # @param column [Integer] 1-based column
    # @return [Hash]
    # @raise [IronCalc::Error]
    def get_cell_style(sheet, row, column)
      style_hash(get_cell_style_json(sheet, row, column))
    end

    # Sets the cell style from a Hash (or JSON string), applying each leaf
    # through {#update_range_style} since there is no whole-style setter here.
    #
    # @param sheet [Integer] 0-based sheet index
    # @param row [Integer] 1-based row
    # @param column [Integer] 1-based column
    # @param style [Hash, String] the style as a Hash or JSON string
    # @return [void]
    # @raise [IronCalc::Error]
    def set_cell_style(sheet, row, column, style)
      desired = style_hash(style)
      flatten_style(desired).each do |path, value|
        update_range_style(sheet, row, column, path, value.to_s)
      end
    end

    private

    # Flattens a nested style Hash to engine style paths, e.g.
    #   { "font" => { "b" => true } } => { "font.b" => true }
    # @api private
    def flatten_style(hash, prefix = nil)
      hash.each_with_object({}) do |(key, value), out|
        path = prefix ? "#{prefix}.#{key}" : key.to_s
        if value.is_a?(Hash)
          out.merge!(flatten_style(value, path))
        else
          out[path] = value
        end
      end
    end
  end

  Model.include(StyleCoercion)
  UserModel.include(StyleCoercion)
  Model.prepend(DefinedNames)
  Model.prepend(Sheets)
  UserModel.prepend(DefinedNames)
  UserModel.prepend(Batch)
end
