# nongrata

Aggregates multiple IP blacklists, validates each entry and outputs a new, sanitized, and reduced, newline delimited list.

`nongrata` is already very safe as it only connects to services you think are reputable. That being said we have to assume it has serious bugs in its own code or the underlying libraries that are exploitable. As such it is privilege separated, `chroot`ed, and on OpenBSD `pledge`d. In the event that someone attempts to exploit a bug they will have trouble, won't get far, or will outright kill the process.

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

## Configuration

There are included sample configurations under the sample subdirectory.

I recommend whitelisting your LAN block, WAN address, and any other known good addresses or blocks. This will prevent them from being on the resultant list.

The configuration file is likely to change in a following version.

## Contributing

1. Fork it ( https://github.com/chris-huxtable/nongrata/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [Chris Huxtable](https://github.com/chris-huxtable) - creator, maintainer
