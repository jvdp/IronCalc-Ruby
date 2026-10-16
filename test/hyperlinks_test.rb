require "minitest/autorun"
require "ironcalc"
require_relative "models_helper"

# Cell hyperlinks on both APIs: the Link Hash in both shapes, the two listings,
# undo on UserModel, and an xlsx round trip.
class HyperlinksTest < Minitest::Test
  include ModelsHelper

  EXTERNAL = {type: "External", target: "https://www.ironcalc.com", tooltip: nil}.freeze
  INTERNAL = {type: "Internal", location: "Sheet1!A30", tooltip: "Go down"}.freeze

  def test_external_link
    model.set_cell_link(0, 1, 1, EXTERNAL)
    assert_equal EXTERNAL, model.get_cell_link(0, 1, 1)
  end

  def test_internal_link_with_tooltip
    model.set_cell_link(0, 2, 3, INTERNAL)
    assert_equal INTERNAL, model.get_cell_link(0, 2, 3)
  end

  def test_string_keys_and_missing_tooltip_are_accepted
    model.set_cell_link(0, 1, 1, {"type" => "External", "target" => "mailto:a@b.com"})
    assert_equal({type: "External", target: "mailto:a@b.com", tooltip: nil}, model.get_cell_link(0, 1, 1))
  end

  def test_cell_without_link
    assert_nil model.get_cell_link(0, 1, 1)
  end

  def test_set_replaces
    model.set_cell_link(0, 1, 1, EXTERNAL)
    model.set_cell_link(0, 1, 1, INTERNAL)
    assert_equal INTERNAL, model.get_cell_link(0, 1, 1)
  end

  def test_delete
    model.set_cell_link(0, 1, 1, EXTERNAL)
    model.delete_cell_link(0, 1, 1)
    assert_nil model.get_cell_link(0, 1, 1)
    # Deleting a missing link is not an error.
    model.delete_cell_link(0, 1, 1)
  end

  def test_get_links_is_keyed_by_row_and_column
    model.set_cell_link(0, 1, 1, EXTERNAL)
    model.set_cell_link(0, 2, 3, INTERNAL)
    assert_equal({[1, 1] => EXTERNAL, [2, 3] => INTERNAL}, model.get_links(0))
  end

  def test_get_links_list_includes_dynamic_links
    model.set_cell_link(0, 2, 3, INTERNAL)
    model.set_cell_link(0, 1, 1, EXTERNAL)
    model.update_cell_with_formula(0, 4, 1, '=HYPERLINK("https://example.com", "example")')
    model.evaluate

    assert_equal [
      {row: 1, column: 1, dynamic: false, **EXTERNAL},
      {row: 2, column: 3, dynamic: false, **INTERNAL},
      {row: 4, column: 1, dynamic: true, type: "External", target: "https://example.com", tooltip: nil}
    ], model.get_links_list(0)
    # Dynamic links are not worksheet links.
    assert_equal [[1, 1], [2, 3]], model.get_links(0).keys.sort
  end

  def test_invalid_input_raises
    assert_raises(IronCalc::Error) { model.set_cell_link(0, 0, 1, EXTERNAL) }
    assert_raises(IronCalc::Error) { model.get_cell_link(0, 1, 0) }
    assert_raises(IronCalc::Error) { model.get_links(9) }
    assert_raises(IronCalc::Error) { model.get_links_list(9) }
    assert_raises(IronCalc::Error) { model.set_cell_link(0, 1, 1, {type: "Bogus"}) }
    assert_raises(IronCalc::Error) { model.set_cell_link(0, 1, 1, {type: "External"}) }
    assert_raises(TypeError) { model.set_cell_link(0, 1, 1, "https://www.ironcalc.com") }
  end

  def test_round_trips_through_xlsx
    model.set_cell_link(0, 1, 1, EXTERNAL)
    model.set_cell_link(0, 2, 3, INTERNAL)
    reloaded = IronCalc.load_from_xlsx_bytes(model.to_xlsx_bytes, "m", "en", "UTC", "en")
    assert_equal model.get_links(0), reloaded.get_links(0)
  end

  def test_user_model_set_with_label_styles_the_cell
    user_model.set_cell_link(0, 1, 1, EXTERNAL, "IronCalc")

    assert_equal EXTERNAL, user_model.get_cell_link(0, 1, 1)
    assert_equal "IronCalc", user_model.get_formatted_cell_value(0, 1, 1)
    assert user_model.get_cell_style(0, 1, 1)[:font][:u]
  end

  def test_user_model_set_without_label_keeps_content
    user_model.set_user_input(0, 1, 1, "text")
    user_model.set_cell_link(0, 1, 1, INTERNAL, nil)
    assert_equal "text", user_model.get_formatted_cell_value(0, 1, 1)
  end

  def test_user_model_listings
    user_model.set_cell_link(0, 1, 1, EXTERNAL, nil)
    assert_equal({[1, 1] => EXTERNAL}, user_model.get_links(0))
    assert_equal [{row: 1, column: 1, dynamic: false, **EXTERNAL}], user_model.get_links_list(0)
  end

  def test_user_model_undo_and_redo
    user_model.set_cell_link(0, 1, 1, EXTERNAL, "IronCalc")
    user_model.undo
    assert_nil user_model.get_cell_link(0, 1, 1)
    assert_equal "", user_model.get_formatted_cell_value(0, 1, 1)

    user_model.redo
    assert_equal EXTERNAL, user_model.get_cell_link(0, 1, 1)

    user_model.delete_cell_link(0, 1, 1)
    user_model.undo
    assert_equal EXTERNAL, user_model.get_cell_link(0, 1, 1)
  end

  def test_user_model_invalid_input_raises
    assert_raises(IronCalc::Error) { user_model.set_cell_link(0, 0, 1, EXTERNAL, nil) }
    assert_raises(IronCalc::Error) { user_model.delete_cell_link(0, 1, 0) }
    assert_raises(IronCalc::Error) { user_model.set_cell_link(0, 1, 1, {type: "Internal"}, nil) }
  end

  def test_user_model_round_trips_through_xlsx
    user_model.set_cell_link(0, 1, 1, EXTERNAL, "IronCalc")
    user_model.set_cell_link(0, 2, 3, INTERNAL, nil)
    reloaded = IronCalc.create_user_model_from_xlsx_bytes(user_model.to_xlsx_bytes, "m", "en", "UTC", "en")
    assert_equal user_model.get_links(0), reloaded.get_links(0)
  end
end
