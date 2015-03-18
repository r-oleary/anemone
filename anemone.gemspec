spec = Gem::Specification.new do |s|
  s.name = "anemone"
  s.version = "0.8.1"
  s.author = ["Chris Kite", "Pheonix7284"]
  s.homepage = "https://github.com/Pheonix7284/anemone"
  s.rubyforge_project = "anemone"
  s.platform = Gem::Platform::RUBY
  s.summary = "Anemone web-spider framework"
  s.executables = %w[anemone]
  s.require_path = "lib"
  s.has_rdoc = true
  s.rdoc_options << '-m' << 'README.rdoc' << '-t' << 'Anemone'
  s.extra_rdoc_files = ["README.rdoc"]
  s.add_dependency("nokogiri", ">= 1.6.6.2")
  s.add_dependency("robotex", ">= 1.0.0")

  s.add_development_dependency "rake", ">=10.4.2"
  s.add_development_dependency "rdoc", ">=4.2.0"
  s.add_development_dependency "rspec", ">=3.2.0"
  s.add_development_dependency "fakeweb", ">=1.3.0"
  s.add_development_dependency "redis", ">=3.2.1"
  s.add_development_dependency "mongo", ">=1.12.0"
  s.add_development_dependency "bson_ext", ">=1.3.1"
  s.add_development_dependency "sqlite3", ">=1.3.10"
  s.add_development_dependency "pry-rails"
  #outdated/incompatible with ruby 2.2.0 gems
  #s.add_development_dependency "tokyocabinet", ">=1.29"
  #s.add_development_dependency "kyotocabinet-ruby", ">=1.27.1"

  s.files = %w[
    VERSION
    LICENSE.txt
    CHANGELOG.rdoc
    README.rdoc
    CONTRIBUTORS.rdoc
    Rakefile
  ] + Dir['lib/**/*.rb']

  s.test_files = Dir['spec/*.rb']
end
