# `rake changelog:*` — small helpers around CHANGELOG.md (Keep a Changelog style:
# https://keepachangelog.com). No external gems or API calls — just git + the
# file — so it works offline and in CI.
#
#   changelog:check       guard that IronCalc::VERSION has a non-empty section.
#                         Cheap release preflight; wire it before tagging.
#   changelog:unreleased  scaffold bullets from commits since the last v* tag,
#                         to paste under a new heading (the git-cliff idea, kept
#                         dependency-free and non-magical).
#   changelog:extract     print one version's section (default: current), e.g.
#                         for GitHub release notes: `rake changelog:extract`.

require_relative "../lib/ironcalc/version"

module Changelog
  PATH = File.expand_path("../CHANGELOG.md", __dir__)

  module_function

  # => { "0.7.1.1" => "- Fix build…\n", ... }, preserving file order.
  def sections
    body = File.read(PATH)
    parts = body.split(/^## +/)[1..] || []
    parts.each_with_object({}) do |part, acc|
      heading, _, rest = part.partition("\n")
      version = heading.strip[/\A\S+/] # first token: "0.7.1.1" from "0.7.1.1 (2026-…)"
      acc[version] = rest.strip if version
    end
  end

  def last_tag
    tag = `git tag --sort=-v:refname --list 'v*'`.each_line.first
    tag&.strip
  end

  def commits_since(ref)
    range = ref ? "#{ref}..HEAD" : "HEAD"
    # --no-merges keeps merge commits out; %s is the subject line.
    `git log #{range} --no-merges --pretty=format:'- %s'`.strip
  end
end

namespace :changelog do
  desc "Verify the current version (#{IronCalc::VERSION}) has a CHANGELOG entry"
  task :check do
    version = IronCalc::VERSION
    entry = Changelog.sections[version]
    if entry.nil?
      abort "CHANGELOG.md has no `## #{version}` section. Add one before releasing."
    elsif entry.empty?
      abort "CHANGELOG.md `## #{version}` section is empty. Describe the changes before releasing."
    else
      puts "OK: CHANGELOG.md documents #{version}."
    end
  end

  desc "List commits since the last tag as draft changelog bullets"
  task :unreleased do
    tag = Changelog.last_tag
    bullets = Changelog.commits_since(tag)
    puts "## #{IronCalc::VERSION}\n\n"
    if bullets.empty?
      puts "_(no commits since #{tag || 'repo start'})_"
    else
      puts bullets
    end
    warn "\n# ^ commits since #{tag || 'repo start'} — edit, then paste into CHANGELOG.md"
  end

  desc "Print one version's section (VERSION=x.y.z, default current) for release notes"
  task :extract do
    version = ENV.fetch("VERSION", IronCalc::VERSION)
    entry = Changelog.sections[version]
    abort "No `## #{version}` section in CHANGELOG.md." if entry.nil? || entry.empty?
    puts entry
  end
end
