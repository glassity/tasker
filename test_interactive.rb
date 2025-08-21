#!/usr/bin/env ruby

require_relative 'lib/google_tasks_client'
require_relative 'lib/interactive_mode'

# Mock input for testing
commands = [
  "help",
  "lists", 
  "use 1",
  "tasks",
  "help",
  "exit-list",
  "exit"
]

puts "=== Interactive Mode Test ==="
puts "Simulating commands: #{commands.join(', ')}"
puts "=" * 40

begin
  client = GoogleTasksClient.new
  interactive = InteractiveMode.new(client)
  
  # Override gets method for testing
  command_index = 0
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
  
  interactive.start
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(3)
end