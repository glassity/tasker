#!/usr/bin/env ruby

require_relative 'lib/google_tasks_client'
require_relative 'lib/interactive_mode'

# Mock input for testing review functionality
commands = [
  "lists", 
  "use 1",
  "list --limit 1",
  "review 1",
  "exit-list",
  "exit"
]

puts "=== Testing Review Functionality ==="
puts "Simulating commands: #{commands.join(', ')}"
puts "=" * 50

begin
  client = GoogleTasksClient.new
  interactive = InteractiveMode.new(client)
  
  # Mock TTY for testing
  $stdin.define_singleton_method(:tty?) { true }
  
  # Mock input for commands and review selections
  command_index = 0
  
  # Override gets method for testing
  interactive.define_singleton_method(:gets) do
    if command_index < commands.length
      command = commands[command_index]
      command_index += 1
      puts "> #{command}"  # Show what command we're "typing"
      "#{command}\n"
    else
      nil  # EOF
    end
  end
  
  # For $stdin.gets in review process (priority and department selection)
  $stdin.define_singleton_method(:gets) do
    case command_index
    when 4  # After review command, first gets() call for priority
      puts "2"  # Select "Must" priority
      "2\n"
    when 5  # Second gets() call for department
      puts "2"  # Select "Business" department
      "2\n"
    else
      nil
    end
  end
  
  interactive.start
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5)
end