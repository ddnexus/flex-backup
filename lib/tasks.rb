option_keys = [:index, :type, :scroll, :size, :file, :timeout, :batch_size]
options     = { }

ENV.keys.map do |k|
  key = k.downcase.to_sym
  options[key] = ENV[k] if option_keys.include?(key)
end

env = defined?(Rails) ? :environment : []

namespace :flex do

  desc 'Dumps the data from one or more ElasticSearch indices to a file'
  task(:dump => env) do
    Flex::Backup.dump_to_file(options)
  end

  desc 'Loads a dumpfile into ElasticSearch'
  task(:load => env) do
    Flex::Backup.load_from_file(options)
  end

end
