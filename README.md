# DontDeployDebug
## A gem against brain-farts.

How many times have you accidentally committed a debug statement and deployed
it? To production? Ugh! I've been there, brothers and sisters! I've done it
more times than I care to remember. So many that I finally decided to do
something about it.

## What?

It prevents code that has debug statements included from being deployed by
Capistrano, along with a message about what was found and where to find it.

Example:

```
    triggering after callbacks for `deploy:finalize_update'
  * 2013-11-05 16:38:44 executing `deploy:find_ruby_breakpoints'
  * executing "find /home/deploy/app/releases/20131105233842 -name \"*.rb\" -exec grep -Hn 'debugger\|binding.pry' {} \\;"
    servers: ["server.example.org"]
    [server.example.org] executing command
    command finished in 621ms

*** Ruby debugger breakpoint found in deployed code. Deploy halted. ***

There was code found that contains debugging breakpoints:

  /testfile.rb:3:require 'ruby-debug'; debugger

Please remove the code, commit the change and try your deploy again.
If you feel you have reached this message in error, please consult
https://github.com/xunker/dont_deploy_debug to learn how to exclude
certain files, or how to tune the detection parameters. To override
this check, set the 'IGNORE_RUBY_BREAKPOINTS' variable to true:

  $ IGNORE_RUBY_BREAKPOINTS=true cap <environment> deploy

*** [deploy:update_code] rolling back
  * executing "rm -rf /home/deploy/app/releases/20131105233842; true"
    servers: ["server.example.org"]
    [server.example.org] executing command
    command finished in 159ms
```

## Why?

Because even the rockstar-iest of ninjas sometimes forget to remove a 'debug'.

## How?

It's a gem that hooks in to your Capistrano deploy process. After the code is
updated on the server, but before it's made "live", the gem scans the release
path for ruby source files that have "debug" statements in them. If any are
found, the deploy is halted and rolled back, and a list of the offending files
is displayed to the user.

By default, the gem looks for statements in `*.rb` that are like:

```ruby
require 'ruby-debug'; debugger

require 'ruby-debug'
debugger

debugger;

binding.pry
```

The gem will ignore `test/*`, `spec/*`, `features/*` and `config/deploy.rb`.

## Ruby only?

Yes, for now. But if there is any interest it could be easily modified for
any language where the source was parsable on the deployment server.

## Installation

Add this line to your application's Gemfile:

```ruby
# ":require => false" is important!  
gem 'dont_deploy_debug', :require =>  false
```

Or from the command line if you aren't using bunder:

```
$ gem install dont_deploy_debug
```

Then, add the following to your Capistrano `deploy.rb`:

```
require 'capistrano/dont_deploy_debug'
```

For basic usage, this is all that is required.

## Configuration

### Enable or disable the check

Be default, every deploy will be checked regardless of environment. This can
be set programmatically by altering the 'skip_ruby_breakpoint_check' setting
in your deloy.rb file:

```ruby
# turn off for all
set :skip_ruby_breakpoint_check, true

# skip on stage
set :skip_ruby_breakpoint_check, (fetch(:rails_env) == 'stage')

# on for everyone (default)
set :skip_ruby_breakpoint_check, false
```

### Files to exclude from check

By default, `test/*`, `spec/*`, `features/*` and `config/deploy.rb` are
ignored. You can modify this behaviour by changing the
'exclude_from_ruby_breakpoint_check' setting in your deploy.rb and adding or
removing regular expressions:

```ruby
set :exclude_from_ruby_breakpoint_check, [
  /^\.\/config\/deploy\.rb$/,
  /^\.\/spec\//,
  /^\.\/test\//,
  /^\.\/features\//,
  /^\.\/something_else_here\//,
]
```

### Breakpoint patterns

By default, the gem will look for variations of:

```ruby
require 'ruby-debug'; debugger

binding.pry
```

This can be changed by altering the "ruby_breakpoint_patterns" setting in your
`deploy.rb` and adding or removing regular expressions:

```ruby
set :ruby_breakpoint_patterns, [
  /require [\'\"]ruby-debug[\'\"][;\n]\s*debugger/,
  /^\s*debugger[;\n]/,
  /^\s*debugger\s*$/,
  /\bbinding\.pry\b/,
  /some_other_debugger/
]
```

### Server-side grep command

To first find the files, the gem executes a grep() of the release path to get
"coarse" list of files and then lets ruby do the actual check. The command
used by default is:

```
find #{release_path} -name "*.rb" -exec grep -Hn 'debugger\|binding.pry' {} \;
```

A find() and grep() is used instead of a recursive grep because I have no way
of knowing if you are deploying to system with BSD, SYSV or GNU style tools.

You can change this command in your `deploy.rb` with the
"ruby_breakpoint_grep_command" setting:

```ruby
# default value is:
#   Proc.new { "find #{release_path} -name \"*.rb\" -exec grep -Hn #{fetch(:ruby_breakpoint_trigger)} {} \\;" }

# pass it a Proc object so we can read release_path and other variables
# It MUST return a string
set :ruby_breakpoint_grep_command, Proc.new { "some better grep here" }
```

If you only want to change the pattern that grep() uses, you can set
"ruby_breakpoint_trigger" instead:

```ruby
# default value is " 'debugger\|binding.pry' "
# note the single quotes!
set :ruby_breakpoint_trigger, " 'some_other_pattern' "
```

### Skipping check from command line

Finally, if you just want to deploy the damn'ed thing and skip the check
temporarily, you can set the "IGNORE_RUBY_BREAKPOINTS" shell variable:

```
$ IGNORE_RUBY_BREAKPOINTS=true cap <environment> deploy
```

## Caveats

This gem has not been throughly tested in any way. Like seriously. I use it,
but I'm the only one so far. I know it works on Redhat linux and it will likely
work in most linuxes. It *should* work on any BSD system, but YMMV.

If you find a case where it doesn't work please let me know.


[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/xunker/dont_deploy_debug/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

