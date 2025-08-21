require_relative 'google_tasks_client'

class InteractiveMode
  def initialize(client)
    @client = client
    @current_context = nil
    @current_list = nil
    @running = true
  end

  def start
    # Check if we have a proper interactive terminal
    unless $stdin.tty?
      puts "Error: Interactive mode requires a terminal (TTY)."
      puts "Please run this command directly in a terminal, not through pipes or redirects."
      return
    end

    puts "Welcome to Google Tasks Interactive Mode!"
    puts "Type 'help' for available commands or 'exit' to quit."
    puts

    while @running
      print prompt
      begin
        $stdout.flush  # Ensure prompt is displayed
        input = $stdin.gets
        break if input.nil?  # Handle Ctrl+D (EOF)
        input = input.chomp.strip
        next if input.empty?

        handle_command(input)
      rescue Interrupt
        puts "\nUse 'exit' to quit."
      rescue => e
        puts "Input error: #{e.message}"
        puts "Type 'exit' to quit."
      end
    end

    puts "Goodbye!"
  end

  def demo
    puts "=== Interactive Mode Demo ==="
    puts "This demonstrates the interactive mode functionality."
    puts

    demo_commands = [
      "help",
      "lists", 
      "use 1",
      "list --limit 3",
      "show 2",
      "create \"Demo task with email: test@example.com\"",
      "help",
      "exit-list",
      "exit"
    ]

    demo_commands.each do |command|
      puts "#{prompt}#{command}"
      handle_command(command)
      puts
      sleep(0.5) if command != "exit"  # Small delay for readability
    end
  end

  private

  def prompt
    if @current_context == :list && @current_list
      "[#{@current_list[:title]}] > "
    else
      "> "
    end
  end

  def handle_command(input)
    parts = input.split(' ', 2)
    command = parts[0].downcase
    args = parts[1]

    case command
    when 'help'
      show_help
    when 'exit', 'quit'
      @running = false
    when 'lists'
      list_task_lists
    when 'use'
      use_list(args)
    when 'exit-list', 'exit_list'
      exit_list
    when 'tasks', 'list'
      if @current_context == :list
        list_tasks_in_current_list(args)
      else
        puts "Error: No list context set. Use 'use <list_name>' first or provide list ID."
      end
    when 'create'
      if @current_context == :list
        create_task_in_current_list(args)
      else
        puts "Error: No list context set. Use 'use <list_name>' first."
      end
    when 'complete'
      if @current_context == :list
        complete_task_in_current_list(args)
      else
        puts "Error: No list context set. Use 'use <list_name>' first."
      end
    when 'delete'
      if @current_context == :list
        delete_task_in_current_list(args)
      else
        puts "Error: No list context set. Use 'use <list_name>' first."
      end
    when 'show'
      if @current_context == :list
        show_task_in_current_list(args)
      else
        puts "Error: No list context set. Use 'use <list_name>' first."
      end
    else
      puts "Unknown command: #{command}. Type 'help' for available commands."
    end
  rescue => e
    puts "Error: #{e.message}"
  end

  def show_help
    puts "Available commands:"
    puts
    puts "General commands:"
    puts "  help                    - Show this help message"
    puts "  exit, quit             - Exit interactive mode"
    puts "  lists                  - List all task lists"
    puts "  use <list_name>        - Set context to a specific list"
    puts "  exit-list              - Exit current list context"
    puts
    
    if @current_context == :list
      puts "List context commands (current list: #{@current_list[:title]}):"
      puts "  tasks, list [--completed] [--limit N] - Show tasks in current list"
      puts "  create <title>         - Create a new task"
      puts "  complete <task_id>     - Mark a task as completed"
      puts "  delete <task_id>       - Delete a task"
      puts "  show <task_id>         - Show full task details"
    else
      puts "List context commands (available when in a list context):"
      puts "  tasks, list [--completed] [--limit N] - Show tasks in current list"
      puts "  create <title>         - Create a new task"
      puts "  complete <task_id>     - Mark a task as completed"
      puts "  delete <task_id>       - Delete a task"
      puts "  show <task_id>         - Show full task details"
    end
    puts
  end

  def list_task_lists
    puts "Available task lists:"
    lists = @client.list_task_lists
    
    if lists.empty?
      puts "No task lists found."
      return
    end

    lists.each_with_index do |list, index|
      puts "  #{index + 1}. #{list.title} (#{list.id})"
    end
    puts
  end

  def use_list(args)
    return puts "Usage: use <list_name_or_number>" if args.nil? || args.empty?

    lists = @client.list_task_lists
    return puts "No task lists available." if lists.empty?

    # Try to find by number first
    if args.match?(/^\d+$/)
      index = args.to_i - 1
      if index >= 0 && index < lists.length
        set_list_context(lists[index])
        return
      else
        puts "Invalid list number. Use 'lists' to see available lists."
        return
      end
    end

    # Try to find by name (case insensitive, partial match)
    list = lists.find { |l| l.title.downcase.include?(args.downcase) }
    
    if list
      set_list_context(list)
    else
      puts "List not found: '#{args}'"
      puts "Available lists:"
      lists.each_with_index do |l, index|
        puts "  #{index + 1}. #{l.title}"
      end
    end
  end

  def set_list_context(list)
    @current_context = :list
    @current_list = { id: list.id, title: list.title }
    puts "Switched to list context: #{list.title}"
  end

  def exit_list
    if @current_context == :list
      puts "Exited list context: #{@current_list[:title]}"
      @current_context = nil
      @current_list = nil
    else
      puts "Not currently in a list context."
    end
  end

  def list_tasks_in_current_list(args)
    show_completed = args&.include?('--completed') || false
    
    # Parse limit if provided
    limit = nil
    if args&.include?('--limit')
      parts = args.split
      limit_index = parts.index('--limit')
      if limit_index && limit_index + 1 < parts.length
        limit = parts[limit_index + 1].to_i
      end
    end
    
    puts "Tasks in #{@current_list[:title]}:"
    tasks = @client.list_tasks(@current_list[:id], show_completed: show_completed, max_results: limit)
    
    if tasks.empty?
      puts "No tasks found."
      return
    end

    puts "(#{tasks.length} total)"
    tasks.each_with_index do |task, index|
      display_task_summary(task, index + 1)
    end
  end

  def create_task_in_current_list(args)
    return puts "Usage: create <task_title>" if args.nil? || args.empty?

    task = @client.create_task(@current_list[:id], args)
    puts "Created task: #{task.title} (ID: #{task.id})"
  end

  def complete_task_in_current_list(args)
    return puts "Usage: complete <task_id_or_number>" if args.nil? || args.empty?

    task_id = resolve_task_id(args)
    return unless task_id

    @client.complete_task(@current_list[:id], task_id)
    puts "Completed task: #{task_id}"
  end

  def delete_task_in_current_list(args)
    return puts "Usage: delete <task_id_or_number>" if args.nil? || args.empty?

    task_id = resolve_task_id(args)
    return unless task_id

    print "Are you sure you want to delete this task? (y/N): "
    confirmation = gets.chomp.downcase
    
    if confirmation == 'y' || confirmation == 'yes'
      @client.delete_task(@current_list[:id], task_id)
      puts "Deleted task: #{task_id}"
    else
      puts "Task deletion cancelled."
    end
  end

  def show_task_in_current_list(args)
    return puts "Usage: show <task_id_or_number>" if args.nil? || args.empty?

    task_id = resolve_task_id(args)
    return unless task_id

    task = @client.get_task(@current_list[:id], task_id)
    display_task_full(task, @current_list)
  rescue => e
    puts "Error: #{e.message}"
  end

  def display_task_summary(task, number)
    status_icon = task.status == 'completed' ? '✓' : '○'
    
    # Truncate title if longer than 75 characters
    title = task.title.length > 75 ? "#{task.title[0..74]}... +More" : task.title
    
    puts "  #{number}. #{status_icon} #{title}"
    
    # Show notes in brackets format, truncated
    if task.notes && !task.notes.empty?
      notes = task.notes.length > 75 ? "#{task.notes[0..74]}... +More" : task.notes
      puts "     [#{notes}]"
    end
    
    # Show due date if present
    puts "     Due: #{task.due}" if task.due
    puts
  end

  def display_task_full(task, list = nil)
    status_icon = task.status == 'completed' ? '✓' : '○'
    
    # Check for email links in title or notes
    email_icon = has_email_content?(task) ? " 📧" : ""
    
    puts "#{status_icon} #{task.title}#{email_icon}"
    puts "List: #{list[:title]}" if list
    puts "Status: #{task.status}"
    puts "Due: #{task.due}" if task.due
    puts
    if task.notes && !task.notes.empty?
      puts "Notes:"
      puts task.notes
    end
  end

  def has_email_content?(task)
    email_patterns = [
      /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/,  # Email addresses
      /mailto:/i,  # mailto links
      /\bemail\b/i  # The word "email"
    ]
    
    text_to_check = "#{task.title} #{task.notes}"
    email_patterns.any? { |pattern| text_to_check.match?(pattern) }
  end

  def resolve_task_id(input)
    # If it's a number, treat as task number from the list
    if input.match?(/^\d+$/)
      number = input.to_i
      tasks = @client.list_tasks(@current_list[:id])
      
      if number > 0 && number <= tasks.length
        return tasks[number - 1].id
      else
        puts "Invalid task number. Use 'tasks' to see available tasks."
        return nil
      end
    end

    # Otherwise, treat as task ID
    input
  end
end