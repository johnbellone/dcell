require 'uri'
require 'etcd'

module DCell
  module Registry
    class EtcdAdapter
      PREFIX = '/dcell'
      DEFAULT_SCHEME = 'http'
      DEFAULT_PORT   = 4001

      # Create a new connect to Etc daemon.
      #
      # servers: List of Etcd servers to connect to. Each server
      # has a host/port configuration.
      def initialize(options={})
        options = options.inject({}) { |h,(k,v)| h[k.to_s] = v; h }

        @env = options['env'] || 'production'
        @base_path = "#{PREFIX}/#{@env}"

        if options['server']
          servers = [ options['server'] ]
        else
          servers = options['servers']
        end

        # Sanity check.
        raise 'no Etcd servers given' unless servers

        # Add default Etcd port unless specified.
        servers.map! do |server|
          server = server.is_a?(URI) ? server : URI(server)
          if server.scheme && server.host && server.port
            server
          else
            server = URI("#{DEFAULT_SCHEME}://#{server.to_s}:#{DEFAULT_PORT}")
          end
        end

        server = servers[rand(servers.count)]
        @etcd = Etcd.client(host: server.host,
          port: server.port,
          use_ssl: server.scheme == 'https' ? true : false,
          user_name: server.user,
          password: server.password)

        @node_registry = Registry.new(@etcd, @base_path, :nodes)
        @global_registry = Registry.new(@etcd, @base_path, :globals)
      end

      def get_node(node_id);       @node_registry.get(node_id) end
      def set_node(node_id, addr); @node_registry.set(node_id, addr) end
      def nodes;                   @node_registry.all end
      def clear_nodes;             @node_registry.clear end

      def get_global(key);        @global_registry.get(key) end
      def set_global(key, value); @global_registry.set(key, value) end
      def global_keys;            @global_registry.all end
      def clear_globals;          @global_registry.clear end

      class Registry
        def initialize(etcd, base_path, name)
          @etcd = etcd
          @base_path = File.join(base_path, name.to_s)
          unless @etcd.exists?(@base_path)
            @etcd.create(@base_path, dir: true)
          end
        end

        def get(key)
          result = @etcd.get(File.join(base_path, key))
          Marshal.load(result.value) if result
        end

        def set(key, value)
          path = File.join @base_path, key
          string = Marshal.dump(value)
          @etcd.set(path, value: string)
        rescue Etcd::NodeExist
          @etcd.update(path, value: string)
        end

        def all
          @etcd.get(@base_path).children
        end

        def clear
          @etcd.delete(@base_path)
          @etcd.create(@base_path, dir: true)
        end
      end
    end
  end
end
