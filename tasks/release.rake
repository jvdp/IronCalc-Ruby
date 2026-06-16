# `rake release` comes from bundler/gem_tasks (required in the Rakefile) and
# expands to:
#   build → release:guard_clean → release:source_control_push → release:rubygem_push
#
# In this repo, publishing is done by CI (.github/workflows/release.yml) on tag
# push: it cross-compiles the precompiled platform gems and pushes everything
# via Trusted Publishing (with SigStore provenance). A local `gem push` would
# instead publish an unsigned, source-only gem AND claim the (immutable)
# version before CI can — racing the workflow. So we keep the tag/push half and
# turn the publish step into a no-op.
#
# Net: `rake release` tags `v#{VERSION}`, pushes branch + tag (triggering CI),
# and stops. This file loads after bundler/gem_tasks, so the override sticks.
if Rake::Task.task_defined?("release:rubygem_push")
  Rake::Task["release:rubygem_push"].clear

  namespace :release do
    desc "No-op: gems are published by CI on tag push, not from a workstation"
    task :rubygem_push do
      puts "Skipping local `gem push` — CI publishes all gems for the pushed tag."
    end
  end
end
