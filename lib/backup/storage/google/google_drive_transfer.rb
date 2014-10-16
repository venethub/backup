class GoogleDriveTransfer
  include Config::Helpers

  def initialize(client, drive)
    @client = client
    @drive = drive
  end

  def uplaod(filename, folder_id = nil)
    src = File.join(Config.tmp_path, filename)

    Logger.info "Storing '#{ src }'..."

    File.open(src, "r") do |file|
      
      file_options = {
        "title" => filename
      }

      unless folder_id.nil?
        folder_options = {
          "parents" => [{
            "id" => folder_id
          }]
        }
        
        file_options.merge(folder_options)
      end

      file = @drive.files.insert.request_schema.new(file_options)
      content_type = MIME::Types.type_for(filename)
      media = Google::APIClient::UploadIO.new(src, content_type)
      result = @client.execute(
        api_method: @drive.files.insert,
        body_object: file,
        media: media,
        parameters: {
          "uploadType" => "multipart"
        }
      )
    end
  end

  def delete(path)
    # TODO
  end
end