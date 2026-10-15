require "minitest/autorun"
require "ironcalc"
require_relative "models_helper"

# The workbook theme on both APIs, and resolving theme colors against it.
class ThemesTest < Minitest::Test
  include ModelsHelper

  THEME_KEYS = %i[
    name dk1 lt1 dk2 lt2 accent1 accent2 accent3 accent4 accent5 accent6 hlink fol_hlink
  ].freeze

  def test_get_theme
    theme = model.get_theme

    assert_equal THEME_KEYS, theme.keys
    assert_equal "Office", theme[:name]
    assert_match(/\A#\h{6}\z/, theme[:accent1])
  end

  def test_set_theme
    theme = model.get_theme.merge(name: "Mine", accent1: "#112233")
    model.set_theme(theme)

    assert_equal theme, model.get_theme
  end

  def test_set_theme_accepts_string_keys
    theme = model.get_theme.merge(name: "Mine")
    model.set_theme(theme.transform_keys(&:to_s))

    assert_equal theme, model.get_theme
  end

  def test_set_theme_rejects_an_incomplete_theme
    error = assert_raises(IronCalc::Error) { model.set_theme({name: "Mine"}) }
    assert_match(/missing field/, error.message)
  end

  def test_round_trips_through_xlsx
    theme = model.get_theme.merge(name: "Mine", dk2: "#ABCDEF")
    model.set_theme(theme)

    reloaded = IronCalc.load_from_xlsx_bytes(model.to_xlsx_bytes, "m", LOCALE, TIMEZONE, LANGUAGE)

    assert_equal theme, reloaded.get_theme
  end

  def test_round_trips_through_bytes
    theme = model.get_theme.merge(name: "Mine", dk2: "#ABCDEF")
    model.set_theme(theme)

    assert_equal theme, IronCalc.load_from_bytes(model.to_bytes, LANGUAGE).get_theme
  end

  # UserModel ---------------------------------------------------------------

  def test_user_model_set_theme_undo_and_redo
    original = user_model.get_theme
    theme = original.merge(name: "Mine", accent1: "#112233")
    user_model.set_theme(theme)
    assert_equal theme, user_model.get_theme

    user_model.undo
    assert_equal original, user_model.get_theme

    user_model.redo
    assert_equal theme, user_model.get_theme
  end

  def test_resolve_color
    accent1 = user_model.get_theme[:accent1]

    assert_equal accent1, user_model.resolve_color([4, 0.0])
    assert_equal "#8FABDC", user_model.resolve_color([4, 0.4])
    assert_equal "#123456", user_model.resolve_color("#123456")
    assert_equal "", user_model.resolve_color(nil)
  end

  def test_resolve_color_follows_the_theme
    user_model.set_theme(user_model.get_theme.merge(accent1: "#112233"))

    assert_equal "#112233", user_model.resolve_color([4, 0.0])
  end

  def test_resolve_color_rejects_other_shapes
    assert_raises(IronCalc::Error) { user_model.resolve_color(4) }
  end
end
