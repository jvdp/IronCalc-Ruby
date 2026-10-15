require "minitest/autorun"
require "ironcalc"
require_relative "models_helper"

# Sheet insertion at a position, duplication, moves, and sheet visibility, on
# the raw Model.
class SheetsTest < Minitest::Test
  include ModelsHelper

  def names
    model.get_worksheets_properties.map { |s| s[:name] }
  end

  def states
    model.get_worksheets_properties.map { |s| s[:state] }
  end

  def test_insert_sheet_at_a_position
    model.add_sheet("Last")
    model.insert_sheet("First", 0, nil)

    assert_equal %w[First Sheet1 Last], names
  end

  def test_insert_sheet_in_the_middle
    model.add_sheet("Third")
    model.insert_sheet("Second", 1, nil)

    assert_equal %w[Sheet1 Second Third], names
  end

  def test_insert_sheet_rejects_a_duplicate_sheet_id
    taken = model.get_worksheets_properties.first[:sheet_id]

    error = assert_raises(IronCalc::Error) { model.insert_sheet("Dup", 0, taken) }

    assert_match(/already in use/, error.message)
    assert_equal ["Sheet1"], names, "the workbook is left untouched"
  end

  def test_insert_sheet_accepts_an_unused_sheet_id
    model.insert_sheet("Explicit", 0, 42)

    assert_equal [42, 1], model.get_worksheets_properties.map { |s| s[:sheet_id] }
  end

  def test_sheet_ids_stay_unique
    model.insert_sheet("A", 0, nil)
    model.add_sheet("B")
    ids = model.get_worksheets_properties.map { |s| s[:sheet_id] }

    assert_equal ids.uniq, ids
  end

  def test_duplicate_sheet_copies_content_and_style_after_the_source
    model.add_sheet("Other")
    model.set_user_input(0, 1, 1, "=1+1")
    bold = style_with { |s| s[:font][:b] = true }
    model.set_cell_style(0, 1, 1, bold)

    assert_equal ["Sheet1 (1)", 1], model.duplicate_sheet(0)
    model.evaluate

    assert_equal ["Sheet1", "Sheet1 (1)", "Other"], names
    assert_equal "=1+1", model.get_cell_formula(1, 1, 1)
    assert_equal "2", model.get_formatted_cell_value(1, 1, 1)
    assert model.get_style_for_cell(1, 1, 1)[:font][:b]
  end

  def test_duplicate_sheet_allocates_a_new_sheet_id
    model.duplicate_sheet(0)
    ids = model.get_worksheets_properties.map { |s| s[:sheet_id] }

    assert_equal ids.uniq, ids
  end

  def test_duplicate_sheet_rejects_an_out_of_range_index
    assert_raises(IronCalc::Error) { model.duplicate_sheet(1) }
  end

  def test_move_sheet_keeps_cross_sheet_references
    model.add_sheet("B")
    model.add_sheet("C")
    model.set_user_input(2, 1, 1, "7")
    model.set_user_input(0, 1, 1, "=C!A1")
    model.move_sheet(2, 0)
    model.evaluate

    assert_equal %w[C Sheet1 B], names
    assert_equal "7", model.get_formatted_cell_value(1, 1, 1)
  end

  def test_move_sheet_rejects_an_out_of_range_index
    error = assert_raises(IronCalc::Error) { model.move_sheet(0, 1) }

    assert_match(/too large/, error.message)
  end

  def test_set_sheet_state_hidden
    model.add_sheet("Hideable")
    model.set_sheet_state(1, "hidden")

    assert_equal %w[visible hidden], states
  end

  def test_set_sheet_state_very_hidden_accepts_both_spellings
    model.add_sheet("A")
    model.add_sheet("B")
    model.set_sheet_state(1, "veryHidden")
    model.set_sheet_state(2, "very_hidden")

    assert_equal %w[visible veryHidden veryHidden], states
  end

  def test_set_sheet_state_back_to_visible
    model.set_sheet_state(0, "hidden")
    model.set_sheet_state(0, "visible")

    assert_equal ["visible"], states
  end

  def test_set_sheet_state_rejects_an_unknown_state
    error = assert_raises(IronCalc::Error) { model.set_sheet_state(0, "bogus") }

    assert_match(/Invalid sheet state/, error.message)
  end

  def test_sheet_color_round_trips_a_hex_string
    model.set_sheet_color(0, "#FF0000")

    assert_equal "#FF0000", model.get_worksheets_properties[0][:color]
  end

  def test_sheet_color_round_trips_a_theme_pair
    model.add_sheet("Other")
    model.set_sheet_color(0, [3, 0.4])
    # The shape reads back as it was written, so it can be copied to a sheet.
    model.set_sheet_color(1, model.get_worksheets_properties[0][:color])

    assert_equal [3, 0.4], model.get_worksheets_properties[1][:color]
  end

  def test_sheet_color_is_cleared_by_nil
    model.set_sheet_color(0, "#FF0000")
    model.set_sheet_color(0, nil)

    assert_nil model.get_worksheets_properties[0][:color]
  end

  def test_sheet_color_rejects_other_shapes
    [42, {a: 1}, %w[x y], [1]].each do |bad|
      assert_raises(IronCalc::Error, "expected #{bad.inspect} to be rejected") do
        model.set_sheet_color(0, bad)
      end
    end
  end
end
