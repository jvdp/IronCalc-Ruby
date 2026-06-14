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
end
