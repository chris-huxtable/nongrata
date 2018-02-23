# Copyright (c) 2018 Christian Huxtable <chris@huxtable.ca>.
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

require "option_parser"
require "yaml"

require "ch_socket/ip/address"
require "ch_socket/ip/block"

require "pledge"
require "restrict"

require "./nongrata/*"

module NonGrata

	USER = "daemon"
	GROUP = "daemon"
	EMPTY = "/var/empty"

	@@config_path : String = "/etc/nongrata.yaml"
	@@silent : Bool = false
	@@lists : Hash(String, List) = Hash(String, List).new()

	if ( !Process.root? )
		puts "Requires user to be root."
		exit 1
	end

	{% if flag?(:openbsd) %}
		#Process.pledge(:stdio, :rpath, :wpath, :cpath, :flock, :unix, :dns, :getpw, :proc, :id)
	{% end %}

	process_args()
	process_config()
	process_lists()


	# MARK: - Process Arguements

	protected def self.process_args()
		config_path = @@config_path

		OptionParser.parse! { |parser|
			parser.banner = "Usage: logsite [arguments]"
			parser.on("-f file", "Specifies the configuration file. The default is #{config_path}.") { |file| config_path = file }
			parser.on("-s", "silences the applications output. Useful for cron.") { @@silent = true }
			parser.on("-h", "--help", "Show this help") { puts parser }
		}

		raise "Configuration does not exist." if ( !config_path || config_path.empty? || !File.exists?(config_path) )
		@@config_path = config_path
	end


	# MARK: - Process Configuration

	def self.process_config()
		config = YAML.parse_file(@@config_path)
		lists = config.as_h?
		raise "Configuration has errors." if ( !lists )

		lists.each() { |key, value|
			key = YAML::Any.new(key).to_s
			next if key == "user" || key == "group"

			value = List.from_yaml(key, YAML::Any.new(value))
			raise "Configuration has errors. No list" if ( !value )
			@@lists[key] = value
		}
	end


	# MARK: - Process Lists

	def self.process_lists()
		@@lists.each{ |key, list| process_list(list) }
	end

	protected def self.process_list(list : List)
		dir = File.dirname(list.output)
		Dir.mkdir_p(dir) if ( !File.exists?(dir) )

		puts "#{list.label}"
		puts "  Acquiring:"
		list.acquire() { |source| puts "    - #{source.label}" }

		File.open(list.output, "w+") { |fd|
			Process.restrict(EMPTY, USER, GROUP) {

				{% if flag?(:openbsd) %}
					Process.pledge(:stdio)
				{% end %}

				puts "  Processing..."
				list.process()

				puts "  Reducing..."
				list.reduce()

				puts "  Counts:"
				puts "    - #{list.addresses.size} addresses"
				puts "    - #{list.blocks.size} blocks"
				puts "    - #{list.reject_count} rejects"

				puts "  Writing:"
				success = list.write(fd)
				if success
					puts "    - Wrote Results: #{list.output}"
				else
					puts "    - Unchanged: #{list.output}"
				end
				puts
			}
		}
	end


	# MARK: - Properties

	class_property silent : Bool
	class_property config_path : String


	# MARK: - Tools

	def self.puts(*string)
		return if ( @@silent )
		STDOUT.puts(*string)
	end

end
