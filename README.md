# nongrata

Aggregates several IP blacklists, validates each entry and outputs a new, safe, reduced, and newline delimited list.

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
nongrata -s
```

Cron Usage + `PF`:
```
nongrata -s && (pfctl -t tablename -T replace -f /etc/pf/name.list)
```

## Contributing

1. Fork it ( https://github.com/chris-huxtable/nongrata/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [Chris Huxtable](https://github.com/chris-huxtable) - creator, maintainer
