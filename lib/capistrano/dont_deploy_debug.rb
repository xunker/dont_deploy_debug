require 'capistrano'

module Capistrano
  module DontDeployDebug
    def contains_ruby_breakpoint?(ruby_code)
      ruby_code = ruby_code.split('#').first.strip
      return false if ruby_code.size < 1
      fetch(:ruby_breakpoint_patterns).each do |pattern|
        return true if ruby_code =~ pattern
      end
      false
    end

    def exclude_from_ruby_breakpint_check?(file_path)
      fetch(:exclude_from_ruby_breakpoint_check).each do |pattern|
        return true if file_path =~ pattern
      end
      false
    end
  end
end

include Capistrano::DontDeployDebug

configuration = Capistrano::Configuration.respond_to?(:instance) ?
  Capistrano::Configuration.instance(:must_exist) :
  Capistrano.configuration(:must_exist)

configuration.load do

  set :exclude_from_ruby_breakpoint_check, [
    /^\.\/config\/deploy\.rb$/,
    /^\.\/spec\//,
    /^\.\/test\//,
    /^\.\/features\//
  ]

  set :ruby_breakpoint_patterns, [
    /require [\'\"]ruby-debug[\'\"][;\n]\s*debugger/,
    /^\s*debugger[;\n]/,
    /^\s*debugger\s*$/,
    /\bbinding\.pry\b/
  ]

  set :ruby_breakpoint_trigger, '--regex "[debugger|binding\.pry]"'

  set :ruby_breakpoint_grep_command, Proc.new { "find #{release_path} -name \"*.rb\" -exec grep -Hn #{fetch(:ruby_breakpoint_trigger)} {} \\;" }

  set :skip_ruby_breakpoint_check, false

  after "deploy:finalize_update", "deploy:find_ruby_breakpoints"

  namespace :deploy do
    task :find_ruby_breakpoints do
      if fetch(:skip_ruby_breakpoint_check) || ENV['IGNORE_RUBY_BREAKPOINTS'].to_s != "true"
        files = capture(fetch(:ruby_breakpoint_grep_command)).to_s.split("\n")
        found = []
        files.each do |f|
          (file_path, line_number, ruby_code) = f.split(':', 3)
          next if exclude_from_ruby_breakpint_check?(file_path)
          next unless contains_ruby_breakpoint?(ruby_code)
          found << [file_path.sub(release_path,''), line_number, ruby_code]
        end

        if found.size>0
          message = [
            "",
            "*** Ruby debugger breakpoint found in deployed code. Deploy halted. ***",
            "",
            "There was code found that contains debugging breakpoints:",
            ""
          ]
          found.each { |f| message << "\t#{f.join(':')}" }
          message += [
            "",
            "Please remove the code, commit the change and try your deploy again.",
            "If you feel you have reached this message in error, please consult the",
            "documentation to learn how to exclude certain files, or how to tune the",
            "detection parameters. To override, set the 'IGNORE_RUBY_BREAKPOINTS'",
            " variable to true:",
            "",
            "\t$ IGNORE_RUBY_BREAKPOINTS=true cap <environment> deploy",
            "\n"
          ]
          abort(message.join("\n"))
        else
          abort('done')
        end
      end
    end
  end
end
