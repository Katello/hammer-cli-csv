$:.unshift(File.expand_path("../lib", __FILE__))

require 'hammer_cli_csv/version'

Gem::Specification.new do |spec|
  spec.name = "hammer_cli_csv"
  spec.version = HammerCLICsv.version
  spec.authors = ["@thomasmckay"]
  spec.email = ["thomasmckay@redhat.com"]

  spec.platform = Gem::Platform::RUBY
  spec.summary = "Csv commands for Hammer"
  spec.description = "Hammer-CLI-CSV is a plugin for Hammer to provide bulk actions against a Katello server."

  spec.files = Dir["lib/**/*.rb"]
  spec.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")

  spec.add_dependency("hammer_cli", ">= 0.0.9")
  spec.add_dependency("katello_api", "= 0.0.4")
  spec.add_dependency("foreman_api", '= 0.1.8')
end
