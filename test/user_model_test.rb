require "minitest/autorun"
require "ironcalc"

# Covers the enriched UserModel surface (the recommended, auto-recalc API). The
# raw Model is covered by surface_test.rb; here we focus on behaviours unique to
# UserModel: automatic recalculation after every action, undo/redo, and the
# per-property styling path (update_range_style / the set_cell_style wrapper).
class UserModelTest < Minitest::Test
  def model
    @model ||= IronCalc.create_user_model("m", "en", "UTC", "en")
  end

  def test_auto_recalculates_without_evaluate
    model.set_user_input(0, 1, 1, "10")
    model.set_user_input(0, 1, 2, "=A1*2")
    # No evaluate call: the user model recalculates after each action.
    assert_equal "20", model.get_formatted_cell_value(0, 1, 2)

    model.set_user_input(0, 1, 1, "100")
    assert_equal "200", model.get_formatted_cell_value(0, 1, 2)
  end

  def test_cell_content_and_type
    model.set_user_input(0, 1, 1, "10")
    model.set_user_input(0, 1, 2, "=A1*2")
    assert_equal :number, model.get_cell_type(0, 1, 1)
    assert_equal "=A1*2", model.get_cell_content(0, 1, 2)
  end

  def test_styling_via_hash_wrapper
    model.set_cell_style(0, 1, 1, { "font" => { "b" => true, "i" => true } })
    style = model.get_cell_style(0, 1, 1)
    assert_equal true, style["font"]["b"]
    assert_equal true, style["font"]["i"]
  end

  def test_update_range_style_directly
    model.update_range_style(0, 1, 1, "font.b", "true")
    assert_equal true, model.get_cell_style(0, 1, 1)["font"]["b"]
  end

  def test_undo_redo
    model.set_user_input(0, 1, 1, "keep")
    assert model.can_undo
    refute model.can_redo

    model.undo
    assert_equal "", model.get_formatted_cell_value(0, 1, 1)
    assert model.can_redo

    model.redo
    assert_equal "keep", model.get_formatted_cell_value(0, 1, 1)
  end

  def test_clear_cell_contents
    model.set_user_input(0, 1, 1, "gone")
    assert_equal "gone", model.get_formatted_cell_value(0, 1, 1)
    model.clear_cell_contents(0, 1, 1)
    assert_equal "", model.get_formatted_cell_value(0, 1, 1)
  end

  def test_insert_and_delete_rows
    model.set_user_input(0, 5, 1, "marker")
    model.insert_rows(0, 5, 2)
    assert_equal "marker", model.get_formatted_cell_value(0, 7, 1)
    model.delete_rows(0, 5, 2)
    assert_equal "marker", model.get_formatted_cell_value(0, 5, 1)
  end

  def test_insert_and_delete_columns
    model.set_user_input(0, 1, 5, "marker")
    model.insert_columns(0, 5, 1)
    assert_equal "marker", model.get_formatted_cell_value(0, 1, 6)
    model.delete_columns(0, 5, 1)
    assert_equal "marker", model.get_formatted_cell_value(0, 1, 5)
  end

  def test_column_width_and_row_height
    model.set_column_width(0, 3, 99.0)
    model.set_row_height(0, 4, 42.0)
    assert_in_delta 99.0, model.get_column_width(0, 3)
    assert_in_delta 42.0, model.get_row_height(0, 4)
  end

  def test_frozen_counts
    model.set_frozen_rows_count(0, 2)
    model.set_frozen_columns_count(0, 3)
    assert_equal 2, model.get_frozen_rows_count(0)
    assert_equal 3, model.get_frozen_columns_count(0)
  end

  def test_sheet_management
    model.new_sheet
    model.rename_sheet(1, "Two")
    model.set_sheet_color(1, "#00FF00")
    props = model.get_worksheets_properties
    assert_equal 2, props.size
    assert_equal "Two", props[1][:name]
    assert_equal "#00FF00", props[1][:color]

    model.delete_sheet(1)
    assert_equal 1, model.get_worksheets_properties.size
  end

  def test_sheet_dimensions
    model.set_user_input(0, 3, 5, "a")
    model.set_user_input(0, 10, 8, "b")
    assert_equal [3, 10, 5, 8], model.get_sheet_dimensions(0).to_a
  end

  def test_to_bytes_roundtrip
    model.set_user_input(0, 1, 1, "=6*7")
    reloaded = IronCalc.load_from_bytes(model.to_bytes, "en")
    reloaded.evaluate
    assert_equal "42", reloaded.get_formatted_cell_value(0, 1, 1)
  end
end
