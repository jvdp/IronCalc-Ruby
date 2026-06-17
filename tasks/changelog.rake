# `rake changelog:*` — helpers around CHANGELOG.md (Keep a Changelog format).
# Pure git + file reads, no gems or network, so they run offline and in CI.
# See each task's `desc` below.

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
