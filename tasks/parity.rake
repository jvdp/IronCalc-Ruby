# `rake parity` — reports API-surface drift against the engine and the Python
# bindings. What the checks are for, and how to act on the report, is in AGENTS.md.
#
# Every surface comes from a tool that already knows it: Ruby's from runtime
# introspection, the engine's from rustdoc's JSON output for the version we
# build against, Python's from introspecting the published wheel of the same
# version (via uv), and the doc stubs from YARD's registry.
#
# STRICT=1 makes hard gaps exit non-zero; otherwise the task only reports.

require "json"
require "open3"
require "yard"

module Parity
  ROOT = File.expand_path("..", __dir__)
  RUSTDOC_TARGET = File.join(ROOT, "tmp", "parity", "rustdoc")
  CLASSES = %w[Model UserModel].freeze

  # Ruby name => engine name. Two reasons to rename, and nothing else qualifies:
  #
  #   1. The engine name describes its own plumbing rather than the operation.
  #      `range_clear_*` and `set_columns_width` take an area or a span; we bind
  #      the 1x1 case, so the Ruby name says cell, row or column.
  #   2. The two engine classes spell one operation differently (`set_column_width`
  #      on Model, `set_columns_width` on UserModel). One Ruby name for both, so a
  #      call reads the same whichever class it lands on.
  #
  # Where the Python bindings already made the same call we follow their spelling
  # rather than invent a third: `clear_cell_contents`, `get_cell_content`,
  # `set_frozen_*_count`, `rename_sheet`, and Model's `set_column_width` /
  # `set_row_height` are all theirs.
  MODEL_RENAMES = {
    "clear_cell_contents" => "range_clear_contents",
    "get_cell_content" => "get_localized_cell_content",
    "get_cell_style_json" => "get_style_for_cell",
    "set_frozen_columns_count" => "set_frozen_columns",
    "set_frozen_rows_count" => "set_frozen_rows",
    "rename_sheet" => "rename_sheet_by_index",
    "clear_cell_all" => "range_clear_all"
    # Row/column `*_json` accessors need no entry; `engine_name` strips the suffix.
  }.freeze
  USERMODEL_RENAMES = {
    "clear_cell_contents" => "range_clear_contents",
    "clear_cell_all" => "range_clear_all",
    "clear_cell_formatting" => "range_clear_formatting",
    "set_column_width" => "set_columns_width",
    "set_row_height" => "set_rows_height",
    "set_column_hidden" => "set_columns_hidden",
    "set_row_hidden" => "set_rows_hidden"
  }.freeze

  # Ruby name => Python name, where the two bindings chose differently.
  PYTHON_RENAMES = {
    "number_to_column" => "column_name_from_number",
    "column_to_number" => "column_number_from_name",
    "get_cell_value_by_index" => "get_cell_value"
  }.freeze

  # Assembled in the Ruby layer or in the binding; no single engine method behind them.
  RUBY_COMPOSED = %w[
    get_cell_style set_cell_style get_sheet_dimensions defined_names
    valid_defined_name? batch to_xlsx_bytes
  ].freeze

  # Engine functionality that is not a method of the class itself: the xlsx and
  # icalc writers live in the export crate, and the hidden readers are on the
  # engine's Model only (UserModel reaches them through `get_model`).
  ENGINE_ELSEWHERE = %w[
    save_to_xlsx save_to_icalc
    is_row_hidden is_column_hidden
  ].freeze

  # Engine methods we intentionally do not expose. Keyed per class: the same
  # name can mean different things on each — `rename_sheet` is the by-name
  # variant on Model, the by-index method we do expose on UserModel.
  ENGINE_OMIT_SHARED = %w[
    new_empty from_bytes get_fmt_settings
    get_cell_style_index get_cell_style_or_none get_sheet_markup parse_reference
    extend_to extend_copied_value move_cell_value_to_area
    formula_completion cycle_reference
  ].freeze
  ENGINE_OMIT = {
    # Constructors, the sheet-id allocator, and the by-name/by-id lookups for
    # operations we already expose by index.
    "Model" => %w[
      from_workbook rename_sheet delete_sheet_by_name delete_sheet_by_sheet_id
      get_new_sheet_id set_cell_style_by_name
      set_sheet_style set_sheet_row_style set_sheet_column_style
    ].freeze,
    # Constructors, the raw-model escape hatch, workbook naming, and UI-only
    # helpers not covered by the patterns below.
    "UserModel" => %w[
      from_model get_model get_name set_name
      set_area_with_border on_paste_styles set_top_left_visible_cell
      get_last_non_empty_in_row_before_column get_first_non_empty_in_row_after_column
    ].freeze
  }.freeze
  # Unlike the lists above, a pattern also absorbs engine methods added later, so
  # the report counts what each class loses to one (VERBOSE=1 names them).
  ENGINE_OMIT_PATTERNS = [
    /\Aon_/, /\Aget_selected_/, /\Aset_selected_/, /\Aget_scroll_/,
    /window/, /clipboard/, /\Aauto_fill_/, /\Apaste_/,
    /\Amove_(rows|columns)/, /grid_lines/, /timezone/, /locale/, /language/,
    /hide_sheet/
  ].freeze

  # Python's constructors are classmethods, with no engine counterpart to omit.
  PYTHON_CONSTRUCTORS = %w[new from_bytes from_xlsx from_icalc].freeze

  # In the Python bindings but deliberately not here. `test_panic` proves a Rust
  # panic reaches the caller as a catchable error; under magnus it arrives as a
  # `fatal`, which no `rescue` can take and which ends the process — so binding it
  # would ship a public method whose only contract is to kill the interpreter.
  PYTHON_OMIT = %w[test_panic].freeze

  # Listed rather than pattern-matched so they stay visible in the report.
  ENGINE_DEFERRED = %w[
    add_conditional_formatting delete_conditional_formatting
    update_conditional_formatting get_conditional_formatting_list
    evaluate_conditional_formatting get_dxf_for_conditional_formatting
    raise_conditional_formatting_priority lower_conditional_formatting_priority
    create_named_style update_named_style delete_named_style
    get_named_style get_named_style_includes get_named_style_list
    get_builtin_named_styles
    get_theme set_theme resolve_color
    get_extended_style_for_cell get_extended_cell_style
    duplicate_sheet move_sheet
    set_user_array_formula get_cell_array_structure
  ].freeze

  module_function

  # Booting Ruby and loading the extension dominates the task's runtime, so one
  # script collects everything. A class's surface is its own methods plus those
  # of any prepended module, which `instance_methods(false)` omits.
  INTROSPECT = <<~RUBY.freeze
    require "ironcalc"
    require "json"

    # Methods a prepended module (DefinedNames, Batch) adds; these are
    # documented in model.rb, not in native_methods.rb.
    def prepended(klass)
      klass.ancestors.take_while { |a| a != klass }
           .select { |a| a.instance_of?(Module) }
           .flat_map { |m| m.instance_methods(false) }.map(&:to_s)
    end

    # Arity of the native method, looking past any prepended wrapper.
    def native_arity(klass, name)
      m = klass.instance_method(name)
      m = m.super_method while m && m.owner != klass
      m&.arity
    end

    def surface(klass)
      own = klass.instance_methods(false).map(&:to_s)
      pre = prepended(klass)
      {
        "own" => own.sort.uniq,
        "prepended" => pre.sort.uniq,
        "arity" => own.to_h { |n| [n, native_arity(klass, n)] },
        # Parameter kinds of the method a caller actually reaches.
        "params" => (own + pre).to_h { |n| [n, klass.instance_method(n).parameters.map { |kind, _| kind.to_s }] },
      }
    end

    puts JSON.generate(
      "Model" => surface(IronCalc::Model),
      "UserModel" => surface(IronCalc::UserModel),
      "module" => IronCalc.singleton_methods(false).map(&:to_s).sort.uniq,
    )
  RUBY

  def introspect
    out, status = Open3.capture2(RbConfig.ruby, "-Ilib", "-e", INTROSPECT)
    raise "could not introspect Ruby API (is the extension compiled? run `rake compile`)" unless status.success?

    JSON.parse(out)
  end

  # Flattens `introspect` to the name lists the surface checks compare against.
  def ruby_api(data)
    api = {"module" => data["module"]}
    CLASSES.each { |name| api[name] = (data[name]["own"] + data[name]["prepended"]).sort.uniq }
    api
  end

  # The engine's public API, from rustdoc's JSON output for the `ironcalc_base`
  # we build against: `{"version" => "0.8.3", "Model" => {name => [param names]},
  # "UserModel" => {...}}`, receiver excluded. The JSON output is a nightly
  # feature; RUSTC_BOOTSTRAP unlocks it on a stable toolchain. Nil if it fails.
  def engine_api
    return @engine_api if defined?(@engine_api)

    _, status = Open3.capture2e(
      {"RUSTC_BOOTSTRAP" => "1"},
      "cargo", "rustdoc", "-q", "-p", "ironcalc_base", "--target-dir", RUSTDOC_TARGET,
      "--", "-Z", "unstable-options", "--output-format", "json",
      chdir: ROOT
    )
    return @engine_api = nil unless status.success?

    doc = JSON.parse(File.read(File.join(RUSTDOC_TARGET, "doc", "ironcalc_base.json")))
    @engine_api = CLASSES.to_h { |name| [name, rustdoc_methods(doc, name)] }
    @engine_api["version"] = doc["crate_version"]
    @engine_api
  end

  # Public methods of the engine's struct named `type_name`, across all of its
  # inherent `impl` blocks. `paths` records it under its defining module
  # (`ironcalc_base::model::Model`), not the crate-root re-export.
  def rustdoc_methods(doc, type_name)
    index = doc["index"]
    id = doc["paths"].find { |_, p| p["crate_id"].zero? && p["kind"] == "struct" && p["path"].last == type_name }&.first
    return {} unless id

    index[id]["inner"]["struct"]["impls"]
      .map { |impl_id| index[impl_id.to_s]["inner"]["impl"] }
      .select { |impl| impl["trait"].nil? }
      .flat_map { |impl| impl["items"].map { |item_id| index[item_id.to_s] } }
      .select { |item| item["visibility"] == "public" && item["inner"].key?("function") }
      .to_h { |fn| [fn["name"], fn["inner"]["function"]["sig"]["inputs"].map(&:first) - ["self"]] }
  end

  PYTHON_INTROSPECT = <<~PYTHON.freeze
    import inspect, json, ironcalc

    def surface(obj):
        return {name: inspect.getdoc(getattr(obj, name)) or ""
                for name in dir(obj) if not name.startswith("_")}

    module = {name: doc for name, doc in surface(ironcalc).items()
              if callable(getattr(ironcalc, name)) and not inspect.isclass(getattr(ironcalc, name))}
    print(json.dumps({"Model": surface(ironcalc.Model),
                      "UserModel": surface(ironcalc.UserModel),
                      "module": module}))
  PYTHON

  # The Python bindings' API, from introspecting the published wheel whose
  # version matches the engine's: `{"Model" => {name => docstring}, ...}`. uv
  # provides the throwaway environment. Nil if it fails (e.g. offline, no uv).
  def python_api(version)
    return @python_api if defined?(@python_api)

    out, status = Open3.capture2(
      "uv", "run", "--quiet", "--no-project", "--with", "ironcalc==#{version}",
      "python", "-c", PYTHON_INTROSPECT
    )
    @python_api = status.success? ? JSON.parse(out) : nil
  rescue Errno::ENOENT
    @python_api = nil
  end

  # Methods YARD documents on `IronCalc::<class_name>`, `@!method` stubs and
  # inline-documented Ruby methods alike, as {name => YARD::CodeObjects::MethodObject}.
  def documented(class_name)
    @registry ||= begin
      YARD::Logger.instance.level = YARD::Logger::ERROR
      YARD::Registry.clear
      YARD.parse(File.join(ROOT, "lib", "**", "*.rb"))
      true
    end
    YARD::Registry.at("IronCalc::#{class_name}")
      .meths(inherited: false, included: false)
      .select { |m| m.scope == :instance && m.visibility == :public }
      .to_h { |m| [m.name.to_s, m] }
  end

  # A Ruby method maps to an engine method by rename, or by dropping the `_json`
  # suffix the private style accessors carry (`get_row_style_json` backs
  # `get_row_style`).
  def engine_name(method, renames)
    renames.fetch(method, method.delete_suffix("_json"))
  end

  # Engine methods not reachable from Ruby, as [deferred, unreviewed, by_pattern]:
  # the ones we've knowingly deferred, the ones nobody has looked at yet (the
  # actionable list), and the ones a pattern absorbed.
  def engine_gap(class_name, engine, ruby_methods, renames)
    exposed = ruby_methods.map { |m| engine_name(m, renames) }
    missing = engine - exposed - ENGINE_OMIT_SHARED - ENGINE_OMIT.fetch(class_name)
    patterned, missing = missing.partition { |m| ENGINE_OMIT_PATTERNS.any? { |re| m =~ re } }
    missing.partition { |m| ENGINE_DEFERRED.include?(m) } << patterned.sort
  end

  # Names we expose with no engine counterpart — typos and stale renames.
  def invented_names(engine, ruby_methods, renames)
    ruby_methods.map { |m| engine_name(m, renames) } - engine - RUBY_COMPOSED - ENGINE_ELSEWHERE
  end

  # Ruby methods that share an engine method's name but not its signature: the
  # same number of parameters, all positional and required. Checked against the
  # class's own engine counterpart first, then the other engine class's.
  def signature_drift(params, own_methods, other_methods)
    params.filter_map do |name, kinds|
      expected = own_methods.fetch(name) { other_methods[name] }&.size
      next if expected.nil?
      next if kinds.all?("req") && kinds.size == expected

      "#{name} (ruby: #{kinds.size} #{kinds.uniq.join("/")}, engine: #{expected} positional)"
    end
  end

  # Python methods we neither expose nor have already accounted for. Applies the
  # same renames and omit lists as the engine check, so the report is limited to
  # decisions nobody has made yet.
  def python_gap(class_name, py_methods, ruby_methods)
    if class_name == "module"
      exposed = ruby_methods + ruby_methods.filter_map { |m| PYTHON_RENAMES[m] }
      return py_methods - exposed - PYTHON_OMIT
    end

    renames = (class_name == "Model") ? MODEL_RENAMES : USERMODEL_RENAMES
    exposed = ruby_methods +
      ruby_methods.filter_map { |m| renames[m] } +
      ruby_methods.filter_map { |m| PYTHON_RENAMES[m] }
    missing = py_methods - exposed - ENGINE_DEFERRED -
      ENGINE_OMIT_SHARED - ENGINE_OMIT.fetch(class_name) -
      PYTHON_CONSTRUCTORS - PYTHON_OMIT
    missing.reject { |m| ENGINE_OMIT_PATTERNS.any? { |re| m =~ re } }
  end

  # Doc drift: documented methods vs the methods actually defined. Returns
  # [arity mismatches, undocumented, stale].
  def doc_gap(class_name, data)
    docs = documented(class_name)
    own = data["own"]

    mismatched = docs.filter_map do |name, doc|
      actual = data["arity"][name]
      next if actual.nil? || actual.negative? || actual == doc.parameters.size

      "#{name} (documented #{doc.parameters.size}, actual #{actual})"
    end
    [mismatched, (own - docs.keys).sort, (docs.keys - own).sort]
  end
