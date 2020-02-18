# opencl.cr

This library is primarily maintained to provide necessary utilites to the
`num.cr` numerical library, so not all features may be covered.  This library
should however cover all basic use cases, as well as provide a lower level ability
to implement more advanced use cases.  Feel free to submit PR's to add functionality

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     opencl:
       github: crystal-data/opencl.cr
   ```

2. Run `shards install`

## Usage

```crystal
require "opencl"

device, context, queue = Cl.single_device_defaults
puts Cl.device_name(device)
```

## Contributing

1. Fork it (<https://github.com/crystal-data/opencl.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Chris Zimmerman](https://github.com/christopherzimmerman) - creator and maintainer
