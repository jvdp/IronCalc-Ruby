# Ruby-side helpers over the native classes, under names of their own: every
# method named after an engine method is native and takes the engine's
# signature.
module IronCalc
  # Prepended to {Model} and {UserModel}, so these helpers count as part of the
  # class surface.
  module DefinedNames
    # Same as `get_defined_name_list`: defined names as an Array of Hashes with
    # Symbol keys:
    #   [{ name: "_key", scope: nil, formula: "Sheet1!$C$1" }, ...]
    #
    # @return [Array<Hash>]
    def defined_names
      get_defined_name_list
    end

    # Whether {#new_defined_name} would succeed for these arguments: the boolean
    # form of `is_valid_defined_name`, which raises with the reason instead.
    #
    # @param name [String]
    # @param scope [Integer, nil] 0-based sheet index, or nil for workbook scope
    # @param formula [String]
    # @return [Boolean]
    def valid_defined_name?(name, scope, formula)
      is_valid_defined_name(name, scope, formula)
      true
    rescue Error
      false
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

  class UserModel
    # Sets the cell style from a Hash like the one {#get_cell_style} returns,
    # applying each leaf through {#update_range_style}, since the engine's
    # UserModel has no whole-style setter.
    #
    # @param sheet [Integer] 0-based sheet index
    # @param row [Integer] 1-based row
    # @param column [Integer] 1-based column
    # @param style [Hash] the style
    # @return [void]
    # @raise [IronCalc::Error]
    def set_cell_style(sheet, row, column, style)
      flatten_style(style).each do |path, value|
        update_range_style({sheet: sheet, row: row, column: column, width: 1, height: 1}, path, value.to_s)
      end
    end

    private

    # Flattens a nested style Hash to engine style paths, e.g.
    #   { font: { b: true } } => { "font.b" => true }
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

  Model.prepend(DefinedNames)
  UserModel.prepend(DefinedNames)
  UserModel.prepend(Batch)
end
