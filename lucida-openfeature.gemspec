# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = "lucida-openfeature"
  s.version = "0.1.0"
  s.summary = "OpenFeature server provider for Lucida"
  s.license = "Apache-2.0"
  s.homepage = "https://github.com/lucidaanalytics/lucida-ruby-openfeature"
  s.metadata = { "source_code_uri" => "https://github.com/lucidaanalytics/lucida-ruby-openfeature", "rubygems_mfa_required" => "true" }
  s.authors = ["Lucida"]
  s.required_ruby_version = ">= 3.1"
  s.files = Dir["lib/**/*.rb"]
  s.add_dependency "lucida", "~> 0.1"
  s.add_dependency "openfeature-sdk", "~> 0.4" # Apache-2.0
end
