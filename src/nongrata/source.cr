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

require "socket"
require "http"


abstract class NonGrata::Source

	@comment : String|Char = '#'
	@cache : String? = nil


	# MARK: - Initializer

	def initialize(@label : String, @url : String)
	end


	# MARK: - Properties

	getter label : String
	getter url : String

	property comment : String|Char


	# MARK: - Cacheing

	# Cachces the cached content of the source.
	def cache() : String
		cache = @cache
		return cache if cache
		return recache()
	end

	# Empties the cache and re-downloads the source.
	def recache() : String
		cache = nil

		UNIXSocket.pair { |rooted, forked|
			proc = Process.restrict(user: NonGrata::USER, group: NonGrata::GROUP, wait: false) {

				{% if flag?(:openbsd) %}
					Process.pledge(:stdio, :rpath, :wpath, :inet, :dns)
				{% end %}

				HTTP::Client.get(@url) { |responce|
					IO.copy(responce.body_io, forked)
					forked.puts("\0")
				}

				forked.close
			}

			raise "Missing child process" if ( !proc )

			cache = String.build() { |builder|
				while line = rooted.gets
					break if ( line == "\0" )
					builder.puts(line)
				end
				rooted.close
			}

			proc.wait
		}

		raise "Caching failed" if !cache
		@cache = cache

		return cache
	end

	# Empties the cache.
	def empty_cache()
		@cache = nil
	end


	# MARK: - Listing

	# Iterates through each entry in the source.
	def listing(&block : IP::Address|IP::Block -> Nil) : Nil
		cache.each_line() { |line|
			address = address_from_line(line)
			next if ( !address )
			if ( address.is_a?(Array) )
				address.each() { |e| yield(e) }
			else
				yield(address)
			end
		}
	end


	# MARK: - Utilities

	# Extracts and address from a given line.
	protected def address_from_line(line : String) : IP::Address|IP::Block|Array(IP::Block)|Nil
		return nil if ( !line || line.empty?() )
		line = strip_comment(line)
		line = line.strip()
		return nil if ( line.empty?() )
		address = IP::Address[line]?
		address = IP::Block[line]? if !address

		return address
	end

	# Stripps comments from a line
	protected def strip_comment(line : String) : String
		return "" if ( line.starts_with?(@comment) )

		offset = line.index(@comment)
		return line if ( !offset )

		return line[0, offset]
	end


	# A `List` type of source
	class List < Source

		@entry_delimiter : Char|String = '\n'

		def self.from_config(label : String, config : Config::Any) : self
			tmp = config.as_s?("url")
			raise "Malformed Configuration: Source missing url" if ( !tmp || tmp.empty? )
			url = tmp

			source = new(label, url)

			tmp = config.as_s?("comment")
			source.comment = tmp if ( tmp && !tmp.empty? )

			tmp = config.as_s?("delimiter")
			source.entry_delimiter = tmp if ( tmp && !tmp.empty?() )

			return source
		end

		property entry_delimiter : Char|String

	end

	# A `Table` type of source
	class Table < List

		@column_delimiter : Char|String = ','

		@prefix : Char|String|Nil = nil
		@suffix : Char|String|Nil = nil

		@column : UInt32 = 0_u32
		@width : UInt32? = nil

		def self.from_config(label : String, config : Config::Any) : self
			source = super(label, config)

			tmp = config.as_s?("delimiter")
			source.column_delimiter = tmp if ( tmp && !tmp.empty?() )

			tmp = config.as_i64?("column")
			source.column = tmp.to_u32 if ( tmp )

			tmp = config.as_i64?("width")
			source.width = tmp.to_u32 if ( tmp )

			tmp = config.as_s?("prefix")
			source.prefix = tmp if ( tmp && !tmp.empty?() )

			tmp = config.as_s?("suffix")
			source.suffix = tmp if ( tmp && !tmp.empty?() )

			return source
		end

		property column_delimiter : Char|String

		property prefix : Char|String|Nil
		property suffix : Char|String|Nil

		property column : UInt32
		property width : UInt32?

		# Extracts and address from a given line.
		protected def address_from_line(line : String) : IP::Address|IP::Block|Array(IP::Block)|Nil
			prefix = @prefix
			return nil if ( prefix && !line.starts_with?(prefix) )

			suffix = @suffix
			return nil if ( suffix && !line.ends_with?(suffix) )

			line = line.split(@column_delimiter)

			address = line[@column]?
			return nil if !address

			address = super(address)
			return nil if !address

			width = @width
			return address if address.is_a?(IP::Block)
			return address if !width
			count = line[width].to_i
			size = address.width - Math.log2(count).floor
			floor = size.floor.to_i32

			return IP::Block.new?(address, floor)
		end

	end

end
