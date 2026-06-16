# `rake parity` — checks the Ruby binding's API surface against:
#
#   1. The Python bindings (authoritative for the "mirror Python" principle).
#      - Model        : must match PyModel exactly (modulo allowlisted internals).
#      - UserModel    : must be a SUPERSET of PyUserModel (we deliberately enrich it).
#      - module fns   : must match the Python module functions.
#      Needs an IronCalc checkout; set IRONCALC_REPO (defaults to /home/code/IronCalc).
#      Advisory only: the checkout is HEAD, not pinned to our engine version.
#
#   2. The engine's UserModel (the canonical/WASM surface), pinned to the exact
#      `ironcalc_base` version we build against (resolved from the Cargo registry).
#      Advisory: reports engine UserModel methods we don't expose yet, minus an
#      allowlist of intentionally-unexposed UI/internal methods.
#
# Method sets for the Ruby side come from runtime introspection (so they include
# both Rust-defined methods and the Ruby-layer wrappers). Rust/Python sides are
# extracted by scanning `pub fn` inside the relevant `impl` blocks.
#
# Exit status: non-zero only on hard Python-parity gaps (and only when STRICT=1),
# so it can gate CI without failing on advisory drift.

require "json"
require "open3"

module Parity
  PYTHON_REPO = ENV.fetch("IRONCALC_REPO", "/home/code/IronCalc")

  # Ruby methods that have no Python counterpart by design.
  RUBY_MODEL_INTERNAL = %w[get_cell_style_json set_cell_style_json].freeze
  # Ruby UserModel adds these on top of the engine names (rename map: ruby => engine).
  USERMODEL_RENAMES = {
    "set_column_width" => "set_columns_width",
    "set_row_height" => "set_rows_height",
    "clear_cell_contents" => "range_clear_contents",
  }.freeze
  # Ruby UserModel-only internals (JSON style accessor) with no engine equivalent name.
  USERMODEL_INTERNAL = %w[get_cell_style_json].freeze

  # Engine UserModel methods we intentionally do NOT expose (UI/selection/clipboard/
  # locale/defined-names/etc., plus constructors handled at module level). Patterns
  # keep this terse; anything not matched and not exposed is a real candidate.
  ENGINE_OMIT_EXACT = %w[
    from_model new_empty from_bytes get_model get_name set_name
    pause_evaluation resume_evaluation range_clear_all range_clear_formatting
    on_paste_styles set_area_with_border get_fmt_settings set_top_left_visible_cell
    get_last_non_empty_in_row_before_column get_first_non_empty_in_row_after_column
  ].freeze
  ENGINE_OMIT_PATTERNS = [
    /\Aon_/, /\Aget_selected_/, /\Aset_selected_/, /\Aget_scroll_/,
    /window/, /clipboard/, /defined_name/, /\Aauto_fill_/, /\Apaste_/,
    /\Amove_.*_action\z/, /grid_lines/, /timezone/, /locale/, /language/,
    /hide_sheet/, /can_(undo|redo)/,
  ].freeze

  module_function

  def ruby_api
    out, status = Open3.capture2(
      RbConfig.ruby, "-Ilib", "-e",
      'require "ironcalc"; require "json";' \
      'puts JSON.generate({' \
      '  "Model" => IronCalc::Model.instance_methods(false).map(&:to_s),' \
      '  "UserModel" => IronCalc::UserModel.instance_methods(false).map(&:to_s),' \
      '  "module" => IronCalc.singleton_methods(false).map(&:to_s),' \
      '})'
    )
    raise "could not introspect Ruby API (is the extension compiled? run `rake compile`)" unless status.success?

    JSON.parse(out).transform_values { |v| v.sort.uniq }
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

  def engine_base_src
    out, status = Open3.capture2("cargo", "metadata", "--format-version", "1")
    return nil unless status.success?

    pkg = JSON.parse(out)["packages"].find { |p| p["name"] == "ironcalc_base" }
    pkg && File.join(File.dirname(pkg["manifest_path"]), "src")
  rescue StandardError
    nil
  end

  def python_lib_rs
    path = File.join(PYTHON_REPO, "bindings", "python", "src", "lib.rs")
    File.exist?(path) ? path : nil
  end
end

desc "Check Ruby API parity against the Python bindings and the engine UserModel"
task :parity do
  ruby = Parity.ruby_api
  hard_gaps = 0

  section = ->(title) { puts "\n== #{title} ==" }
  list = lambda do |label, items|
    return if items.empty?

    puts "  #{label}:"
    items.sort.each { |m| puts "    - #{m}" }
  end

  # --- 1. Python parity (authoritative) -------------------------------------
  if (py = Parity.python_lib_rs)
    py_model     = Parity.rust_impl_methods([py], "PyModel")
    py_usermodel = Parity.rust_impl_methods([py], "PyUserModel")
    py_module    = Parity.rust_module_fns(py)

    section.call("Python parity — Model (expect exact match)")
    missing = py_model - ruby["Model"]
    extra   = ruby["Model"] - py_model - Parity::RUBY_MODEL_INTERNAL
    hard_gaps += missing.size
    list.call("in PyModel, MISSING from Ruby Model", missing)
    list.call("in Ruby Model, not in PyModel (review)", extra)
    puts "  ✓ Model matches PyModel (#{py_model.size} methods)" if missing.empty? && extra.empty?

    section.call("Python parity — UserModel (expect Ruby ⊇ PyUserModel)")
    missing = py_usermodel - ruby["UserModel"]
    hard_gaps += missing.size
    list.call("in PyUserModel, MISSING from Ruby UserModel", missing)
    puts "  ✓ Ruby UserModel is a superset of PyUserModel " \
         "(+#{(ruby['UserModel'] - py_usermodel).size} enriched methods)" if missing.empty?

    section.call("Python parity — module functions (expect exact match)")
    missing = py_module - ruby["module"]
    extra   = ruby["module"] - py_module
    hard_gaps += missing.size
    list.call("in Python module, MISSING from Ruby", missing)
    list.call("in Ruby module, not in Python (review)", extra)
    puts "  ✓ module functions match (#{py_module.size})" if missing.empty? && extra.empty?
  else
    puts "\n(Python bindings not found at #{Parity::PYTHON_REPO}; " \
         "set IRONCALC_REPO to enable Python-parity checks.)"
  end

  # --- 2. Engine UserModel drift (advisory) ---------------------------------
  section.call("Engine UserModel drift (advisory, version-pinned)")
  if (src = Parity.engine_base_src)
    files = Dir[File.join(src, "user_model", "*.rs")]
    engine = Parity.rust_impl_methods(files, "UserModel")
    exposed = ruby["UserModel"].map { |m| Parity::USERMODEL_RENAMES.fetch(m, m) } +
              Parity::USERMODEL_INTERNAL
    candidates = engine - exposed - Parity::ENGINE_OMIT_EXACT
    candidates = candidates.reject { |m| Parity::ENGINE_OMIT_PATTERNS.any? { |re| m =~ re } }
    if candidates.empty?
      puts "  ✓ Ruby UserModel exposes every non-omitted engine UserModel method " \
           "(#{engine.size} engine methods scanned)"
    else
      list.call("engine UserModel methods NOT exposed in Ruby (consider adding)", candidates)
    end
  else
    puts "  (could not resolve ironcalc_base source via cargo metadata)"
  end

  puts "\n#{'-' * 60}"
  if hard_gaps.zero?
    puts "Parity OK: no Python-parity gaps."
  else
    puts "Parity: #{hard_gaps} hard Python-parity gap(s) above."
    abort("FAILED (STRICT=1)") if ENV["STRICT"] == "1"
  end
end
