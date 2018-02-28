# terrafying

A small ruby dsl for [terraform](https://www.terraform.io), based on [terrafied](https://github.com/thattommyhall/terrafied).

## Setup

- Ruby 2.2:ish
- Terraform with the right version: https://www.terraform.io/downloads.html
  - OSX: `brew install terraform`
- `bundle install`

###

## Usage

The `terrafying` command is in `bin`:

```
$ ./bin/terrafying [path]
```

### Creating a specification

Create ruby file somewhere and declare resources as you wish.

For example `example/main.rb`

```ruby
require 'terrafying'

include Terrafying::DSL

resource :aws_security_group, "example_group", {
  name: "example_group",
  description: "Allow all inbound traffic to port 80",
  vpc_id: 'vpc-ec0c118e',

  ingress: {
    from_port: 80,
    to_port: 80,
    protocol: "tcp",
    cidr_blocks: ["0.0.0.0/0"],
  }
}
```
