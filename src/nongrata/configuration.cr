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
require "config"

require "user_group"


class NonGrata::Configuration

	{% begin %}
		BUILD = {{ `git log --pretty=format:'%H' -n 1`.stringify }}.chomp
		VERSION = {{ `git describe --abbrev=0 --tags`.stringify }}.chomp
	{% end %}

	USER = System::User.get("daemon")
	GROUP = System::Group.get("daemon")
	EMPTY = "/var/empty"


	# MARK: - Default Configuration

	@@default : self?

	def self.default() : self
		default = @@default
		return default if default

		default = new()
		@@default = default
		return default
	end

	@path : String = "/etc/nongrata.conf"
	@lists : Hash(String, List) = Hash(String, List).new()

	@cron : Bool = false
	@verbose : Bool = false


	# MARK: - Initialization

	def initialize()

		OptionParser.parse! { |parser|
			parser.banner = "Usage: nongrata [arguments]"
			parser.on("-f file", "Specifies the configuration file. The default is #{@path}.") { |file| @path = file }
			parser.on("-c", "--cron", "Silences the applications output unless there is an error. Useful for cron.") { @cron = true }
			parser.on("-v", "--version", "Show the version number.") {
				Console.line("Nongrata", Configuration.version_string)
				exit(0)
			}
			parser.on("-h", "--help", "Show this help.") {
				Console.line(parser)
				exit(0)
			}
		}

		raise "Configuration does not exist." if ( !@path || @path.empty? || !File.exists?(@path) )

		config = Config.file(@path)

		lists = config.as_h?
		raise "Configuration has errors." if ( !lists )

		lists.each() { |key, value|
			next if ( key == "user" || key == "group" )
			value = List.from_config(key, value)
			raise "Configuration has errors. No list" if ( !value )
			@lists[key] = value
		}

	end


	# MARK: - Properties

	getter path : String
	getter lists : Hash(String, List)

	getter? cron : Bool
	getter? verbose : Bool

	def user() : System::User
		return USER
	end

	def group() : System::Group
		return GROUP
	end

	def empty_dir() : String
		return EMPTY
	end


	# MARK: - Versioning

	def self.version_string() : String
		return String.build() { |io| version_string(io) }
	end

	def self.version_string(io : IO)
		io << VERSION
		io << " (" << BUILD[0..7] << ')'
	end

end


class NonGrata::List

	def self.from_config(label : String, config : Config::Any) : self?

		# Output
		tmp = config.as_s?("output")
		return nil if ( !tmp || tmp.empty? )
		output = File.expand_path(tmp)

		list = build(label, output) { |list|

			# Whitelist
			if ( whitelist = config.as_a?("whitelist", each_as: String) )
				new_whitelist = Array(IP::Address|IP::Block).new(whitelist.size)
				whitelist.each() { |entry|
					entry = IP::Address[entry]? || IP::Block[entry]?
					raise "Configuration has errors: Whitelist" if entry.nil?
					new_whitelist << entry
				}
				list.whitelist = new_whitelist
			end

			# Sources
			sources = config.as_h?("sources")
			raise "Configuration has errors. No Sources" if ( !sources )

			sources.each() { |key, src_config|
				list.sources << Source.from_config(key.to_s, src_config)
			}

			# Header
			if ( header = config.as_s?("header") )
				list.header = header
			end

		}

		return list
	end

end


abstract class NonGrata::Source

	def self.from_config(label : String, config : Config::Any) : self
		if ( url = config.as_s?() )
			return Source::List.new(label, url)
		end

		a_type = config.as_s?("type")
		a_type = "list" if ( !a_type )

		return case ( a_type.downcase )
			when "list"		then Source::List.from_config(label, config)
			when "table"	then Source::Table.from_config(label, config)
			else raise "Malformed Configuration: Invalid type"
		end
	end

end
