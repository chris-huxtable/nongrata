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

module YAML
	def self.parse_file(path : String) : Any
		File.open(path, "r") do |fd|
			return YAML.parse(fd)
		end
	end

	def self.parse_all_file(path : String) : Array(Any)
		File.open(path, "r") do |fd|
			return YAML.parse_all(fd)
		end
	end
end

struct YAML::Any

	def extract?(key, new_type : U.class) : U? forall U
		value = self[key]?
		return nil if ( value.nil? )
		return value.raw.as?(U)
	end

	def extract_array?(key, new_type : U.class) : Array(U)? forall U

		array = self[key]?
		return nil if ( array.nil? )
		array = array.as_a?()
		return nil if ( array.nil? )

		final = Array(U).new(array.size)
		array.each() { |elm|
			elm = elm.as?(U)
			return nil if ( !elm )
			final << elm
		}

		return final
	end

end
