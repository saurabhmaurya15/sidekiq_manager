module SidekiqManager
  class CLI
    def initialize; end

    def run(args = ARGV)
      puts "Hello World #{args.join(' ')}"
    end
  end
end
