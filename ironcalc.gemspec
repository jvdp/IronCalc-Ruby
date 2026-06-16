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
  spec.homepage      = "https://github.com/jvdp/IronCalc-Ruby"
  spec.license       = "MIT OR Apache-2.0"

  spec.author        = "jvdp"
  spec.email         = "jaap@vage-ideeen.nl"

  spec.metadata = {
    "homepage_uri" => "https://www.ironcalc.com/",
    "source_code_uri" => "https://github.com/jvdp/IronCalc-Ruby",
    "bug_tracker_uri" => "https://github.com/jvdp/IronCalc-Ruby/issues"
  }

  spec.files         = Dir["*.{md,txt}", "{ext,lib}/**/*", "Cargo.*", "LICENSE-*"]
    .reject { |f| f.match?(/\.(so|bundle|dll)$/) }
  spec.require_path  = "lib"
  spec.extensions    = ["ext/ironcalc/extconf.rb"]

  spec.required_ruby_version = ">= 3.0"

  # Drives the Rust build at install time. Precompiled platform gems built by
  # the release workflow ship the .so directly and clear `spec.extensions`, so
  # they never compile and this dependency is inert for those users.
  spec.add_dependency "rb_sys", "~> 0.9"
end
