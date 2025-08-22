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

  def edit_task_in_current_list(args)
    return puts "Usage: edit <task_id_or_number>" if args.nil? || args.empty?

    task_id = resolve_task_id(args)
    puts "Resolved task ID: #{task_id}" if ENV['DEBUG']
    return unless task_id

    begin
      puts "Fetching task with ID: #{task_id} from list: #{@current_list[:id]}" if ENV['DEBUG']
      task = @client.get_task(@current_list[:id], task_id)
      puts "Editing task: #{task.title}"
      puts

      # Show current values
      puts "Current values:"
      puts "  Title: #{task.title}"
      puts "  Notes: #{task.notes || '(none)'}"
      puts "  Due: #{task.due ? Time.parse(task.due).strftime('%Y-%m-%d %H:%M') : '(none)'}"
      puts "  Status: #{task.status || 'needsAction'}"
      puts

      # Allow user to edit each field
      new_title = edit_field("Title", task.title)
      new_notes = edit_field("Notes", task.notes)
      new_due = edit_due_date(task.due)

      # Update the task with new values
      puts "Updating task..." if ENV['DEBUG']
      @client.update_task(@current_list[:id], task_id, 
                         title: new_title, 
                         notes: new_notes, 
                         due: new_due)
      
      puts "\nTask updated successfully!"
      puts "New title: #{new_title}"
      puts "New notes: #{new_notes || '(none)'}"
      puts "New due: #{new_due ? Time.parse(new_due).strftime('%Y-%m-%d %H:%M') : '(none)'}"
      
    rescue => e
      puts "Error: #{e.message}"
    end
  end

  def search_tasks_in_current_list(args)
    return puts "Usage: search <text>" if args.nil? || args.empty?

    search_text = args.strip.downcase
    puts "Searching for tasks containing: \"#{search_text}\""
    puts "List: #{@current_list[:title]}"
    puts

    begin
      # Get all uncompleted tasks from current list
      tasks = @client.list_tasks(@current_list[:id], show_completed: false)
      puts "Found #{tasks.length} uncompleted tasks total" if ENV['DEBUG']

      # Filter tasks that contain the search text in title or notes
      matching_tasks = tasks.select do |task|
        title_match = task.title&.downcase&.include?(search_text)
        notes_match = task.notes&.downcase&.include?(search_text)
        match = title_match || notes_match
        
        puts "Task '#{task.title}': title_match=#{title_match}, notes_match=#{notes_match}" if ENV['DEBUG']
        match
      end

      if matching_tasks.empty?
        puts "No uncompleted tasks found containing \"#{search_text}\""
      else
        puts "Found #{matching_tasks.length} matching task#{'s' if matching_tasks.length != 1}:"
        puts

        matching_tasks.each_with_index do |task, index|
          # Show task number, title, and highlight where match was found
          puts "#{index + 1}. #{task.title}"
          puts "   ID: #{task.id}"
          
          # Show notes if they exist and contain match
          if task.notes && !task.notes.empty?
            if task.notes.downcase.include?(search_text)
              puts "   Notes: #{task.notes}"
            end
          end
          
          # Show due date if exists
          if task.due
            begin
              due_date = Time.parse(task.due)
              puts "   Due: #{due_date.strftime('%Y-%m-%d %H:%M')}"
            rescue
              puts "   Due: #{task.due}"
            end
          end
          
          puts
        end
        
        puts "Use 'show <number>' or 'edit <number>' to work with these tasks."
        puts "Task numbers: 1-#{matching_tasks.length} correspond to the search results above."
      end

    rescue => e
      puts "Error searching tasks: #{e.message}"
    end
  end

  def plan_task_in_current_list(args)
    return puts "Usage: plan <task_id_or_number>" if args.nil? || args.empty?

    task_id = resolve_task_id(args)
    puts "Resolved task ID: #{task_id}" if ENV['DEBUG']
    return unless task_id

    begin
      puts "Fetching task with ID: #{task_id} from list: #{@current_list[:id]}" if ENV['DEBUG']
      task = @client.get_task(@current_list[:id], task_id)
      puts "Planning task: #{task.title}"
      puts

      # Show current due date if exists
      current_due = nil
      if task.due
        begin
          current_due = Time.parse(task.due)
          puts "Current due date: #{current_due.strftime('%Y-%m-%d %H:%M')}"
        rescue
          puts "Current due date: #{task.due}"
        end
      else
        puts "Current due date: (none)"
      end
      puts

      # Show planning options
      selected_date = select_planning_date

      if selected_date.nil?
        puts "Planning cancelled."
        return
      end

      # Update the task with new due date
      puts "Setting due date to: #{selected_date ? Time.parse(selected_date).strftime('%Y-%m-%d %H:%M') : '(removed)'}" if ENV['DEBUG']
      @client.update_task(@current_list[:id], task_id, 
                         title: task.title,  # Preserve title
                         notes: task.notes,  # Preserve notes
                         due: selected_date)
      
      if selected_date
        formatted_date = Time.parse(selected_date).strftime('%A, %B %d, %Y at %H:%M')
        puts "\nTask scheduled for: #{formatted_date}"
      else
        puts "\nDue date removed from task."
      end
      
    rescue => e
      puts "Error planning task: #{e.message}"
    end
  end

  private

  def select_planning_date
    puts "Select when to schedule this task:"
    puts "  1. Today"
    puts "  2. Tomorrow"
    puts "  3. Next Monday"
    puts "  4. Next Tuesday"
    puts "  5. Next Wednesday"
    puts "  6. Next Thursday" 
    puts "  7. Next Friday"
    puts "  8. Remove current date"
    puts "  9. Cancel"
    puts
    print "Enter your choice (1-9): "

    unless $stdin.tty?
      # Demo mode - auto-select option 1 (Today)
      choice = '1'
      puts choice
    else
      choice = $stdin.gets.chomp.strip
    end

    case choice
    when '1'
      # Today at 9 AM
      today = Date.today
      Time.new(today.year, today.month, today.day, 9, 0, 0).utc.strftime('%Y-%m-%dT%H:%M:%S.000Z')
    when '2'
      # Tomorrow at 9 AM
      tomorrow = Date.today + 1
      Time.new(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0, 0).utc.strftime('%Y-%m-%dT%H:%M:%S.000Z')
    when '3'
      # Next Monday at 9 AM
      next_weekday(1, 9).utc.strftime('%Y-%m-%dT%H:%M:%S.000Z')
    when '4'
      # Next Tuesday at 9 AM
      next_weekday(2, 9).utc.strftime('%Y-%m-%dT%H:%M:%S.000Z')
    when '5'
      # Next Wednesday at 9 AM
      next_weekday(3, 9).utc.strftime('%Y-%m-%dT%H:%M:%S.000Z')
    when '6'
      # Next Thursday at 9 AM
      next_weekday(4, 9).utc.strftime('%Y-%m-%dT%H:%M:%S.000Z')
    when '7'
      # Next Friday at 9 AM
      next_weekday(5, 9).utc.strftime('%Y-%m-%dT%H:%M:%S.000Z')
    when '8'
      # Remove date
      nil
    when '9'
      # Cancel
      return nil
    else
      puts "Invalid choice. Please select 1-9."
      select_planning_date
    end
  end

  def next_weekday(target_wday, hour = 9)
    # target_wday: 1=Monday, 2=Tuesday, ..., 5=Friday
    today = Date.today
    current_wday = today.wday # 0=Sunday, 1=Monday, ..., 6=Saturday
    
    # Convert Sunday=0 to Sunday=7 for easier calculation
    current_wday = 7 if current_wday == 0
    target_wday = 7 if target_wday == 0
    
    # Calculate days to add
    if current_wday < target_wday
      days_to_add = target_wday - current_wday
    else
      days_to_add = 7 - current_wday + target_wday
    end
    
    # If it's the same weekday and it's already past the hour, go to next week
    if current_wday == target_wday && Time.now.hour >= hour
      days_to_add = 7
    end
    
    target_date = today + days_to_add
    Time.new(target_date.year, target_date.month, target_date.day, hour, 0, 0)
  end

  def edit_field(field_name, current_value)
    print "#{field_name} [#{current_value || '(none)'}]: "
    
    unless $stdin.tty?
      # In non-TTY mode (like testing), return current value
      puts "(keeping current)"
      return current_value
    end
    
    input = $stdin.gets.chomp.strip
    
    if input.empty?
      current_value
    elsif input == "(clear)" || input == "(none)"
      nil
    else
      input
    end
  end

  def edit_due_date(current_due)
    current_display = current_due ? Time.parse(current_due).strftime('%Y-%m-%d %H:%M') : '(none)'
    print "Due date (YYYY-MM-DD HH:MM or 'clear') [#{current_display}]: "
    
    unless $stdin.tty?
      # In non-TTY mode (like testing), return current value
      puts "(keeping current)"
      return current_due
    end
    
    input = $stdin.gets.chomp.strip
    
    if input.empty?
      current_due
    elsif input == "clear" || input == "(clear)" || input == "(none)"
      nil
    else
      begin
        # Parse the date and convert to RFC3339 format
        parsed_date = Time.parse(input)
        parsed_date.utc.strftime('%Y-%m-%dT%H:%M:%S.000Z')
      rescue ArgumentError
        puts "Invalid date format. Keeping current value."
        current_due
      end
    end
  end

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
    when 'review'
      if @current_context == :list
        review_task_in_current_list(args)
      else
        puts "Error: No list context set. Use 'use <list_name>' first."
      end
    when 'edit'
      if @current_context == :list
        edit_task_in_current_list(args)
      else
        puts "Error: No list context set. Use 'use <list_name>' first."
      end
    when 'search'
      if @current_context == :list
        search_tasks_in_current_list(args)
      else
        puts "Error: No list context set. Use 'use <list_name>' first."
      end
    when 'plan'
      if @current_context == :list
        plan_task_in_current_list(args)
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
      puts "  edit <task_id>         - Edit task title, notes, or due date"
      puts "  search <text>          - Search for uncompleted tasks containing text"
      puts "  plan <task_id>         - Quickly schedule task (today, tomorrow, next week, etc.)"
      puts "  review <task_id>       - Review and classify task with priority/department"
    else
      puts "List context commands (available when in a list context):"
      puts "  tasks, list [--completed] [--limit N] - Show tasks in current list"
      puts "  create <title>         - Create a new task"
      puts "  complete <task_id>     - Mark a task as completed"
      puts "  delete <task_id>       - Delete a task"
      puts "  show <task_id>         - Show full task details"
      puts "  edit <task_id>         - Edit task title, notes, or due date"
      puts "  search <text>          - Search for uncompleted tasks containing text"
      puts "  plan <task_id>         - Quickly schedule task (today, tomorrow, next week, etc.)"
      puts "  review <task_id>       - Review and classify task with priority/department"
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
    confirmation = $stdin.gets.chomp.downcase
    
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

  def review_task_in_current_list(args)
    return puts "Usage: review <task_id_or_number>" if args.nil? || args.empty?

    task_id = resolve_task_id(args)
    puts "Resolved task ID: #{task_id}" if ENV['DEBUG']
    return unless task_id

    begin
      puts "Fetching task with ID: #{task_id} from list: #{@current_list[:id]}" if ENV['DEBUG']
      task = @client.get_task(@current_list[:id], task_id)
      puts "Reviewing task: #{task.title}"
      puts "Task ID from object: #{task.id}" if ENV['DEBUG']
      puts "Current notes: #{task.notes}" if ENV['DEBUG']
      puts

      # Select priority
      priority = select_priority
      return if priority.nil?

      # Select department
      department = select_department
      
      # Update task with new classification
      update_task_classification(task, priority, department, task_id)
      
    rescue => e
      puts "Error: #{e.message}"
    end
  end

  def select_priority
    puts "Select Priority:"
    puts "  1. 🔥 Hot - Urgent/critical tasks"
    puts "  2. 🟢 Must - Important/required tasks"
    puts "  3. 🟠 Nice - Nice to have/optional tasks"
    puts "  4. 🔴 NotNow - Deferred/not current priority"
    puts
    print "Enter priority number (1-4): "
    
    unless $stdin.tty?
      # Demo mode - auto-select option 2 (Must)
      choice = '2'
      puts choice
    else
      choice = $stdin.gets.chomp.strip
    end
    
    case choice
    when '1'
      '🔥Hot'
    when '2'
      '🟢Must'
    when '3'
      '🟠nice'
    when '4'
      '🔴NotNow'
    else
      puts "Invalid choice. Please enter 1-4."
      return nil
    end
  end

  def select_department
    puts "\nSelect Department:"
    puts "  1. 🧩 Product - Product development tasks"
    puts "  2. 📈 Business - Business operations/strategy"
    puts "  3. 📢 Marketing - Marketing and promotion"
    puts "  4. 🔒 Security - Security/compliance tasks"
    puts "  5. 👩‍💼 Others - General/administrative tasks"
    puts "  6. None - Skip department classification"
    puts
    print "Enter department number (1-6): "
    
    unless $stdin.tty?
      # Demo mode - auto-select option 2 (Business)
      choice = '2'
      puts choice
    else
      choice = $stdin.gets.chomp.strip
    end
    
    case choice
    when '1'
      '🧩Product'
    when '2'
      '📈Business'
    when '3'
      '📢Marketing'
    when '4'
      '🔒Security'
    when '5'
      '👩‍💼Others'
    when '6'
      nil
    else
      puts "Invalid choice. Please enter 1-6."
      unless $stdin.tty?
        return nil  # In demo mode, don't retry
      else
        return select_department  # Retry
      end
    end
  end

  def update_task_classification(task, priority, department, task_id)
    # Get current notes or empty string
    current_notes = task.notes || ""
    
    # Remove existing priority and department icons from notes
    clean_notes = remove_existing_classifications(current_notes)
    
    # Add new classification
    classification = priority
    classification += " #{department}" if department
    
    # Combine with existing notes
    if clean_notes.empty?
      new_notes = classification
    else
      new_notes = "#{classification}\n\n#{clean_notes}"
    end
    
    # Update the task
    puts "Updating task ID: #{task_id}" if ENV['DEBUG']
    puts "List ID: #{@current_list[:id]}" if ENV['DEBUG']
    puts "Preserving title: #{task.title}" if ENV['DEBUG']
    puts "New notes: #{new_notes}" if ENV['DEBUG']
    puts "Calling @client.update_task(#{@current_list[:id]}, #{task_id}, title: '#{task.title}', notes: '#{new_notes}')" if ENV['DEBUG']
    @client.update_task(@current_list[:id], task_id, title: task.title, notes: new_notes)
    
    puts "\nTask classification updated:"
    puts "Priority: #{priority}"
    puts "Department: #{department || 'None'}"
    puts "Task updated successfully!"
  end

  def remove_existing_classifications(notes)
    # Remove existing priority and department icons
    classification_patterns = [
      /🔥Hot\s*/,
      /🟢Must\s*/,
      /🟠nice\s*/,
      /🔴NotNow\s*/,
      /🧩Product\s*/,
      /📈Business\s*/,
      /📢Marketing\s*/,
      /🔒Security\s*/,
      /👩‍💼Others\s*/,
      /💳Sales\s*/  # Handle existing sales icon too
    ]
    
    clean_notes = notes
    classification_patterns.each do |pattern|
      clean_notes = clean_notes.gsub(pattern, '')
    end
    
    # Clean up multiple newlines and whitespace
    clean_notes.gsub(/\n\n+/, "\n\n").strip
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