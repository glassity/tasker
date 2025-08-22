# Google Tasks Client - GTD Task Manager

A Ruby-based Google Tasks client implementing Getting Things Done (GTD) methodology with comprehensive task management features, interactive mode, and automated workflows.

## 🚀 Features

- **Full GTD Implementation** - Complete Getting Things Done workflow with grooming, review, and planning
- **Interactive Mode** - Context-aware shell for efficient task management
- **Smart Scheduling** - Quick date selection (today, tomorrow, next week)
- **Task Classification** - Priority and department-based organization
- **Search & Filter** - Find tasks across all content
- **OAuth Authentication** - Secure Google account integration
- **Automatic Pagination** - Handles thousands of tasks seamlessly

## 📋 Setup

### 1. Install Dependencies
```bash
bundle install
```

### 2. Google OAuth Setup
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create/select project and enable **Google Tasks API**
3. Create **OAuth client ID** credentials (Desktop application)
4. Add `http://localhost:9090/oauth2callback` as redirect URI
5. Download JSON file as `oauth_credentials.json` in project root

### 3. Authentication
```bash
# First-time login (opens browser)
./bin/tasker login

# All subsequent commands use stored tokens automatically
./bin/tasker lists
```

## 🎯 Getting Things Done (GTD) Workflow

### Grooming Command - Complete GTD Workflow

The `grooming` command is the centerpiece of the GTD implementation, automatically organizing your task backlog.

**What it does:**
1. **Finds tasks needing attention** - All uncompleted tasks that are overdue or have no due date
2. **Review Phase** - Forces classification of unreviewed tasks with priority/department
3. **Planning Phase** - Schedules all tasks with quick date selection

#### Interactive Mode:
```bash
./bin/tasker interactive
> use "My Tasks"
> grooming
```

#### Console Mode:
```bash
./bin/tasker grooming LIST_ID
```

#### Example Grooming Session:
```
🧹 Starting GTD Grooming Workflow
List: ⭐️ CEO Tasks
============================================================

📋 Gathering tasks for grooming...
Found 8 tasks needing grooming:
  1. Prepare quarterly report (No due date)
  2. Call client about project (Overdue)
  3. Review team feedback (No due date)
  ...

📝 REVIEW PHASE: 3 tasks need review first
----------------------------------------

🔍 Reviewing task 1 of 3:
Title: Prepare quarterly report
Notes: (empty)

Select Priority:
  1. 🔥 Hot - Urgent/critical tasks
  2. 🟢 Must - Important/required tasks  
  3. 🟠 Nice - Nice to have/optional tasks
  4. 🔴 NotNow - Deferred/not current priority

Enter priority number (1-4): 2

Select Department:
  1. 🧩 Product - Product development tasks
  2. 📈 Business - Business operations/strategy
  3. 📢 Marketing - Marketing and promotion
  4. 🔒 Security - Security/compliance tasks
  5. 👩‍💼 Others - General/administrative tasks
  6. None - Skip department classification

Enter department number (1-6): 2

✅ Review completed for: Prepare quarterly report

📅 PLANNING PHASE: Scheduling 8 tasks
----------------------------------------

📋 Planning task 1 of 8:
Title: Prepare quarterly report
Classification: 🟢Must 📈Business
Current due date: (none)

Select when to schedule this task:
  1. Today
  2. Tomorrow
  3. Next Monday
  4. Next Tuesday
  5. Next Wednesday
  6. Next Thursday
  7. Next Friday
  8. Remove current date
  9. Skip this task

Enter your choice (1-9): 5
✅ Scheduled for: Wednesday, August 27, 2025 at 09:00

🎉 GTD Grooming completed!
All 8 tasks have been processed.
```

## 💻 Interactive Mode

Launch interactive mode for the best task management experience:

```bash
./bin/tasker interactive
```

