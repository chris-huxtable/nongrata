# nongrata
[![GitHub release](https://img.shields.io/github/release/chris-huxtable/nongrata.svg)](https://github.com/chris-huxtable/nongrata/releases)

Aggregates multiple IP blacklists, validates each entry, and outputs a new, sanitized, and reduced, newline delimited list.

`nongrata` is already very safe as it only connects to services you think are reputable. That being said the assumption has be that it  is exploitable are the underlying libraries. As such `nongrata` is privilege separated, `chroot`ed, and on OpenBSD `pledge`d. If someone attempts to exploit this software they will have trouble, won't get far, or will outright kill the process.


## Installation

```
sudo make install
make clean
```


## Usage

Basic Usage:
```
nongrata
```

Cron Usage:
```
nongrata -c
```

Cron Usage + `pf`:
```
nongrata -c && (pfctl -q -t drop -T replace -f /etc/pf.list/drop)
```

Help:
```
Usage: nongrata [arguments]
    -f file          Specifies the configuration file. The default is /etc/nongrata.conf.
    -c, --cron       silences the applications output. Useful for cron.
    -v, --version    Show the version number.
    -h, --help       Show this help.
```

## Configuration

There are included sample configurations under the sample subdirectory.

I recommend whitelisting your LAN block, WAN address, and any other known good addresses or blocks. This will prevent them from being on the resultant list.

### Lists:
The configuration is a collection of named lists you would like to construct. Each List should contain an `output` where the list will be written and optionally a `whitelist`, which can contain addresses or address blocks which will not be allowed in the resulting list. Additioanlly It needs to contain a collection of named sources from which to get the source data.

- `output`: *string*
- `whitelist`: \[ *optional*, *list*, *of*, *addresses*, *and*, *blocks* \]

```
BadGuyList: {
	output: /etc/pf.lists/badguys
	whitelist: [ "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16" ]
	sources: {
		// Your collection of named sources.
	}
}
```

### Sources:
Sources can currently be 1 of 2 types, `list` or `table`.  By default if type is not specified `list` is used. Both types have the `url` key which contains the url for the source.

A source which is a `list` is (by default) a newline delimited list of addresses and blocks. With this type you also have the option of selecting the entry delimiter with the `delimiter` key (by default a newline), as well as the  comment style with the `comment` key (by default a `#`).

- `url`: *url string*
- `type`: list
- `delimiter`: *string* # by default \n
- `comment`: *string* # by defualt \#

```
Spamhaus: {
	url: https://www.spamhaus.org/drop/drop.txt
	type: list
	comment: ;
}
```

A source which is a `table` is  a table with newline delimited rows where a column contains an address or  block. With this type you also have the option of selecting the column whcih will be interpreted as an address or block with the `column` key (by default 0), the column delimiter with the `delimiter` key (by default a comma),  the  comment style with the `comment` key (by default a `#`), and selectors of a line based on the lines prefix, or suffix using the keys `prefix`, and `suffix` respectivly.

- `url`: *url string*
- `type`: table
- `column`: *integer* # 0-n
- `delimiter`: *string* # by default ,
- `comment`: *string* # by defualt \#
- `prefix`:  *string* # disabled by default
- `suffix`: *string* # disabled by default

```
Tor: {
	url: https://check.torproject.org/exit-addresses
	type: table
	column: 1
	delimiter: " "
	prefix: ExitAddress
	suffix: nil
}
```


## Contributing

1. Fork it ( https://github.com/chris-huxtable/nongrata/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request


## Contributors

- [Chris Huxtable](https://github.com/chris-huxtable) - creator, maintainer
