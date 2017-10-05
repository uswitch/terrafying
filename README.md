# terrafying

A small ruby dsl for [terraform](https://www.terraform.io), based on [terrafied](https://github.com/thattommyhall/terrafied).

## Setup

- Ruby 2.2:ish
- Terraform with the right version: https://www.terraform.io/downloads.html
  - OSX: `brew install terraform`
- `bundle install`

###

`Terraform::CLI_VERSION` checks for the correct version of terraform. Due to Hashicorp continually releasing versions and sometimes with breaking changes / bugs, we have locked the terraform version. As terraform continues to get updated we will attempt to keep this version up-to-date with the latest stable version of terraform.

## Usage

The `terrafying` command is in `bin`:

```
$ ./bin/terrafying
Commands:
  terrafying apply PATH             # Apply changes to resources
  terrafying destroy PATH           # Destroy resources
  terrafying graph PATH             # Show execution graph
  terrafying help [COMMAND]         # Describe available commands or one specific command
  terrafying import PATH ADDR ID    # Import existing infrastructure into your Terraform state
  terrafying json PATH              # Show terraform JSON
  terrafying list PATH              # List resources defined
  terrafying plan PATH              # Show execution plan
  terrafying show-state PATH        # Show state
  terrafying use-local-state PATH   # Migrate to using local state storage
  terrafying use-remote-state PATH  # Migrate to using remote state storage

Options:
  [--no-lock], [--no-no-lock]
  [--keep], [--no-keep]
  [--target=TARGET]
```

### Creating a specification

Create ruby file somewhere and declare resources as you wish.

For example `example/main.rb`

```ruby
Terrafying::Generator.generate {
  aws_security_group "example_group", {
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
}
```

### Showing changes

Run `./bin/terrafying plan example/main.rb`:

```
$ ./bin/terrafying plan example/main.rb
Refreshing Terraform state prior to plan...


The Terraform execution plan has been generated and is shown below.
Resources are shown in alphabetical order for quick scanning. Green resources
will be created (or destroyed and then created if an existing resource
exists), yellow resources are being changed in-place, and red resources
will be destroyed.

Note: You didn't specify an "-out" parameter to save this plan, so when
"apply" is called, Terraform can't guarantee this is what will execute.

+ aws_security_group.example_group
    description:                          "" => "Allow all inbound traffic to port 80"
    egress.#:                             "" => "<computed>"
    ingress.#:                            "" => "1"
    ingress.2214680975.cidr_blocks.#:     "" => "1"
    ingress.2214680975.cidr_blocks.0:     "" => "0.0.0.0/0"
    ingress.2214680975.from_port:         "" => "80"
    ingress.2214680975.protocol:          "" => "tcp"
    ingress.2214680975.security_groups.#: "" => "0"
    ingress.2214680975.self:              "" => "0"
    ingress.2214680975.to_port:           "" => "80"
    name:                                 "" => "example_group"
    owner_id:                             "" => "<computed>"
    vpc_id:                               "" => "vpc-ec0c118e"


Plan: 1 to add, 0 to change, 0 to destroy.
```


### Applying changes

Run `./bin/terrafying apply`

```
$ ./bin/terrafying apply example/main.rb
aws_security_group.example_group: Creating...
  description:                          "" => "Allow all inbound traffic to port 80"
  egress.#:                             "" => "<computed>"
  ingress.#:                            "" => "1"
  ingress.2214680975.cidr_blocks.#:     "" => "1"
  ingress.2214680975.cidr_blocks.0:     "" => "0.0.0.0/0"
  ingress.2214680975.from_port:         "" => "80"
  ingress.2214680975.protocol:          "" => "tcp"
  ingress.2214680975.security_groups.#: "" => "0"
  ingress.2214680975.self:              "" => "0"
  ingress.2214680975.to_port:           "" => "80"
  name:                                 "" => "example_group"
  owner_id:                             "" => "<computed>"
  vpc_id:                               "" => "vpc-ec0c118e"
aws_security_group.example_group: Creation complete

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

The state of your infrastructure has been saved to the path
below. This state is required to modify and destroy your
infrastructure, so keep it safe. To inspect the complete state
use the `terraform show` command.

State path: terraform.tfstate
```

## Locking

To prevent concurrent changes to infrastructure any operations that
mutate resources (apply/delete) are done under a distributed lock.

If an operation fails completely or partially, you may be left still
holding the lock. This is intended behaviour and will allow you to fix
your specifications and continue applying your changes until you reach a
consistent state.

If you or someone else has a lock that you want to re-acquire or steal
(if you deem it safe to do so) you can use the `-f` flag.

```
$ ./bin/terrafying apply -f example/main.rb
```
