require "json"

# Ruby-side conveniences layered on top of the native classes. Styles cross the
# native boundary as JSON; here we expose them as plain Ruby hashes, mirroring
# the Node binding's serde-based approach.
module IronCalc
  class Model
    # Returns the cell style as a Hash (with string keys), e.g.
    #   { "num_fmt" => "general", "font" => { "b" => false, ... }, ... }
    def get_cell_style(sheet, row, column)
      JSON.parse(get_cell_style_json(sheet, row, column))
    end

    # Sets the cell style from a Hash (or a JSON string).
    def set_cell_style(sheet, row, column, style)
      json = style.is_a?(String) ? style : JSON.generate(style)
      set_cell_style_json(sheet, row, column, json)
    end
  end

  class UserModel
    # Returns the cell style as a Hash (with string keys), like Model#get_cell_style.
    def get_cell_style(sheet, row, column)
      JSON.parse(get_cell_style_json(sheet, row, column))
    end

    # The user model has no whole-style setter; styling is per-property via the
    # engine's `update_range_style` (mirroring the WASM binding). `set_cell_style`
    # is therefore offered as a convenience that diffs the given Hash against the
    # current style and applies each changed leaf with `update_range_style`.
    def set_cell_style(sheet, row, column, style)
      desired = style.is_a?(String) ? JSON.parse(style) : style
      flatten_style(desired).each do |path, value|
        update_range_style(sheet, row, column, path, value.to_s)
      end
    end

    private

    # Flattens a nested style Hash to engine style paths, e.g.
    #   { "font" => { "b" => true } } => { "font.b" => true }
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
