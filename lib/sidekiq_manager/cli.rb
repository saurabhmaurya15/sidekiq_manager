require 'singleton'
require 'optparse'
require 'yaml'
require 'sidekiq_manager/sidekiq/stop_on_complete'

module SidekiqManager
  class CLI
    include Singleton unless $TESTING

    module Utilities
      SIDEKIQ = 'sidekiq'.freeze
      ALL = [SIDEKIQ].freeze
    end

    alias die exit
    attr_reader :options, :utility, :command, :environment

    def initialize; end

    def parse(args = ARGV)
      setup_operation(args)
      setup_options(args)
      validate!
      daemonize
    end

    def run
      boot_rails_application

      case utility
      when 'sidekiq'
        run_sidekiq_operations
      else
        puts "invalid utility: #{utility}"
      end
    end

    private

    def setup_operation(args)
      if ARGV.length < 2
        print_usage
        die(1)
      else
        @utility = args[0]
        @command = args[1]
      end
    end

    def setup_options(args)
      opts = parse_options(args)
      set_environment(opts[:environment])
      @options = opts
    end

    def parse_options(argv)
      opts = {}

      @parser = OptionParser.new do |o|
        o.on '-d', '--daemon', 'Daemonize process' do |arg|
          opts[:daemon] = arg
        end

        o.on '-P', '--pidfile PATH', 'path to pidfile' do |arg|
          opts[:pidfile] = arg
        end

        o.on '-e', '--environment ENV', 'Application environment' do |arg|
          opts[:environment] = arg
        end

        o.on '-V', '--version', 'Print version and exit' do |_arg|
          puts "Sidekiq Manager #{SidekiqManager::VERSION}"
          die(0)
        end
      end

      @parser.banner = 'sidekiq manager [options]'
      @parser.on_tail '-h', '--help', 'Show help' do
        puts @parser
        die 1
      end
      @parser.parse!(argv)

      opts
    end

    def validate!
      raise ArgumentError, "utility: #{utility} is not a valid value" unless Utilities::ALL.include?(utility)

      raise ArgumentError, "command: #{command} is not a valid value" unless %w[
        quiet start stop stop_on_complete
      ].include?(command)
    end

    def daemonize
      return unless options[:daemon]

      ::Process.daemon(true, false)
    end

    def run_sidekiq_operations
      case command
      when 'stop_on_complete'
        SidekiqManager::Sidekiq::StopOnComplete.new(options[:pidfile]).process
      else
        puts "invalid command: #{command}"
      end
    end

    def boot_rails_application
      ENV['RACK_ENV'] = ENV['RAILS_ENV'] = environment
      require File.expand_path('./config/environment.rb')
    end

    def set_environment(cli_env)
      @environment = cli_env || ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
    end

    def print_usage
      puts 'Sidekiq Manager - manage Sidekiq process from the command line.'
      puts
      puts 'Usage: sidekiq_manager <utility> <command> --options'
      puts " where <utility> is 'sidekiq'"
      puts "       <command> is either 'quiet', 'start', 'stop' or 'stop_on_complete'"
      puts '       (use --help for options)'
      puts
      puts "'start', 'stop', 'quiet' not available in this version."
      puts
    end
  end
end
