require "minitest/autorun"
require "ironcalc"
require_relative "models_helper"

# Conditional formatting rules on both APIs, and the extended style that
# carries their effect on a cell.
class ConditionalFormattingTest < Minitest::Test
  include ModelsHelper

  RED_BOLD = {font: {b: true, color: "#FF0000"}}.freeze
  YELLOW_FILL = {fill: {color: "#FFFF00"}}.freeze

  def greater_than(value, format = RED_BOLD)
    {type: "CellIs", operator: "GreaterThan", formula: value.to_s, formula2: nil,
     format: format, stop_if_true: false}
  end

  def fill_column(target, values)
    values.each_with_index { |v, i| target.set_user_input(0, i + 1, 1, v.to_s) }
  end

  def test_add_and_list
    assert_equal 1, model.add_conditional_formatting(0, "A1:A3", greater_than(4))
    assert_equal 2, model.add_conditional_formatting(0, "B1", {type: "Blanks", format: YELLOW_FILL, stop_if_true: true})

    list = model.get_conditional_formatting_list(0)
    # Highest priority first; `index` is the storage position the mutators take.
    assert_equal [[1, "B1", 2], [0, "A1:A3", 1]], list.map { |cf| cf.values_at(:index, :range, :priority) }
    assert_equal({type: "CellIs", operator: "GreaterThan", formula: "4", formula2: nil, dxf_id: 0, stop_if_true: false},
      list.last[:cf_rule])
  end

  def test_rule_shapes_round_trip
    data_bar = {type: "DataBar", min: "Min", max: {Number: 10.0}, positive_color: "#00FF00",
                negative_color: nil, is_gradient: true, show_value: true}
    rating = {type: "IconRating", icon: "Star", color: [1, 0.5],
              thresholds: [[{Percent: 50.0}, false]], show_value: true}
    model.add_conditional_formatting(0, "A1:A3", data_bar)
    model.add_conditional_formatting(0, "B1:B3", rating)

    rules = model.get_conditional_formatting_list(0).map { |cf| cf[:cf_rule] }
    assert_equal [rating, data_bar], rules
  end

  def test_get_dxf
    model.add_conditional_formatting(0, "A1", greater_than(4))
    model.add_conditional_formatting(0, "A1", {type: "ColorScale", thresholds: []})

    dxf = model.get_dxf_for_conditional_formatting(0, 0)
    assert_equal RED_BOLD[:font], dxf[:font]
    assert_nil model.get_dxf_for_conditional_formatting(0, 1)
  end

  def test_extended_style_after_evaluate
    fill_column(model, [1, 5])
    model.add_conditional_formatting(0, "A1:A2", greater_than(4))

    model.evaluate
    assert_equal true, model.get_extended_style_for_cell(0, 2, 1)[:style][:font][:b]
    refute model.get_extended_style_for_cell(0, 1, 1)[:style][:font][:b]

    extended = model.get_extended_style_for_cell(0, 1, 1)
    assert_equal model.get_style_for_cell(0, 1, 1), extended[:style]
    assert_equal({icon: nil, data_bar: nil, rating: nil}, extended.except(:style))
  end

  def test_evaluate_conditional_formatting_alone
    fill_column(model, [5])
    model.evaluate
    model.add_conditional_formatting(0, "A1", greater_than(4))
    refute model.get_extended_style_for_cell(0, 1, 1)[:style][:font][:b]

    model.evaluate_conditional_formatting
    assert_equal true, model.get_extended_style_for_cell(0, 1, 1)[:style][:font][:b]
  end

  def test_update_returns_previous_entry
    model.add_conditional_formatting(0, "A1", greater_than(4))
    old = model.update_conditional_formatting(0, 0, "A1:A5", greater_than(9, YELLOW_FILL))

    assert_equal "A1", old[:range]
    cf = model.get_conditional_formatting_list(0).first
    assert_equal ["A1:A5", "9", 1], [cf[:range], cf[:cf_rule][:formula], cf[:priority]]
    assert_equal YELLOW_FILL[:fill], model.get_dxf_for_conditional_formatting(0, 0)[:fill]
  end

  def test_priority
    model.add_conditional_formatting(0, "A1", greater_than(1))
    model.add_conditional_formatting(0, "A1", greater_than(2))
    priorities = -> { model.get_conditional_formatting_list(0).map { |cf| cf[:index] } }
    assert_equal [1, 0], priorities.call

    model.raise_conditional_formatting_priority(0, 0)
    assert_equal [0, 1], priorities.call
    model.raise_conditional_formatting_priority(0, 0)
    assert_equal [0, 1], priorities.call
    model.lower_conditional_formatting_priority(0, 0)
    assert_equal [1, 0], priorities.call
  end

  def test_delete_returns_removed_entry
    model.add_conditional_formatting(0, "A1", greater_than(4))
    removed = model.delete_conditional_formatting(0, 0)

    assert_equal ["A1", 1], removed.values_at(:range, :priority)
    assert_empty model.get_conditional_formatting_list(0)
  end

  def test_invalid_input_raises
    assert_raises(IronCalc::Error) { model.add_conditional_formatting(0, "!!", greater_than(4)) }
    assert_raises(IronCalc::Error) { model.add_conditional_formatting(0, "A1", {type: "Nope"}) }
    assert_raises(IronCalc::Error) { model.add_conditional_formatting(0, "A1", greater_than(4).except(:stop_if_true)) }
    assert_raises(IronCalc::Error) { model.add_conditional_formatting(0, "A1", greater_than("=(")) }
    assert_raises(IronCalc::Error) { model.delete_conditional_formatting(0, 0) }
    assert_raises(IronCalc::Error) { model.raise_conditional_formatting_priority(0, 0) }
    assert_raises(IronCalc::Error) { model.get_dxf_for_conditional_formatting(0, 0) }
    assert_raises(IronCalc::Error) { model.get_conditional_formatting_list(9) }
    assert_empty model.get_conditional_formatting_list(0)
  end

  def test_xlsx_round_trip
    model.add_conditional_formatting(0, "A1:A3", greater_than(4))
    reloaded = IronCalc.load_from_xlsx_bytes(model.to_xlsx_bytes, "m", LOCALE, TIMEZONE, LANGUAGE)

    cf = reloaded.get_conditional_formatting_list(0).first
    assert_equal ["A1:A3", "GreaterThan", "4"], [cf[:range], cf[:cf_rule][:operator], cf[:cf_rule][:formula]]
    assert_equal true, reloaded.get_dxf_for_conditional_formatting(0, 0)[:font][:b]
  end

  def test_user_model_evaluates_and_undoes
    fill_column(user_model, [5])
    user_model.add_conditional_formatting(0, "A1", greater_than(4))
    assert_equal true, user_model.get_extended_cell_style(0, 1, 1)[:style][:font][:b]

    user_model.update_conditional_formatting(0, 0, "A1", greater_than(9))
    refute user_model.get_extended_cell_style(0, 1, 1)[:style][:font][:b]
    user_model.undo
    assert_equal true, user_model.get_extended_cell_style(0, 1, 1)[:style][:font][:b]

    user_model.delete_conditional_formatting(0, 0)
    assert_empty user_model.get_conditional_formatting_list(0)
    user_model.undo
    assert_equal 1, user_model.get_conditional_formatting_list(0).size
    user_model.undo
    user_model.undo
    assert_empty user_model.get_conditional_formatting_list(0)
  end

  def test_user_model_priority_and_dxf
    user_model.add_conditional_formatting(0, "A1", greater_than(1))
    user_model.add_conditional_formatting(0, "A1", greater_than(2))
    user_model.raise_conditional_formatting_priority(0, 0)
    assert_equal [0, 1], user_model.get_conditional_formatting_list(0).map { |cf| cf[:index] }
    user_model.lower_conditional_formatting_priority(0, 0)
    assert_equal [1, 0], user_model.get_conditional_formatting_list(0).map { |cf| cf[:index] }
    user_model.undo
    assert_equal [0, 1], user_model.get_conditional_formatting_list(0).map { |cf| cf[:index] }

    assert_equal RED_BOLD[:font], user_model.get_dxf_for_conditional_formatting(0, 1)[:font]
    assert_raises(IronCalc::Error) { user_model.delete_conditional_formatting(0, 5) }
  end
end
