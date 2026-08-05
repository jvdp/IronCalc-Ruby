require "minitest/autorun"
require "ironcalc"
require_relative "models_helper"

# Row/column default styles and copy_cell_style on the raw Model.
class StylesTest < Minitest::Test
  include ModelsHelper

  def test_column_style_round_trips
    model.set_column_style(0, 2, style_with { |s| s["num_fmt"] = "0.00" })

    assert_equal "0.00", model.get_column_style(0, 2)["num_fmt"]
  end

  def test_column_style_is_nil_when_unset
    assert_nil model.get_column_style(0, 2)
  end

  def test_delete_column_style
    model.set_column_style(0, 2, style_with { |s| s["num_fmt"] = "0.00" })
    model.delete_column_style(0, 2)

    assert_nil model.get_column_style(0, 2)
  end

  def test_row_style_round_trips
    model.set_row_style(0, 3, style_with { |s| s["num_fmt"] = "0.00" })

    assert_equal "0.00", model.get_row_style(0, 3)["num_fmt"]
  end

  def test_row_style_is_nil_when_unset
    assert_nil model.get_row_style(0, 3)
  end

  def test_delete_row_style_resets_to_the_default
    model.set_row_style(0, 3, style_with { |s| s["num_fmt"] = "0.00" })
    model.delete_row_style(0, 3)

    # Every row record carries a style index, so this reads back as the default
    # style rather than nil (unlike columns).
    assert_equal "general", model.get_row_style(0, 3)["num_fmt"]
  end

  def test_invalid_style_raises
    assert_raises(IronCalc::Error) { model.set_column_style(0, 2, {"num_fmt" => "0.00"}) }
  end

  def test_copy_cell_style
    model.set_cell_style(0, 1, 1, style_with { |s| s["font"]["b"] = true })
    model.copy_cell_style(0, 1, 1, 0, 5, 5)

    assert model.get_cell_style(0, 5, 5).dig("font", "b")
  end

  def test_copy_cell_style_copies_only_the_style
    model.set_user_input(0, 1, 1, "source")
    model.set_cell_style(0, 1, 1, style_with { |s| s["font"]["b"] = true })
    model.copy_cell_style(0, 1, 1, 0, 5, 5)

    assert_equal "", model.get_formatted_cell_value(0, 5, 5)
  end
end
