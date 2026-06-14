require_relative "lib/ironcalc/version"

Gem::Specification.new do |spec|
  spec.name          = "ironcalc"
  spec.version       = IronCalc::VERSION
  spec.summary       = "Create, edit and evaluate Excel spreadsheets"
  spec.description   = "Ruby bindings for the IronCalc spreadsheet engine. " \
    "Create, read and manipulate xlsx files: manage sheets, set and read cell " \
    "values, and evaluate spreadsheets."
  spec.homepage      = "https://github.com/ironcalc/ironcalc-ruby"
  spec.license       = "MIT OR Apache-2.0"

  spec.author        = "IronCalc"
  spec.email         = "nicolas@theuniverse.today"

  spec.metadata = {
    "homepage_uri" => "https://www.ironcalc.com/",
    "source_code_uri" => "https://github.com/ironcalc/ironcalc-ruby",
    "bug_tracker_uri" => "https://github.com/ironcalc/ironcalc-ruby/issues"
  }

  spec.files         = Dir["*.{md,txt}", "{ext,lib}/**/*", "Cargo.*", "LICENSE-*"]
    .reject { |f| f.match?(/\.(so|bundle|dll)$/) }
  spec.require_path  = "lib"
  spec.extensions    = ["ext/ironcalc/extconf.rb"]

  spec.required_ruby_version = ">= 3.0"

  spec.add_dependency "rb_sys"
end
