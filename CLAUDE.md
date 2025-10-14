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
- `agenda` - **NEW**: Category-based time-blocking with 2-minute rule filtering
- `grooming` - **NEW**: GTD workflow for reviewing and scheduling tasks
- `recap [date]` - **NEW**: Review day's tasks (completed/incomplete), select by number for follow-ups

### Console Commands
- `./bin/tasker lists`
- `./bin/tasker tasks LIST_ID`
- `./bin/tasker agenda LIST_ID` - **NEW**: Category-based time-blocking with batched calendar events
- `./bin/tasker grooming LIST_ID` - **NEW**: GTD grooming workflow
- `./bin/tasker recap LIST_ID [date]` - **NEW**: Review day's tasks, select by number for follow-ups

## NEW: Category-Based Agenda Time-Blocking Feature

### What it does
The `agenda` command implements a category-based GTD approach combining Google Tasks + Google Calendar:

1. **Finds today's tasks**: All uncompleted tasks with due date = today
2. **Groups by category and priority**: Organizes tasks by department (🧩Product, 📈Business, etc.) and priority within each category
3. **2-minute rule filtering**: For each task, asks if it takes less than 2 minutes; if yes, it's excluded from time-blocking
4. **Batches tasks by category**: Creates single calendar events for all tasks in each category
5. **30-minute average per task**: Calculates total time block duration (e.g., 3 tasks = 90 minutes)
6. **User-confirmed scheduling**: User specifies the start time for each category block
7. **Efficient context switching**: Groups related tasks together to minimize cognitive overhead

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
📅 Starting Category-Based Agenda Planning
List: My Task List
============================================================

📋 Gathering today's tasks...
Found 6 tasks for today.

📊 Tasks grouped by category and priority:

🧩Product:
  🔥Hot:
    1. Prepare presentation
    2. Fix critical bug
  🟢Must:
    3. Review code PR

📈Business:
  🟢Must:
    4. Call client meeting
  🟠Nice:
    5. Update quarterly report

No Category:
  No Priority:
    6. Check emails

============================================================
🏷️  Processing Category: 🧩Product
============================================================

📋 Task 1 of 3: 🔥Hot Prepare presentation
Does this take less than 2 minutes? (y/N): n
✅ Added to scheduling queue

📋 Task 2 of 3: 🔥Hot Fix critical bug
Does this take less than 2 minutes? (y/N): n
✅ Added to scheduling queue

📋 Task 3 of 3: 🟢Must Review code PR
Does this take less than 2 minutes? (y/N): y
⏭️  Task takes less than 2 minutes - ignoring for time-blocking

📅 Time Block Summary for 🧩Product:
   Tasks to schedule: 2
   Total duration: 1h 0min (30 min per task)

Schedule this block starting at what time? (HH:MM or Enter for 14:30): 14:30

📅 Creating calendar event:
   Title: 2 tasks for 🧩Product
   Time: 14:30 - 15:30
   Duration: 1h 0min
✅ Calendar event created successfully!

============================================================
🏷️  Processing Category: 📈Business
============================================================

📋 Task 1 of 2: 🟢Must Call client meeting
Does this take less than 2 minutes? (y/N): n
✅ Added to scheduling queue

📋 Task 2 of 2: 🟠Nice Update quarterly report
Does this take less than 2 minutes? (y/N): n
✅ Added to scheduling queue

📅 Time Block Summary for 📈Business:
   Tasks to schedule: 2
   Total duration: 1h 0min (30 min per task)

Schedule this block starting at what time? (HH:MM or Enter for 15:30): 16:00

📅 Creating calendar event:
   Title: 2 tasks for 📈Business
   Time: 16:00 - 17:00
   Duration: 1h 0min
✅ Calendar event created successfully!

================================================================================
📅 TODAY'S CATEGORY-BASED AGENDA SUMMARY
================================================================================

14:30-15:30 | 2 tasks for 🧩Product (1h 0min)
16:00-17:00 | 2 tasks for 📈Business (1h 0min)

