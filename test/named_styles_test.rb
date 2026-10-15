require "minitest/autorun"
require "ironcalc"
require_relative "models_helper"

# Named styles on both APIs, and applying them by name on the raw Model.
class NamedStylesTest < Minitest::Test
  include ModelsHelper

  FONT_ONLY = {
    number_format: false, font: true, fill: false,
    border: false, alignment: false, protection: false
  }.freeze

  def bold(target = model)
    style = target.get_named_style("normal")
    style[:font][:b] = true
    style
  end

  def test_new_workbook_has_only_the_default_style
    assert_equal ["normal"], model.get_named_style_list
    assert_equal FONT_ONLY.transform_values { true }, model.get_named_style_includes("normal")
  end

  def test_create_and_read
    model.create_named_style("Bold", bold, FONT_ONLY)

    assert_equal %w[normal Bold], model.get_named_style_list
    assert model.get_named_style("Bold")[:font][:b]
    assert_equal FONT_ONLY, model.get_named_style_includes("Bold")
  end

  def test_missing_includes_keys_count_as_true
    model.create_named_style("Bold", bold, {font: true})

    assert model.get_named_style_includes("Bold").values.all?
  end

  def test_create_rejects_a_taken_name
    model.create_named_style("Bold", bold, FONT_ONLY)

    assert_raises(IronCalc::Error) { model.create_named_style("Bold", bold, FONT_ONLY) }
  end

  def test_unknown_name_raises
    assert_raises(IronCalc::Error) { model.get_named_style("Nope") }
    assert_raises(IronCalc::Error) { model.get_named_style_includes("Nope") }
    assert_raises(IronCalc::Error) { model.delete_named_style("Nope") }
    assert_raises(IronCalc::Error) { model.update_named_style("Nope", "Nope", bold, {}) }
  end

  def test_update_renames_and_propagates
    model.create_named_style("Bold", bold, FONT_ONLY)
    model.set_cell_style_by_name(0, 1, 1, "Bold")
    italic = bold.tap { |s| s[:font][:i] = true }
    model.update_named_style("Bold", "Strong", italic, FONT_ONLY)

    assert_equal %w[normal Strong], model.get_named_style_list
    assert model.get_style_for_cell(0, 1, 1)[:font][:i]
  end

  def test_delete_keeps_cell_formatting
    model.create_named_style("Bold", bold, FONT_ONLY)
    model.set_cell_style_by_name(0, 1, 1, "Bold")
    model.delete_named_style("Bold")

    assert_equal ["normal"], model.get_named_style_list
    assert model.get_style_for_cell(0, 1, 1)[:font][:b]
  end

  def test_built_in_style_cannot_be_changed
    assert_raises(IronCalc::Error) { model.delete_named_style("normal") }
    assert_raises(IronCalc::Error) { model.update_named_style("normal", "normal", bold, {}) }
  end

  def test_set_cell_style_by_name_keeps_categories_the_style_excludes
    model.set_cell_style(0, 1, 1, style_with { |s| s[:num_fmt] = "0.00" })
    model.create_named_style("Bold", bold, FONT_ONLY)
    model.set_cell_style_by_name(0, 1, 1, "Bold")

    style = model.get_style_for_cell(0, 1, 1)
    assert style[:font][:b]
    assert_equal "0.00", style[:num_fmt]
  end

  def test_set_sheet_style
    model.create_named_style("Bold", bold, FONT_ONLY)
    model.set_sheet_style(0, "Bold")

    assert model.get_style_for_cell(0, 10, 10)[:font][:b]
  end

  def test_set_sheet_row_style
    model.create_named_style("Bold", bold, FONT_ONLY)
    model.set_sheet_row_style(0, 3, "Bold")

    assert model.get_row_style(0, 3)[:font][:b]
  end

  def test_set_sheet_column_style
    model.create_named_style("Bold", bold, FONT_ONLY)
    model.set_sheet_column_style(0, 4, "Bold")

    assert model.get_column_style(0, 4)[:font][:b]
  end

  def test_applying_an_unknown_name_raises
    assert_raises(IronCalc::Error) { model.set_cell_style_by_name(0, 1, 1, "Nope") }
    assert_raises(IronCalc::Error) { model.set_sheet_style(0, "Nope") }
    assert_raises(IronCalc::Error) { model.set_sheet_row_style(0, 1, "Nope") }
    assert_raises(IronCalc::Error) { model.set_sheet_column_style(0, 1, "Nope") }
  end

  def test_round_trips_through_xlsx
    model.create_named_style("Bold", bold, FONT_ONLY)
    model.set_cell_style_by_name(0, 1, 1, "Bold")
    reloaded = IronCalc.load_from_xlsx_bytes(model.to_xlsx_bytes, "m", LOCALE, TIMEZONE, LANGUAGE)

    assert_equal %w[normal Bold], reloaded.get_named_style_list
    assert reloaded.get_named_style("Bold")[:font][:b]
    includes = reloaded.get_named_style_includes("Bold")
    assert includes[:font]
    refute includes[:number_format]
    assert reloaded.get_style_for_cell(0, 1, 1)[:font][:b]
  end

  def test_round_trips_through_icalc_bytes
    model.create_named_style("Bold", bold, FONT_ONLY)
    reloaded = IronCalc.load_from_bytes(model.to_bytes, LANGUAGE)

    assert_equal FONT_ONLY, reloaded.get_named_style_includes("Bold")
  end

  def test_user_model_builtin_named_styles
    builtins = user_model.get_builtin_named_styles
    name, style = builtins.find { |n, _| n == "Good" }

    assert_equal "Good", name
    assert_equal "#C6EFCE", style[:fill][:color]
    # Definitions only: the workbook does not hold them.
    assert_equal ["normal"], user_model.get_named_style_list
  end

  def test_user_model_create_update_delete
    user_model.create_named_style("Bold", bold(user_model), FONT_ONLY)
    assert_equal FONT_ONLY, user_model.get_named_style_includes("Bold")

    user_model.update_named_style("Bold", "Strong", bold(user_model), {})
    assert_equal %w[normal Strong], user_model.get_named_style_list
    assert user_model.get_named_style("Strong")[:font][:b]

    user_model.delete_named_style("Strong")
    assert_equal ["normal"], user_model.get_named_style_list
  end

  def test_user_model_undo_and_redo
    user_model.create_named_style("Bold", bold(user_model), FONT_ONLY)
    user_model.undo
    assert_equal ["normal"], user_model.get_named_style_list
    user_model.redo
    assert_equal %w[normal Bold], user_model.get_named_style_list

    user_model.update_named_style("Bold", "Strong", bold(user_model), FONT_ONLY)
    user_model.undo
    assert_equal %w[normal Bold], user_model.get_named_style_list

    user_model.delete_named_style("Bold")
    user_model.undo
    assert_equal %w[normal Bold], user_model.get_named_style_list
  end
end
