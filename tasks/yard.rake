# `rake doc` — generate HTML API docs into doc/ via YARD (config in .yardopts).
# YARD is a dev dependency, so guard the task so the Rakefile loads without it.
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
