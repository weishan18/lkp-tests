require 'spec_helper'
require 'yaml'

def check_config_name(name)
  # Check if config name format is valid:
  # 1. not start with CONFIG_
  return !name.to_s.start_with?("CONFIG_")
end

def check_config_value(value)
  # Check if value format is valid:
  # 1. only contain n, m, y or nothing
  # 2. only contain i386, x86_64, or nothing
  allowed_chars = /^(n|m|y|i386|x86_64|)$/
  return value.match?(allowed_chars) || value.empty?
end

def preprocess_yaml_file(file_path)
  yaml_content = ''
  
  File.open(file_path, 'r') do |file|
    file.each_line do |line|
      # Skip lines containing conditional directives
      next if line.strip.start_with?('%') || line.strip.empty?

      # Concatenate the remaining lines
      yaml_content << line
    end
  end
  yaml_content
end

def load_yaml_with_conditionals(file_path)
  yaml_content = preprocess_yaml_file(file_path)
  YAML.safe_load(yaml_content)
end

describe 'Check need_kconfig from' do
  # Check the config format in include/ dir
  files = Dir.glob("#{LKP_SRC}/include/**/*").select { |file| File.file?(file) }

  files.each do |file|
    begin
      yaml_data = load_yaml_with_conditionals(file)
      next if yaml_data.nil?

      kconfig_section = yaml_data['need_kconfig']
      
      next if kconfig_section.nil?

      it file do
        if kconfig_section.is_a?(String)
          var_name = kconfig_section
          expect(check_config_name(var_name)).to be_truthy
        elsif kconfig_section.is_a?(Array)
          kconfig_section.each do |config|
            var_name, var_val = config.is_a?(String) ? [config.split(':').map(&:strip)[0], ""] : [config.keys[0], config.values[0]]
            conditions = check_config_name(var_name) && check_config_value(var_val)
            expect(conditions).to be_truthy
          end
        end
      end
    rescue Psych::SyntaxError => e
      # Expecting need_kconfig will be put in yaml file, so files like include/md/raid_level will be skipped
      next
    end
  end
end
