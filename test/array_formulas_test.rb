require "minitest/autorun"
require "ironcalc"
require_relative "models_helper"

class ArrayFormulasTest < Minitest::Test
  include ModelsHelper

  def test_model_sets_array_formula
    model.set_user_array_formula(0, 1, 1, 2, 2, "={1,2;3,4}")
    model.evaluate

    assert_equal %w[1 2 3 4], [[1, 1], [1, 2], [2, 1], [2, 2]].map { |r, c| model.get_formatted_cell_value(0, r, c) }
    assert_equal "={1,2;3,4}", model.get_cell_formula(0, 1, 1)
    assert_nil model.get_cell_formula(0, 2, 2)
  end

  def test_user_model_structure
    user_model.set_user_input(0, 1, 1, "1")
    user_model.set_user_input(0, 2, 1, "2")
    user_model.set_user_array_formula(0, 1, 2, 1, 2, "=A1:A2*10")

    assert_equal "20", user_model.get_formatted_cell_value(0, 2, 2)
    assert_equal({ArrayAnchor: [1, 2]}, user_model.get_cell_array_structure(0, 1, 2))
    assert_equal({ArrayChild: [1, 2, 1, 2]}, user_model.get_cell_array_structure(0, 2, 2))
    assert_equal "SingleCell", user_model.get_cell_array_structure(0, 1, 1)
    assert_equal "SingleCell", user_model.get_cell_array_structure(0, 5, 5)
  end

  def test_dynamic_spill_structure
    user_model.set_user_input(0, 1, 1, "=SEQUENCE(3)")

    assert_equal({DynamicAnchor: [1, 3]}, user_model.get_cell_array_structure(0, 1, 1))
    assert_equal({DynamicChild: [1, 1, 1, 3]}, user_model.get_cell_array_structure(0, 3, 1))
  end

  def test_overlapping_array_formula_raises
    user_model.set_user_array_formula(0, 1, 1, 2, 2, "={1,2;3,4}")

    error = assert_raises(IronCalc::Error) { user_model.set_user_array_formula(0, 2, 2, 2, 2, "=1") }
    assert_match(/array formula/, error.message)
    assert_raises(IronCalc::Error) { model.set_user_array_formula(9, 1, 1, 1, 1, "=1") }
    assert_raises(IronCalc::Error) { user_model.get_cell_array_structure(9, 1, 1) }
  end

  def test_undo_and_redo
    user_model.set_user_array_formula(0, 1, 1, 2, 2, "={1,2;3,4}")
    user_model.undo

    assert_equal "SingleCell", user_model.get_cell_array_structure(0, 2, 2)
    assert_equal "", user_model.get_formatted_cell_value(0, 2, 2)

    user_model.redo
    assert_equal({ArrayChild: [1, 1, 2, 2]}, user_model.get_cell_array_structure(0, 2, 2))
    assert_equal "4", user_model.get_formatted_cell_value(0, 2, 2)
  end

  def test_round_trips_through_xlsx
    model.set_user_array_formula(0, 1, 1, 2, 2, "={1,2;3,4}")
    model.evaluate
    reloaded = IronCalc.create_user_model_from_xlsx_bytes(model.to_xlsx_bytes, "m", LOCALE, TIMEZONE, LANGUAGE)

    assert_equal "={1,2;3,4}", reloaded.get_cell_content(0, 1, 1)
    assert_equal({ArrayAnchor: [2, 2]}, reloaded.get_cell_array_structure(0, 1, 1))
    assert_equal({ArrayChild: [1, 1, 2, 2]}, reloaded.get_cell_array_structure(0, 2, 2))
    assert_equal "4", reloaded.get_formatted_cell_value(0, 2, 2)
  end
end
