require "json"

# Ruby-side conveniences layered on top of the native classes. Styles cross the
# native boundary as JSON; here we expose them as plain Ruby hashes, mirroring
# the Node binding's serde-based approach.
module IronCalc
  class Model
    # Returns the cell style as a Hash with string keys (snake_case, matching the
    # engine's serde field names), e.g.
    #   { "num_fmt" => "general", "font" => { "b" => false, ... }, ... }
    #
    # @param sheet [Integer] 0-based sheet index
    # @param row [Integer] 1-based row
    # @param column [Integer] 1-based column
    # @return [Hash]
    # @raise [IronCalc::Error]
    def get_cell_style(sheet, row, column)
      JSON.parse(get_cell_style_json(sheet, row, column))
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
      json = style.is_a?(String) ? style : JSON.generate(style)
      set_cell_style_json(sheet, row, column, json)
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
      JSON.parse(get_cell_style_json(sheet, row, column))
    end

    # Sets the cell style from a Hash (or JSON string). The user model has no
    # whole-style setter; styling is per-property via the engine's
    # {#update_range_style} (mirroring the WASM binding). This convenience
    # flattens the Hash and applies each leaf with {UserModel#update_range_style}.
    #
    # @param sheet [Integer] 0-based sheet index
    # @param row [Integer] 1-based row
    # @param column [Integer] 1-based column
    # @param style [Hash, String] the style as a Hash or JSON string
    # @return [void]
    # @raise [IronCalc::Error]
    def set_cell_style(sheet, row, column, style)
      desired = style.is_a?(String) ? JSON.parse(style) : style
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
end