### Global Commands
| Command | Description | Example |
|---------|-------------|---------|
| `help` | Show available commands | `help` |
| `lists` | List all task lists | `lists` |
| `use <list_name/number>` | Switch to list context | `use "My Tasks"` or `use 1` |
| `exit-list` | Exit current list context | `exit-list` |
| `exit` / `quit` | Exit interactive mode | `exit` |

### List Context Commands
*Available when you've selected a list with `use`*

| Command | Description | Example |
|---------|-------------|---------|
| `tasks [--completed] [--limit N]` | Show tasks in current list | `tasks --limit 10` |
| `create <title>` | Create new task | `create "Review documentation"` |
| `complete <task_id/number>` | Mark task completed | `complete 1` |
| `delete <task_id/number>` | Delete task | `delete 2` |
| `show <task_id/number>` | Show full task details | `show 1` |
| `edit <task_id/number>` | Edit task (title, notes, due date) | `edit 3` |
| `search <text>` | Search uncompleted tasks | `search "report"` |
| `plan <task_id/number>` | Quick schedule task | `plan 1` |
| `review <task_id/number>` | Classify task priority/department | `review 2` |
| `grooming` | **GTD workflow** - review & schedule tasks | `grooming` |

### Interactive Examples

#### Basic Task Management:
```bash
> lists
Available task lists:
  1. 📋 Personal Tasks
  2. 💼 Work Projects  
  3. 🛒 Shopping List

> use 2
Switched to list context: 💼 Work Projects

[💼 Work Projects] > tasks
Tasks in 💼 Work Projects: (12 total)
  1. ○ Finish project proposal
  2. ○ Schedule team meeting
  3. ✓ Update documentation

[💼 Work Projects] > create "Prepare presentation slides"
Created task: Prepare presentation slides (ID: abc123)

[💼 Work Projects] > plan 4
Planning task: Prepare presentation slides
Current due date: (none)

Select when to schedule this task:
  1. Today
  2. Tomorrow
  3. Next Monday
...
Enter your choice (1-9): 7
Task scheduled for: Friday, August 29, 2025 at 09:00
```

#### Task Review & Classification:
```bash
[💼 Work Projects] > review 1
Reviewing task: Finish project proposal

Select Priority:
  1. 🔥 Hot - Urgent/critical tasks
  2. 🟢 Must - Important/required tasks
...
Enter priority number (1-4): 1

Select Department:
  1. 🧩 Product - Product development
  2. 📈 Business - Business operations
...
Enter department number (1-6): 1

Task classification updated:
Priority: 🔥Hot
Department: 🧩Product
Task updated successfully!
```

#### Search and Edit:
```bash
[💼 Work Projects] > search "presentation"
Searching for tasks containing: "presentation"
List: 💼 Work Projects

Found 2 matching tasks:
1. Prepare presentation slides
   ID: abc123
2. Review presentation feedback
   ID: def456

[💼 Work Projects] > edit 1
Editing task: Prepare presentation slides

Current values:
  Title: Prepare presentation slides
  Notes: (none)
  Due: 2025-08-29 09:00
  Status: needsAction

Title [Prepare presentation slides]: Prepare Q3 presentation slides
Notes [(none)]: Include budget analysis and team metrics
Due date (YYYY-MM-DD HH:MM or 'clear') [2025-08-29 09:00]: 

Task updated successfully!
```

## 🖥️ Console Commands

All commands support `--credentials path/to/file.json` for custom OAuth files.

### Basic Operations
```bash
# Authentication
./bin/tasker login              # First-time OAuth login
./bin/tasker logout            # Clear stored tokens

# Task Lists
./bin/tasker lists             # List all task lists
./bin/tasker lists --limit 5   # Show first 5 lists
./bin/tasker create-list "New List"  # Create task list
./bin/tasker delete-list LIST_ID     # Delete task list

# Tasks
./bin/tasker tasks LIST_ID                    # Show all tasks
./bin/tasker tasks LIST_ID --completed        # Include completed
./bin/tasker tasks LIST_ID --limit 20         # Limit results

# Task Management
./bin/tasker create-task LIST_ID "Task title"
./bin/tasker create-task LIST_ID "Task title" --notes "Details" --due "2025-01-15"
./bin/tasker complete-task LIST_ID TASK_ID
./bin/tasker update-task LIST_ID TASK_ID --title "New title" --notes "Updated"
./bin/tasker delete-task LIST_ID TASK_ID

# GTD Workflow
./bin/tasker grooming LIST_ID    # Complete GTD grooming workflow
./bin/tasker interactive         # Launch interactive mode
```

