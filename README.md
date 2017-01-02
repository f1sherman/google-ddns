![Travis](https://travis-ci.org/f1sherman/google-ddns.svg?branch=master)

# Google::Ddns

Client for Google DDNS. Designed to be run as a scheduled job on a *nix machine (e.g. cron).

## Installation

```
$ gem install google-ddns
```    

## Usage

To get setup, run the `google-ddns` command and you will be prompted for your Google DDNS credentials. See [this
documentation on how to retrieve the credentials for your domain](https://support.google.com/domains/answer/6147083?hl=en).

NOTE: Your Google DDNS credentials will be stored in plaintext on your local machine.

Once you've provided your credentials, you can create a scheduled task to update your IP at an interval of your
choosing.

## Development

1. Fork the repo
2. Write tests
3. Add your feature/fix
4. Submit a pull request

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/f1sherman/google-ddns.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
