require 'google/apis/calendar_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'launchy'
require 'webrick'
require 'yaml'

class GoogleCalendarClient
  SCOPES = [
    'https://www.googleapis.com/auth/tasks',
    'https://www.googleapis.com/auth/calendar'
  ].freeze
  CREDENTIALS_PATH = 'oauth_credentials.json'.freeze
  TOKEN_PATH = 'token.yaml'.freeze

  def initialize(credentials_path = nil)
    @credentials_path = credentials_path || CREDENTIALS_PATH
    @service = Google::Apis::CalendarV3::CalendarService.new
    @service.client_options.application_name = 'GTD Task Manager'
  end

  def ensure_authenticated
    return if @service.authorization&.access_token

    puts "Loading shared calendar credentials from token..." if ENV['DEBUG']
    credentials = load_stored_credentials
    
    if credentials&.access_token
      @service.authorization = credentials
      puts "Calendar authentication successful using shared token!" if ENV['DEBUG']
      return
    end

    puts "No valid calendar credentials found. Please run the login command first."
    raise "Authentication required. Run './bin/tasker login' first to authenticate both Tasks and Calendar access."
  end

  # Get user's primary calendar
  def get_primary_calendar
    ensure_authenticated
    handle_api_error do
      @service.get_calendar('primary')
    end
  end

  # Create a calendar event for a task time slot
  def create_task_event(task_title, start_time, end_time, task_notes = nil, task_id = nil, list_id = nil)
    ensure_authenticated
    
    event = Google::Apis::CalendarV3::Event.new
    event.summary = "📋 #{task_title}"
    event.description = build_event_description(task_notes, task_id, list_id, task_title)
    
    # Set start time - use UTC format to avoid timezone issues
    event.start = Google::Apis::CalendarV3::EventDateTime.new
    event.start.date_time = start_time.utc.strftime('%Y-%m-%dT%H:%M:%S.000Z')
    
    # Set end time - use UTC format to avoid timezone issues  
    event.end = Google::Apis::CalendarV3::EventDateTime.new
    event.end.date_time = end_time.utc.strftime('%Y-%m-%dT%H:%M:%S.000Z')
    
    event.color_id = '9' # Blue color for task events

    handle_api_error do
      result = @service.insert_event('primary', event)
      puts "Created calendar event: #{result.html_link}" if ENV['DEBUG']
      result
    end
  end

  # Update an existing calendar event
  def update_task_event(event_id, task_title, start_time, end_time, task_notes = nil, task_id = nil, list_id = nil)
    ensure_authenticated
    
    event = Google::Apis::CalendarV3::Event.new
    event.summary = "📋 #{task_title}"
    event.description = build_event_description(task_notes, task_id, list_id, task_title)
    
    # Set start time - use UTC format to avoid timezone issues
    event.start = Google::Apis::CalendarV3::EventDateTime.new
    event.start.date_time = start_time.utc.strftime('%Y-%m-%dT%H:%M:%S.000Z')
    
    # Set end time - use UTC format to avoid timezone issues  
    event.end = Google::Apis::CalendarV3::EventDateTime.new
    event.end.date_time = end_time.utc.strftime('%Y-%m-%dT%H:%M:%S.000Z')

    handle_api_error do
      @service.update_event('primary', event_id, event)
    end
  end

  # Delete a calendar event
  def delete_task_event(event_id)
    ensure_authenticated
    handle_api_error do
      @service.delete_event('primary', event_id)
    end
  end

  # Find task events for a specific day
  def find_task_events(date)
    ensure_authenticated
    
    start_time = Time.new(date.year, date.month, date.day, 0, 0, 0)
    end_time = start_time + 24 * 60 * 60  # 24 hours later
    
    handle_api_error do
      result = @service.list_events('primary',
        time_min: start_time.strftime('%Y-%m-%dT%H:%M:%S%:z'),
        time_max: end_time.strftime('%Y-%m-%dT%H:%M:%S%:z'),
        single_events: true,
        order_by: 'startTime',
        q: '📋'  # Search for events with task emoji
      )
      result.items || []
    end
  end

  private

  def get_system_timezone
    # Use Ruby's built-in timezone handling
    begin
      # Get the system timezone using Ruby
      tz_name = Time.now.zone
      puts "Ruby detected timezone: #{tz_name}" if ENV['DEBUG']
      
      # Try to get IANA timezone identifier
      # Check if we can get it from ENV first
      if ENV['TZ'] && !ENV['TZ'].empty?
        puts "Using TZ environment variable: #{ENV['TZ']}" if ENV['DEBUG']
        return ENV['TZ']
      end
      
      # Use Ruby's Time zone information
      time_zone_offset = Time.now.utc_offset
      puts "Timezone offset: #{time_zone_offset} seconds" if ENV['DEBUG']
      
      # Convert offset to hours for common timezone mapping
      offset_hours = time_zone_offset / 3600
      puts "Timezone offset: #{offset_hours} hours from UTC" if ENV['DEBUG']
      
      # Map common offsets to IANA timezones
      result = case offset_hours
      when 0
        'UTC'
      when 1
        'Europe/Berlin'  # Central European Time
      when 2
        'Europe/Tallinn' # Eastern European Time
      when 3
        'Europe/Moscow'  # Moscow Time
      when -5
        'America/New_York' # Eastern Time
      when -6
        'America/Chicago'  # Central Time
      when -7
        'America/Denver'   # Mountain Time
      when -8
        'America/Los_Angeles' # Pacific Time
      else
        # For other offsets, try to construct a reasonable timezone
        if offset_hours > 0
          "Etc/GMT-#{offset_hours}"
        elsif offset_hours < 0
          "Etc/GMT+#{offset_hours.abs}"
        else
          'UTC'
        end
      end
      
      puts "Mapped to IANA timezone: #{result}" if ENV['DEBUG']
      return result
      
    rescue => e
      puts "Error getting timezone: #{e.message}" if ENV['DEBUG']
      return 'UTC'
    end
  end

  def load_stored_credentials
    return nil unless File.exist?(TOKEN_PATH)
    
    puts "Reading token file..." if ENV['DEBUG']
    token_yaml = YAML.load_file(TOKEN_PATH)
    
    # The token is stored as JSON string under 'default' key
    return nil unless token_yaml && token_yaml['default']
    
    puts "Parsing token JSON..." if ENV['DEBUG']
    require 'json'
    token_data = JSON.parse(token_yaml['default'])
    return nil unless token_data['access_token']
    
    # Read client_secret from credentials file
    unless File.exist?(@credentials_path)
      puts "OAuth credentials file not found: #{@credentials_path}" if ENV['DEBUG']
      return nil
    end
    
    credentials_data = JSON.parse(File.read(@credentials_path))
    client_secret = credentials_data['installed']['client_secret']
    
    puts "Creating credentials object..." if ENV['DEBUG']
    puts "Token scopes: #{token_data['scope']}" if ENV['DEBUG']
    
    credentials = Google::Auth::UserRefreshCredentials.new(
      client_id: token_data['client_id'],
      client_secret: client_secret,
      scope: SCOPES,
      access_token: token_data['access_token'],
      refresh_token: token_data['refresh_token']
    )
    
    # Refresh if needed
    if credentials.expired?
      puts "Token expired, refreshing..." if ENV['DEBUG']
      credentials.refresh!
    end
    
    puts "Credentials loaded successfully!" if ENV['DEBUG']
    credentials
  rescue => e
    puts "Error loading calendar credentials: #{e.message}" if ENV['DEBUG']
    puts "Error details: #{e.class} - #{e.backtrace.first}" if ENV['DEBUG']
    nil
  end

  def build_event_description(task_notes, task_id = nil, list_id = nil, task_title = nil)
    description = "🎯 Focused Work Session\n\n"
    
    if task_notes && !task_notes.empty?
      # Extract priority and department from notes
      if task_notes.match(/🔥|🟢|🟠|🔴/)
        description += "#{task_notes}\n\n"
      end
    end
    
    # Add link to original Google Task with task title as link text
    if task_id && list_id && task_title
      # Google Tasks web URL format with HTML link
      task_url = "https://tasks.google.com/task/#{task_id}?list=#{list_id}"
      description += "📋 Original Task: <a href=\"#{task_url}\">#{task_title}</a>\n\n"
    end
    
    description += "Created by GTD Task Manager\n"
    description += "⏰ Time-blocked for focused execution"
    description
  end

  def handle_api_error
    yield
  rescue Google::Apis::Error => e
    puts "Google Calendar API Error: #{e.message}"
    raise e
  rescue => e
    puts "Unexpected error: #{e.message}"
    raise e
  end
end