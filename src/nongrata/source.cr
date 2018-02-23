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

abstract class Source

	@comment : String|Char = '#'
	@cache : String? = nil

	def self.from_yaml(label : String, yaml : YAML::Any) : self
		type = yaml.extract?("type", String)
		type = "newline" if ( !type )

		return case ( type.downcase )
			when "newline" then Newline.from_yaml(label, yaml)
			when "table" then Table.from_yaml(label, yaml)
			else raise "Malformed Configuration: Invalid type"
		end
	end


	# MARK: - Initializer

	def initialize(@label : String, @url : String)
	end


	# MARK: - Properties

	getter label : String
	getter url : String

	property comment : String|Char


	# MARK: - Cacheing

	def cache() : String
		cache = @cache
		return cache if cache
		return recache()
	end

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

	def empty_cache()
		@cache = nil
	end


	# MARK: - Listing

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

	def listing() : Array(IP::Address|IP::Block)
		list = Array(IP::Address|IP::Block).new()
		listing() { |entry| list << entry }
		return list
	end


	# MARK: - Utilities

	protected def address_from_line(line : String) : IP::Address|IP::Block|Array(IP::Block)|Nil
		return nil if ( !line || line.empty?() )
		line = strip_comment(line)
		line = line.strip()
		return nil if ( line.empty?() )
		address = IP::Address[line]?
		address = IP::Block[line]? if !address

		return address
	end

	protected def strip_comment(line : String) : String
		return "" if ( line.starts_with?(@comment) )

		offset = line.index(@comment)
		return line if ( !offset )

		return line[0, offset]
	end

	class Newline < Source

		def self.from_yaml(label : String, yaml : YAML::Any) : self
			tmp = yaml.extract?("url", String)
			raise "Malformed Configuration: Source missing url" if ( !tmp || tmp.empty? )
			url = tmp

			source = new(label, url)

			tmp = yaml.extract?("comment", String)
			source.comment = tmp if ( tmp && !tmp.empty? )

			return source
		end

	end

	class Table < Newline

		@delimiter : Char|String = ','

		@prefix : Char|String|Nil = nil
		@suffix : Char|String|Nil = nil

		@column : UInt32 = 0_u32
		@width : UInt32? = nil

		def self.from_yaml(label : String, yaml : YAML::Any) : self
			source = super(label, yaml)

			tmp = yaml.extract?("delimiter", String)
			source.delimiter = tmp if ( tmp && !tmp.empty?() )

			tmp = yaml.extract?("column", Int64)
			source.column = tmp.to_u32 if ( tmp )

			tmp = yaml.extract?("width", Int64)
			source.width = tmp.to_u32 if ( tmp )

			tmp = yaml.extract?("prefix", String)
			source.prefix = tmp if ( tmp && !tmp.empty?() )

			tmp = yaml.extract?("suffix", String)
			source.suffix = tmp if ( tmp && !tmp.empty?() )

			return source
		end

		property delimiter : Char|String

		property prefix : Char|String|Nil
		property suffix : Char|String|Nil

		property column : UInt32
		property width : UInt32?

		protected def address_from_line(line : String) : IP::Address|IP::Block|Array(IP::Block)|Nil
			prefix = @prefix
			return nil if ( prefix && !line.starts_with?(prefix) )

			suffix = @suffix
			return nil if ( suffix && !line.ends_with?(suffix) )

			line = line.split(@delimiter)

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
