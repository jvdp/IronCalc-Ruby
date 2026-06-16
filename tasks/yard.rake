# `rake doc` — generates HTML API docs into doc/ using YARD (config in .yardopts).
# This is what rubydoc.info builds from once the gem is published; the output can
# later be copied to ironcalc.dev. YARD is a development dependency, so guard the
# task so the Rakefile still loads without it installed.
begin
  require "yard"

  YARD::Rake::YardocTask.new(:doc) do |t|
    t.stats_options = ["--list-undoc"]
  end
rescue LoadError
  desc "Generate API docs (install the `yard` gem first)"
  task :doc do
    abort "YARD is not available. Add it to the Gemfile (group :development) and `bundle install`."
  end
end
