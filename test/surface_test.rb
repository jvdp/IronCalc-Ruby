require "minitest/autorun"
require "ironcalc"
require "tmpdir"
require_relative "fixtures_helper"

# Surface-coverage suite: exercises the binding's *own* methods - the idiomatic
# wrappers (style Hash, symbol cell types, symbol-keyed worksheet properties),
# mutation, sheet management, and the save/load round-trips - which the
# formula-regression suite (calc_tests_test.rb) deliberately does not touch.
#
# Fixture-backed tests use the engine's own sample files (example.xlsx etc.,
# resolved from the dependency) as realistic inputs, and skip cleanly if those
# aren't present. The remaining tests build models from scratch and always run.
class SurfaceTest < Minitest::Test
  # --- Reading real files: structure, freeze panes, styles, formula eval ------

  def test_worksheet_properties_from_example
    model = load_fixture("example.xlsx")
    names = model.get_worksheets_properties.map { |p| p[:name] }
    assert_equal(
      ["Sheet1", "Second", "Sheet4", "shared", "Table",
       "Sheet2", "Created fourth", "Frozen", "Split", "Hidden"],
      names
    )
    # Idiomatic shape: array of Hashes with symbol keys.
    first = model.get_worksheets_properties.first
    assert_equal %i[name state sheet_id color].sort, first.keys.sort
  end

  def test_frozen_panes_read_from_fixtures
    freeze = load_fixture("freeze.xlsx")
    assert_equal 2, freeze.get_frozen_rows_count(0)
    assert_equal 3, freeze.get_frozen_columns_count(0)

    split = load_fixture("split.xlsx")
    assert_equal 0, split.get_frozen_rows_count(0)
    assert_equal 0, split.get_frozen_columns_count(0)
  end

  def test_cell_styles_read_as_hash
    model = load_fixture("basic_text.xlsx")
    # Row 1: A bold, B italic, C underline, F strikethrough (see engine test.rs).
    assert_equal true, model.get_cell_style(0, 1, 1)["font"]["b"]
    assert_equal true, model.get_cell_style(0, 1, 2)["font"]["i"]
    assert_equal true, model.get_cell_style(0, 1, 3)["font"]["u"]
    assert_equal true, model.get_cell_style(0, 1, 6)["font"]["strike"]
    # A1 is bold but not italic.
    refute_equal true, model.get_cell_style(0, 1, 1)["font"]["i"]
  end

  def test_formula_evaluation_from_fixture
    model = load_fixture("openpyxl_example.xlsx")
    model.evaluate
    assert_equal "Hello, World!", model.get_formatted_cell_value(0, 1, 1)
    assert_equal "2", model.get_formatted_cell_value(0, 2, 1)            # =1+1
    assert_equal "It is what it is", model.get_formatted_cell_value(0, 1, 2)
  end

  # --- Idiomatic conversions --------------------------------------------------

  def test_cell_type_returns_symbol
    model = IronCalc.create("m", "en", "UTC", "en")
    model.set_user_input(0, 1, 1, "42")
    model.set_user_input(0, 2, 1, "hello")
    model.set_user_input(0, 3, 1, "=1/0")
    model.evaluate
    assert_equal :number, model.get_cell_type(0, 1, 1)
    assert_equal :text, model.get_cell_type(0, 2, 1)
    assert_equal :error_value, model.get_cell_type(0, 3, 1)
  end

  def test_cell_style_roundtrip_via_hash
    model = IronCalc.create("m", "en", "UTC", "en")
    style = model.get_cell_style(0, 1, 1)
    style["font"]["b"] = true
    style["font"]["i"] = true
    model.set_cell_style(0, 1, 1, style)
    roundtripped = model.get_cell_style(0, 1, 1)
    assert_equal true, roundtripped["font"]["b"]
    assert_equal true, roundtripped["font"]["i"]
  end

  def test_get_cell_content_returns_formula
    model = IronCalc.create("m", "en", "UTC", "en")
    model.set_user_input(0, 1, 1, "=1+2")
    assert_equal "=1+2", model.get_cell_content(0, 1, 1)
  end

  # --- Mutation ---------------------------------------------------------------

  def test_insert_and_delete_rows_shift_content
    model = IronCalc.create("m", "en", "UTC", "en")
    model.set_user_input(0, 5, 1, "marker")
    model.evaluate

    model.insert_rows(0, 5, 2)
    assert_equal "", model.get_formatted_cell_value(0, 5, 1)
    assert_equal "marker", model.get_formatted_cell_value(0, 7, 1)

    model.delete_rows(0, 5, 2)
    assert_equal "marker", model.get_formatted_cell_value(0, 5, 1)
  end

  def test_clear_cell_contents
    model = IronCalc.create("m", "en", "UTC", "en")
    model.set_user_input(0, 1, 1, "gone")
    model.evaluate
    assert_equal "gone", model.get_formatted_cell_value(0, 1, 1)
    model.clear_cell_contents(0, 1, 1)
    assert_equal "", model.get_formatted_cell_value(0, 1, 1)
  end

  def test_column_width_and_row_height_roundtrip
    model = IronCalc.create("m", "en", "UTC", "en")
    model.set_column_width(0, 3, 123.5)
    model.set_row_height(0, 4, 55.0)
    assert_in_delta 123.5, model.get_column_width(0, 3)
    assert_in_delta 55.0, model.get_row_height(0, 4)
  end

  def test_frozen_counts_setters
    model = IronCalc.create("m", "en", "UTC", "en")
    model.set_frozen_rows_count(0, 2)
    model.set_frozen_columns_count(0, 3)
    assert_equal 2, model.get_frozen_rows_count(0)
    assert_equal 3, model.get_frozen_columns_count(0)
  end

  def test_sheet_dimensions
    model = IronCalc.create("m", "en", "UTC", "en")
    model.set_user_input(0, 3, 5, "a")
    model.set_user_input(0, 10, 8, "b")
    model.evaluate
    assert_equal [3, 10, 5, 8], model.get_sheet_dimensions(0).to_a
  end

  # --- Sheet management -------------------------------------------------------

  def test_sheet_management
    model = IronCalc.create("m", "en", "UTC", "en")
    model.add_sheet("Extra")
    model.new_sheet
    assert_equal 3, model.get_worksheets_properties.size

    model.rename_sheet(0, "Renamed")
    assert_equal "Renamed", model.get_worksheets_properties.first[:name]

    model.set_sheet_color(0, "#FF0000")
    assert_equal "#FF0000", model.get_worksheets_properties.first[:color]

    model.delete_sheet(2)
    assert_equal 2, model.get_worksheets_properties.size
  end

  # --- Persistence round-trips ------------------------------------------------

  def test_save_to_xlsx_roundtrip
    model = IronCalc.create("m", "en", "UTC", "en")
    model.set_user_input(0, 1, 1, "=6*7")
    model.rename_sheet(0, "Calc")
    model.evaluate

    Dir.mktmpdir do |dir|
      path = File.join(dir, "roundtrip.xlsx") # must not pre-exist
      model.save_to_xlsx(path)
      reloaded = IronCalc.load_from_xlsx(path, "en", "UTC", "en")
      assert_equal "Calc", reloaded.get_worksheets_properties.first[:name]
      assert_equal "42", reloaded.get_formatted_cell_value(0, 1, 1) # cached on save
      reloaded.evaluate
      assert_equal "42", reloaded.get_formatted_cell_value(0, 1, 1)
    end
  end

  def test_to_bytes_roundtrip
    model = IronCalc.create("m", "en", "UTC", "en")
    model.set_user_input(0, 1, 1, "=6*7")
    model.evaluate

    reloaded = IronCalc.load_from_bytes(model.to_bytes, "en")
    reloaded.evaluate
    assert_equal "42", reloaded.get_formatted_cell_value(0, 1, 1)
  end

  # --- Fixture-driven mutation (real file in, mutate, save, reload) -----------

  def test_load_mutate_save_reload
    model = load_fixture("openpyxl_example.xlsx")
    model.set_user_input(0, 10, 1, "=2+2")
    model.rename_sheet(0, "Mutated")
    model.evaluate

    Dir.mktmpdir do |dir|
      path = File.join(dir, "mutated.xlsx")
      model.save_to_xlsx(path)
      reloaded = IronCalc.load_from_xlsx(path, "en", "UTC", "en")
      reloaded.evaluate
      assert_equal "Mutated", reloaded.get_worksheets_properties.first[:name]
      assert_equal "Hello, World!", reloaded.get_formatted_cell_value(0, 1, 1)
      assert_equal "4", reloaded.get_formatted_cell_value(0, 10, 1)
    end
  end

  private

  def load_fixture(name)
    path = FixturesHelper.fixture(name)
    skip "IronCalc fixture #{name} not found (run `rake compile` first)." if path.nil? || !File.exist?(path)
    IronCalc.load_from_xlsx(path, "en", "UTC", "en")
  end
end
