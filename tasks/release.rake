# bundler/gem_tasks' `rake release` ends in `release:rubygem_push` (a local
# `gem push`). Here publishing is CI's job (release.yml, on tag push): a local
# push would publish an unsigned, source-only gem and claim the immutable
# version before CI's cross-compiled, signed gems land. So we no-op that step,
# leaving `rake release` to only build, guard-clean, tag, and push the tag —
# which triggers CI. Loads after bundler/gem_tasks, so the override wins.
if Rake::Task.task_defined?("release:rubygem_push")
  Rake::Task["release:rubygem_push"].clear

  namespace :release do
    desc "No-op: gems are published by CI on tag push, not from a workstation"
    task :rubygem_push do
      puts "Skipping local `gem push` — CI publishes all gems for the pushed tag."
    end
  end
end
