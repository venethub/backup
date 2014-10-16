class GoogleDriveAuth
  include Config::Helpers
  
  def initialize(options = {})
    @options = {
      client_id: options["client_id"],
      client_secret: options["client_secret"], 
      api_version: options["api_version"],
      cache_path: options["cache_path"],
      scope: "https://www.googleapis.com/auth/drive",
      authorization_uri: "https://accounts.google.com/o/oauth2/auth",
      token_credential_uri: "https://accounts.google.com/o/oauth2/token",
      redirect_uri: "urn:ietf:wg:oauth:2.0:oob"
    }

    connect
  end

  def connect
    @client = (auth.nil? ? authorize_and_cache : authorized_client)
    @drive = @client.discovered_api("drive", api_version)
  rescue => err
    raise Error.wrap(err, "Authorization Failed")
  end

  def file_storage
    Google::APIClient::FileStorage.new(credential_store_file)
  end

  def auth
    file_storage.authorization
  end

  def authorize_and_cache
    require "timeout"

    Logger.info "Creating a new authorization!"

    client = Google::APIClient.new(
      application_name: "Ruby backup to google drive",
      application_version: "0.1.0"
    )

    authorization = Signet::OAuth2::Client.new(@options)

    template = Backup::Template.new(
      auth: authorization,
      credential_store_file: credential_store_file
    )
    template.render("storage/google_drive/authorization_url.erb")

    Timeout::timeout(180) {
      authorization.code = STDIN.gets
    }

    authorization.fetch_access_token!

    template.render("storage/google_drive/authorized.erb")
    write_cache!(authorization)
    template.render("storage/google_drive/cache_file_written.erb")

    client.authorization = authorization

    client

  rescue => err
    raise Error.wrap(err, "Could not authorize")
  end

  def authorized_client
    client = Google::APIClient.new(
      application_name: "Ruby backup to google drive",
      application_version: "0.1.0"
    )

    client.authorization = auth

    client
  end

  def credential_store_file
    path = @options.cache_path.start_with?("/") ? @options.cache_path : File.join(Config.root_path, @options.cache_path)
    File.join(path, @options.client_id + @options.client_secret)
  end

  def write_cache!(authorization)
    FileUtils.mkdir_p File.dirname(credential_store_file)
    file_storage.write_credentials(authorization)
  end
end