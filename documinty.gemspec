# frozen_string_literal: true

require_relative "lib/documinty/version"

Gem::Specification.new do |spec|
  spec.name          = "documinty"
  spec.version       = Documinty::VERSION
  spec.authors       = ["Marcel Carrero Pedre"]
  spec.email         = ["marcel.pedre001@outlook.com"]

  spec.summary       = "A codebase auto documentation tool."
  spec.description   = "This gem will enable developers to document their classes and features"
  spec.homepage      = "https://github.com/BatouGlitch/documinty"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  # Metadata URIs
  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Dependencies
  spec.add_runtime_dependency "thor", "~> 1.2"
  spec.add_development_dependency "rspec", "~> 3.0"

  # Files to include in the gem
  spec.files = Dir.chdir(__dir__) do
    Dir[
      "exe/*",
      "lib/documinty.rb",
      "lib/documinty/*.rb",
      "README.md",
      "LICENSE.txt",
      "CHANGELOG.md",
      "CODE_OF_CONDUCT.md"
    ]
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
