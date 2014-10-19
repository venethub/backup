module Backup
  class GoogleDriveTransfer
    include Config::Helpers

    def initialize(client, drive)
      @client = client
      @drive = drive

      get_info
    end

    def get_info
      list = @client.execute(api_method: @drive.about.get)
      @about = list.data
    end

    # File upload
    #
    def upload(package, folder_id = nil)
      package.filenames.each do |filename|
        src = File.join(Config.tmp_path, filename)

        Logger.info "Storing '#{ src }'..."

        file_folder = create_folder(package.time, folder_id)
        insert_file(filename, src, file_folder.id)
      end
    end

    def create_folder(title, parent_folder_id)
      parent_folder_id ||= @about.root_folder_id

      folder = @drive.files.insert.request_schema.new({
        "title" => title,
        "mimeType" => "application/vnd.google-apps.folder",
        "parents" => [{
          "id" => parent_folder_id
        }],
      })
      result = @client.execute!(
        api_method: @drive.files.insert,
        body_object: folder
      )

      result.status == 200 ? result.data : nil
    end

    def insert_file(filename, src, folder_id)
      folder_id ||= @about.root_folder_id

      File.open(src, "r") do |file|
        file_options = {
          "title" => filename,
          "parents" => [{
            "id" => folder_id
          }]
        }

        file = @drive.files.insert.request_schema.new(file_options)

        media = Google::APIClient::UploadIO.new(src, MIME::Types.type_for(filename))
        result = @client.execute(
          api_method: @drive.files.insert,
          body_object: file,
          media: media,
          parameters: {
            "uploadType" => "multipart"
          }
        )

        result
      end
    end


    # Delete file
    #
    def delete(package, folder_id = nil)
      folder_id ||= @about.root_folder_id

      del_folder = find_files({
        "folderId" => folder_id,
        "q" => "title = '#{package.time}'",
        "maxResults" => 1
      })[0]

      delete_folder(folder_id, del_folder.id)

      nil
    end

    def find_files(params = {})
      page_token = nil

      begin
        params["pageToken"] = page_token if page_token.to_s != ""

        result = @client.execute(
          api_method: @drive.children.list,
          parameters: params
        )

        if result.status == 200
          children = result.data
          page_token = children.next_page_token

          return children.items
        else
          puts "An error occurred: #{result.data['error']['message']}"
          page_token = nil
        end
      end while page_token.to_s != ""
    end

    def delete_folder(parent_folder_id, del_folder_id)
      @client.execute!(
        api_method: @drive.children.delete,
        parameters: {
          "folderId" => parent_folder_id,
          "childId" => del_folder_id
        }
      )
    end
  end
end