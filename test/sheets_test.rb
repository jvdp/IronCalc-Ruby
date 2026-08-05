require "minitest/autorun"
require "ironcalc"
require_relative "models_helper"

# Sheet insertion at a position, and sheet visibility, on the raw Model.
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
    model.insert_sheet("First", 0)

    assert_equal %w[First Sheet1 Last], names
  end

  def test_insert_sheet_in_the_middle
    model.add_sheet("Third")
    model.insert_sheet("Second", 1)

    assert_equal %w[Sheet1 Second Third], names
  end

  def test_insert_sheet_rejects_a_duplicate_sheet_id
    taken = model.get_worksheets_properties.first[:sheet_id]

    error = assert_raises(IronCalc::Error) { model.insert_sheet("Dup", 0, sheet_id: taken) }

    assert_match(/already in use/, error.message)
    assert_equal ["Sheet1"], names, "the workbook is left untouched"
  end

  def test_insert_sheet_accepts_an_unused_sheet_id
    model.insert_sheet("Explicit", 0, sheet_id: 42)

    assert_equal [42, 1], model.get_worksheets_properties.map { |s| s[:sheet_id] }
  end

  def test_sheet_ids_stay_unique
    model.insert_sheet("A", 0)
    model.add_sheet("B")
    ids = model.get_worksheets_properties.map { |s| s[:sheet_id] }

    assert_equal ids.uniq, ids
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
