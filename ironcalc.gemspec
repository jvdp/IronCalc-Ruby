require_relative "lib/ironcalc/version"

Gem::Specification.new do |spec|
  spec.name          = "ironcalc"
  spec.version       = IronCalc::VERSION
  spec.summary       = "Create, edit and evaluate Excel spreadsheets"
  spec.description   = <<~DESC
    Ruby bindings for the IronCalc spreadsheet engine. Create, read and
    manipulate xlsx files: manage sheets, set and read cell values, and
    evaluate formulas.
  DESC
  spec.homepage      = "https://www.ironcalc.com/"
  spec.licenses      = ["MIT", "Apache-2.0"]

  spec.author        = "jvdp"
  spec.email         = "jaap@vage-ideeen.nl"

  spec.metadata = {
    "source_code_uri" => "https://github.com/jvdp/IronCalc-Ruby",
    "bug_tracker_uri" => "https://github.com/jvdp/IronCalc-Ruby/issues",
    "changelog_uri" => "https://github.com/jvdp/IronCalc-Ruby/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://www.rubydoc.info/gems/ironcalc/",
    "rubygems_mfa_required" => "true"
  }

  spec.files         = Dir["*.{md,txt}", "{ext,lib}/**/*", "Cargo.*", "LICENSE-*", ".yardopts"]
    .reject { |f| f.match?(/\.(so|bundle|dll)$/) }
  spec.require_path  = "lib"
  spec.extensions    = ["ext/ironcalc/extconf.rb"]

  spec.required_ruby_version = ">= 3.0"

  # Builds the Rust extension at install time. Precompiled platform gems ship
  # the .so and clear `spec.extensions`, so this never runs for those users.
  spec.add_dependency "rb_sys", "~> 0.9"
end
