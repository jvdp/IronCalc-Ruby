require_relative "ironcalc/version"

# Load the compiled native extension. Built gems place the shared library under
# a Ruby-version subdirectory; a locally compiled one sits directly in lib.
begin
  require "ironcalc/#{RUBY_VERSION.to_f}/ironcalc_ruby"
rescue LoadError
  require "ironcalc/ironcalc_ruby"
end

require_relative "ironcalc/model"
