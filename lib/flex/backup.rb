module Flex
  module Backup

    extend self

    include Templates

    flex.define_search :scan_all, <<-yaml
      query:
        match_all: {}
      yaml

    class Tasks

      attr_reader :options

      def initialize(overrides={})
        options = Flex::Utils.env2options *default_options.keys

        options[:size]       = options[:size].to_i       if options[:size]
        options[:timeout]    = options[:timeout].to_i    if options[:timeout]
        options[:batch_size] = options[:batch_size].to_i if options[:batch_size]

        @options = default_options.merge(options).merge(overrides)
      end

      def default_options
        @default_options ||= { :file       => './flex-backup.dump',
                               :index      => Conf.variables[:index],
                               :type       => Conf.variables[:type],
                               :scroll     => '5m',
                               :size       => 50,
                               :timeout    => 20,
                               :batch_size => 1000,
                               :verbose    => true }
      end

      def dump_to_file
        vars = { :index => options[:index],
                 :type  => options[:type] }
        if options[:verbose]
          total_hits  = Backup.flex.count_search(:scan_all, vars)['hits']['total']
          total_count = 0
          pbar        = ProgBar.new(total_hits)
          dump_stats  = Hash.new { |hash, key| hash[key] = Hash.new { |h, k| h[k] = 0 } }
          file_size   = 0
        end
        vars.merge! :params => { :scroll => options[:scroll],
                                 :size   => options[:size],
                                 :fields => '_source,*' }

        file = options[:file].is_a?(String) ? File.open(options[:file], 'wb') : options[:file]
        path = file.path

        Backup.flex.scan_search(:scan_all, vars) do |result|
          lines = result['hits']['hits'].map do |h|
                    dump_stats[h['_index']][h['_type']] += 1 if options[:verbose]
                    meta = { :_index => h['_index'],
                             :_type  => h['_type'],
                             :_id    => h['_id'] }
                    if h.has_key?('fields')
                      h['fields'].each do |k, v|
                        meta[k] = v if k[0] == '_'
                      end
                    end
                    [ MultiJson.encode({ 'index' => meta }),
                      MultiJson.encode(h['_source']) ].join("\n")
                  end
          file.puts lines.join("\n")
          if options[:verbose]
            total_count += lines.size
            pbar.pbar.inc(lines.size)
          end
        end
        file_size = file.size if options[:verbose]
        file.close

        if options[:verbose]
          formatted_file_size = file_size.to_s.reverse.gsub(/...(?=.)/, '\&,').reverse
          pbar.pbar.finish
          puts "\n***** WARNING: Expected document to dump: #{total_hits}, dumped: #{total_count}. *****" \
               unless total_hits == total_count
          puts "\nDumped #{total_count} documents to #{path} (size: #{formatted_file_size} bytes)"
          puts dump_stats.to_yaml
        end
      end

      def load_from_file
        Configuration.http_client.options[:timeout] = options[:timeout]
        chunk_size = options[:batch_size] * 2 # 2 lines per doc
        lines      = ''
        file       = options[:file].is_a?(String) ? File.open(options[:file]) : options[:file]
        path       = file.path
        if options[:verbose]
          line_count = 0
          file.lines { line_count += 1 }
          file.rewind
          puts "\nLoading from #{path}...\n"
          pbar = ProgBar.new(line_count / 2, options[:batch_size])
        end
        file.lines do |line|
          lines << line
          if file.lineno % chunk_size == 0
            result = Flex.bulk :lines => lines
            lines  = ''
            pbar.process_result(result, options[:batch_size]) if options[:verbose]
          end
        end
        # last chunk
        unless lines == ''
          result = Flex.bulk :lines => lines
          pbar.process_result(result, (file.lineno % chunk_size) / 2) if options[:verbose]
        end
        file.close
        pbar.finish if options[:verbose]
      end

    end
  end
end