## 🏗️ Ruby API

```ruby
require_relative 'lib/google_tasks_client'

# Initialize
client = GoogleTasksClient.new
# or: client = GoogleTasksClient.new('custom_credentials.json')

# Task Lists
task_lists = client.list_task_lists
new_list = client.create_task_list('My List')
client.delete_task_list(list_id)

# Tasks
tasks = client.list_tasks(list_id)
tasks_with_completed = client.list_tasks(list_id, show_completed: true)

# Task Operations
task = client.create_task(list_id, 'Title', notes: 'Notes', due: '2025-01-15T10:00:00.000Z')
client.update_task(list_id, task_id, title: 'New Title', notes: 'Updated')
client.complete_task(list_id, task_id)
client.delete_task(list_id, task_id)

# Get specific task
task = client.get_task(list_id, task_id)
```

## 🎨 Task Classification System

### Priority Levels
- **🔥 Hot** - Urgent/critical tasks requiring immediate attention
- **🟢 Must** - Important/required tasks that must be completed
- **🟠 Nice** - Nice to have/optional tasks when time permits
- **🔴 NotNow** - Deferred tasks not currently prioritized

### Department Categories
- **🧩 Product** - Product development and feature work
- **📈 Business** - Business operations, strategy, and growth
- **📢 Marketing** - Marketing, promotion, and outreach
- **🔒 Security** - Security, compliance, and risk management
- **👩‍💼 Others** - General administrative and miscellaneous tasks

## ⚡ Quick Planning Options

When using `plan` or during `grooming`, choose from:
1. **Today** - Schedule for today at 9:00 AM
2. **Tomorrow** - Schedule for tomorrow at 9:00 AM
3. **Next Monday-Friday** - Schedule for next occurrence at 9:00 AM
4. **Remove current date** - Clear existing due date
5. **Skip** - Leave unchanged (grooming only)

*Smart weekday logic: If it's already the target weekday after 9 AM, schedules for the following week.*

## 🗂️ Files Structure

```
tasker/
├── oauth_credentials.json    # Google OAuth credentials (you provide)
├── token.yaml               # Stored access tokens (auto-created)
├── CLAUDE.md                # Development instructions
├── lib/
│   ├── google_tasks_client.rb   # Google Tasks API wrapper
│   └── interactive_mode.rb      # Interactive shell & GTD workflows
└── bin/
    └── tasker               # Main CLI executable
```

## 🔍 Debug Mode

Enable detailed logging for troubleshooting:
```bash
DEBUG=1 ./bin/tasker interactive
DEBUG=1 ./bin/tasker grooming LIST_ID
```

## 📦 Dependencies

- **google-apis-tasks_v1** - Google Tasks API client
- **googleauth** - Google OAuth 2.0 authentication  
- **thor** - CLI framework for console commands
- **launchy** - Browser automation for OAuth flow

## 🎯 GTD Methodology

This application implements core Getting Things Done principles:

1. **Capture** - Quickly create tasks with `create` command
2. **Clarify** - Use `review` to classify tasks with priority/department
3. **Organize** - `grooming` workflow systematically processes backlogs
4. **Reflect** - `search` and filtered `tasks` views for regular review
5. **Engage** - `plan` command for quick scheduling and execution

The `grooming` workflow ensures no task falls through the cracks by forcing review of unclassified items and scheduling of all overdue/unscheduled tasks in a single session.

---

**Happy Task Management! 🎉**