🎯 Category-based agenda complete! 2 time blocks created for 4 tasks.
📅 Check your Google Calendar for the scheduled blocks
💡 Tip: Each block groups related tasks by category for efficient context switching
```

### Calendar Event Details
Each category block includes:
- **Title**: "X tasks for [Category]" (e.g., "2 tasks for 🧩Product")
- **Description**:
  - Category name
  - Numbered list of all tasks with their priorities
  - Total estimated time
  - "Created by GTD Task Manager" footer
- **Color**: Green (color_id = 10) for easy identification

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

## NEW: Recap Feature for Daily Task Review

### What it does
The `recap` command implements a daily task review workflow:

1. **Shows all tasks for a specific day**: Displays both completed and incomplete tasks with due date matching the target date
2. **Selective follow-up creation**: User selects tasks by number that need follow-ups (comma-separated list)
3. **Creates follow-up tasks**: For selected items, creates new tasks with:
   - What you're expecting to receive
   - From whom you're expecting it
   - Link back to the original task
   - Automatically scheduled (tomorrow for today's recap, next Monday for past dates)
4. **Optional task completion**: After creating each follow-up, asks if the original task should be marked as complete

### Usage Examples

**Interactive Mode:**
```bash
# After selecting a list with 'use <list_name>'
recap                    # Review today's tasks
recap yesterday         # Review yesterday's tasks
recap 2025-01-15       # Review specific date's tasks
```

**Console Mode:**
```bash
./bin/tasker recap LIST_ID              # Today's tasks
./bin/tasker recap LIST_ID yesterday    # Yesterday's tasks
./bin/tasker recap LIST_ID 2025-01-15  # Specific date's tasks
```

### Expected Output Flow
```
📋 Daily Recap Review
List: My Task List
Date: Monday, September 16, 2025
============================================================

🔍 Gathering all tasks for 09/16/2025...
Found 5 tasks for this day:

  1. [✓] Complete project documentation 🟢Must
      Status: Completed
  2. [○] Wait for proposal feedback 🟢Must
      Status: Incomplete
  3. [○] Follow up on budget request 🟠Nice
      Status: Incomplete
  4. [✓] Team standup meeting
      Status: Completed
  5. [○] Review contract draft 🔥Hot
      Status: Incomplete

📝 SELECT TASKS FOR FOLLOW-UP
------------------------------------------------------------
Enter the numbers of tasks that need follow-ups (comma-separated)
Example: 1,3,5 or just press Enter to skip

Task numbers for follow-up: 2,3

============================================================
📋 Creating follow-up for task #2:
Title: Wait for proposal feedback
Status: Incomplete
Notes: 🟢Must 📈Business

What are you expecting to receive? (e.g., 'Report from client', 'Approval from manager'): Proposal feedback and decision
From whom are you expecting it? (e.g., 'John Smith', 'Client team', 'HR department'): Client ABC Corp

✅ Follow-up task created:
   Title: Follow up: Proposal feedback and decision
   Due: Tuesday, September 17, 2025 at 09:00
   Expecting: Proposal feedback and decision from Client ABC Corp
   ID: xyz123

Mark original task 'Wait for proposal feedback' as complete? (y/N): y
✅ Original task marked as complete

============================================================
📋 Creating follow-up for task #3:
Title: Follow up on budget request
Status: Incomplete

What are you expecting to receive?: Budget approval
From whom are you expecting it?: Finance team

✅ Follow-up task created:
   Title: Follow up: Budget approval
   Due: Tuesday, September 17, 2025 at 09:00
   Expecting: Budget approval from Finance team
   ID: xyz124

Mark original task 'Follow up on budget request' as complete? (y/N): n
⏭️  Original task remains incomplete

============================================================
🎉 Recap completed!
Selected tasks: 2
Follow-ups created: 2
Tasks marked complete: 1

💡 Tips for managing follow-ups:
• Use 'search follow' to find all follow-up tasks
• Review follow-ups regularly to stay on top of delegated work
```

### Follow-up Task Structure
Each follow-up task includes comprehensive notes with:
- What you're expecting
- From whom
- Original task due date
- Recap date
- Link to original task (ID and title)
- Full context from original task notes

Example follow-up task notes:
```
📋 FOLLOW-UP TASK

Expecting: Proposal feedback and decision
From: Client ABC Corp
Original task due: 2025-09-15
Recap date: 2025-09-16

🔗 REFERENCE
Original task: "Wait for proposal feedback"
Task ID: abc456
List: My Task List

Original notes:
🟢Must 📈Business
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