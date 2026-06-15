require "minitest/autorun"
require "ironcalc"
require_relative "fixtures_helper"

# Formula-evaluation regression suite, driven by the IronCalc engine's own
# calc_tests/*.xlsx fixtures (resolved from the dependency - see fixtures_helper).
#
# These fixtures are self-checking the way the engine's Rust `compare::test_file`
# uses them: each file stores formulas together with the values Excel/Sheets
# cached when it was saved. We load the file twice - once WITHOUT evaluating (so
# cells hold those cached, ground-truth values) and once WITH `evaluate` (so the
# engine recomputes them) - then assert every visible cell matches. Excel is the
# oracle; IronCalc reproducing it is the test.
#
# Scope note: this exercises a narrow slice of the binding (load + evaluate +
# read), so it is primarily an *engine-drift guard* for dependency bumps. Tests
# that cover the binding's own surface (styles, mutation, save, UserModel) live
# in surface_test.rb.
class CalcTestsTest < Minitest::Test
  # Files whose cached vs. recomputed values legitimately diverge (volatile/
  # time-dependent functions, or known engine gaps at the pinned version).
  # Keep this list short and annotated; revisit on every dependency bump.
  SKIP_FILES = %w[].freeze

  # Sheet that is test scaffolding (locale/epsilon config) rather than data.
  META_SHEET = "metadata".freeze

  # Default relative tolerance, matching the engine's `compare` module. Excel and
  # IronCalc reach the last digits of many functions by slightly different
  # numerical routes; a file may override this via its METADATA sheet.
  EPS = 5e-8

  files = FixturesHelper.calc_test_files

  if files.empty?
    def test_calc_fixtures_available
      skip "IronCalc calc_tests fixtures not found (run `rake compile` first " \
           "so the engine crate is in the Cargo registry)."
    end
  else
    files.each do |path|
      name = File.basename(path, ".xlsx")
      method_name = "test_calc_#{name.gsub(/[^0-9A-Za-z]/, '_')}"
      define_method(method_name) do
        skip "#{name}: on the volatile/known-divergence skip list" if SKIP_FILES.include?(name)
        assert_recomputes_to_cached(path)
      end
    end
  end

  private

  def assert_recomputes_to_cached(path)
    locale, eps = read_metadata(path)
    cached     = IronCalc.load_from_xlsx(path, locale, "UTC", "en")
    recomputed = IronCalc.load_from_xlsx(path, locale, "UTC", "en")
    recomputed.evaluate

    diffs = []
    cached.get_worksheets_properties.each_with_index do |props, sheet|
      next if props[:name].to_s.casecmp?(META_SHEET)

      min_r, max_r, min_c, max_c = cached.get_sheet_dimensions(sheet).to_a
      (min_r..max_r).each do |row|
        (min_c..max_c).each do |col|
          want = cached.get_formatted_cell_value(sheet, row, col)
          got  = recomputed.get_formatted_cell_value(sheet, row, col)
          next if values_match?(want, got, eps)

          diffs << format("  %s!%s%d  cached=%p  recomputed=%p  (=%s)",
                          props[:name], col_letter(col), row, want, got,
                          recomputed.get_cell_content(sheet, row, col))
          return assert(false, fail_message(path, diffs)) if diffs.size >= 20
        end
      end
    end

    assert_empty diffs, fail_message(path, diffs)
  end

  def fail_message(path, diffs)
    capped = diffs.size >= 20 ? "+" : ""
    "#{File.basename(path)}: IronCalc recomputation diverged from Excel's " \
      "cached values in #{diffs.size}#{capped} cell(s):\n" + diffs.join("\n")
  end

  # Mirrors the engine's convention: a METADATA sheet configures the comparison.
  # A1 (read as cell *content*, not the formatted value, which can display as
  # "#VALUE!") is either the literal "Locale" - then B1 holds the locale to
  # evaluate under, e.g. "en-GB" - or a number that overrides the comparison
  # epsilon for that file (e.g. BESSEL uses 1e-5 because its special functions
  # reach Excel's last digits by a different numerical route). Returns [locale, eps].
  def read_metadata(path)
    model = IronCalc.load_from_xlsx(path, "en", "UTC", "en")
    model.get_worksheets_properties.each_with_index do |props, sheet|
      next unless props[:name].to_s.casecmp?(META_SHEET)

      a1 = model.get_cell_content(sheet, 1, 1).to_s
      if a1 == "Locale"
        b1 = model.get_cell_content(sheet, 1, 2).to_s
        return [b1.empty? ? "en" : b1, EPS]
      end

      override = Float(a1, exception: false)
      return ["en", override] if override
    end
    ["en", EPS]
  rescue IronCalc::Error
    ["en", EPS]
  end

  def values_match?(want, got, eps)
    return true if want == got

    x = numeric(want)
    y = numeric(got)
    return false if x.nil? || y.nil?

    numbers_are_close(x, y, eps)
  end

  def numbers_are_close(x, y, eps)
    norm = Math.sqrt((x * x) + (y * y))
    return true if norm.zero?

    d = (x - y).abs
    d < eps || (d / norm) < eps
  end

  # Parses a formatted value as a Float when it is a number, tolerating en/en-GB
  # thousands separators and a leading/trailing currency or percent symbol (so
  # "-0.00 EUR" and "0.00 EUR" compare as the equal numbers they are). Returns
  # nil for dates, text and errors, which then fall back to exact comparison.
  def numeric(str)
    return nil if str.nil? || str.empty?

    t = str.gsub(/[[:space:]]/, "").delete(",").gsub(/[€$£¥%]/, "")
    return nil if t.empty?
    return nil unless t.match?(/\A[-+]?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?\z/)

    Float(t)
  rescue ArgumentError
    nil
  end

  def col_letter(col)
    letters = +""
    n = col
    while n > 0
      n, rem = (n - 1).divmod(26)
      letters.prepend((rem + 65).chr)
    end
    letters
  end
end
