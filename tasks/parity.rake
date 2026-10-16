# `rake parity` — reports API-surface drift against the engine and the Python
# bindings. What the checks are for, and how to act on the report, is in AGENTS.md.
#
# Every surface comes from a tool that already knows it: Ruby's from runtime
# introspection, the engine's from rustdoc's JSON output for the version we
# build against, Python's from introspecting the published wheel of the same
# version (via uv), and the documentation from YARD's registry.
#
# STRICT=1 makes hard gaps exit non-zero; otherwise the task only reports.

require "json"
require "open3"
require "yard"

module Parity
  ROOT = File.expand_path("..", __dir__)
  RUSTDOC_TARGET = File.join(ROOT, "tmp", "parity", "rustdoc")
  CLASSES = %w[Model UserModel].freeze

  # Native methods with no engine method of the same name on either class: the
  # xlsx/icalc writers live in the export crate and `get_sheet_dimensions` reads
  # a worksheet. Methods implemented in Ruby are helpers by definition and need
  # no entry.
  NATIVE_EXTRAS = %w[
    save_to_xlsx to_xlsx_bytes save_to_icalc get_sheet_dimensions
  ].freeze

  # Ruby modules prepended to each class; their methods are helpers.
  PREPENDED = {"Model" => %w[DefinedNames], "UserModel" => %w[DefinedNames Batch]}.freeze

  # Engine methods we intentionally do not expose. Keyed per class where the
  # reason is specific to one.
  ENGINE_OMIT_SHARED = %w[
    new_empty from_bytes get_fmt_settings
    get_cell_style_index get_cell_style_or_none get_sheet_markup parse_reference
    extend_to extend_copied_value move_cell_value_to_area
    formula_completion cycle_reference
  ].freeze
  ENGINE_OMIT = {
    # Constructors, the sheet-id allocator, by-name/by-id variants of operations
    # we expose by index, and the named-style setters, which need the
    # named-style table we don't expose yet.
    "Model" => %w[
      from_workbook delete_sheet_by_name delete_sheet_by_sheet_id
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

  # The backlog. Listed rather than pattern-matched so it stays visible.
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
    get_max_evaluation_depth set_max_evaluation_depth
    get_max_evaluation_stack set_max_evaluation_stack
    merge_cells merge_cells_across merge_cells_center merge_cells_down
    unmerge_cells get_merged_cells get_merge_structure
  ].freeze

  module_function

  # Booting Ruby and loading the extension dominates the task's runtime, so one
  # script collects everything. A class's surface is its own methods plus those
  # of any prepended module, which `instance_methods(false)` omits.
  INTROSPECT = <<~RUBY.freeze
    require "ironcalc"
    require "json"

    def prepended(klass)
      klass.ancestors.take_while { |a| a != klass }
           .select { |a| a.instance_of?(Module) }
           .flat_map { |m| m.instance_methods(false) }.map(&:to_s)
    end

    def surface(klass)
      own = klass.instance_methods(false).map(&:to_s)
      all = (own + prepended(klass)).sort.uniq
      {
        "own" => own.sort.uniq,
        "all" => all,
        # Native methods have no source location; Ruby-layer helpers do.
        "native" => all.reject { |n| klass.instance_method(n).source_location },
        "arity" => all.to_h { |n| [n, klass.instance_method(n).arity] },
        "params" => all.to_h { |n| [n, klass.instance_method(n).parameters.map { |kind, _| kind.to_s }] },
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

  # Methods YARD documents on `IronCalc::<class_name>` and the modules prepended
  # to it, `@!method` stubs and inline-documented Ruby methods alike, as
  # {name => YARD::CodeObjects::MethodObject}.
  def documented(class_name)
    @registry ||= begin
      YARD::Logger.instance.level = YARD::Logger::ERROR
      YARD::Registry.clear
      YARD.parse(File.join(ROOT, "lib", "**", "*.rb"))
      true
    end
    owners = ["IronCalc::#{class_name}"] + PREPENDED.fetch(class_name).map { |m| "IronCalc::#{m}" }
    # YARD registers every Ruby method, so documented means it has prose or tags.
    owners.flat_map { |path| YARD::Registry.at(path).meths(inherited: false, included: false) }
      .select { |m| m.scope == :instance && m.visibility == :public }
      .reject { |m| m.docstring.blank? && m.tags.empty? }
      .to_h { |m| [m.name.to_s, m] }
  end

  # Engine methods not reachable from Ruby, as [deferred, unreviewed, by_pattern]:
  # the ones we've knowingly deferred, the ones nobody has looked at yet (the
  # actionable list), and the ones a pattern absorbed.
  def engine_gap(class_name, engine, ruby_methods)
    missing = engine - ruby_methods - ENGINE_OMIT_SHARED - ENGINE_OMIT.fetch(class_name)
    patterned, missing = missing.partition { |m| ENGINE_OMIT_PATTERNS.any? { |re| m =~ re } }
    missing.partition { |m| ENGINE_DEFERRED.include?(m) } << patterned.sort
  end

  # List entries that no longer describe anything: omitted or deferred names the
  # engine doesn't have (or that we now expose), and extras we no longer define
  # or that the engine has after all.
  def stale_entries(engine, ruby)
    all_engine = engine.values_at(*CLASSES).flat_map(&:keys)
    exposed = ruby.values_at(*CLASSES).flat_map { |data| data["all"] }
    omitted = ENGINE_OMIT_SHARED + ENGINE_OMIT.values.flatten + ENGINE_DEFERRED
    (omitted - all_engine) + (omitted & exposed) + (NATIVE_EXTRAS - exposed) + (NATIVE_EXTRAS & all_engine)
  end

  # Native methods with no engine method of that name on either class.
  def invented_names(data, engine)
    data["native"] - engine.values_at(*CLASSES).flat_map(&:keys) - NATIVE_EXTRAS
  end

  # Methods that share an engine method's name but not its signature: the same
  # number of parameters, all positional and required. Checked against the
  # class's own engine counterpart first, then the other engine class's.
  def signature_drift(params, own_methods, other_methods)
    params.filter_map do |name, kinds|
      expected = own_methods.fetch(name) { other_methods[name] }&.size
      next if expected.nil?
      next if kinds.all?("req") && kinds.size == expected

      "#{name} (ruby: #{kinds.size} #{kinds.uniq.join("/")}, engine: #{expected} positional)"
    end
  end

  # Doc drift: documented methods vs the methods actually defined. Returns
  # [arity mismatches, undocumented, stale].
  def doc_gap(class_name, data)
    docs = documented(class_name)
    own = data["all"]

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
  ruby = Parity.introspect
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
  gap = lambda do |label, items|
    hard_gaps += items.size
    list.call(label, items)
  end

  # --- 1. Engine shape (authoritative) --------------------------------------
  engine = Parity.engine_api
  if engine
    section.call("Engine surface v#{engine["version"]} (authoritative)")
    # Finding nothing means the rustdoc JSON layout changed, not that the engine
    # lost its API.
    gap.call("found no methods at all (has the rustdoc JSON format changed?)",
      Parity::CLASSES.select { |name| engine[name].empty? })

    Parity::CLASSES.each do |name|
      methods = engine[name].keys
      deferred, unreviewed, patterned = Parity.engine_gap(name, methods, ruby[name]["all"])
      gap.call("#{name}: engine methods NOT exposed and NOT allowlisted", unreviewed)
      if unreviewed.empty?
        puts "  ✓ #{name}: every non-omitted engine method is exposed " \
             "(#{methods.size} in the engine, #{deferred.size} deferred, " \
             "#{patterned.size} absorbed by ENGINE_OMIT_PATTERNS)"
      end
      list.call("#{name}: deferred (known, not yet exposed)", deferred)
      list.call("#{name}: absorbed by ENGINE_OMIT_PATTERNS", patterned) if verbose
    end

    gap.call("list entries that no longer match anything", Parity.stale_entries(engine, ruby))

    section.call("Native methods mirror the engine (expect no drift)")
    drift_total = 0
    Parity::CLASSES.each do |name|
      other = (Parity::CLASSES - [name]).first
      invented = Parity.invented_names(ruby[name], engine)
      drift = Parity.signature_drift(ruby[name]["params"], engine[name], engine[other])
      drift_total += invented.size + drift.size
      gap.call("#{name}: native, but no engine method has this name", invented)
      gap.call("#{name}: signature differs from the engine's", drift)
    end
    puts "  ✓ every native method has an engine name and the engine's parameters" if drift_total.zero?
  else
    engine_skipped = true
    skipped << "engine surface — `cargo rustdoc` could not document ironcalc_base"
    puts "\n== Engine surface ==\n  ✗ skipped: `cargo rustdoc` could not document ironcalc_base"
  end

  # --- 2. Documentation (native methods are invisible to YARD) ---------------
  section.call("Documentation (expect every method documented, arities matching)")
  Parity::CLASSES.each do |name|
    mismatched, undocumented, stale = Parity.doc_gap(name, ruby[name])
    gap.call("#{name}: documented arity disagrees with the method", mismatched)
    gap.call("#{name}: defined but not documented", undocumented)
    gap.call("#{name}: documented but no longer defined", stale)
    if (mismatched + undocumented + stale).empty?
      puts "  ✓ #{name}: #{Parity.documented(name).size} methods, all documented and matching"
    end
  end

  # --- 3. Python bindings (informational) ------------------------------------
  # Anything Python exposes from the engine is covered by the engine check, so
  # this lists only Python's own names, for reference. Never a gap.
  python = engine && Parity.python_api(engine["version"])
  if python
    section.call("Python bindings v#{engine["version"]} (informational)")
    Parity::CLASSES.each do |name|
      py = python[name].keys
      own = py - ruby[name]["all"] - engine[name].keys
      puts "  #{name}: Python #{py.size}, we expose #{ruby[name]["all"].size}, #{(py & ruby[name]["all"]).size} shared"
      list.call("#{name}: Python-only names", own) if verbose
      borrowable = Parity.documented(name).select { |m, doc| doc.docstring.blank? && !python[name][m].to_s.empty? }
      list.call("#{name}: no description, but Python documents it", borrowable.keys)
    end
    module_only = python["module"].keys - ruby["module"]
    puts "  module: Python #{python["module"].size}, we expose #{ruby["module"].size}"
    list.call("module: Python-only names", module_only) if verbose
  else
    puts "\n== Python bindings ==\n  ✗ skipped: the ironcalc wheel could not be introspected (needs uv and network)"
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
    puts "Parity incomplete: no gaps found, but #{skipped.size} check(s) did not run."
    abort("FAILED (STRICT=1): the engine check did not run") if strict && engine_skipped
  end
end
