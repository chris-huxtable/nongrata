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

	def self.chown(path, user : String? = nil, group : String? = nil, follow_symlinks = false)

		if ( user )
			user.check_no_null_byte
			user = LibC.getpwnam(user)
			raise "User not found." if ( user.null? )
			user = user.value.pw_uid
		else
			user = -1
		end

		if ( group )
			group.check_no_null_byte
			group = LibC.getgrnam(group)
			raise "Group not found." if ( group.null? )
			group = group.value.gr_gid
		else
			group = -1
		end

		return chown(path, user, group, follow_symlinks)

	end

end
