# SidekiqManager

Sidekiq Manager gem handle sidekiq operations smartly. It includes sidekiq
integration for Capistrano deployment.
## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sidekiq_manager', github: 'saurabhmaurya15/sidekiq_manager'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sidekiq_manager

## Usage

To shutdown a sidekiq proccess it can be put on `quiet` and then stopped using
`stop` signal but it does not guarantee the completion of jobs already running
and those jobs are forcefully terminated. Some times re-running these time
consuming jobs can be a problem.

Sidekiq Manger comes with a `stop_on_complete`
signal for sidekiq which stops a sidekiq process only when the process has
finished processing all the jobs.

```ruby
bundle exec sidekiq_manager stop_on_complete --pidfile [PID_FILE]
```
Use `-d` option to run it as daemon.

This behaviour can be used during deployment also which sends `quiet` signal at the start of the deployment and does a `stop_on_complete` & `start` to bring up the new processes.
Old processes will be stopped once they have finished executing.

This is an improvment over existing `capistrano-sidekiq` gem.

For Capistrano integration
```ruby
# Capfile
require 'sidekiq_manager/capistrano/sidekiq'
require 'sidekiq_manager/capistrano/monit'  # to require monit tasks
```
Below is the list of default sidekiq deployment configs:
```ruby
:sidekiq_log => File.join(shared_path, 'log', 'sidekiq.log')
:sidekiq_config => nil # if you have a config/sidekiq.yml, do not forget to set this.
:sidekiq_queue => nil
:sidekiq_timeout => 10
:sidekiq_roles => :app
:sidekiq_processes => 1
:sidekiq_options_per_process => nil
:sidekiq_concurrency => nil
# sidekiq monit
:sidekiq_monit_templates_path => 'config/deploy/templates'
:sidekiq_monit_conf_dir => '/etc/monit/conf.d'
:sidekiq_monit_use_sudo => true
:monit_bin => '/usr/bin/monit'
:sidekiq_service_name => "sidekiq_#{fetch(:application)}_#{fetch(:sidekiq_env)}" + (index ? "_#{index}" : '')
:sidekiq_user => nil #user to run sidekiq as
```

To start multiple sidekiq process set `sidekiq_processes` and options for each process can be set using:
```ruby
# in your deployment file
set :sidekiq_options_per_process, [
  {
    pid_label: 'main',
    args: "--config /path_to_config/sidekiq.yml"
  },
  {
    pid_label: 'small',
    args: "--config /path_to_config/small.sidekiq.yml"
  }
]
```
`pid_file` for each sidekiq process can have a its own label instead of `sidekiq-0.pid` (default).

To use the functionality of `stop_on_complete` during deployment:
```ruby
set :sidekiq_stop_on_complete, true
```
If not set it does a normal sidekiq `stop`.

Note: Supports Capistrano version 3 & above.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/saurabhmaurya15/sidekiq_manager.

## Motivation
Deployment functionality within this gem is inspired by [capistrano-sidekiq](https://github.com/seuros/capistrano-sidekiq). We have re-used some parts of `capistrano-sidekiq` but it's architecture unfortunately didn't allow us to extend it easily with the features we needed. Also we preferred some things to work differently and wanted to add more functionality to the gem in future.
