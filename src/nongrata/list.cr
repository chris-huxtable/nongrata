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

require "./source"

class List

	# MARK: - Constructors

	def self.from_yaml(label : String, yaml : YAML::Any) : self?

		# Whitelist
		whitelist = yaml.extract_array?("whitelist", String)
		if ( whitelist )
			whitelist = whitelist.map() { |entry|
				next IP::Address[entry]? || IP::Block[entry]? || raise "Configuration has errors: Whitelist"
			}
		end

		# Output
		tmp = yaml.extract?("output", String)
		return nil if ( !tmp || tmp.empty? )
		output = File.expand_path(tmp)

		list = build(label, output) { |list|
			list.whitelist = whitelist if ( whitelist )

			sources = yaml["sources"]?
			raise "Configuration has errors. No Sources" if ( !sources )
			sources = sources.as_h?
			raise "Configuration has errors. No Sources" if ( !sources )

			sources.each() { |key, yaml2|
				list.sources << Source.from_yaml(key.to_s, YAML::Any.new(yaml2))
			}
		}

		return list
	end

	def self.build(label : String, output : String) : self
		list = new(label, output)
		yield(list)

		list.sources.uniq!()

		list.whitelist.uniq!()
		list.whitelist.sort!()

		return list
	end


	# MARK: - Initializer

	def initialize(@label : String, output : String)
		@output = File.expand_path(output)
	end


	# MARK: - Properties

	@sources	= Array(Source).new()
	@whitelist	= Array(IP::Address|IP::Block).new()

	@blocks		= Array(IP::Block).new()
	@addresses	= Array(IP::Address).new()

	@reject_count = 0_i32

	property label : String
	property output : String

	property sources : Array(Source)
	property whitelist : Array(IP::Address|IP::Block)

	getter blocks : Array(IP::Block)
	getter addresses : Array(IP::Address)

	getter reject_count : Int32


	# MARK: Iterators

	def each_address(&block) : Nil
		@addresses.each() { |e| yield(e) }
	end

	def each_block(&block) : Nil
		@blocks.each() { |e| yield(e) }
	end

	def each_entry(&block) : Nil
		@addresses.each() { |e| yield(e) }
		@blocks.each() { |e| yield(e) }
	end


	# MARK: - Processing

	def acquire(&block) : Nil

		@sources.each() { |source|
			yield(source)
			source.cache()
		}
	end

	def process() : Nil

		# MARK: Processing Sources
		@sources.each() { |source|
			source.listing() { |address|
				@blocks << address		if ( address.is_a?(IP::Block) )
				@addresses << address	if ( address.is_a?(IP::Address) )
			}
			source.empty_cache
		}

		# MARK: Sorting Results
		@reject_count = @addresses.size

		@blocks.uniq!()
		@addresses.uniq!()

		@blocks.sort!() { |a, b| a <=> b }
		@addresses.sort!()

		@reject_count -= @addresses.size
	end

	def reduce() : Nil

		# MARK: Reducing Results
		@blocks.reject!() { |block|
			whitelisted = block_whitelisted?(block)
			next false if ( !whitelisted )

			@reject_count += 1
			next true
		}

		@addresses.reject!() { |address|
			value = @whitelist.bsearch { |whitelisted|
				next ( whitelisted == address ) if ( whitelisted.is_a?(IP::Address) )
				next whitelisted.includes?(address)
			}
			next false if ( value.nil? )

			value = @blocks.bsearch { |block|
				next block.includes?(address)
			}
			next false if ( value.nil? )

			@reject_count += 1
			next true
		}
	end


	# MARK: - Utilities

	protected def block_whitelisted?(block)
		@whitelist.each() { |white|
			return true if ( block.intersects?(white) )
		}
		return false
	end

end
