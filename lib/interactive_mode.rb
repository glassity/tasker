require_relative 'google_tasks_client'
require_relative 'google_calendar_client'

class InteractiveMode
  def initialize(client, calendar_client = nil)
    @client = client
    @calendar_client = calendar_client || GoogleCalendarClient.new
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

      if selected_date == :cancel
        puts "Planning cancelled."
        return
      elsif selected_date == :complete
        # Mark task as completed
        begin
          @client.complete_task(@current_list[:id], task_id)
          puts "\nTask marked as completed!"
        rescue => complete_error
          puts "❌ Error completing task: #{complete_error.message}"
        end
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

  def grooming_workflow(list_id = nil)
    # Use provided list_id or current list
    working_list_id = list_id || @current_list[:id]
    working_list_title = if list_id
                          list = @client.get_task_list(list_id)
                          list.title
                        else
                          @current_list[:title]
                        end

    puts "🧹 Starting GTD Grooming Workflow"
    puts "List: #{working_list_title}"
    puts "=" * 60
    puts

    begin
      # Step 1: Find all uncompleted tasks that are overdue or have no due date
      puts "📋 Gathering tasks for grooming..."
      all_tasks = @client.list_tasks(working_list_id, show_completed: false)
      
      # Filter tasks: past due date OR no due date
      grooming_tasks = all_tasks.select do |task|
        if task.due.nil?
          true  # No due date
        else
          begin
            due_time = Time.parse(task.due)
            due_time < Time.now  # Past due
          rescue
            true  # Invalid due date, include in grooming
          end
        end
      end

      if grooming_tasks.empty?
        puts "✅ All tasks are properly scheduled! No grooming needed."
        return
      end

      # Separate due tasks from new/unscheduled tasks
      due_tasks = grooming_tasks.select { |task| !task.due.nil? }
      new_tasks = grooming_tasks.select { |task| task.due.nil? }

      # Sort each group by priority (highest to lowest)
      due_tasks = sort_tasks_by_priority(due_tasks)
      new_tasks = sort_tasks_by_priority(new_tasks)

      # Combine: due tasks first, then new tasks
      grooming_tasks = due_tasks + new_tasks

      puts "Found #{grooming_tasks.length} task#{'s' if grooming_tasks.length != 1} needing grooming:"

      # Show due tasks first
      if due_tasks.any?
        puts "\n  📅 Due/Overdue Tasks (by priority):"
        due_tasks.each_with_index do |task, index|
          priority_emoji = extract_priority_from_notes(task.notes)
          priority_text = priority_emoji || "○"
          puts "    #{index + 1}. #{priority_text} #{task.title} (Overdue)"
        end
      end

      # Then show new/unscheduled tasks
      if new_tasks.any?
        puts "\n  📋 Unscheduled Tasks (by priority):"
        new_tasks.each_with_index do |task, index|
          priority_emoji = extract_priority_from_notes(task.notes)
          priority_text = priority_emoji || "○"
          puts "    #{due_tasks.length + index + 1}. #{priority_text} #{task.title} (No due date)"
        end
      end
      puts

      # Step 2: Review phase - handle tasks with empty/minimal notes first
      unreviewed_tasks = grooming_tasks.select do |task|
        notes = task.notes || ""
        # Consider a task unreviewed if notes are empty or only contain basic text without priority/department emojis
        notes.empty? || !(notes.include?('🔥') || notes.include?('🟢') || notes.include?('🟠') || notes.include?('🔴'))
      end

      if unreviewed_tasks.any?
        puts "📝 REVIEW PHASE: #{unreviewed_tasks.length} task#{'s' if unreviewed_tasks.length != 1} need review first"
        puts "-" * 40
        
        unreviewed_tasks.each_with_index do |task, index|
          puts "\n🔍 Reviewing task #{index + 1} of #{unreviewed_tasks.length}:"
          puts "Title: #{task.title}"
          puts "Notes: #{task.notes || '(empty)'}"
          puts

          # Set context temporarily for review
          original_context = [@current_context, @current_list]
          @current_context = :list
          @current_list = {id: working_list_id, title: working_list_title}

          # Perform review
          puts "Starting review process..."
          review_task_by_object(task)

          # Restore original context
          @current_context, @current_list = original_context
          
          puts "✅ Review completed for: #{task.title}"
          puts
        end
        
        puts "📝 Review phase completed! All tasks are now classified."
        puts
      end

      # Step 3: Planning phase - schedule all tasks
      puts "📅 PLANNING PHASE: Scheduling #{grooming_tasks.length} task#{'s' if grooming_tasks.length != 1}"
      puts "-" * 40

      grooming_tasks.each_with_index do |task, index|
        # Fetch fresh task data in case it was updated during review
        fresh_task = @client.get_task(working_list_id, task.id)
        
        puts "\n📋 Planning task #{index + 1} of #{grooming_tasks.length}:"
        puts "Title: #{fresh_task.title}"
        
        if fresh_task.notes && !fresh_task.notes.empty?
          puts "Classification: #{fresh_task.notes.split("\n").first}"  # Show first line (usually the classification)
        end
        
        if fresh_task.due
          begin
            current_due = Time.parse(fresh_task.due)
            if current_due < Time.now
              puts "Current due date: #{current_due.strftime('%Y-%m-%d %H:%M')} (OVERDUE)"
            else
              puts "Current due date: #{current_due.strftime('%Y-%m-%d %H:%M')}"
            end
          rescue
            puts "Current due date: #{fresh_task.due} (invalid format)"
          end
        else
          puts "Current due date: (none)"
        end
        puts

        # Set context temporarily for planning
        original_context = [@current_context, @current_list]
        @current_context = :list
        @current_list = {id: working_list_id, title: working_list_title}

        # Plan the task
        selected_date = select_planning_date
        
        if selected_date && selected_date != :cancel && selected_date != :complete
          @client.update_task(working_list_id, fresh_task.id,
                             title: fresh_task.title,
                             notes: fresh_task.notes,
                             due: selected_date)
          
          if selected_date
            formatted_date = Time.parse(selected_date).strftime('%A, %B %d, %Y at %H:%M')
            puts "✅ Scheduled for: #{formatted_date}"
          else
            puts "✅ Due date removed"
          end
        elsif selected_date == :complete
          # Mark task as completed
          begin
            @client.complete_task(working_list_id, fresh_task.id)
            puts "✅ Task marked as completed"
          rescue => complete_error
            puts "❌ Error completing task: #{complete_error.message}"
            puts "⏭️  Skipped instead"
          end
        elsif selected_date == :cancel
          puts "⏭️  Skipped scheduling"
        end

        # Restore original context
        @current_context, @current_list = original_context
        
        puts
      end

      puts "🎉 GTD Grooming completed!"
      puts "All #{grooming_tasks.length} task#{'s' if grooming_tasks.length != 1} have been processed."
      puts

    rescue => e
      puts "Error during grooming workflow: #{e.message}"
      puts e.backtrace.first(3).join("\n") if ENV['DEBUG']
    end
  end

  def agenda_workflow(list_id = nil)
    # Use provided list_id or current list
    working_list_id = list_id || @current_list[:id]
    working_list_title = if list_id
                          list = @client.get_task_list(list_id)
                          list.title
                        else
                          @current_list[:title]
                        end

    puts "📅 Starting Category-Based Agenda Planning"
    puts "List: #{working_list_title}"
    puts "=" * 60
    puts

    begin
      # Step 1: Find all tasks scheduled for today
      puts "📋 Gathering today's tasks..."
      all_tasks = @client.list_tasks(working_list_id, show_completed: false)

      today = Date.today
      todays_tasks = all_tasks.select do |task|
        if task.due.nil?
          false
        else
          begin
            due_date = Time.parse(task.due).to_date
            due_date == today
          rescue
            false
          end
        end
      end

      if todays_tasks.empty?
        puts "📭 No tasks scheduled for today!"
        puts "Use 'plan' command to schedule tasks for today, or run 'grooming' to organize your backlog."
        return
      end

      puts "Found #{todays_tasks.length} task#{'s' if todays_tasks.length != 1} for today."
      puts

      # Step 2: Group tasks by category (department) and priority
      grouped_tasks = group_tasks_by_category_and_priority(todays_tasks)

      # Show grouped tasks
      puts "📊 Tasks grouped by category and priority:"
      grouped_tasks.each do |category, priority_groups|
        puts "\n#{category}:"
        priority_groups.each do |priority, tasks|
          puts "  #{priority}:"
          tasks.each_with_index do |task, idx|
            puts "    #{idx + 1}. #{task.title}"
          end
        end
      end
      puts

      # Step 3: Process each category (ordered by priority within each category)
      scheduled_events = []

      grouped_tasks.each do |category, priority_groups|
        puts "\n" + "=" * 60
        puts "🏷️  Processing Category: #{category}"
        puts "=" * 60

        # Flatten priority groups to process tasks by priority order
        category_tasks = []
        ['🔥Hot', '🟢Must', '🟠Nice', '🔴NotNow', 'No Priority'].each do |priority|
          if priority_groups[priority]
            category_tasks.concat(priority_groups[priority])
          end
        end

        # Step 4: Ask about 2-minute rule for each task
        tasks_to_schedule = []

        category_tasks.each_with_index do |task, idx|
          priority_emoji = extract_priority_from_notes(task.notes)
          priority_text = priority_emoji || "○"

          puts "\n📋 Task #{idx + 1} of #{category_tasks.length}: #{priority_text} #{task.title}"

          unless $stdin.tty?
            # In non-TTY mode, assume all tasks need scheduling
            confirm = 'n'
            puts "Does this take less than 2 minutes? (y/N): #{confirm}"
          else
            print "Does this take less than 2 minutes? (y/N): "
            confirm = $stdin.gets.chomp.strip.downcase
          end

          if confirm == 'y' || confirm == 'yes'
            puts "⏭️  Task takes less than 2 minutes - ignoring for time-blocking"
          else
            tasks_to_schedule << task
            puts "✅ Added to scheduling queue"
          end
        end

        # Step 5: If no tasks to schedule for this category, skip
        if tasks_to_schedule.empty?
          puts "\n⏭️  No tasks to schedule for category: #{category}"
          next
        end

        # Step 6: Calculate time block duration (30 min per task)
        num_tasks = tasks_to_schedule.length
        duration_minutes = num_tasks * 30
        hours = duration_minutes / 60
        minutes = duration_minutes % 60
        duration_text = hours > 0 ? "#{hours}h #{minutes}min" : "#{minutes}min"

        puts "\n📅 Time Block Summary for #{category}:"
        puts "   Tasks to schedule: #{num_tasks}"
        puts "   Total duration: #{duration_text} (30 min per task)"
        puts

        # Step 7: Build calendar event content
        event_title = "#{num_tasks} task#{num_tasks > 1 ? 's' : ''} for #{category}"
        event_description = build_category_event_description(tasks_to_schedule, category)

        # Step 8: Ask user for scheduling time
        unless $stdin.tty?
          # In non-TTY mode, auto-schedule starting from next half-hour
          current_time = Time.now
          slot_start = if current_time.min < 30
                        Time.new(current_time.year, current_time.month, current_time.day, current_time.hour, 30, 0)
                      else
                        Time.new(current_time.year, current_time.month, current_time.day, current_time.hour + 1, 0, 0)
                      end
          puts "Schedule this block starting at #{slot_start.strftime('%H:%M')}? (HH:MM or Enter for #{slot_start.strftime('%H:%M')}): #{slot_start.strftime('%H:%M')}"
        else
          current_time = Time.now
          suggested_time = if current_time.min < 30
                            Time.new(current_time.year, current_time.month, current_time.day, current_time.hour, 30, 0)
                          else
                            Time.new(current_time.year, current_time.month, current_time.day, current_time.hour + 1, 0, 0)
                          end

          print "Schedule this block starting at what time? (HH:MM or Enter for #{suggested_time.strftime('%H:%M')}): "
          time_input = $stdin.gets.chomp.strip

          if time_input.empty?
            slot_start = suggested_time
          else
            slot_start = parse_custom_time(time_input)
            unless slot_start
              puts "❌ Invalid time format. Skipping this category."
              next
            end
          end
        end

        slot_end = slot_start + (duration_minutes * 60)

        puts "\n📅 Creating calendar event:"
        puts "   Title: #{event_title}"
        puts "   Time: #{slot_start.strftime('%H:%M')} - #{slot_end.strftime('%H:%M')}"
        puts "   Duration: #{duration_text}"

        # Step 9: Create calendar event
        begin
          @calendar_client.ensure_authenticated

          # Create a single calendar event for all tasks in this category
          calendar_event = create_category_calendar_event(
            event_title,
            slot_start,
            slot_end,
            event_description,
            working_list_id
          )

          puts "✅ Calendar event created successfully!"

          scheduled_events << {
            category: category,
            num_tasks: num_tasks,
            time_slot: "#{slot_start.strftime('%H:%M')}-#{slot_end.strftime('%H:%M')}",
            start_time: slot_start,
            duration: duration_text,
            tasks: tasks_to_schedule
          }

        rescue => e
          puts "❌ Error creating calendar event: #{e.message}"
          puts "🔍 Debug: #{e.class}: #{e.message}" if ENV['DEBUG']
        end
      end

      # Step 10: Show final agenda summary
      if scheduled_events.any?
        puts "\n" + "=" * 80
        puts "📅 TODAY'S CATEGORY-BASED AGENDA SUMMARY"
        puts "=" * 80
        puts

        scheduled_events.sort_by { |e| e[:start_time] }.each do |event|
          puts "#{event[:time_slot]} | #{event[:num_tasks]} task#{event[:num_tasks] > 1 ? 's' : ''} for #{event[:category]} (#{event[:duration]})"
        end

        total_tasks = scheduled_events.sum { |e| e[:num_tasks] }
        puts "\n🎯 Category-based agenda complete! #{scheduled_events.length} time block#{scheduled_events.length > 1 ? 's' : ''} created for #{total_tasks} task#{total_tasks > 1 ? 's' : ''}."
        puts "📅 Check your Google Calendar for the scheduled blocks"
        puts "💡 Tip: Each block groups related tasks by category for efficient context switching"
      else
        puts "\n📝 No time blocks were scheduled."
      end

      puts

    rescue => e
      puts "Error during agenda workflow: #{e.message}"
      puts e.backtrace.first(3).join("\n") if ENV['DEBUG']
    end
  end

  def recap_workflow(list_id = nil, date_arg = nil)
    # Use provided list_id or current list
    working_list_id = list_id || @current_list[:id]
    working_list_title = if list_id
                          list = @client.get_task_list(list_id)
                          list.title
                        else
                          @current_list[:title]
                        end

    # Parse date argument
    target_date = parse_recap_date(date_arg)
    return unless target_date

    puts "📋 Daily Recap Review"
    puts "List: #{working_list_title}"
    puts "Date: #{target_date.strftime('%A, %B %d, %Y')}"
    puts "=" * 60
    puts

    begin
      # Step 1: Find ALL tasks (completed and incomplete) with due date matching target_date
      puts "🔍 Gathering all tasks for #{target_date.strftime('%m/%d/%Y')}..."

      # Get both completed and uncompleted tasks
      uncompleted_tasks = @client.list_tasks(working_list_id, show_completed: false)
      completed_tasks = @client.list_tasks(working_list_id, show_completed: true)
      all_tasks = (uncompleted_tasks + completed_tasks).uniq { |t| t.id }

      # Filter tasks with due date exactly matching target date
      target_tasks = all_tasks.select do |task|
        if task.due
          begin
            due_date = Time.parse(task.due).to_date
            due_date == target_date
          rescue
            false
          end
        else
          false
        end
      end

      if target_tasks.empty?
        puts "📭 No tasks found for #{target_date.strftime('%A, %B %d, %Y')}"
        puts "Try a different date or use the 'plan' command to schedule tasks."
        return
      end

      # Step 2: Display all tasks for the day
      puts "Found #{target_tasks.length} task#{'s' if target_tasks.length != 1} for this day:\n"

      target_tasks.each_with_index do |task, index|
        status_icon = task.status == 'completed' ? '✓' : '○'
        status_text = task.status == 'completed' ? 'Completed' : 'Incomplete'
        priority_emoji = extract_priority_from_notes(task.notes)
        priority_text = priority_emoji ? " #{priority_emoji}" : ""

        puts "  #{index + 1}. [#{status_icon}] #{task.title}#{priority_text}"
        puts "      Status: #{status_text}"
      end
      puts

      # Step 3: Ask which tasks need follow-ups (by number)
      puts "📝 SELECT TASKS FOR FOLLOW-UP"
      puts "-" * 60
      puts "Enter the numbers of tasks that need follow-ups (comma-separated)"
      puts "Example: 1,3,5 or just press Enter to skip"
      puts

      unless $stdin.tty?
        # In non-TTY mode, skip
        puts "⏭️  Skipped (non-interactive mode)"
        return
      end

      print "Task numbers for follow-up: "
      input = $stdin.gets.chomp.strip

      if input.empty?
        puts "\n⏭️  No follow-ups requested"
        return
      end

      # Parse the selected task numbers
      selected_numbers = input.split(',').map { |n| n.strip.to_i }.select { |n| n > 0 && n <= target_tasks.length }

      if selected_numbers.empty?
        puts "\n⏭️  No valid task numbers provided"
        return
      end

      # Step 4: Process each selected task
      follow_ups_created = 0
      tasks_completed = 0

      selected_numbers.each do |task_num|
        task = target_tasks[task_num - 1]

        puts "\n" + "=" * 60
        puts "📋 Creating follow-up for task ##{task_num}:"
        puts "Title: #{task.title}"
        puts "Status: #{task.status == 'completed' ? 'Completed' : 'Incomplete'}"
        if task.notes && !task.notes.empty?
          puts "Notes: #{task.notes.split("\n").first}"  # Show first line
        end
        puts

        # Collect follow-up information
        print "What are you expecting to receive? (e.g., 'Report from client', 'Approval from manager'): "
        expected_item = $stdin.gets.chomp.strip

        if expected_item.empty?
          puts "⏭️  Follow-up cancelled (no item specified)"
          next
        end

        print "From whom are you expecting it? (e.g., 'John Smith', 'Client team', 'HR department'): "
        from_whom = $stdin.gets.chomp.strip

        if from_whom.empty?
          puts "⏭️  Follow-up cancelled (no person/team specified)"
          next
        end

        # Create the follow-up task
        begin
          followup_title = "Follow up: #{expected_item}"

          # Build comprehensive notes with link to original task
          followup_notes = "📋 FOLLOW-UP TASK\n\n"
          followup_notes += "Expecting: #{expected_item}\n"
          followup_notes += "From: #{from_whom}\n"
          followup_notes += "Original task due: #{task.due ? Time.parse(task.due).strftime('%Y-%m-%d') : 'No due date'}\n"
          followup_notes += "Recap date: #{target_date.strftime('%Y-%m-%d')}\n\n"
          followup_notes += "🔗 REFERENCE\n"
          followup_notes += "Original task: \"#{task.title}\"\n"
          followup_notes += "Task ID: #{task.id}\n"
          followup_notes += "List: #{working_list_title}\n"

          if task.notes && !task.notes.empty?
            followup_notes += "\nOriginal notes:\n#{task.notes}"
          end

          # Set follow-up for appropriate time based on urgency
          if target_date == Date.today
            # If recapping today, schedule follow-up for tomorrow
            followup_due = (Date.today + 1)
            followup_time = Time.new(followup_due.year, followup_due.month, followup_due.day, 9, 0, 0).utc.strftime('%Y-%m-%dT%H:%M:%S.000Z')
          else
            # If recapping past dates, schedule for next Monday
            followup_time = next_week_monday(9).utc.strftime('%Y-%m-%dT%H:%M:%S.000Z')
          end

          # Create the follow-up task
          new_task = @client.create_task(working_list_id, followup_title,
                                       notes: followup_notes,
                                       due: followup_time)

          puts "\n✅ Follow-up task created:"
          puts "   Title: #{followup_title}"
          puts "   Due: #{Time.parse(followup_time).strftime('%A, %B %d, %Y at %H:%M')}"
          puts "   Expecting: #{expected_item} from #{from_whom}"
          puts "   ID: #{new_task.id}"

          follow_ups_created += 1

          # Step 5: Ask if original task should be marked as complete
          if task.status != 'completed'
            puts
            print "Mark original task '#{task.title}' as complete? (y/N): "
            mark_complete = $stdin.gets.chomp.strip.downcase

            if mark_complete == 'y' || mark_complete == 'yes'
              begin
                @client.complete_task(working_list_id, task.id)
                puts "✅ Original task marked as complete"
                tasks_completed += 1
              rescue => complete_error
                puts "❌ Error completing task: #{complete_error.message}"
              end
            else
              puts "⏭️  Original task remains incomplete"
            end
          else
            puts "ℹ️  Original task already marked as complete"
          end

        rescue => e
          puts "❌ Error creating follow-up task: #{e.message}"
        end
      end

      # Summary
      puts "\n" + "=" * 60
      puts "🎉 Recap completed!"
      puts "Selected tasks: #{selected_numbers.length}"
      puts "Follow-ups created: #{follow_ups_created}"
      puts "Tasks marked complete: #{tasks_completed}"

      if follow_ups_created > 0
        puts "\n💡 Tips for managing follow-ups:"
        puts "• Use 'search follow' to find all follow-up tasks"
        puts "• Review follow-ups regularly to stay on top of delegated work"
      end
      puts

    rescue => e
      puts "Error during recap workflow: #{e.message}"
      puts e.backtrace.first(3).join("\n") if ENV['DEBUG']
    end
  end

  def debug_task_in_current_list(args)
    return puts "Usage: debug <task_id_or_number>" if args.nil? || args.empty?

    task_id = resolve_task_id(args)
    puts "Resolved task ID: #{task_id}"
    return unless task_id

    begin
      puts "Fetching detailed task information..."
      task = @client.get_task(@current_list[:id], task_id)

      puts "\n=== COMPLETE TASK ANALYSIS ==="
      puts "Task ID: #{task.id}"
      puts "Title: #{task.title}"
      puts "Status: #{task.status}"
      puts "Notes: #{task.notes || '(none)'}"
      puts "Due: #{task.due || '(none)'}"
      puts "Completed: #{task.completed || '(none)'}"
      puts "Updated: #{task.updated || '(none)'}"
      puts

      puts "=== TASK OBJECT DETAILS ==="
      puts "Class: #{task.class}"
      puts

      puts "=== ALL AVAILABLE METHODS ==="
      relevant_methods = task.methods.select { |m| !m.to_s.start_with?('_') && m.to_s.length < 20 }
      relevant_methods.sort.each { |method| puts "  #{method}" }
      puts

      puts "=== INSTANCE VARIABLES ==="
      task.instance_variables.each do |var|
        value = task.instance_variable_get(var)
        puts "  #{var}: #{value.inspect}"
      end
      puts

      puts "=== TASK AS HASH ==="
      if task.respond_to?(:to_h)
        task.to_h.each do |key, value|
          puts "  #{key}: #{value.inspect}"
        end
      else
        puts "Task doesn't respond to :to_h"
      end
      puts

      puts "=== RAW INSPECTION ==="
      puts task.inspect
      puts "=========================="

    rescue => e
      puts "Error debugging task: #{e.message}"
      puts e.backtrace.first(3).join("\n") if ENV['DEBUG']
    end
  end

  private

  def login_command
    puts "🔐 Forcing re-authentication with Google..."
    puts "This will clear stored tokens and prompt for fresh OAuth login."
    puts
    
    begin
      # Force re-authentication by calling the private authenticate method with force_reauth
      @client.send(:authenticate, true)
      puts "✅ Re-authentication completed successfully!"
      puts "You can now use all Google Tasks and Google Calendar features."
      
      # Clear the current context since we've refreshed auth
      if @current_context == :list
        puts "📋 Refreshing list context..."
        # Re-fetch the current list to ensure we have fresh data
        current_list_id = @current_list[:id]
        fresh_list = @client.get_task_list(current_list_id)
        @current_list = { id: fresh_list.id, title: fresh_list.title }
        puts "✅ List context refreshed: #{fresh_list.title}"
      end
      
    rescue => e
      puts "❌ Authentication failed: #{e.message}"
      puts "Make sure you have:"
      puts "1. Valid oauth_credentials.json file"
      puts "2. Internet connection"
      puts "3. Access to a web browser for OAuth flow"
    end
  end

  def logout_command
    puts "🚪 Logging out and clearing stored tokens..."
    
    begin
      @client.logout
      puts "✅ Logout completed successfully!"
      
      # Clear current list context since we're logged out
      if @current_context == :list
        puts "📋 Exiting list context due to logout."
        @current_context = nil
        @current_list = nil
      end
      
      puts "Use 'login' to re-authenticate when ready."
      
    rescue => e
      puts "❌ Error during logout: #{e.message}"
    end
  end

  def parse_custom_time(input, base_date = Date.today)
    # Parse time input like "14:30", "2:30 PM", "14", etc.
    return nil unless input
    
    # Remove common variations and normalize
    time_str = input.strip.downcase
    
    # Match patterns like "14:30", "2:30", "14", "2"
    if time_str.match(/^(\d{1,2})(?::(\d{2}))?(?:\s*(am|pm))?$/)
      hour = $1.to_i
      minute = $2 ? $2.to_i : 0
      ampm = $3
      
      # Handle AM/PM
      if ampm == 'pm' && hour != 12
        hour += 12
      elsif ampm == 'am' && hour == 12
        hour = 0
      end
      
      # Validate hour and minute
      return nil unless (0..23).include?(hour) && (0..59).include?(minute)
      
      # Create time object for today
      Time.new(base_date.year, base_date.month, base_date.day, hour, minute, 0)
    else
      nil
    end
  end

  def get_duration_choice
    puts "\nSelect duration for this task:"
    puts "1. 15 minutes"
    puts "2. 30 minutes (default)"
    puts "3. 1 hour"
    puts "4. Cancel"
    print "Choose duration (1-4): "
    
    choice = $stdin.gets.chomp.strip
    
    case choice
    when '1'
      15
    when '2', ''
      30
    when '3'
      60
    when '4'
      nil
    else
      puts "Invalid choice, using default 30 minutes"
      30
    end
  end

  def extract_priority_from_notes(notes)
    return nil unless notes

    case notes
    when /🔥/
      '🔥Hot'
    when /🟢/
      '🟢Must'
    when /🟠/
      '🟠Nice'
    when /🔴/
      '🔴NotNow'
    else
      nil
    end
  end

  def extract_category_from_notes(notes)
    return 'No Category' unless notes

    case notes
    when /🧩/
      '🧩Product'
    when /📈/
      '📈Business'
    when /📢/
      '📢Marketing'
    when /🔒/
      '🔒Security'
    when /💰/
      '💰Finance'
    when /💳/
      '💳Sales'
    when /🎧/
      '🎧Support'
    when /👩‍💼/
      '👩‍💼Others'
    else
      'No Category'
    end
  end

  def group_tasks_by_category_and_priority(tasks)
    # Group tasks by category first
    grouped = {}

    tasks.each do |task|
      category = extract_category_from_notes(task.notes)
      priority = extract_priority_from_notes(task.notes) || 'No Priority'

      grouped[category] ||= {}
      grouped[category][priority] ||= []
      grouped[category][priority] << task
    end

    # Sort categories by priority weight (highest priority category first)
    sorted_grouped = grouped.sort_by do |category, priority_groups|
      # Calculate the highest priority weight in this category
      max_weight = priority_groups.keys.map { |p| get_priority_weight_from_text(p) }.max || 0
      -max_weight  # Negative for descending order
    end.to_h

    sorted_grouped
  end

  def get_priority_weight_from_text(priority_text)
    case priority_text
    when '🔥Hot'
      4
    when '🟢Must'
      3
    when '🟠Nice'
      2
    when '🔴NotNow'
      1
    else
      0  # No priority
    end
  end

  def build_category_event_description(tasks, category)
    description = "🏷️  Category: #{category}\n"
    description += "📋 Tasks in this block (#{tasks.length}):\n\n"

    tasks.each_with_index do |task, idx|
      priority_emoji = extract_priority_from_notes(task.notes)
      priority_text = priority_emoji || "○"
      description += "#{idx + 1}. #{priority_text} #{task.title}\n"
    end

    description += "\n⏰ Estimated time: #{tasks.length * 30} minutes (30 min per task)\n"
    description += "\n💡 Created by GTD Task Manager - Category Time Blocking"
    description
  end

  def create_category_calendar_event(title, start_time, end_time, description, list_id)
    @calendar_client.ensure_authenticated

    event = Google::Apis::CalendarV3::Event.new
    event.summary = title
    event.description = description

    # Set start time - use UTC format
    event.start = Google::Apis::CalendarV3::EventDateTime.new
    event.start.date_time = start_time.utc.strftime('%Y-%m-%dT%H:%M:%S.000Z')

    # Set end time - use UTC format
    event.end = Google::Apis::CalendarV3::EventDateTime.new
    event.end.date_time = end_time.utc.strftime('%Y-%m-%dT%H:%M:%S.000Z')

    event.color_id = '10'  # Green color for category blocks

    calendar_service = Google::Apis::CalendarV3::CalendarService.new
    calendar_service.authorization = @calendar_client.instance_variable_get(:@service).authorization

    result = calendar_service.insert_event('primary', event)
    puts "Created category calendar event: #{result.html_link}" if ENV['DEBUG']
    result
  end

  def sort_tasks_by_priority(tasks)
    # Sort by priority: Hot > Must > Nice > NotNow > No priority
    tasks.sort do |a, b|
      priority_a = get_priority_weight(a.notes)
      priority_b = get_priority_weight(b.notes)
      
      # Higher weight = higher priority (appears first)
      priority_b <=> priority_a
    end
  end

  def get_priority_weight(notes)
    return 0 unless notes
    
    case notes
    when /🔥/  # Hot
      4
    when /🟢/  # Must
      3
    when /🟠/  # Nice
      2
    when /🔴/  # NotNow
      1
    else
      0  # No priority
    end
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

  def review_task_by_object(task)
    puts "Reviewing task: #{task.title}"
    puts "Current notes: #{task.notes || '(empty)'}" if ENV['DEBUG']
    puts

    # Select priority
    priority = select_priority
    return if priority.nil?

    # Select department
    department = select_department
    
    # Update task with new classification
    update_task_classification(task, priority, department, task.id)
  end

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
    puts "  9. Mark as completed"
    puts " 10. Skip this task"
    puts
    print "Enter your choice (1-10): "

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
      # Mark as completed
      :complete
    when '10'
      # Skip
      :cancel
    else
      puts "Invalid choice. Please select 1-10."
      select_planning_date
    end
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

  def parse_recap_date(date_arg)
    case date_arg&.strip&.downcase
    when nil, '', 'today'
      Date.today
    when 'yesterday'
      Date.today - 1
    else
      begin
        Date.parse(date_arg)
      rescue ArgumentError
        puts "❌ Invalid date format: #{date_arg}"
        puts "Supported formats: 'today', 'yesterday', or YYYY-MM-DD (e.g., 2025-01-15)"
        return nil
      end
    end
  end

  def next_week_monday(hour = 9)
    today = Date.today
    current_wday = today.wday # 0=Sunday, 1=Monday, ..., 6=Saturday

    # Calculate days to next Monday
    if current_wday == 0 # Sunday
      days_to_add = 1
    else
      days_to_add = 8 - current_wday # Days until next Monday
    end

    target_date = today + days_to_add
    Time.new(target_date.year, target_date.month, target_date.day, hour, 0, 0)
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
    when 'login', 'auth'
      login_command
    when 'logout'
      logout_command
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
    when 'grooming'
      if @current_context == :list
        grooming_workflow(@current_list[:id])
      else
        puts "Error: No list context set. Use 'use <list_name>' first."
      end
    when 'agenda'
      if @current_context == :list
        agenda_workflow(@current_list[:id])
      else
        puts "Error: No list context set. Use 'use <list_name>' first."
      end
    when 'debug'
      if @current_context == :list
        debug_task_in_current_list(args)
      else
        puts "Error: No list context set. Use 'use <list_name>' first."
      end
    when 'recap'
      if @current_context == :list
        recap_workflow(@current_list[:id], args)
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
    puts "  login, auth            - Force re-authentication with Google"
    puts "  logout                 - Clear stored authentication tokens"
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
      puts "  agenda                 - Category-based time-blocking with 2-minute rule filtering"
      puts "  grooming               - GTD workflow: review unclassified tasks then schedule all overdue/unscheduled tasks"
      puts "  recap [date]           - Review day's tasks (completed/incomplete), select tasks by number for follow-ups (today/yesterday/YYYY-MM-DD)"
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
      puts "  agenda                 - Category-based time-blocking with 2-minute rule filtering"
      puts "  grooming               - GTD workflow: review unclassified tasks then schedule all overdue/unscheduled tasks"
      puts "  recap [date]           - Review day's tasks (completed/incomplete), select tasks by number for follow-ups (today/yesterday/YYYY-MM-DD)"
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
    puts "  5. 💰 Finance - Financial/accounting tasks"
    puts "  6. 💳 Sales - Sales and revenue tasks"
    puts "  7. 🎧 Support - Customer support tasks"
    puts "  8. 👩‍💼 Others - General/administrative tasks"
    puts "  9. None - Skip department classification"
    puts
    print "Enter department number (1-9): "
    
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
      '💰Finance'
    when '6'
      '💳Sales'
    when '7'
      '🎧Support'
    when '8'
      '👩‍💼Others'
    when '9'
      nil
    else
      puts "Invalid choice. Please enter 1-9."
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
      /💰Finance\s*/,
      /💳Sales\s*/,
      /🎧Support\s*/,
      /👩‍💼Others\s*/
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
    
    # Build single line display with task info
    line = "  #{number}. #{status_icon} #{task.title}"
    
    # Add notes inline if present (shortened)
    if task.notes && !task.notes.empty?
      # Extract first priority/classification for compact display
      first_line = task.notes.split("\n").first
      if first_line && first_line.length <= 30
        line += " [#{first_line}]"
      else
        # Show truncated notes
        notes_preview = first_line ? first_line[0..25] + "..." : task.notes[0..25] + "..."
        line += " [#{notes_preview}]"
      end
    end
    
    # Add due date inline if present
    if task.due
      due_time = task.due.include?('T') ? 
        Time.parse(task.due).strftime('%m/%d %H:%M') : 
        Time.parse(task.due).strftime('%m/%d')
      line += " (Due: #{due_time})"
    end
    
    puts line
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