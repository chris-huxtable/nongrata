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


class NonGrata::List

	# MARK: - Factories

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

	@header : String? = nil

	@sources	= Array(Source).new()
	@whitelist	= Array(IP::Address|IP::Block).new()

	@blocks		= Array(IP::Block).new()
	@addresses	= Array(IP::Address).new()

	@reject_count = 0_i32

	property label : String
	property output : String
	property header : String?

	property sources : Array(Source)
	property whitelist : Array(IP::Address|IP::Block)

	getter blocks : Array(IP::Block)
	getter addresses : Array(IP::Address)

	getter reject_count : Int32


	# MARK: - Iterators

	# Iterates over each address
	def each_address(&block) : Nil
		@addresses.each() { |e| yield(e) }
	end

	# Iterates over each block
	def each_block(&block) : Nil
		@blocks.each() { |e| yield(e) }
	end

	# Iterates over each address and block
	def each_entry(&block) : Nil
		@addresses.each() { |e| yield(e) }
		@blocks.each() { |e| yield(e) }
	end


	# MARK: - Processing

	# Caches all source data.
	def acquire(&block) : Nil
		@sources.each() { |source|
			yield(source)
			source.cache()
		}
	end

	# Processes each source.
	def process() : Nil
		# Processing Sources
		@sources.each() { |source|
			source.listing() { |address|
				@blocks << address		if ( address.is_a?(IP::Block) )
				@addresses << address	if ( address.is_a?(IP::Address) )
			}
			source.empty_cache
		}

		@reject_count = @addresses.size

		# Cleanup
		@blocks.uniq!()
		@addresses.uniq!()

		# Sorting Results
		@blocks.sort!() { |a, b| a <=> b }
		@addresses.sort!()

		@reject_count -= @addresses.size
	end

	# Reduces results. Rejecting whitelisted addresses and addresses already included in blocks.
	def reduce() : Nil
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

	# Writes list to `IO`
	def write(io : IO) : Nil
		io << header << "\n\n" if ( header )
		each_entry() { |entry| io << entry << '\n' }
	end


	# MARK: - Utilities

	protected def block_whitelisted?(block)
		@whitelist.each() { |white|
			return true if ( block.intersects?(white) )
		}
		return false
	end

end
