# Claude Code Instructions for Tasker Project

## Project Overview
This is a Ruby-based Google Tasks client that implements Getting Things Done (GTD) methodology with interactive and console modes.

## Key Features Implemented

### Interactive Commands
- `lists` - Show all task lists
- `use <list_name>` - Set current list context
- `tasks` - Show tasks in current list
- `create <title>` - Create new task
- `complete <task_id>` - Mark task completed
- `delete <task_id>` - Delete task
- `show <task_id>` - Show full task details
- `edit <task_id>` - Edit task title, notes, due date
- `search <text>` - Search uncompleted tasks containing text
- `plan <task_id>` - Quickly schedule task (today, tomorrow, next week, etc.)
- `review <task_id>` - Review and classify task with priority/department
- `agenda` - **NEW**: Time-block today's tasks in 30-min slots starting from now (ordered by priority)
- `grooming` - **NEW**: GTD workflow for reviewing and scheduling tasks

### Console Commands
- `./bin/tasker lists`
- `./bin/tasker tasks LIST_ID`
- `./bin/tasker agenda LIST_ID` - **NEW**: Time-block today's tasks in 30-minute slots
- `./bin/tasker grooming LIST_ID` - **NEW**: GTD grooming workflow

## NEW: Hybrid Agenda Time-Blocking Feature

### What it does
The `agenda` command implements a hybrid GTD approach combining Google Tasks + Google Calendar:

1. **Finds today's tasks**: All uncompleted tasks with due date = today
2. **Priority sorting**: Automatically orders tasks by priority (🔥Hot → 🟢Must → 🟠Nice → 🔴NotNow → No priority)  
3. **Hybrid scheduling**: 
   - 📋 **Google Tasks**: Keeps tasks clean with today's due date (no time pollution)
   - 📅 **Google Calendar**: Creates time-blocked events for precise scheduling
4. **Interactive time-blocking**: User confirms each 30-minute time slot
5. **Dual-system agenda**: Tasks for completion tracking, calendar for time awareness

### Usage Examples

**Interactive Mode:**
```bash
# After selecting a list with 'use <list_name>'
agenda
```

**Console Mode:**
```bash
./bin/tasker agenda LIST_ID
```

### Expected Output Flow
```
📅 Starting Daily Agenda Time-Blocking
List: My Task List
============================================================

📋 Gathering today's tasks...
Found 4 tasks for today:
  1. ○ Review quarterly report
  2. 🔥Hot Prepare presentation
  3. 🟢Must Call client meeting
  4. 🟠Nice Update documentation

📊 Tasks ordered by priority:
  1. 🔥Hot Prepare presentation
  2. 🟢Must Call client meeting  
  3. ○ Review quarterly report
  4. 🟠Nice Update documentation

⏰ Scheduling tasks in 30-minute time blocks starting from 14:30
------------------------------------------------------------

📋 Time Slot 1: 14:30-15:00
Task: 🔥Hot Prepare presentation
Classification: 🔥Hot 🧩Product
Schedule this task for 14:30-15:00? (y/n/s=skip): y
Creating calendar event for time slot...
✅ Scheduled: Prepare presentation
   📋 Google Tasks: Due today
   📅 Google Calendar: 14:30-15:00

📋 Time Slot 2: 15:00-15:30
Task: 🟢Must Call client meeting
Schedule this task for 15:00-15:30? (y/n/s=skip): y
Creating calendar event for time slot...
✅ Scheduled: Call client meeting
   📋 Google Tasks: Due today  
   📅 Google Calendar: 15:00-15:30

================================================================================
📅 TODAY'S HYBRID AGENDA SUMMARY
================================================================================
📋 Google Tasks: All scheduled tasks are due today
📅 Google Calendar: Time-blocked schedule below

14:30-15:00 | 🔥Hot Prepare presentation 📅
15:00-15:30 | 🟢Must Call client meeting 📅

🎯 Hybrid approach activated! 2 tasks scheduled.
📋 Tasks remain in Google Tasks (clean, no time pollution)
📅 Calendar events created for precise time-blocking
💡 Tip: Use your calendar for time awareness, tasks for completion tracking
```

## NEW: Grooming Workflow Feature

### What it does
The `grooming` command implements a complete Getting Things Done workflow that:

1. **Finds tasks needing attention**: All uncompleted tasks that are either:
   - Past due date, OR
   - Have no due date

2. **Review Phase** (for unclassified tasks):
   - Identifies tasks with empty notes or no priority/department emojis
   - Forces user to review each unclassified task
   - Applies priority (🔥Hot, 🟢Must, 🟠Nice, 🔴NotNow) 
   - Applies department (🧩Product, 📈Business, 📢Marketing, 🔒Security, 👩‍💼Others)

3. **Planning Phase** (for all tasks):
   - Goes through all grooming tasks in creation date order
   - Shows current classification and due date status
   - Provides quick scheduling options:
     - Today, Tomorrow
     - Next Monday through Friday
     - Remove current date
     - Skip this task

### Usage Examples

**Interactive Mode:**
```bash
# After selecting a list with 'use <list_name>'
grooming
```

**Console Mode:**
```bash
./bin/tasker grooming LIST_ID
```

### Expected Output Flow
```
🧹 Starting GTD Grooming Workflow
List: My Task List
============================================================

📋 Gathering tasks for grooming...
Found 5 tasks needing grooming:
  1. Unscheduled task (No due date)
  2. Overdue task (Overdue)
  ...

📝 REVIEW PHASE: 2 tasks need review first
----------------------------------------

🔍 Reviewing task 1 of 2:
Title: Unscheduled task
Notes: (empty)

[Priority and department selection follows]
✅ Review completed for: Unscheduled task

📅 PLANNING PHASE: Scheduling 5 tasks
----------------------------------------

📋 Planning task 1 of 5:
Title: Unscheduled task
Classification: 🟢Must 📈Business
Current due date: (none)

[Scheduling options follow]
✅ Scheduled for: Friday, August 22, 2025 at 09:00

🎉 GTD Grooming completed!
All 5 tasks have been processed.
```

## Authentication Requirements

The hybrid agenda feature requires both Google Tasks and Google Calendar API access:

1. **Google Tasks API**: Already configured with existing OAuth setup
2. **Google Calendar API**: Uses the same OAuth credentials and token file
3. **Scopes**: The application now requests both Tasks and Calendar permissions
4. **First-time setup**: User may need to re-authenticate to grant Calendar access

## Testing Guidelines

**⚠️ IMPORTANT**: Never create automated tests that run against real Google Tasks data. This would modify the user's actual tasks and compromise privacy.

**For testing grooming:**
1. User should manually run: `ruby bin/tasker interactive` or `ruby bin/tasker grooming LIST_ID`  
2. User can test with their own disposable task lists
3. Verify the workflow phases work correctly:
   - Task identification (overdue + no due date)
   - Review phase for unclassified tasks
   - Planning phase for all tasks
   - Proper context switching and data preservation

## Debug Mode
Set `DEBUG=1` environment variable to see detailed API calls and internal state.

## Architecture Notes
- `lib/google_tasks_client.rb` - Google Tasks API wrapper
- `lib/interactive_mode.rb` - Interactive shell and workflows
- `bin/tasker` - Console interface
- All grooming logic preserves task titles and notes while updating classifications and due dates
- Uses RFC3339 format for Google Tasks API dates
- Auto-schedules tasks at 9:00 AM for consistency