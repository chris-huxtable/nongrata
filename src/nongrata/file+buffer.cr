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

class File

	def self.update(filename, perm = DEFAULT_CREATE_MODE, encoding = nil, invalid = nil, buffer = 64, &block : IO -> Nil) : Bool

		if ( exists?(filename) )
			raise "File not writable" if ( !writable?(filename) )
			raise "File not readable" if ( !readable?(filename) )
		end

		return update(File.new(filename, "w+", perm, encoding: encoding, invalid: invalid), buffer) { |file|
			yield(file)
		}
	end

	def self.update(io : File, buffer = 64, &block : IO -> Nil) : Bool
		buffer = String.build(buffer) { |io| yield(io) }

		return false if ( !compare?(io, buffer) )

		io << buffer
		return true
	end

	def self.compare?(filename : String, string : String) : Bool
		raise "File not readable" if ( !readable?(filename) )
		return false if ( size(filename) != string.size )

		open(filename, "r") { |fd|
			return compare?(fd, string)
		}
		raise "An error occurred... "
	end

	def self.compare?(io : IO::FileDescriptor, string : String) : Bool
		io.seek(0) {
			idx = 0
			io.each_char() { |c|
				return false if ( c != string[idx] )
				idx += 1
			}
		}
		return true
	end

end
