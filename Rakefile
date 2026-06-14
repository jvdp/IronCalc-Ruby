require "bundler/gem_tasks"
require "rake/testtask"
require "rb_sys/extensiontask"

Rake::TestTask.new do |t|
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: %i[compile test]

platforms = [
  "x86_64-linux",
  "x86_64-linux-musl",
  "aarch64-linux",
  "aarch64-linux-musl",
  "x86_64-darwin",
  "arm64-darwin",
  "x64-mingw-ucrt"
]

gemspec = Bundler.load_gemspec("ironcalc.gemspec")

# The Cargo package is `ironcalc_ruby` (not `ironcalc`): rb_sys resolves the
# extension by Cargo package name, and the engine dependency is itself named
# `ironcalc`. The gem and `require "ironcalc"` are unaffected.
RbSys::ExtensionTask.new("ironcalc_ruby", gemspec) do |ext|
  ext.lib_dir = "lib/ironcalc"
  ext.cross_compile = true
  ext.cross_platform = platforms
end

task :remove_ext do
  Dir["lib/ironcalc/ironcalc_ruby.{bundle,so}"].each { |path| File.unlink(path) }
end

Rake::Task["build"].enhance [:remove_ext]