end

desc "Check the Ruby API surface against the pinned engine (and the Python bindings)"
task :parity do
  introspected = Parity.introspect
  ruby = Parity.ruby_api(introspected)
  hard_gaps = 0
  skipped = []
  engine_skipped = false
  verbose = ENV["VERBOSE"] == "1"

  section = ->(title) { puts "\n== #{title} ==" }
  list = lambda do |label, items|
    return if items.empty?

    puts "  #{label}:"
    items.sort.each { |m| puts "    - #{m}" }
  end

  # --- 1. Engine shape (authoritative) --------------------------------------
  engine = Parity.engine_api
  if engine
    section.call("Engine surface v#{engine["version"]} (authoritative)")
    targets = {"Model" => Parity::MODEL_RENAMES, "UserModel" => Parity::USERMODEL_RENAMES}
    # Finding nothing means the rustdoc JSON layout changed, not that the engine
    # lost its API.
    empty = targets.keys.select { |name| engine[name].empty? }
    hard_gaps += empty.size
    list.call("found no methods at all (has the rustdoc JSON format changed?)", empty)
    targets.each do |name, renames|
      methods = engine[name].keys
      deferred, unreviewed, patterned = Parity.engine_gap(name, methods, ruby[name], renames)
      hard_gaps += unreviewed.size
      if unreviewed.empty?
        puts "  ✓ #{name}: every non-omitted engine method is exposed " \
             "(#{methods.size} in the engine, #{deferred.size} deferred, " \
             "#{patterned.size} absorbed by ENGINE_OMIT_PATTERNS)"
      else
        list.call("#{name}: engine methods NOT exposed and NOT allowlisted", unreviewed)
      end
      list.call("#{name}: deferred (known, not yet exposed)", deferred)
      list.call("#{name}: absorbed by ENGINE_OMIT_PATTERNS", patterned) if verbose
    end

    # Names we expose that the engine does not have — typos and stale renames.
    section.call("Invented names (expect none)")
    invented_total = 0
    targets.each do |name, renames|
      invented = Parity.invented_names(engine[name].keys, ruby[name], renames)
      invented_total += invented.size
      list.call("#{name}: no such engine method (typo, or a rename to record)", invented)
    end
    hard_gaps += invented_total
    puts "  ✓ no invented names" if invented_total.zero?

    # A Ruby method that shares an engine name keeps the engine's signature;
    # anything friendlier goes in a helper under its own name.
    section.call("Signatures of engine-named methods (expect none to differ)")
    drift_total = 0
    Parity::CLASSES.each do |name|
      other = (Parity::CLASSES - [name]).first
      drift = Parity.signature_drift(introspected[name]["params"], engine[name], engine[other])
      drift_total += drift.size
      list.call("#{name}: signature differs from the engine's", drift)
    end
    hard_gaps += drift_total
    puts "  ✓ every engine-named method takes the engine's parameters" if drift_total.zero?
  else
    engine_skipped = true
    skipped << "engine surface — `cargo rustdoc` could not document ironcalc_base"
    puts "\n== Engine surface ==\n  ✗ skipped: `cargo rustdoc` could not document ironcalc_base"
  end

  # --- 2. Doc stubs (native methods are invisible to YARD) -------------------
  section.call("Documentation (expect every method documented, arities matching)")
  Parity::CLASSES.each do |name|
    mismatched, undocumented, stale = Parity.doc_gap(name, introspected[name])
    hard_gaps += mismatched.size + undocumented.size + stale.size
    list.call("#{name}: documented arity disagrees with the method", mismatched)
    list.call("#{name}: defined but not documented", undocumented)
    list.call("#{name}: documented but no longer defined", stale)
    if (mismatched + undocumented + stale).empty?
      puts "  ✓ #{name}: #{Parity.documented(name).size} methods, all documented and matching"
    end
  end

  # --- 3. Python bindings (advisory: never fall behind) ----------------------
  python = engine && Parity.python_api(engine["version"])
  if python
    section.call("Python bindings v#{engine["version"]}")
    %w[Model UserModel module].each do |name|
      py_methods = python[name].keys
      missing = Parity.python_gap(name, py_methods, ruby[name])
      hard_gaps += missing.size
      if missing.empty?
        shared = (py_methods & ruby[name]).size
        puts "  ✓ #{name}: nothing unaccounted (Python #{py_methods.size}, " \
             "we expose #{ruby[name].size}, #{shared} shared, " \
             "#{py_methods.size - shared} renamed, deferred or omitted)"
      else
        list.call("in Python #{name}, MISSING from Ruby", missing)
      end
    end

    # Advisory: methods we document only with tags, where Python has prose to borrow.
    Parity::CLASSES.each do |name|
      borrowable = Parity.documented(name).select { |m, doc| doc.docstring.blank? && !python[name][m].to_s.empty? }
      list.call("#{name}: no description, but Python documents it", borrowable.keys)
    end
  else
    skipped << "Python bindings — the ironcalc wheel could not be introspected (needs uv and network)"
    puts "\n== Python bindings ==\n  ✗ skipped: the ironcalc wheel could not be introspected"
  end

  puts "\n#{"-" * 60}"
  skipped.each { |what| puts "SKIPPED: #{what}" }
  strict = ENV["STRICT"] == "1"
  if hard_gaps.positive?
    puts "Parity: #{hard_gaps} unreviewed gap(s) above."
    abort("FAILED (STRICT=1)") if strict
  elsif skipped.empty?
    puts "Parity OK: no unreviewed gaps."
  else
    # Only the engine check is authoritative, so only its absence is a failure —
    # a green run that checked nothing is the outcome worth ruling out.
    puts "Parity incomplete: no gaps found, but #{skipped.size} check(s) did not run."
    abort("FAILED (STRICT=1): the engine check did not run") if strict && engine_skipped
  end
end
