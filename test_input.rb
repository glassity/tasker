#!/usr/bin/env ruby

puts "Testing input handling..."
puts "Type something and press Enter:"

begin
  print "> "
  $stdout.flush
  input = $stdin.gets
  
  if input.nil?
    puts "Got nil (EOF)"
  else
    puts "Got input: '#{input.chomp}'"
  end
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(3)
end