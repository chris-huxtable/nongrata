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


class NonGrata::List

	def self.from_config(label : String, config : Config::Any) : self?

		# Output
		tmp = config.as_s?("output")
		return nil if ( !tmp || tmp.empty? )
		output = File.expand_path(tmp)

		list = build(label, output) { |list|

			# Whitelist
			if ( whitelist = config.as_a?("whitelist", String) )
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
