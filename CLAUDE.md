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
- `grooming` - **NEW**: GTD workflow for reviewing and scheduling tasks

### Console Commands
- `./bin/tasker lists`
- `./bin/tasker tasks LIST_ID`
- `./bin/tasker grooming LIST_ID` - **NEW**: GTD grooming workflow

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