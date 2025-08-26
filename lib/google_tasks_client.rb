require 'google/apis/tasks_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'googleauth/user_authorizer'
require 'fileutils'
require 'launchy'
require 'webrick'
require 'uri'

class GoogleTasksClient
  SCOPE = [
    'https://www.googleapis.com/auth/tasks',
    'https://www.googleapis.com/auth/calendar'
  ].freeze
  CREDENTIALS_PATH = 'oauth_credentials.json'.freeze
  TOKEN_PATH = 'token.yaml'.freeze

  def initialize(credentials_path = CREDENTIALS_PATH)
    @service = Google::Apis::TasksV1::TasksService.new
    @credentials_path = credentials_path
    @authenticated = false
  end

  private

  def ensure_authenticated
    return if @authenticated
    authenticate
    @authenticated = true
  end

  def authenticate(force_reauth = false)
    unless File.exist?(@credentials_path)
      raise "OAuth credentials file not found: #{@credentials_path}\n\nTo set up OAuth credentials:\n1. Go to https://console.cloud.google.com/\n2. Create a project and enable Google Tasks API\n3. Go to Credentials → Create Credentials → OAuth client ID\n4. Choose 'Desktop application'\n5. Download the JSON file and save it as '#{@credentials_path}'"
    end

    client_id = Google::Auth::ClientId.from_file(@credentials_path)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
    
    # Configure authorizer for offline access to get refresh tokens
    authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)

    user_id = 'default'
    
    # Clear stored credentials if force reauth is requested
    if force_reauth && File.exist?(TOKEN_PATH)
      File.delete(TOKEN_PATH)
      puts "Cleared stored credentials. Starting fresh authentication..."
    end
    
    credentials = authorizer.get_credentials(user_id)
    
    # Debug token information
    if force_reauth
      puts "=== Debug Token Information ==="
      puts "Token file exists: #{File.exist?(TOKEN_PATH)}"
      if File.exist?(TOKEN_PATH)
        puts "Token file size: #{File.size(TOKEN_PATH)} bytes"
      end
      puts "Credentials found: #{!credentials.nil?}"
      if credentials
        puts "Access token present: #{!credentials.access_token.nil?}"
        puts "Refresh token present: #{!credentials.refresh_token.nil?}"
        puts "Token expired: #{credentials.expired?}"
      end
      puts "=== End Debug ==="
    end
    
    # Check if we have valid credentials
    if credentials.nil?
      puts "No stored credentials found. Starting OAuth flow..."
      credentials = perform_oauth_flow(authorizer, user_id)
    elsif credentials.expired?
      puts "Access token expired. Refreshing..." if force_reauth
      begin
        credentials.refresh!
        # Store the refreshed tokens
        token_store.store(user_id, credentials)
        puts "Successfully refreshed access token." if force_reauth
      rescue => e
        puts "Token refresh failed: #{e.message}. Starting new OAuth flow..." if force_reauth
        File.delete(TOKEN_PATH) if File.exist?(TOKEN_PATH)
        credentials = perform_oauth_flow(authorizer, user_id)
      end
    else
      puts "Using stored credentials..." if force_reauth
    end

    @service.authorization = credentials
  rescue Errno::ENOENT => e
    raise "OAuth credentials file not found: #{@credentials_path}\n\nTo set up OAuth credentials:\n1. Go to https://console.cloud.google.com/\n2. Create a project and enable Google Tasks API\n3. Go to Credentials → Create Credentials → OAuth client ID\n4. Choose 'Desktop application'\n5. Download the JSON file and save it as '#{@credentials_path}'"
  rescue JSON::ParserError => e
    raise "Invalid OAuth credentials file format: #{@credentials_path}. Please download a fresh copy from Google Cloud Console."
  rescue StandardError => e
    if e.message.include?('invalid_grant') || e.message.include?('invalid_request')
      File.delete(TOKEN_PATH) if File.exist?(TOKEN_PATH)
      raise "Stored credentials are invalid. Please run 'tasker login' to re-authenticate."
    else
      raise "Authentication failed: #{e.message}"
    end
  end

  def perform_oauth_flow(authorizer, user_id)
    puts "Starting OAuth authentication flow..."
    
    # Use localhost redirect with callback server
    redirect_uri = 'http://localhost:9090/oauth2callback'
    port = 9090
    
    # Set up authorization URL
    url = authorizer.get_authorization_url(base_url: redirect_uri)
    
    puts "\nStarting local server on port #{port} to receive OAuth callback..."
    puts "Opening your browser for Google OAuth login..."
    puts "URL: #{url}"
    
    # Start local server to handle OAuth callback
    code = nil
    error = nil
    server = nil
    
    begin
      # Create a simple HTTP server to handle the callback
      server = WEBrick::HTTPServer.new(Port: port, Logger: WEBrick::Log.new('/dev/null'), AccessLog: [])
      
      server.mount_proc '/oauth2callback' do |req, res|
        if req.query['code']
          code = req.query['code']
          res.body = '<html><body><h1>Success!</h1><p>Authorization received. You can close this window and return to the terminal.</p></body></html>'
          res.content_type = 'text/html'
          res.status = 200
        elsif req.query['error']
          error = req.query['error']
          res.body = '<html><body><h1>Error!</h1><p>Authorization failed: ' + error + '</p></body></html>'
          res.content_type = 'text/html'
          res.status = 400
        else
          res.body = '<html><body><h1>Error!</h1><p>No authorization code received.</p></body></html>'
          res.content_type = 'text/html'
          res.status = 400
        end
        
        # Stop the server after handling the request
        Thread.new { sleep(1); server.shutdown }
      end
      
      # Start server in a separate thread
      server_thread = Thread.new { server.start }
      
      # Open browser
      begin
        Launchy.open(url)
        puts "Browser opened. Please complete the authorization in your browser."
      rescue => e
        puts "Could not open browser automatically: #{e.message}"
        puts "Please open the URL above in your browser manually."
      end
      
      puts "Waiting for authorization callback..."
      
      # Wait for the callback (with timeout)
      timeout = 300  # 5 minutes
      start_time = Time.now
      
      while code.nil? && error.nil? && (Time.now - start_time) < timeout
        sleep(1)
      end
      
      if error
        raise "OAuth authorization failed: #{error}"
      elsif code.nil?
        raise "OAuth authorization timed out. Please try again."
      end
      
      puts "Authorization code received successfully!"
      
    rescue Errno::EADDRINUSE
      puts "Port #{port} is already in use. Falling back to manual code entry..."
      return perform_manual_oauth_flow(authorizer, user_id)
    rescue => e
      puts "Server error: #{e.message}. Falling back to manual code entry..."
      return perform_manual_oauth_flow(authorizer, user_id)
    ensure
      server&.shutdown
    end
    
    # Exchange the code for tokens
    puts "Exchanging authorization code for tokens..."
    
    begin
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, 
        code: code, 
        base_url: redirect_uri
      )
      
      puts "Token exchange successful!"
      puts "Access token present: #{!credentials.access_token.nil?}"
      puts "Refresh token present: #{!credentials.refresh_token.nil?}"
      
      # Verify we got both access and refresh tokens
      if credentials.refresh_token.nil?
        puts "\nWarning: No refresh token received!"
        puts "This usually happens when you've already authorized this app before."
        puts "To get a refresh token:"
        puts "1. Go to https://myaccount.google.com/permissions"
        puts "2. Remove access for this app"
        puts "3. Try logging in again"
      else
        puts "Successfully authenticated with refresh token!"
      end
      
      puts "Tokens saved to #{TOKEN_PATH}"
      
      # Manually verify the token was stored
      if File.exist?(TOKEN_PATH)
        puts "Verified: Token file created successfully"
      else
        puts "Error: Token file was not created!"
      end
      
      credentials
    rescue => e
      puts "Token exchange failed: #{e.class} - #{e.message}"
      raise "Failed to exchange authorization code: #{e.message}"
    end
  end

  def perform_manual_oauth_flow(authorizer, user_id)
    puts "Using manual OAuth flow (out-of-band)..."
    
    redirect_uri = 'urn:ietf:wg:oauth:2.0:oob'
    url = authorizer.get_authorization_url(base_url: redirect_uri)
    
    puts "\nOpening your browser for Google OAuth login..."
    puts "URL: #{url}"
    puts "\nAfter authorizing, you'll get a code. Paste it below."
    
    begin
      Launchy.open(url)
    rescue => e
      puts "Could not open browser automatically."
      puts "Please copy the URL above and open it manually in your browser."
    end
    
    print "\nEnter the authorization code: "
    code = gets.chomp.strip
    
    if code.empty?
      raise "No authorization code provided. OAuth login cancelled."
    end
    
    puts "Exchanging authorization code for tokens..."
    
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, 
      code: code, 
      base_url: redirect_uri
    )
    
    puts "Successfully authenticated!"
    credentials
  end

  def handle_api_error
    yield
  rescue Google::Apis::Error => e
    raise "Google API error: #{e.message}"
  end

  public

  def list_task_lists(max_results: nil)
    ensure_authenticated
    handle_api_error do
      all_lists = []
      next_page_token = nil
      
      loop do
        response = @service.list_tasklists(
          max_results: max_results || 100,  # Default page size
          page_token: next_page_token
        )
        
        # Add task lists from this page
        lists = response.items || []
        all_lists.concat(lists)
        
        # Check if there are more pages
        next_page_token = response.next_page_token
        break if next_page_token.nil? || next_page_token.empty?
        
        # If max_results was specified and we have enough, stop
        if max_results && all_lists.length >= max_results
          all_lists = all_lists.first(max_results)
          break
        end
      end
      
      all_lists
    end
  end

  def get_task_list(list_id)
    ensure_authenticated
    handle_api_error do
      @service.get_tasklist(list_id)
    end
  end

  def create_task_list(title)
    ensure_authenticated
    task_list = Google::Apis::TasksV1::TaskList.new(title: title)
    handle_api_error do
      @service.insert_tasklist(task_list)
    end
  end

  def delete_task_list(list_id)
    ensure_authenticated
    handle_api_error do
      @service.delete_tasklist(list_id)
    end
  end

  def list_tasks(list_id, show_completed: false, max_results: nil)
    ensure_authenticated
    handle_api_error do
      all_tasks = []
      next_page_token = nil
      
      loop do
        response = @service.list_tasks(
          list_id,
          show_completed: show_completed,
          max_results: max_results || 100,  # Default page size
          page_token: next_page_token
        )
        
        # Add tasks from this page
        tasks = response.items || []
        all_tasks.concat(tasks)
        
        # Check if there are more pages
        next_page_token = response.next_page_token
        break if next_page_token.nil? || next_page_token.empty?
        
        # If max_results was specified and we have enough, stop
        if max_results && all_tasks.length >= max_results
          all_tasks = all_tasks.first(max_results)
          break
        end
      end
      
      all_tasks
    end
  end

  def get_task(list_id, task_id)
    ensure_authenticated
    handle_api_error do
      task = @service.get_task(list_id, task_id)
      
      # Debug specific task if it matches the one we're investigating
      if task_id == 'eGxBNEdCSmJKa2F5Q1VmTQ' && ENV['DEBUG']
        puts "\n=== DEBUGGING SPECIFIC TASK #{task_id} ==="
        puts "Task object class: #{task.class}"
        puts "All task methods:"
        task.methods.sort.each { |m| puts "  #{m}" }
        puts "\nAll instance variables:"
        task.instance_variables.each do |var|
          puts "  #{var}: #{task.instance_variable_get(var)}"
        end
        puts "\nTask as JSON:"
        puts task.to_json if task.respond_to?(:to_json)
        puts "\nTask as Hash:"
        puts task.to_h if task.respond_to?(:to_h)
        puts "\nRaw task inspection:"
        puts task.inspect
        puts "=== END DEBUGGING ==="
      end
      
      task
    end
  end

  def create_task(list_id, title, notes: nil, due: nil)
    ensure_authenticated
    task = Google::Apis::TasksV1::Task.new(
      title: title,
      notes: notes,
      due: due
    )
    handle_api_error do
      @service.insert_task(list_id, task)
    end
  end

  def update_task(list_id, task_id, title: nil, notes: nil, due: nil, status: nil)
    ensure_authenticated
    puts "API Call: update_task(list_id: #{list_id}, task_id: #{task_id})" if ENV['DEBUG']
    
    # First, get the current task to check its current state
    current_task = get_task(list_id, task_id)
    puts "Current task due: #{current_task.due}" if ENV['DEBUG']
    puts "Current task due format: #{current_task.due ? (current_task.due.include?('T') ? 'specific time' : 'all-day') : 'no due date'}" if ENV['DEBUG']
    
    # Create new task object with all fields
    task = Google::Apis::TasksV1::Task.new
    task.id = task_id  # Set the task ID on the task object
    
    # Always set fields explicitly to ensure they're updated
    task.title = title if title
    task.notes = notes if notes
    
    # Handle due date - ensure it's properly set even if nil
    if due
      task.due = due
      puts "Task object due date set to: #{task.due}" if ENV['DEBUG']
      
      # Check if current task has "all day" format and we're setting a specific time
      if current_task.due && !current_task.due.include?('T') && due.include?('T')
        puts "Converting from all-day to specific time" if ENV['DEBUG']
      end
    else
      # If due is explicitly nil, we want to clear the due date
      task.due = nil
      puts "Task object due date cleared (set to nil)" if ENV['DEBUG']
    end
    
    task.status = status if status
    
    puts "Complete task object before API call:" if ENV['DEBUG']
    puts "  ID: #{task.id}" if ENV['DEBUG']
    puts "  Title: #{task.title}" if ENV['DEBUG']
    puts "  Notes: #{task.notes}" if ENV['DEBUG']
    puts "  Due: #{task.due}" if ENV['DEBUG']
    puts "  Status: #{task.status}" if ENV['DEBUG']
    puts "  Task object class: #{task.class}" if ENV['DEBUG']
    puts "  Task object methods containing 'due': #{task.methods.grep(/due/)}" if ENV['DEBUG']

    handle_api_error do
      puts "Calling Google Tasks API: @service.update_task(#{list_id}, #{task_id}, task)" if ENV['DEBUG']
      result = @service.update_task(list_id, task_id, task)
      puts "API Response successful: #{result.class}" if ENV['DEBUG']
      
      # Log the returned task's due date to verify the update
      if ENV['DEBUG'] && result.respond_to?(:due)
        puts "API returned task due date: #{result.due}"
      end
      
      result
    end
  end

  def delete_task(list_id, task_id)
    ensure_authenticated
    handle_api_error do
      @service.delete_task(list_id, task_id)
    end
  end

  def complete_task(list_id, task_id)
    ensure_authenticated
    update_task(list_id, task_id, status: 'completed')
  end

  def logout
    if File.exist?(TOKEN_PATH)
      File.delete(TOKEN_PATH)
      puts "Logged out successfully. Stored tokens cleared."
    else
      puts "No stored tokens found."
    end
    @authenticated = false
  end
end