namespace :load do
  task :defaults do
    set :sidekiq_default_hooks, -> { true }

    set :sidekiq_pid, -> { File.join(shared_path, 'tmp', 'pids', 'sidekiq.pid') }
    set :sidekiq_env, -> { fetch(:rack_env, fetch(:rails_env, fetch(:stage))) }
    set :sidekiq_log, -> { File.join(shared_path, 'log', 'sidekiq.log') }
    set :sidekiq_timeout, -> { 10 }
    set :sidekiq_roles, fetch(:sidekiq_roles, :app)
    set :sidekiq_processes, -> { 1 }
    set :sidekiq_options_per_process, -> { [] }
    set :sidekiq_stop_on_complete, -> { false }
    set :sidekiq_user, -> { nil }
    # Rbenv, Chruby, and RVM integration
    set :rbenv_map_bins, fetch(:rbenv_map_bins).to_a.concat(%w[sidekiq sidekiqctl sidekiq_manager])
    set :rvm_map_bins, fetch(:rvm_map_bins).to_a.concat(%w[sidekiq sidekiqctl sidekiq_manager])
    set :chruby_map_bins, fetch(:chruby_map_bins).to_a.concat(%w[sidekiq sidekiqctl sidekiq_manager])
    # Bundler integration
    set :bundle_bins, fetch(:bundle_bins).to_a.concat(%w[sidekiq sidekiqctl sidekiq_manager])
  end
end

namespace :deploy do
  before :starting, :check_sidekiq_hooks do
    invoke 'sidekiq:add_default_hooks' if fetch(:sidekiq_default_hooks)
  end
  after :publishing, :restart_sidekiq do
    invoke 'sidekiq:restart' if fetch(:sidekiq_default_hooks)
  end
end

