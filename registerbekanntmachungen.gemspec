# frozen_string_literal: true

require_relative "lib/registerbekanntmachungen/version"

Gem::Specification.new do |spec|
  spec.name = "registerbekanntmachungen"
  spec.version = Registerbekanntmachungen::VERSION
  spec.authors = ["Christopher Oezbek"]
  spec.email = ["c.oezbek@gmail.com"]

  spec.summary = "Webscraper for the German Handelsregister Registerbekanntmachungen"
  spec.description = "A simple/polite webscraper for the German Handelsregister Registerbekanntmachungen using Ruby with Watir."
  spec.homepage = "https://github.com/coezbek/registerbekanntmachungen"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/coezbek/registerbekanntmachungen"
  spec.metadata["changelog_uri"] = "https://github.com/coezbek/registerbekanntmachungen/README.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Browser automation
  spec.add_development_dependency "watir", "~> 7.3"
  spec.add_development_dependency "webdrivers", "~> 5.3"
  # ANSI colors
  spec.add_development_dependency "colorize", "~> 1.1"
  # HTML parsing
  spec.add_development_dependency "nokogiri", "~> 1.16"
end
