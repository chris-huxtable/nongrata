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

require "console"

require "pledge"
require "restrict"

require "atomic_write"

require "./nongrata/*"


module NonGrata

#	{% if flag?(:openbsd) %}
#		Process.pledge(:stdio, :rpath, :wpath, :cpath, :flock, :unix, :dns, :getpw, :proc, :id)
#	{% end %}

	Console::Error.fatal("Requires user to be root.") if ( !Process.root? )
	@@config : Configuration = catch { Configuration.default() }

	if ( @@config.cron? )
		success = true
		buffer = Console.to_buffer() do
			process_lists()
		rescue ex
			success = false
		end
		STDOUT << buffer if !success
	else
		process_lists()
	end


	# MARK: - Process Lists

	def self.process_lists()
		@@config.lists.each{ |key, list|
			process_list(list)
			Console.newline
		}
	rescue ex
		Console::Error.fatal(ex.message)
	end

	protected def self.process_list(list : List)
		dir = File.dirname(list.output)
		Dir.mkdir_p(dir) if ( !File.exists?(dir) )

		Console.heading(list.label)
		Console.line("  Acquiring:")
		list.acquire() { |source| Console.line("    - ", source.label) }

		a, b = UNIXSocket.pair()

		dir = @@config.empty_dir
		user = @@config.user
		group = @@config.group

		File.atomic_write(list.output) { |fd|
			Process.restrict(dir, user, group, wait: false) {
				{% if flag?(:openbsd) %}
					Process.pledge(:stdio)
				{% end %}

				list.process()
				list.reduce()

				Console.line("  Counts:")
				Console.line("    - ", list.addresses.size, " addresses")
				Console.line("    - ", list.blocks.size, " blocks")
				Console.line("    - ", list.reject_count, " rejects")

				list.write(a)
			}

			a.close
			IO.copy(b, fd)
			b.close

			Console.line("  Writing:")
			Console.line("    - Wrote Results: ", list.output)
		}
	ensure
		a.close if ( a )
		b.close if ( b )
	end


	# MARK: - Utilities

	def self.catch(&block)
		return yield()
	rescue ex
		Console::Error.fatal(ex.message)
	end

end
