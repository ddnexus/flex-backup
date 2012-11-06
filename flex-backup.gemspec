require 'date'

Gem::Specification.new do |s|
  s.name                      = 'flex-backup'
  s.summary                   = 'Backup CLI to dump/load data from/to ElasticSearch'
  s.description               = 'Simple tool to dump/load one or more ElasticSearch indices and types'
  s.homepage                  = 'http://github.com/ddnexus/flex-backup'
  s.authors                   = ["Domizio Demichelis"]
  s.email                     = 'dd.nexus@gmail.com'
  s.executables               = %w[flex-backup]
  s.extra_rdoc_files          = %w[README.md]
  s.files                     = `git ls-files -z`.split("\0")
  s.version                   = File.read(File.expand_path('../VERSION', __FILE__)).strip
  s.date                      = Date.today.to_s
  s.required_rubygems_version = ">= 1.3.6"
  s.rdoc_options              = %w[--charset=UTF-8]

  s.add_runtime_dependency 'flex', '>= 0.5.0'
end