namespace :sidekiq do
  def for_each_process(reverse = false)
    pids = processes_pids
    pids.reverse! if reverse
    pids.each_with_index do |pid_file, idx|
      within release_path do
        yield(pid_file, idx)
      end
    end
  end

  def processes_pids
    pids = []
    sidekiq_roles = Array(fetch(:sidekiq_roles))
    sidekiq_roles.each do |role|
      next unless host.roles.include?(role)

      processes = fetch(:"#{ role }_processes") || fetch(:sidekiq_processes)
      sidekiq_options_per_process = fetch(:"#{ role }_options_per_process") || fetch(:sidekiq_options_per_process)
      processes.times do |idx|
        pid_label = nil
        pid_label = sidekiq_options_per_process[idx][:pid_label] if sidekiq_options_per_process[idx]

        if pid_label.nil? || pid_label.empty?
          pids.push fetch(:sidekiq_pid).gsub(/\.pid$/, "-#{idx}.pid")
        else
          pids.push fetch(:sidekiq_pid).gsub(/\.pid$/, "-#{pid_label}.pid")
        end
      end
    end

    pids
  end

  def options_for_process(role, index)
    options_for_process = fetch(:"#{ role }_options_per_process") || fetch(:sidekiq_options_per_process)
    options_for_process[index]
  end

  def pid_process_exists?(pid_file)
    pid_file_exists?(pid_file) && test(*"kill -0 $( cat #{pid_file} )".split(' '))
  end

  def pid_file_exists?(pid_file)
    test(*"[ -f #{pid_file} ]".split(' '))
  end

  def stop_sidekiq(pid_file)
    if fetch(:stop_sidekiq_in_background, fetch(:sidekiq_run_in_background))
      if fetch(:sidekiq_use_signals)
        background "kill -TERM `cat #{pid_file}`"
      else
        background :sidekiqctl, 'stop', pid_file.to_s, fetch(:sidekiq_timeout)
      end
    else
      execute :sidekiqctl, 'stop', pid_file.to_s, fetch(:sidekiq_timeout)
    end
  end

  def stop_sidekiq_on_complete(pid_file)
    new_pid_file = archive_pid_file(pid_file)
    execute :sidekiq_manager, 'sidekiq', 'stop_on_complete', '--pidfile', new_pid_file, "--environment #{fetch(:sidekiq_env)}", '-d'
  end

  def archive_pid_file(pid_file)
    dirname, basename = File.split(pid_file)
    new_file = File.join(dirname, basename + '.'+ Time.now.to_i.to_s + '.old')
    execute "mv #{pid_file} #{new_file}"
    # File.rename(pid_file, new_file)
    new_file
  end

  def quiet_sidekiq(pid_file)
    if fetch(:sidekiq_use_signals)
      background "kill -USR1 `cat #{pid_file}`"
    else
      begin
        execute :sidekiqctl, 'quiet', pid_file.to_s
      rescue SSHKit::Command::Failed
        # If gems are not installed eq(first deploy) and sidekiq_default_hooks as active
        warn 'sidekiqctl not found (ignore if this is the first deploy)'
      end
    end
  end

  def start_sidekiq(pid_file, idx, process_options = nil)
    args = []
    args.push "--index #{idx}"
    args.push "--pidfile #{pid_file}"
    args.push "--environment #{fetch(:sidekiq_env)}"
    args.push "--logfile #{fetch(:sidekiq_log)}" if fetch(:sidekiq_log)
    args.push "--require #{fetch(:sidekiq_require)}" if fetch(:sidekiq_require)
    args.push "--tag #{fetch(:sidekiq_tag)}" if fetch(:sidekiq_tag)
    Array(fetch(:sidekiq_queue)).each do |queue|
      args.push "--queue #{queue}"
    end
    args.push "--config #{fetch(:sidekiq_config)}" if fetch(:sidekiq_config)
    args.push "--concurrency #{fetch(:sidekiq_concurrency)}" if fetch(:sidekiq_concurrency)

    # passed from sidekiq_options_per_process
    args.push process_options[:args] if process_options[:args]
    # use sidekiq_options for special options
    args.push fetch(:sidekiq_options) if fetch(:sidekiq_options)

    process_env = process_options.fetch(:env, {})

    if defined?(JRUBY_VERSION)
      args.push '>/dev/null 2>&1 &'
      warn 'Since JRuby doesn\'t support Process.daemon, Sidekiq will not be running as a daemon.'
    else
      args.push '--daemon'
    end
    with process_env do
      if fetch(:start_sidekiq_in_background, fetch(:sidekiq_run_in_background))
        background :sidekiq, args.compact.join(' ')
      else
        execute :sidekiq, args.compact.join(' ')
      end
    end
  end

  task :add_default_hooks do
    stop_on_complete = fetch(:sidekiq_stop_on_complete)
    after 'deploy:starting', 'sidekiq:quiet'
    after('deploy:updated', stop_on_complete ? 'sidekiq:stop_on_complete' : 'sidekiq:stop')
    after('deploy:reverted', stop_on_complete ? 'sidekiq:stop_on_complete' : 'sidekiq:stop')
    after 'deploy:published', 'sidekiq:start'
  end

  desc 'Quiet sidekiq (stop processing new tasks)'
  task :quiet do
    on roles fetch(:sidekiq_roles) do |role|
      switch_user(role) do
        if test("[ -d #{release_path} ]") # fixes #11
          for_each_process(true) do |pid_file, _idx|
            quiet_sidekiq(pid_file) if pid_process_exists?(pid_file)
          end
        end
      end
    end
  end

  desc 'Stop sidekiq'
  task :stop do
    on roles fetch(:sidekiq_roles) do |role|
      switch_user(role) do
        if test("[ -d #{release_path} ]")
          for_each_process(true) do |pid_file, _idx|
            stop_sidekiq(pid_file) if pid_process_exists?(pid_file)
          end
        end
      end
    end
    Rake::Task['sidekiq:stop'].reenable
  end

  desc 'Stop sidekiq on Job Completion'
  task :stop_on_complete do
    on roles fetch(:sidekiq_roles) do |role|
      switch_user(role) do
        if test("[ -d #{release_path} ]")
          for_each_process(true) do |pid_file, _idx|
            stop_sidekiq_on_complete(pid_file) if pid_process_exists?(pid_file)
          end
        end
      end
    end
    Rake::Task['sidekiq:stop_on_complete'].reenable
  end

  desc 'Start sidekiq'
  task :start do
    on roles fetch(:sidekiq_roles) do |role|
      switch_user(role) do
        for_each_process do |pid_file, idx|
          start_sidekiq(pid_file, idx, options_for_process(role, idx)) unless pid_process_exists?(pid_file)
        end
      end
    end
  end

  desc 'Restart sidekiq'
  task :restart do
    stop_on_complete = fetch(:sidekiq_stop_on_complete)
    invoke(stop_on_complete ? 'sidekiq:stop_on_complete' : 'sidekiq:stop')
    invoke 'sidekiq:start'
  end

  desc 'Rolling-restart sidekiq'
  task :rolling_restart do
    on roles fetch(:sidekiq_roles) do |role|
      switch_user(role) do
        for_each_process(true) do |pid_file, idx|
          stop_sidekiq(pid_file) if pid_process_exists?(pid_file)
          start_sidekiq(pid_file, idx, options_for_process(idx))
        end
      end
    end
  end

  # Delete any pid file not in use
  task :cleanup do
    on roles fetch(:sidekiq_roles) do |role|
      switch_user(role) do
        for_each_process do |pid_file, _idx|
          if pid_file_exists?(pid_file)
            execute "rm #{pid_file}" unless pid_process_exists?(pid_file)
          end
        end
      end
    end
  end

  # TODO : Don't start if all processes are off, raise warning.
  desc 'Respawn missing sidekiq processes'
  task :respawn do
    invoke 'sidekiq:cleanup'
    on roles fetch(:sidekiq_roles) do |role|
      switch_user(role) do
        for_each_process do |pid_file, idx|
          start_sidekiq(pid_file, idx, options_for_process(idx)) unless pid_file_exists?(pid_file)
        end
      end
    end
  end

  def switch_user(role)
    su_user = sidekiq_user(role)
    if su_user == role.user
      yield
    else
      as su_user do
        yield
      end
    end
  end

  def sidekiq_user(role)
    properties = role.properties
    properties.fetch(:sidekiq_user) || # local property for sidekiq only
      fetch(:sidekiq_user) ||
      properties.fetch(:run_as) || # global property across multiple capistrano gems
      role.user
  end

  def upload_sidekiq_template(from, to, role)
    template = sidekiq_template(from, role)
    upload!(StringIO.new(ERB.new(template).result(binding)), to)
  end

  def sidekiq_template(name, role)
    local_template_directory = fetch(:sidekiq_monit_templates_path)

    search_paths = [
      "#{name}-#{role.hostname}-#{fetch(:stage)}.erb",
      "#{name}-#{role.hostname}.erb",
      "#{name}-#{fetch(:stage)}.erb",
      "#{name}.erb"
    ].map { |filename| File.join(local_template_directory, filename) }

    global_search_path = File.expand_path(
      File.join('..', '..', '..', 'generators', 'capistrano', 'sidekiq', 'monit', 'templates', "#{name}.conf.erb"),
      __FILE__
    )

    search_paths << global_search_path

    template_path = search_paths.detect { |path| File.file?(path) }
    File.read(template_path)
  end
end
