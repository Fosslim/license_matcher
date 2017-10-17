# LicenseMatcher

LicenseMatcher is a rubygem that matches a fulltext of Opensource License Text with the SPDX id; So you dont have to guess is it **BSD** or **MIT** license, let the `LicenseMatcher` does the heavy lifting for you;


It uses [Fosslim](https://github.com/Fosslim/fosslim/) library underneath, which gives remarkable performance with lower memory cost than pure Ruby implementation;

This Gem is designed to be high-level Ruby client for the Fosslim library and may probably never expose low-level functions for manipulating index or models;


To experiment with that code, run `bin/console` for an interactive prompt.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'license_matcher'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install license_matcher

## Usage

run `bundle exec irb` on your commandline to fire up Ruby REPL;

```
require 'license_matcher'

# download pre-build index
curl -O https://github.com/Fosslim/license_matcher/blob/master/data/index.msgpack

# or build index from the SPDX data
LicenseMatcher::IndexBuilder.build_index( "data/licenses", "data/index.msgpack")

# match license text
txt = File.read("fixtures/files/mit.txt");

lm = LicenseMatcher::TFRubyMatcher.new("data/index.msgpack")
m  = lm.match_text(txt, 0.9)
p "spdx id: #{m.label}, confidence: #{m.score}"

```


## Matchers

It currently supports 4 different models:

* **UrlMatcher.match_url** - finds matching SPDX license by comparing URL with urls in the `licenses.json`

```ruby
lm = LicenseMatcher::UrlMatcher.new
lm.match_url "https://opensource.org/licenses/AAL"

=> "AAL"
```

* **RuleMatcher.match_rule** - scans a text and returns the SPDX id, which rule matches longest substring in the license text

```ruby
lm = LicenseMatcher::RuleMatcher.new
lm.match_rules "It is license under Apache 2.0 License."

=> "Apache-2.0"
```

* **TFRubyMatcher** - original Ruby implementation, uses TF/IDF and Cosine similarity;

```
lm = LicenseMatcher::TFRubyMatcher.new

txt = File.read "fixtures/files/mit.html"
clean_txt = LicenseMatcher::Preprocess.preprocess_html txt # NB! it may help to increase accuracy
lm.match_txt clean_txt
```

* **TFRustMatcher** - uses simple Jaccard similarity;

```
lm2 = LicenseMatcher::TFRustMatcher.new

txt = File.read "fixtures/files/mit.txt"
lm2.match_text txt
```

* **FingerprintMacher** - uses hashes of 5-word-ngrams to build fingerprints of the license files;

```
lm3 = File.read "fixtures/files/mit.txt"
lm3.match_text txt
```

## Benchmarks

* initialization 1x

```
       				user     system      total        real
TFRubyMatcher: 		12.970000   0.170000  13.140000 ( 13.361568)
TFRustMatcher:  	0.030000   0.010000   0.040000 (  0.033793)
FingerprintMatcher:  0.340000   0.010000   0.350000 (  0.368786)
```

* matching preprocessed short [MIT](https://raw.githubusercontent.com/Fosslim/license_matcher/master/data/spdx_licenses/plain/MIT) text 1000x times

```
      			  user     system      total        real
TFRubyMatcher:102.380000   6.730000 109.110000 (113.526434)
TFRustMatcher:  7.920000   0.100000   8.020000 (  8.248314)
FingerMatcher:  4.750000   0.060000   4.810000 (  5.187512)
```

* matching preprocessed long [AGPL-3.0](https://raw.githubusercontent.com/Fosslim/license_matcher/master/data/spdx_licenses/plain/AGPL-3.0) text 1000x times

```
       			user     system      total        real
TFRubyMatcher:217.270000   9.770000 227.040000 (232.190339)
TFRustMatcher:  9.330000   0.120000   9.450000 (  9.654545)
FingerMatcher: 23.650000   0.250000  23.900000 ( 24.311123)
```

## Development

Run `rake build` command to build native extension from Rust code;


After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fosslim/license_matcher.

This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## Code of Conduct

Everyone interacting in the LicenseMatcher project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/fosslim/license_matcher/blob/master/CODE_OF_CONDUCT.md).
