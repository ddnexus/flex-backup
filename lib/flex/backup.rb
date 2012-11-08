module Flex
  module Backup

    extend self

    include Flex::Loader

    flex.define_search :scan_all, <<-yaml
      query:
        match_all: {}
      yaml


    def dump_to_file(options)
      vars       = { :index => options[:index],
                     :type  => options[:type] }
      total_hits = flex.count_search(:scan_all, vars)['hits']['total']
      vars.merge :params => { :scroll => options[:scroll],
                              :size   => options[:size],
                              :fields => '_source,*' }
      total_count = 0
      pbar        = ProgBar.new(total_hits)
      dump_stats  = Hash.new { |hash, key| hash[key] = Hash.new { |h, k| h[k] = 0 } }
      file_size   = 0
      File.open(options[:file], 'wb') do |file|
        flex.scan_search(:scan_all, vars) do |result|
          lines = result['hits']['hits'].map do |h|
                    dump_stats[h['_index']][h['_type']] += 1
                    meta = { :_index => h['_index'],
                             :_type  => h['_type'],
                             :_id    => h['_id'] }
                    if h.has_key?('fields')
                      h['fields'].each do |k, v|
                        meta[k] = v if k[0] == '_'
                      end
                    end
                    [MultiJson.encode({ 'index' => meta }),
                     MultiJson.encode(h['_source'])].join("\n")
                  end
          file.puts lines.join("\n")
          total_count += lines.size
          pbar.pbar.inc(lines.size)
        end
        file_size = file.size
      end
      formatted_file_size = file_size.to_s.reverse.gsub(/...(?=.)/, '\&,').reverse
      pbar.pbar.finish
      puts "\n***** WARNING: Expected document to dump: #{total_hits}, dumped: #{total_count}. *****" \
           unless total_hits == total_count
      puts "\nDumped #{total_count} documents to #{options[:file]} (size: #{formatted_file_size} bytes)"
      puts dump_stats.to_yaml
    end

    def load_from_file(options)
      Configuration.http_client_options[:timeout] = options[:timeout]
      chunk_size = options[:batch_size] * 2 # 2 lines per doc
      lines      = ''
      line_count = 0
      file       = File.open(options[:file])
      file.lines { line_count += 1 }
      file.rewind
      pbar = ProgBar.new(line_count / 2, options[:batch_size])
      file.lines do |line|
        lines << line
        if file.lineno % chunk_size == 0
          result = Flex.bulk :lines => lines
          lines  = ''
          pbar.process_result(result, options[:batch_size])
        end
      end
      # last chunk
      unless lines == ''
        result = Flex.bulk :lines => lines
        pbar.process_result(result, (file.lineno % chunk_size) / 2)
      end
      file.close
      pbar.finish
    end

    def load_tasks
      load File.expand_path('../tasks.rb', __FILE__)
    end

  end
end
