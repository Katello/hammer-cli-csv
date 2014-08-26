$:.unshift(File.expand_path("../lib", __FILE__))

require 'hammer_cli_csv/version'

Gem::Specification.new do |spec|

  spec.name = "hammer_cli_csv"
  spec.version = HammerCLICsv.version
  spec.authors = ["Tom McKay"]
  spec.email = ["thomasmckay@redhat.com"]
  spec.homepage = "http://github.com/Katello/hammer-cli-csv"
  spec.license = "GPL-2"

  spec.platform = Gem::Platform::RUBY
  spec.summary = "CSV commands for Hammer"
  spec.description = "Hammer-CLI-CSV is a plugin for Hammer to provide bulk actions against a Katello server."

  spec.files = Dir["lib/**/*.rb"]
  spec.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  spec.require_paths = %w(lib)

  spec.add_dependency('hammer_cli_katello')

  spec.add_development_dependency("rubocop", "0.24.1")

end
