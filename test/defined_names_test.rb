require "minitest/autorun"
require "tmpdir"
require "ironcalc"
require_relative "models_helper"

# Defined names (named ranges) on both APIs. Persistence is the property that
# matters: IronCalc drops anything it does not model on resave, so a name must
# survive a round trip through both icalc bytes and xlsx.
class DefinedNamesTest < Minitest::Test
  include ModelsHelper

  def test_new_and_list
    model.new_defined_name("key", "Sheet1!$C$1")
    assert_equal [{name: "key", scope: nil, formula: "Sheet1!$C$1"}], model.defined_names
    assert_equal model.defined_names, model.get_defined_name_list
  end

  def test_sheet_scope
    model.add_sheet("Other")
    model.new_defined_name("key", "Sheet1!$A$1")
    model.new_defined_name("key", "Other!$A$1", scope: 1)

    assert_equal [nil, 1], model.defined_names.map { |n| n[:scope] }
    # Same name, different scope: both coexist.
    assert_equal %w[key key], model.defined_names.map { |n| n[:name] }
  end

  def test_update
    model.new_defined_name("key", "Sheet1!$C$1")
    model.update_defined_name("key", "renamed", "Sheet1!$D$1")

    assert_equal [{name: "renamed", scope: nil, formula: "Sheet1!$D$1"}], model.defined_names
  end

  def test_update_changes_scope
    model.add_sheet("Other")
    model.new_defined_name("key", "Sheet1!$A$1")
    model.update_defined_name("key", "key", "Sheet1!$A$1", new_scope: 1)

    assert_equal 1, model.defined_names.first[:scope]
  end

  def test_delete
    model.new_defined_name("key", "Sheet1!$A$1")
    model.delete_defined_name("key")

    assert_empty model.defined_names
  end

  def test_delete_respects_scope
    model.add_sheet("Other")
    model.new_defined_name("key", "Other!$A$1", scope: 1)
    # Workbook scope (the default) holds no such name.
    assert_raises(IronCalc::Error) { model.delete_defined_name("key") }

    model.delete_defined_name("key", scope: 1)
    assert_empty model.defined_names
  end

  def test_invalid_name_raises
    # "A1" parses as a cell reference, so it is not a valid identifier.
    assert_raises(IronCalc::Error) { model.new_defined_name("A1", "Sheet1!$A$1") }
  end

  def test_is_valid_defined_name
    assert model.is_valid_defined_name("key", "Sheet1!$A$1")
    refute model.is_valid_defined_name("A1", "Sheet1!$A$1"), "a cell reference is not a valid name"
    refute model.is_valid_defined_name("key", "not a reference")
    refute model.is_valid_defined_name("key", "Sheet1!$A$1", scope: 99)

    model.new_defined_name("key", "Sheet1!$A$1")
    refute model.is_valid_defined_name("key", "Sheet1!$B$1"), "already taken in this scope"
  end

  def test_round_trips_through_bytes
    model.add_sheet("Other")
    model.new_defined_name("book_scoped", "Sheet1!$C$1")
    model.new_defined_name("sheet_scoped", "Other!$A$1", scope: 1)
    before = model.defined_names

    reloaded = IronCalc.load_from_bytes(model.to_bytes, "en")

    assert_equal before, reloaded.defined_names
  end

  def test_round_trips_through_xlsx
    model.new_defined_name("key", "Sheet1!$C$1")
    model.set_user_input(0, 1, 3, "42")
    model.evaluate

    Dir.mktmpdir do |dir|
      path = File.join(dir, "named.xlsx")
      model.save_to_xlsx(path)
      reloaded = IronCalc.load_from_xlsx(path, "en", "UTC", "en")

      assert_equal model.defined_names, reloaded.defined_names
      # And the name still resolves after the round trip.
      reloaded.set_user_input(0, 2, 1, "=key")
      reloaded.evaluate
      assert_equal "42", reloaded.get_formatted_cell_value(0, 2, 1)
    end
  end

  # UserModel ---------------------------------------------------------------

  def test_user_model_new_and_list
    user_model.new_defined_name("key", "Sheet1!$C$1")

    assert_equal [{name: "key", scope: nil, formula: "Sheet1!$C$1"}], user_model.defined_names
  end

  def test_user_model_recalculates_without_evaluate
    user_model.set_user_input(0, 1, 3, "42")
    user_model.new_defined_name("answer", "Sheet1!$C$1")
    user_model.set_user_input(0, 1, 1, "=answer")

    assert_equal "42", user_model.get_formatted_cell_value(0, 1, 1)
  end

  # Mutations go through the user model's own engine methods, so they are
  # diff-tracked; the raw model's would not be.
  def test_user_model_undo_and_redo
    user_model.new_defined_name("key", "Sheet1!$A$1")
    user_model.undo
    assert_empty user_model.defined_names

    user_model.redo
    assert_equal ["key"], user_model.defined_names.map { |n| n[:name] }
  end

  def test_user_model_is_valid_defined_name
    assert user_model.is_valid_defined_name("key", "Sheet1!$A$1")
    refute user_model.is_valid_defined_name("A1", "Sheet1!$A$1")
  end

  def test_user_model_round_trips_through_bytes
    user_model.new_defined_name("key", "Sheet1!$C$1")

    reloaded = IronCalc.create_user_model_from_bytes(user_model.to_bytes, "en")

    assert_equal user_model.defined_names, reloaded.defined_names
  end
end
