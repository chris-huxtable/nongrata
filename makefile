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

CRYSTAL_BIN		= /usr/local/bin/crystal

BIN_NAME		= nongrata

PROJECT_SRC		= src/nongrata.cr
PROJECT_BIN		= bin

INSTALL_BIN		= /usr/local/bin
INSTALL_USER	= root
INSTALL_GROUP	= bin
INSTALL_MOD		= 0755

CONFIG_FILE		= /etc/nongrata.conf
CONFIG_USER		= root
CONFIG_GROUP	= wheel
CONFIG_MOD		= 0600

DEBUG_CONF		= sample/nongrata.conf
DEBUG_DIR		= fake

build:
	@mkdir -p bin
	${CRYSTAL_BIN} build ${PROJECT_SRC} -o ${PROJECT_BIN}/${BIN_NAME} --progress --stats

release:
	@mkdir -p bin
	${CRYSTAL_BIN} build ${PROJECT_SRC} --release -o ${PROJECT_BIN}/${BIN_NAME} --progress --stats

debug:
	@rm -fR ${DEBUG_DIR}
	@mkdir -p ${DEBUG_DIR}
	${CRYSTAL_BIN} run ${PROJECT_SRC} --progress --stats -- -f ${DEBUG_CONF}

install: release
	cp ${PROJECT_BIN}/${BIN_NAME} ${INSTALL_BIN}/${BIN_NAME}
	chown ${INSTALL_USER}:${INSTALL_GROUP} ${INSTALL_BIN}/${BIN_NAME}
	chmod ${INSTALL_MOD} ${INSTALL_BIN}/${BIN_NAME}

	touch ${CONFIG_FILE}
	chown ${CONFIG_USER}:${CONFIG_GROUP} ${CONFIG_FILE}
	chmod ${CONFIG_MOD} ${CONFIG_FILE}

uninstall:
	rm ${INSTALL_BIN}/${BIN_NAME}

shards:
	shards update
	shards prune

clean:
	rm -fR ${PROJECT_BIN}
	rm -fR ${PROJECT_FAKE}
	shards prune
	find . -name ".DS_Store" -depth -exec rm {} \;
