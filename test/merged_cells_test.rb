require "minitest/autorun"
require "ironcalc"
require_relative "models_helper"

# Merged cells on both APIs.
class MergedCellsTest < Minitest::Test
  include ModelsHelper

  def area(row, column, width, height)
    {sheet: 0, row: row, column: column, width: width, height: height}
  end

  def test_merge_cells
    model.set_user_input(0, 2, 2, "kept")
    model.merge_cells(area(1, 1, 2, 3))

    assert_equal [{row: 1, column: 1, width: 2, height: 3}], model.get_merged_cells(0)
    assert_equal "kept", model.get_localized_cell_content(0, 1, 1), "the content moves to the anchor"
    assert_equal "", model.get_localized_cell_content(0, 2, 2)
  end

  def test_merge_cells_across
    model.merge_cells_across(area(1, 1, 3, 2))

    assert_equal [{row: 1, column: 1, width: 3, height: 1}, {row: 2, column: 1, width: 3, height: 1}],
      model.get_merged_cells(0)
  end

  def test_merge_cells_down
    model.merge_cells_down(area(1, 1, 2, 3))

    assert_equal [{row: 1, column: 1, width: 1, height: 3}, {row: 1, column: 2, width: 1, height: 3}],
      model.get_merged_cells(0)
  end

  def test_merge_cells_center
    model.merge_cells_center(area(1, 1, 2, 1))

    assert_equal [{row: 1, column: 1, width: 2, height: 1}], model.get_merged_cells(0)
    assert_equal "center", model.get_style_for_cell(0, 1, 1)[:alignment][:horizontal]
  end

  def test_unmerge_cells
    model.merge_cells(area(1, 1, 2, 2))
    model.merge_cells(area(5, 5, 2, 2))
    model.unmerge_cells(area(2, 2, 1, 1))

    assert_equal [{row: 5, column: 5, width: 2, height: 2}], model.get_merged_cells(0)
    model.unmerge_cells(area(10, 10, 1, 1))
    assert_equal 1, model.get_merged_cells(0).size, "unmerging nothing is not an error"
  end

  def test_get_merge_structure
    model.merge_cells(area(1, 1, 2, 3))

    assert_equal({Anchor: {width: 2, height: 3}}, model.get_merge_structure(0, 1, 1))
    assert_equal({Covered: {anchor_row: 1, anchor_column: 1}}, model.get_merge_structure(0, 3, 2))
    assert_equal "None", model.get_merge_structure(0, 4, 1)
  end

  def test_overlapping_merge_raises
    model.merge_cells(area(1, 1, 2, 2))

    error = assert_raises(IronCalc::Error) { model.merge_cells(area(2, 2, 2, 2)) }
    assert_match(/intersects the merged cell/, error.message)
  end

  def test_invalid_ranges_raise
    assert_raises(IronCalc::Error) { model.merge_cells(area(1, 1, 1, 1)) }
    assert_raises(IronCalc::Error) { model.merge_cells(area(0, 1, 2, 2)) }
    assert_raises(IronCalc::Error) { model.unmerge_cells(area(1, 1, 0, 1)) }
    assert_empty model.get_merged_cells(0)
  end

  def test_two_cells_with_content_raise
    model.set_user_input(0, 1, 1, "a")
    model.set_user_input(0, 1, 2, "b")

    error = assert_raises(IronCalc::Error) { model.merge_cells(area(1, 1, 2, 1)) }
    assert_match(/more than one cell has content/, error.message)
  end

  def test_merge_across_is_all_or_nothing
    model.set_user_input(0, 2, 1, "a")
    model.set_user_input(0, 2, 2, "b")

    assert_raises(IronCalc::Error) { model.merge_cells_across(area(1, 1, 2, 2)) }
    assert_empty model.get_merged_cells(0)
  end

  def test_missing_area_key_raises
    assert_raises(IronCalc::Error) { model.merge_cells({sheet: 0, row: 1, column: 1, width: 2}) }
  end

  def test_xlsx_round_trip
    model.merge_cells(area(1, 1, 2, 3))
    model.merge_cells(area(5, 2, 3, 1))
    reloaded = IronCalc.load_from_xlsx_bytes(model.to_xlsx_bytes, "m", LOCALE, TIMEZONE, LANGUAGE)

    assert_equal model.get_merged_cells(0), reloaded.get_merged_cells(0)
  end

  def test_user_model_merge_variants
    user_model.merge_cells(area(1, 1, 2, 2))
    user_model.merge_cells_across(area(4, 1, 2, 2))
    user_model.merge_cells_down(area(7, 1, 2, 2))
    user_model.merge_cells_center(area(10, 1, 2, 1))

    assert_equal 6, user_model.get_merged_cells(0).size
    assert_equal "center", user_model.get_cell_style(0, 10, 1)[:alignment][:horizontal]
  end

  def test_user_model_undo_redo
    user_model.set_user_input(0, 2, 2, "kept")
    user_model.merge_cells(area(1, 1, 2, 2))
    assert_equal "kept", user_model.get_cell_content(0, 1, 1)

    user_model.undo
    assert_empty user_model.get_merged_cells(0)
    assert_equal "kept", user_model.get_cell_content(0, 2, 2)

    user_model.redo
    assert_equal [{row: 1, column: 1, width: 2, height: 2}], user_model.get_merged_cells(0)

    user_model.unmerge_cells(area(1, 1, 1, 1))
    assert_empty user_model.get_merged_cells(0)
    user_model.undo
    assert_equal 1, user_model.get_merged_cells(0).size
  end

  def test_user_model_merge_across_is_one_undo_step
    user_model.merge_cells_across(area(1, 1, 2, 3))
    user_model.undo

    assert_empty user_model.get_merged_cells(0)
  end

  def test_user_model_overlapping_merge_raises
    user_model.merge_cells(area(1, 1, 2, 2))

    assert_raises(IronCalc::Error) { user_model.merge_cells(area(2, 2, 2, 2)) }
    assert_equal 1, user_model.get_merged_cells(0).size
  end

  def test_user_model_xlsx_round_trip
    user_model.merge_cells(area(2, 2, 3, 2))
    reloaded = IronCalc.create_user_model_from_xlsx_bytes(user_model.to_xlsx_bytes, "m", LOCALE, TIMEZONE, LANGUAGE)

    assert_equal [{row: 2, column: 2, width: 3, height: 2}], reloaded.get_merged_cells(0)
  end
end
