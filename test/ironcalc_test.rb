require "minitest/autorun"
require "ironcalc"

class CreateTest < Minitest::Test
  def test_simple
    model = IronCalc.create("model", "en", "UTC", "en")
    model.set_user_input(0, 1, 1, "=1+2")
    model.evaluate

    assert_equal "3", model.get_formatted_cell_value(0, 1, 1)

    bytes = model.to_bytes
    model2 = IronCalc.load_from_bytes(bytes, "en")
    assert_equal "3", model2.get_formatted_cell_value(0, 1, 1)
  end

  def test_simple_user
    model = IronCalc.create_user_model("model", "en", "UTC", "en")
    model.set_user_input(0, 1, 1, "=1+2")
    model.set_user_input(0, 1, 2, "=A1+3")

    assert_equal "3", model.get_formatted_cell_value(0, 1, 1)
    assert_equal "6", model.get_formatted_cell_value(0, 1, 2)

    diffs = model.flush_send_queue

    model2 = IronCalc.create_user_model("model", "en", "UTC", "en")
    model2.apply_external_diffs(diffs)
    assert_equal "3", model2.get_formatted_cell_value(0, 1, 1)
    assert_equal "6", model2.get_formatted_cell_value(0, 1, 2)
  end

  def test_sheet_dimensions
    model = IronCalc.create("model", "en", "UTC", "en")
    assert_equal [1, 1, 1, 1], model.get_sheet_dimensions(0).to_a

    model.set_user_input(0, 3, 5, "Hello")
    model.set_user_input(0, 10, 8, "World")
    model.evaluate

    assert_equal [3, 10, 5, 8], model.get_sheet_dimensions(0).to_a
  end

  def test_sheet_dimensions_user_model
    model = IronCalc.create_user_model("model", "en", "UTC", "en")
    model.set_user_input(0, 2, 3, "Test")
    assert_equal [2, 2, 3, 3], model.get_sheet_dimensions(0).to_a
  end

  def test_cell_style_roundtrip
    model = IronCalc.create("model", "en", "UTC", "en")
    style = model.get_style_for_cell(0, 1, 1)
    style[:font][:b] = true
    model.set_cell_style(0, 1, 1, style)

    assert_equal true, model.get_style_for_cell(0, 1, 1)[:font][:b]
  end

  def test_cell_type
    model = IronCalc.create("model", "en", "UTC", "en")
    model.set_user_input(0, 1, 1, "42")
    model.set_user_input(0, 1, 2, "hello")
    model.evaluate

    assert_equal :number, model.get_cell_type(0, 1, 1)
    assert_equal :text, model.get_cell_type(0, 1, 2)
  end

  def test_worksheets_properties
    model = IronCalc.create("model", "en", "UTC", "en")
    model.add_sheet("Second")
    props = model.get_worksheets_properties

    assert_equal 2, props.length
    assert_equal "Second", props[1][:name]
  end

  def test_error_raised
    model = IronCalc.create("model", "en", "UTC", "en")
    assert_raises(IronCalc::Error) do
      model.get_formatted_cell_value(99, 1, 1)
    end
  end

  def test_create_applies_locale_and_language
    model = IronCalc.create("model", "de", "Europe/Berlin", "es")
    model.set_user_input(0, 1, 1, "1,5")
    model.evaluate

    assert_equal :number, model.get_cell_type(0, 1, 1), "a German decimal comma"
    assert_equal "Hoja1", model.get_worksheets_properties.first[:name]
  end

  def test_create_user_model_applies_locale_and_language
    model = IronCalc.create_user_model("model", "de", "Europe/Berlin", "es")
    model.set_user_input(0, 1, 1, "1,5")

    assert_equal :number, model.get_cell_type(0, 1, 1), "a German decimal comma"
    assert_equal "Hoja1", model.get_worksheets_properties.first[:name]
  end

  def test_create_rejects_invalid_arguments
    error = assert_raises(IronCalc::Error) { IronCalc.create("model", "xx", "UTC", "en") }
    assert_match(/locale/, error.message)
    error = assert_raises(IronCalc::Error) { IronCalc.create("model", "en", "Mars/Base", "en") }
    assert_match(/timezone/, error.message)
    error = assert_raises(IronCalc::Error) { IronCalc.create_user_model("model", "en", "UTC", "xx") }
    assert_match(/language/i, error.message)
  end

  def test_loaders_reject_an_invalid_language
    bytes = IronCalc.create("model", "en", "UTC", "en").to_bytes
    assert_raises(IronCalc::Error) { IronCalc.load_from_bytes(bytes, "xx") }
  end
end
