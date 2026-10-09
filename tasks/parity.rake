# `rake parity` — reports API-surface drift against the engine and the Python
# bindings. What the checks are for, and how to act on the report, is in AGENTS.md.
#
# Ruby's surface comes from runtime introspection, so it covers native and
# Ruby-layer methods alike. The other two come from scanning `pub fn` inside the
# relevant `impl` blocks: the engine from the Cargo registry copy of the version
# we build against, Python from the PyPI sdist of the same version.
#
# STRICT=1 makes hard gaps exit non-zero; otherwise the task only reports.

require "fileutils"
require "json"
require "open-uri"
require "open3"
require "tmpdir"

module Parity
  PYTHON_CACHE = File.expand_path("../tmp/parity", __dir__)
  NATIVE_METHODS = File.expand_path("../lib/ironcalc/native_methods.rb", __dir__)
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

  # Documented inline in model.rb, so they carry no `@!method` stub.
  DOCUMENTED_IN_RUBY = %w[
    get_cell_style set_cell_style get_column_style set_column_style
    get_row_style set_row_style
  ].freeze

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

  # Engine methods the scan cannot reach: it reads only `impl Model` in
  # `src/*.rs` and `impl UserModel` in `src/user_model/*.rs`, so anything behind
  # `workbook.*` or in the export crate is invisible. The hidden readers are on
  # the engine's Model only; UserModel exposes them through `get_model`.
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

  # `@!method name(a, b)` stubs per class, as {name => documented arity}.
  def doc_stubs(class_name)
    src = File.read(NATIVE_METHODS)
    body = src[/^  class #{class_name}\b(.*?)^  end/m].to_s
    body.scan(/^\s*# @!method (\w+)(?:\(([^)]*)\))?/).to_h do |name, args|
      [name, args.to_s.split(",").count { |a| !a.strip.empty? }]
    end
  end

  # Extracts `pub fn` names inside `impl <type_name>` blocks (skipping trait impls)
  # across the given Rust files. Naive brace counting — fine for these sources.
  def rust_impl_methods(paths, type_name)
    methods = []
    paths.each do |path|
      next unless File.exist?(path)

      in_impl = false
      impl_depth = 0
      depth = 0
      File.foreach(path) do |line|
        if !in_impl && line.include?("{") && line !~ / for / &&
            line =~ /\bimpl\b[^{]*\b#{Regexp.escape(type_name)}\b/
          in_impl = true
          impl_depth = depth
        end
        methods << Regexp.last_match(1) if in_impl && line =~ /pub fn (\w+)/
        depth += line.count("{") - line.count("}")
        in_impl = false if in_impl && depth <= impl_depth
      end
    end
    methods.uniq.sort
  end

  # `pub fn` parameter counts (excluding the receiver) inside `impl <type_name>`
  # blocks, as {name => count}. Same naive brace counting as `rust_impl_methods`,
  # but reads whole signatures, which rustfmt spreads over several lines.
  def rust_impl_arities(paths, type_name)
    arities = {}
    paths.each do |path|
      next unless File.exist?(path)

      in_impl = false
      impl_depth = 0
      depth = 0
      signature = nil
      File.foreach(path) do |line|
        if !in_impl && line.include?("{") && line !~ / for / &&
            line =~ /\bimpl\b[^{]*\b#{Regexp.escape(type_name)}\b/
          in_impl = true
          impl_depth = depth
        end
        signature = +"" if in_impl && signature.nil? && line =~ /pub fn \w+/
        if signature
          signature << line
          if (m = signature.match(/pub fn (\w+)\s*(?:<[^(]*>)?\s*\((.*?)\)\s*(?:->|\{|where)/m))
            arities[m[1]] ||= rust_params(m[2]).count { |p| p !~ /\bself\z/ }
            signature = nil
          end
        end
        depth += line.count("{") - line.count("}")
        in_impl = false if in_impl && depth <= impl_depth
      end
    end
    arities
  end

  # Splits a Rust parameter list on the commas outside any `<>`, `()` or `[]`.
  def rust_params(list)
    params, current, nesting = [], +"", 0
    list.each_char do |c|
      nesting += 1 if "<([".include?(c)
      nesting -= 1 if ">)]".include?(c)
      if c == "," && nesting.zero?
        params << current.strip
        current = +""
      else
        current << c
      end
    end
    params << current.strip
    params.reject(&:empty?)
  end

  # Ruby methods that share an engine method's name but not its signature: the
  # same number of parameters, all positional and required. Checked against the
  # class's own engine counterpart first, then the other engine class's.
  def signature_drift(params, own_arities, other_arities)
    params.filter_map do |name, kinds|
      expected = own_arities.fetch(name) { other_arities[name] }
      next if expected.nil?
      next if kinds.all?("req") && kinds.size == expected

      "#{name} (ruby: #{kinds.size} #{kinds.uniq.join("/")}, engine: #{expected} positional)"
    end
  end

  # Top-level `pub fn` (module functions) in a Rust file — those not inside any impl.
  def rust_module_fns(path)
    return [] unless File.exist?(path)

    fns = []
    depth = 0
    File.foreach(path) do |line|
      fns << Regexp.last_match(1) if depth.zero? && line =~ /pub fn (\w+)/
      depth += line.count("{") - line.count("}")
    end
    fns.uniq.sort
  end

  # Memoized: every caller below would otherwise re-shell out to cargo.
  def engine_package
    return @engine_package if defined?(@engine_package)

    @engine_package = begin
      out, status = Open3.capture2("cargo", "metadata", "--format-version", "1")
      status.success? ? JSON.parse(out)["packages"].find { |p| p["name"] == "ironcalc_base" } : nil
    rescue
      nil
    end
  end

  def engine_base_src
    pkg = engine_package
    pkg && File.join(File.dirname(pkg["manifest_path"]), "src")
  end

  def engine_version
    engine_package&.fetch("version")
  end

  # `impl Model` is spread over several top-level files (model.rs, actions.rs,
  # styles.rs, units.rs, ...). `functions/` and `test/` also carry `impl Model`
  # blocks, but those are formula implementations, not API — hence top level only.
  def engine_model_files(src)
    Dir[File.join(src, "*.rs")]
  end

  # The Python bindings ship their Rust sources in the PyPI sdist, whose version
  # tracks the engine's — so the surface we compare against is the released one
  # for the version we build against, with no IronCalc checkout to keep in sync.
  # PyModel and PyUserModel live in their own files from 0.8.3 on, hence the glob.
  def python_sources(engine_version)
    return @python_sources if defined?(@python_sources)

    src = File.join(PYTHON_CACHE, "ironcalc-#{engine_version}", "bindings", "python", "src")
    fetch_python_sdist(engine_version) unless Dir.exist?(src)
    files = Dir[File.join(src, "*.rs")].sort
    @python_sources = files.empty? ? nil : files
  end

  # Extracts the binding sources alone; the sdist also carries the engine and its
  # xlsx fixtures, which we already have from the Cargo registry.
  def fetch_python_sdist(version)
    release = JSON.parse(URI.parse("https://pypi.org/pypi/ironcalc/#{version}/json").read)
    url = release["urls"].find { |u| u["packagetype"] == "sdist" }&.fetch("url")
    return unless url

    FileUtils.mkdir_p(PYTHON_CACHE)
    Dir.mktmpdir do |tmp|
      sdist = File.join(tmp, "ironcalc.tar.gz")
      File.binwrite(sdist, URI.parse(url).read)
      system("tar", "xzf", sdist, "-C", PYTHON_CACHE,
        "ironcalc-#{version}/bindings/python/src")
    end
  rescue
    nil
  end

  # `[name, engine_methods, ruby_methods, renames]` per class, scanned once.
  def engine_targets(src, ruby)
    [
      ["Model", rust_impl_methods(engine_model_files(src), "Model"),
        ruby["Model"], MODEL_RENAMES],
      ["UserModel", rust_impl_methods(Dir[File.join(src, "user_model", "*.rs")], "UserModel"),
        ruby["UserModel"], USERMODEL_RENAMES]
    ]
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

  # Stub names that carry no prose, only tags. A bare `@return` tells a reader
  # nothing the signature did not.
  def undescribed_stubs(class_name)
    body = File.read(NATIVE_METHODS)[/^  class #{class_name}\b(.*?)^  end/m].to_s
    bare, current = [], nil
    body.each_line do |line|
      case line
      when /^\s*# @!method (\w+)/
        bare << current[:name] if current && current[:prose].empty?
        current = {name: $1, prose: []}
      when /^\s*#\s?(.*)$/
        next unless current

        text = $1.strip
        current[:prose] << text unless text.empty? || text.start_with?("@")
      when /^\s*$/
        next
      else
        bare << current[:name] if current && current[:prose].empty?
        current = nil
      end
    end
    bare << current[:name] if current && current[:prose].empty?
    bare
  end

  # Python descriptions, keyed by method, for methods it documents.
  def python_descriptions(sources)
    (sources || []).each_with_object({}) do |path, acc|
      lines = File.readlines(path)
      lines.each_with_index do |line, i|
        next unless line =~ /pub fn (\w+)/

        name, doc, j = $1, [], i - 1
        while j >= 0 && lines[j] =~ %r{^\s*///\s?(.*)$}
          doc.unshift($1.strip)
          j -= 1
        end
        acc[name] = doc.join(" ") unless doc.empty?
      end
    end
  end

  # Doc drift: `@!method` stubs vs the methods actually registered. Returns
  # [arity mismatches, undocumented natives, stale stubs].
  def doc_gap(class_name, data)
    stubs = doc_stubs(class_name)
    native = data["own"]
    prepended = data["prepended"]

    mismatched = stubs.filter_map do |name, documented|
      actual = data["arity"][name]
      next if actual.nil? || actual.negative? || actual == documented

      "#{name} (stub #{documented}, actual #{actual})"
    end
    undocumented = native - stubs.keys - prepended - DOCUMENTED_IN_RUBY
    [mismatched, undocumented.sort, (stubs.keys - native).sort]
  end

  # Names we expose with no engine counterpart — typos and stale renames.
  def invented_names(engine, ruby_methods, renames)
    ruby_methods.map { |m| engine_name(m, renames) } - engine - RUBY_COMPOSED - ENGINE_ELSEWHERE
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
  section.call("Engine surface (authoritative, version-pinned)")
  if (src = Parity.engine_base_src)
    targets = Parity.engine_targets(src, ruby)
    # A scan that finds nothing means the brace counting broke on a new layout,
    # not that the engine lost its API.
    empty = targets.select { |_, engine, _, _| engine.empty? }.map(&:first)
    hard_gaps += empty.size
    list.call("scanned no methods at all (the Rust scan is broken)", empty)

    targets.each do |name, engine, ruby_methods, renames|
      deferred, unreviewed, patterned = Parity.engine_gap(name, engine, ruby_methods, renames)
      hard_gaps += unreviewed.size
      if unreviewed.empty?
        puts "  ✓ #{name}: every non-omitted engine method is exposed " \
             "(#{engine.size} scanned, #{deferred.size} deferred, " \
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
    targets.each do |name, engine, ruby_methods, renames|
      invented = Parity.invented_names(engine, ruby_methods, renames)
      invented_total += invented.size
      list.call("#{name}: no such engine method (typo, or a rename to record)", invented)
    end
    hard_gaps += invented_total
    puts "  ✓ no invented names" if invented_total.zero?

    # A Ruby method that shares an engine name keeps the engine's signature;
    # anything friendlier goes in a helper under its own name.
    section.call("Signatures of engine-named methods (expect none to differ)")
    arities = {
      "Model" => Parity.rust_impl_arities(Parity.engine_model_files(src), "Model"),
      "UserModel" => Parity.rust_impl_arities(Dir[File.join(src, "user_model", "*.rs")], "UserModel")
    }
    drift_total = 0
    Parity::CLASSES.each do |name|
      other = (Parity::CLASSES - [name]).first
      drift = Parity.signature_drift(introspected[name]["params"], arities[name], arities[other])
      drift_total += drift.size
      list.call("#{name}: signature differs from the engine's", drift)
    end
    hard_gaps += drift_total
    puts "  ✓ every engine-named method takes the engine's parameters" if drift_total.zero?
  else
    engine_skipped = true
    skipped << "engine surface — cargo metadata could not resolve ironcalc_base"
    puts "  ✗ skipped: cargo metadata could not resolve ironcalc_base"
  end

  # --- 2. Doc stubs (native methods are invisible to YARD) -------------------
  section.call("Doc stubs (expect every native method documented, arities matching)")
  Parity::CLASSES.each do |name|
    mismatched, undocumented, stale = Parity.doc_gap(name, introspected[name])
    hard_gaps += mismatched.size + undocumented.size + stale.size
    list.call("#{name}: stub arity disagrees with the method", mismatched)
    list.call("#{name}: registered but has no @!method stub", undocumented)
    list.call("#{name}: stub for a method that no longer exists", stale)
    if (mismatched + undocumented + stale).empty?
      puts "  ✓ #{name}: #{Parity.doc_stubs(name).size} stubs, all present and matching"
    end
  end

  # Advisory: stubs with no prose, where Python has a description to borrow.
  py_desc = Parity.python_descriptions(Parity.python_sources(Parity.engine_version))
  Parity::CLASSES.each do |name|
    borrowable = Parity.undescribed_stubs(name).select { |m| py_desc.key?(m) }
    list.call("#{name}: no description, but Python documents it", borrowable)
  end

  # --- 3. Python bindings (advisory: never fall behind) ----------------------
  if (py = Parity.python_sources(Parity.engine_version))
    section.call("Python bindings v#{Parity.engine_version}")
    {
      "Model" => Parity.rust_impl_methods(py, "PyModel"),
      "UserModel" => Parity.rust_impl_methods(py, "PyUserModel"),
      "module" => py.flat_map { |p| Parity.rust_module_fns(p) }.uniq.sort
    }.each do |name, py_methods|
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
  else
    skipped << "Python bindings — no sdist for " \
               "#{Parity.engine_version || "the engine"} could be fetched from PyPI"
    puts "\n== Python bindings ==\n  ✗ skipped: PyPI sdist unavailable"
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
