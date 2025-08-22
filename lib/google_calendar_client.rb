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
    return if @service.authorization

    if File.exist?(TOKEN_PATH)
      puts "Loading stored calendar credentials..." if ENV['DEBUG']
      @service.authorization = load_stored_credentials
      return if @service.authorization&.access_token
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
  def create_task_event(task_title, start_time, end_time, task_notes = nil)
    ensure_authenticated
    
    event = Google::Apis::CalendarV3::Event.new({
      summary: "📋 #{task_title}",
      description: build_event_description(task_notes),
      start: {
        date_time: start_time.strftime('%Y-%m-%dT%H:%M:%S%:z'),
        time_zone: Time.now.zone,
      },
      end: {
        date_time: end_time.strftime('%Y-%m-%dT%H:%M:%S%:z'),
        time_zone: Time.now.zone,
      },
      color_id: '9', # Blue color for task events
    })

    handle_api_error do
      result = @service.insert_event('primary', event)
      puts "Created calendar event: #{result.html_link}" if ENV['DEBUG']
      result
    end
  end

  # Update an existing calendar event
  def update_task_event(event_id, task_title, start_time, end_time, task_notes = nil)
    ensure_authenticated
    
    event = Google::Apis::CalendarV3::Event.new({
      summary: "📋 #{task_title}",
      description: build_event_description(task_notes),
      start: {
        date_time: start_time.strftime('%Y-%m-%dT%H:%M:%S%:z'),
        time_zone: Time.now.zone,
      },
      end: {
        date_time: end_time.strftime('%Y-%m-%dT%H:%M:%S%:z'),
        time_zone: Time.now.zone,
      },
    })

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

  def load_stored_credentials
    return nil unless File.exist?(TOKEN_PATH)
    
    token_data = YAML.load_file(TOKEN_PATH)
    return nil unless token_data['access_token']
    
    credentials = Google::Auth::UserRefreshCredentials.new(
      client_id: token_data['client_id'],
      client_secret: token_data['client_secret'],
      scope: SCOPES,
      access_token: token_data['access_token'],
      refresh_token: token_data['refresh_token']
    )
    
    # Refresh if needed
    credentials.refresh! if credentials.expired?
    credentials
  rescue => e
    puts "Error loading calendar credentials: #{e.message}" if ENV['DEBUG']
    nil
  end

  def build_event_description(task_notes)
    description = "🎯 Focused Work Session\n\n"
    
    if task_notes && !task_notes.empty?
      # Extract priority and department from notes
      if task_notes.match(/🔥|🟢|🟠|🔴/)
        description += "#{task_notes}\n\n"
      end
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