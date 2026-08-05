require "minitest/autorun"
require "ironcalc"
require_relative "models_helper"

# Typed cell setters and the value/formula readers on the raw Model. The setters
# bypass `set_user_input`'s parsing, so text that looks like a number or a
# formula is stored as text.
class CellAccessTest < Minitest::Test
  include ModelsHelper

  def test_text_setter_does_not_parse
    # set_user_input would turn this into the number 7.
    model.update_cell_with_text(0, 1, 1, "007")

    assert_equal "007", model.get_cell_value_by_index(0, 1, 1)
  end

  def test_text_setter_does_not_treat_a_formula_as_one
    model.update_cell_with_text(0, 1, 1, "=1+1")

    assert_equal "=1+1", model.get_cell_value_by_index(0, 1, 1)
    assert_nil model.get_cell_formula(0, 1, 1)
  end

  def test_get_cell_value_returns_native_types
    model.update_cell_with_text(0, 1, 1, "hello")
    model.update_cell_with_number(0, 1, 2, 42.5)
    model.update_cell_with_bool(0, 1, 3, false)

    assert_equal "hello", model.get_cell_value_by_index(0, 1, 1)
    assert_in_delta 42.5, model.get_cell_value_by_index(0, 1, 2)
    assert_equal false, model.get_cell_value_by_index(0, 1, 3)
  end

  def test_get_cell_value_of_empty_cell_is_nil
    assert_nil model.get_cell_value_by_index(0, 9, 9)
  end

  def test_get_cell_value_by_ref
    model.update_cell_with_number(0, 4, 3, 7.0)

    assert_in_delta 7.0, model.get_cell_value_by_ref("Sheet1!C4")
  end

  def test_get_cell_value_by_ref_rejects_a_bad_reference
    assert_raises(IronCalc::Error) { model.get_cell_value_by_ref("not a ref") }
  end

  def test_get_cell_formula
    model.set_user_input(0, 1, 1, "2")
    model.set_user_input(0, 1, 2, "=A1*3")
    model.evaluate

    assert_equal "=A1*3", model.get_cell_formula(0, 1, 2)
    assert_nil model.get_cell_formula(0, 1, 1), "a literal is not a formula"
  end

  def test_is_empty_cell
    model.set_user_input(0, 1, 1, "x")

    refute model.is_empty_cell(0, 1, 1)
    assert model.is_empty_cell(0, 2, 2)
  end

  def test_get_all_cells
    model.set_user_input(0, 2, 1, "a")
    model.set_user_input(0, 1, 3, "b")
    model.add_sheet("Other")
    model.set_user_input(1, 5, 5, "c")

    # Ordered by sheet, then row, then column.
    assert_equal [
      {sheet: 0, row: 1, column: 3},
      {sheet: 0, row: 2, column: 1},
      {sheet: 1, row: 5, column: 5}
    ], model.get_all_cells
  end

  def test_get_all_cells_is_empty_for_a_fresh_model
    assert_empty model.get_all_cells
  end

  def test_get_all_cells_still_lists_a_cleared_cell
    model.set_user_input(0, 1, 1, "x")
    model.clear_cell_contents(0, 1, 1)

    assert model.is_empty_cell(0, 1, 1)
    assert_equal [{sheet: 0, row: 1, column: 1}], model.get_all_cells
  end

  def test_error_cells_read_back_as_their_error_string
    model.set_user_input(0, 1, 1, "=1/0")
    model.evaluate

    # CellValue has no error variant, so this is indistinguishable from a cell
    # holding that literal text; get_cell_type separates them.
    assert_equal "#DIV/0!", model.get_cell_value_by_index(0, 1, 1)
    assert_equal :error_value, model.get_cell_type(0, 1, 1)
  end

  def test_clear_cell_all_removes_content_and_style
    model.set_user_input(0, 1, 1, "x")
    model.set_cell_style(0, 1, 1, style_with { |s| s["font"]["b"] = true })

    model.clear_cell_all(0, 1, 1)

    assert model.is_empty_cell(0, 1, 1)
    refute model.get_cell_style(0, 1, 1).dig("font", "b")
  end

  def test_clear_cell_contents_keeps_the_style
    model.set_user_input(0, 1, 1, "x")
    model.set_cell_style(0, 1, 1, style_with { |s| s["font"]["b"] = true })

    model.clear_cell_contents(0, 1, 1)

    assert_equal "", model.get_formatted_cell_value(0, 1, 1)
    assert model.get_cell_style(0, 1, 1).dig("font", "b")
  end
end
