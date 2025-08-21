# Google Tasks Client

A Ruby client for managing Google Tasks with a command-line interface using OAuth authentication.

## Setup

1. Install dependencies:
   ```bash
   bundle install
   ```

2. Set up Google OAuth credentials:
   - Go to the [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select an existing one
   - Enable the Google Tasks API (search for "Tasks API" and click "Enable")
   - Go to "Credentials" → "Create Credentials" → "OAuth client ID"
   - If prompted, configure the OAuth consent screen first
   - Choose "Desktop application" as the application type
   - Add `http://localhost:9090/oauth2callback` as an authorized redirect URI
   - Download the JSON credentials file
   - Save the credentials file as `oauth_credentials.json` in the project root
   - See `oauth_credentials.json.example` for the expected format

3. Authentication:
   ```bash
   # Run the login command to authenticate (only needed once)
   ./bin/tasker login
   ```
   - This will open your browser for Google OAuth login
   - Sign in with your Google account and grant permissions to access Google Tasks
   - Copy the authorization code and paste it in the terminal
   - Both access and refresh tokens will be saved locally in `token.yaml`
   - Future commands will automatically use stored tokens and refresh them as needed

4. Usage after setup:
   ```bash
   # Subsequent commands will use stored tokens automatically
   ./bin/tasker lists
   ./bin/tasker create-list "My Tasks"
   
   # If you need to re-authenticate or switch accounts
   ./bin/tasker logout  # Clears stored tokens
   ./bin/tasker login   # Re-authenticate
   ```

## Usage

### Command Line Interface

All commands support the `--credentials` option to specify a custom OAuth credentials file path.

```bash
# First time: login with OAuth (stores tokens for future use)
./bin/tasker login

# All subsequent commands use stored tokens automatically
./bin/tasker lists

# Show only first 5 task lists
./bin/tasker lists --limit 5

# Use custom credentials file
./bin/tasker lists --credentials /path/to/my_credentials.json

# Create a new task list
./bin/tasker create-list "My Tasks"

# Show tasks in a list (replace LIST_ID with actual ID) - shows ALL tasks automatically
./bin/tasker tasks LIST_ID

# Show completed tasks too
./bin/tasker tasks LIST_ID --completed

# Limit number of tasks shown
./bin/tasker tasks LIST_ID --limit 20

# Start interactive mode for easier task management
./bin/tasker interactive

# Create a new task
./bin/tasker create-task LIST_ID "Buy groceries"

# Create a task with notes and due date
./bin/tasker create-task LIST_ID "Submit report" --notes "Include Q4 data" --due "2024-01-15"

# Mark a task as completed
./bin/tasker complete-task LIST_ID TASK_ID

# Update a task
./bin/tasker update-task LIST_ID TASK_ID --title "New title" --notes "Updated notes"

# Delete a task
./bin/tasker delete-task LIST_ID TASK_ID

# Delete a task list
./bin/tasker delete-list LIST_ID
```

### Interactive Mode

The interactive mode provides a more efficient way to manage tasks by maintaining context:

```bash
./bin/tasker interactive
```

**Interactive Commands:**
- `help` - Show available commands
- `lists` - List all task lists  
- `use <list_name_or_number>` - Switch to a specific list context
- `exit-list` - Exit current list context
- `exit` or `quit` - Exit interactive mode

**List Context Commands (when inside a list):**
- `tasks [--completed]` - Show tasks in current list
- `create <title>` - Create a new task
- `complete <task_id_or_number>` - Mark task as completed
- `delete <task_id_or_number>` - Delete a task

**Example Interactive Session:**
```
> lists
Available task lists:
  1. ⭐️ CEO - Jose
  2. Readings
  3. Backlog

> use 1
Switched to list context: ⭐️ CEO - Jose

[⭐️ CEO - Jose] > tasks
Tasks in ⭐️ CEO - Jose: (73 total)
  1. ○ Check if julia fixed invoices
  2. ○ RevTech Labs Capital Standard Term Sheet

[⭐️ CEO - Jose] > create "Review quarterly report"
Created task: Review quarterly report

[⭐️ CEO - Jose] > complete 1
Completed task: Check if julia fixed invoices

[⭐️ CEO - Jose] > exit-list
Exited list context: ⭐️ CEO - Jose

> exit
Goodbye!
```

### Ruby API

```ruby
require_relative 'lib/google_tasks_client'

# Initialize client with default OAuth credentials
client = GoogleTasksClient.new

# Or specify custom OAuth credentials file
client = GoogleTasksClient.new('path/to/oauth_credentials.json')

# List all task lists
task_lists = client.list_task_lists

# Create a new task list
new_list = client.create_task_list('My New List')

# List tasks
tasks = client.list_tasks(list_id)

# Create a task
task = client.create_task(list_id, 'Task title', notes: 'Optional notes')

# Complete a task
client.complete_task(list_id, task_id)

# Update a task
client.update_task(list_id, task_id, title: 'New title')

# Delete a task
client.delete_task(list_id, task_id)
```

## Features

- Full CRUD operations for task lists and tasks
- OAuth 2.0 authentication with automatic browser launch
- Persistent token storage - login once, use forever
- Automatic token refresh when expired
- **Automatic pagination - handles hundreds/thousands of tasks seamlessly**
- **Interactive mode with context switching for efficient task management**
- Command-line interface with Thor
- Error handling and validation
- Support for task notes and due dates
- Mark tasks as completed
- Logout command to clear stored tokens
- Optional result limiting for large lists

## Files Created

- `oauth_credentials.json` - Your OAuth client credentials (download from Google Cloud Console)
- `token.yaml` - Stored access/refresh tokens (created automatically after first login)

## Dependencies

- `google-apis-tasks_v1` - Google Tasks API client
- `googleauth` - Google OAuth authentication
- `thor` - CLI framework
- `launchy` - Automatic browser launching for OAuth flow