require "minitest/autorun"
require "ironcalc"

# Module-level helpers bound straight from the engine. These are pass-throughs,
# so what is worth testing is the boundary: the types that come back, nil for
# the engine's None, and errors arriving as IronCalc::Error.
class UtilsTest < Minitest::Test
  def test_column_to_number_converts
    assert_equal 27, IronCalc.column_to_number("AA")
  end

  def test_column_to_number_surfaces_engine_errors
    assert_raises(IronCalc::Error) { IronCalc.column_to_number("XFE") }
  end

  def test_number_to_column_converts_and_is_nil_out_of_range
    assert_equal "AA", IronCalc.number_to_column(27)
    assert_nil IronCalc.number_to_column(16_385)
  end

  def test_predicates_return_booleans
    assert_equal true, IronCalc.is_valid_column("AA")
    assert_equal false, IronCalc.is_valid_column("XFE")
    assert_equal true, IronCalc.is_valid_column_number(1)
    assert_equal true, IronCalc.is_valid_row(1)
  end

  # Guards the claim the two stubs make about each other; if the engine widens
  # or narrows the rule, the documentation is wrong rather than merely stale.
  def test_only_r_and_c_distinguish_the_two_identifier_validators
    differing = %w[total my_name _x RC ZZ A Sales2024 R r C c A1 B2 R1 C3 R1C1 1abc].reject do |name|
      IronCalc.is_valid_a1_identifier(name) == IronCalc.is_valid_identifier(name)
    end

    assert_equal %w[R r C c], differing
  end

  def test_quote_name
    assert_equal "'My Sheet'", IronCalc.quote_name("My Sheet")
  end

  def test_parse_reference_returns_a_symbol_keyed_hash
    assert_equal({row: 2, column: 2, absolute_row: true, absolute_column: true},
      IronCalc.parse_reference_a1("$B$2"))
    assert_equal({row: 2, column: 3, absolute_row: true, absolute_column: true},
      IronCalc.parse_reference_r1c1("R2C3"))
  end

  def test_parse_reference_is_nil_when_it_does_not_parse
    assert_nil IronCalc.parse_reference_a1("nonsense")
  end

  def test_locale_and_timezone_lists
    assert_includes IronCalc.get_supported_locales, "en"
    assert_includes IronCalc.get_all_timezones, "UTC"
  end
end
