require 'fileutils'
require 'tempfile'

def _mock_install(candidate, version)
  bin_dir = "#{$test_env['SDKMAN_CANDIDATES_DIR']}/#{candidate}/#{version}/bin"
  FileUtils.mkdir_p(bin_dir)
  FileUtils.touch("#{bin_dir}/#{candidate}")
  FileUtils.ln_s(bin_dir, "#{$test_env['SDKMAN_CANDIDATES_DIR']}/#{candidate}/current", force: true)
end

Given(/^candidate (\w+) is installed at version (\d+(?:\.\d+)*)$/) do |candidate, version|
  if $run_with_real_install
    run_bash_command("sdk install #{candidate} #{version}") unless installed?(candidate, version)
  else
    _mock_install(candidate, version)
  end
end

Given(/^candidate (\w+) is installed$/) do |candidate|
  if $run_with_real_install
    run_bash_command("sdk install #{candidate}") unless installed?(candidate)
  else
    _mock_install(candidate, "1.2.3")
  end
end

def _uninstall_candidate_version(candidate_dir)
  %r{/([^/]+)/([^/]+)$}.match(candidate_dir) do |match|
    candidate = match[1]
    version = match[2]
    if $run_with_real_install
      run_bash_command("sdk rm #{candidate} #{version}") unless version == 'current'
    else
      FileUtils.rm_rf("#{$test_env['SDKMAN_CANDIDATES_DIR']}/#{candidate}/#{version}/")
      # TODO: Should we ever use this to uninstall only _one_ version of a candidate,
      #       we need to re-link current
    end
  end
end

When(/^candidate (\w+) is uninstalled$/) do |candidate|
  log `ls ~/.sdkman/candidates/#{candidate}`
  Dir["#{$test_env['SDKMAN_CANDIDATES_DIR']}/#{candidate}/*"].each do |candidate_dir|
    _uninstall_candidate_version(candidate_dir)
  end
  log `ls #{$test_env['SDKMAN_CANDIDATES_DIR']}/#{candidate}`
end

Given(/^file ([a-zA-Z0-9\-_.\/]+) exists with content/) do |filename,content|
  FileUtils.mkdir_p(File.dirname(filename))
  File.write(filename, content)
end

$fish_config_files = []
def _remove_fish_configs # called in After hook
  $fish_config_files.each do |f|
    log "Removing #{f}"
    FileUtils.rm_f(f)
  end
  $fish_config_files = []
end

And(/^fish config file ([a-zA-Z0-9\-_.\/]+) exists with content$/) do |filename,content|
  file = "#{ENV['HOME']}/.config/fish/conf.d/#{filename}"
  FileUtils.mkdir_p(File.dirname(file))
  File.write(file, content)
  $fish_config_files << file
end

$config_file = "#{$test_env['SDKMAN_DIR']}/etc/config"
$backup_config_file = nil
def _restore_config # called in After hook
  unless $backup_config_file.nil?
    log "Restoring #{$config_file} from #{$backup_config_file.path}"
    FileUtils.mv($backup_config_file, $config_file)
    $backup_config_file = nil
  end
end

Given(/^SDKMAN! config sets ([a-z_]+) to (.*)$/) do |key,value|
  if $backup_config_file.nil?
    $backup_config_file = Tempfile.new('sdkman_config_backup_')
    log "Backing up #{$config_file} at #{$backup_config_file.path}"
    FileUtils.cp($config_file, $backup_config_file)
  end

  config = File.readlines($config_file).map { |line| line.split("=").map { |v| v.strip } }.to_h
  config[key] = value
  new_config_string = config.map { |k,v| "#{k}=#{v}" }.join("\n")

  File.write($config_file, new_config_string)
end

# TODO: create shared helper for both config files
#
$fish_config = "#{ENV['HOME']}/.config/fish/config.fish"
$backup_fish_config = nil
def _restore_fish_config # called in After hook
  unless $backup_fish_config.nil?
    if $backup_fish_config == :none
      log "Deleting #{$fish_config}"
      FileUtils.rm($fish_config)
    else
      log "Restoring #{$fish_config} from #{$backup_fish_config.path}"
      FileUtils.mv($backup_fish_config, $fish_config)
    end
    $backup_fish_config = nil
  end
end

And(/^fish config contains `([^`]+)`$/) do |line|
  if $backup_fish_config.nil?
    if File.exist?($fish_config)
      $backup_fish_config = Tempfile.new('fish_config_backup_')
      log "Backing up #{$fish_config} at #{$backup_fish_config.path}"
      FileUtils.cp($fish_config, $backup_fish_config)
    else
      $backup_fish_config = :none
    end
  end

  config = File.exist?($fish_config) ? File.readlines($fish_config) : ''
  config << "\n\n# Added by sdkman-for-fish test\n#{line}"

  File.write($fish_config, config.join("\n"))
end
