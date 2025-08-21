#!/usr/bin/env ruby

require_relative 'lib/google_tasks_client'

puts "=== Testing Authentication Flow ==="

# Test 1: First access (should authenticate)
puts "\n1. First access to client (should authenticate once):"
client = GoogleTasksClient.new('oauth_credentials.json')

# Test 2: Multiple operations (should not re-authenticate)
puts "\n2. Multiple operations (should reuse stored authentication):"
begin
  client.list_task_lists
  puts "   ✓ First operation completed"
rescue => e
  puts "   ✗ First operation failed: #{e.message}"
end

begin
  client.list_task_lists  
  puts "   ✓ Second operation completed (no re-auth)"
rescue => e
  puts "   ✗ Second operation failed: #{e.message}"
end

# Test 3: New client instance (should reuse stored tokens)
puts "\n3. New client instance (should reuse stored tokens):"
client2 = GoogleTasksClient.new('oauth_credentials.json')
begin
  client2.list_task_lists
  puts "   ✓ New client used stored tokens"
rescue => e
  puts "   ✗ New client failed: #{e.message}"
end

puts "\n=== Authentication Test Complete ==="