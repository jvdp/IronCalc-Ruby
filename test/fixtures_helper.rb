# Resolves the IronCalc engine's own xlsx test fixtures, which ship inside the
# published `ironcalc` crate and are downloaded into the Cargo registry as part
# of building this extension. We do NOT vendor copies: resolving them from the
# dependency means the fixtures are always pinned to the exact engine version we
# build against (see Cargo.toml `xlsx = { package = "ironcalc", ... }`), so they
# move in lockstep on a dependency bump instead of drifting.
#
# The location is `<crate source>/tests`, found via `cargo metadata` (the
# registry path contains a version- and hash-specific component, so it must not
# be hard-coded). If the crate source can't be found (e.g. `cargo` unavailable or
# the registry not yet populated), `dir` returns nil and the fixture-backed tests
# skip with an explanatory message rather than failing.
require "json"
require "open3"

module FixturesHelper
  REPO_ROOT = File.expand_path("..", __dir__)

  class << self
    # Absolute path to the engine crate's `tests` directory, or nil if unresolved.
    def dir
      return @dir if defined?(@dir)
      @dir = resolve_dir
    end

    # Path to a fixture under the engine crate's tests dir, e.g.
    # fixture("calc_tests", "PMT.xlsx"). nil if the fixtures aren't available.
    def fixture(*parts)
      d = dir or return nil
      File.join(d, *parts)
    end

    # All calc_tests/*.xlsx fixtures (the formula suite), excluding the
    # `.disabled` files the engine intentionally turns off. [] if unavailable.
    def calc_test_files
      d = dir or return []
      Dir[File.join(d, "calc_tests", "*.xlsx")].sort
    end

    private

    def resolve_dir
      manifest = ironcalc_manifest_path or return nil
      tests = File.join(File.dirname(manifest), "tests")
      File.directory?(tests) ? tests : nil
    end

    def ironcalc_manifest_path
      # Full dep graph (not --no-deps): the engine is a dependency, not a
      # workspace member, so it only appears with deps resolved.
      out, = Open3.capture2(
        "cargo", "metadata", "--format-version", "1", chdir: REPO_ROOT
      )
      pkg = find_ironcalc(out)
      pkg && pkg["manifest_path"]
    rescue StandardError
      nil
    end

    def find_ironcalc(metadata_json)
      JSON.parse(metadata_json)["packages"].find { |p| p["name"] == "ironcalc" }
    rescue StandardError
      nil
    end
  end
end
