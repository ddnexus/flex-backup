require 'flex'
require 'flex-backup'

env = defined?(Rails) ? :environment : []

namespace :flex do
  namespace :backup do

    desc 'Dumps the data from one or more ElasticSearch indices to a file'
    task(:dump => env) { Flex::Backup::Tasks.new.dump_to_file }

    desc 'Loads a dumpfile into ElasticSearch'
    task(:load => env) { Flex::Backup::Tasks.new.load_from_file }

  end

end
