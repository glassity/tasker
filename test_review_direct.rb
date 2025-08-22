#!/usr/bin/env ruby

require_relative 'lib/google_tasks_client'
require_relative 'lib/interactive_mode'

puts "=== Direct Review Functionality Test ==="

begin
  client = GoogleTasksClient.new
  interactive = InteractiveMode.new(client)
  
  # Mock TTY
  $stdin.define_singleton_method(:tty?) { false }  # This will enable demo mode in select methods
  
  # Get the first list and first task
  lists = client.list_task_lists
  if lists.empty?
    puts "No task lists found"
    exit 1
  end
  
  first_list = lists.first
  puts "Using list: #{first_list.title}"
  
  # Set list context manually
  interactive.instance_variable_set(:@current_context, :list)
  interactive.instance_variable_set(:@current_list, { id: first_list.id, title: first_list.title })
  
  # Get tasks
  tasks = client.list_tasks(first_list.id)
  if tasks.empty?
    puts "No tasks found in the list"
    exit 1
  end
  
  first_task = tasks.first
  puts "Testing review on task: #{first_task.title}"
  puts "Current notes: #{first_task.notes || 'None'}"
  puts
  
  # Test the review functionality directly
  puts "=== Starting Review Process ==="
  interactive.send(:review_task_in_current_list, "1")
  
  # Check if task was updated
  updated_task = client.get_task(first_list.id, first_task.id)
  puts
  puts "=== After Review ==="
  puts "Updated notes: #{updated_task.notes || 'None'}"
  
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5)
end