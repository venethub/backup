# encoding: utf-8

require "google/api_client"
require "google/api_client/auth/file_storage"
require "backup/storage/google_drive_auth"
require "backup/storage/google_drive_transfer"

module Backup
  module Storage
    class GoogleDrive < Base
      include Storage::Cycler
      class Error < Backup::Error; end

      attr_accessor :client_id, :client_secret, :folder_id, :api_version, :cache_path

      ##
      # Creates a new instance of the storage object
      def initialize(model, storage_id = nil)
        super

        @path           ||= "backups"
        @cache_path     ||= ".cache"
        path.sub!(/^\//, "")
      end

      private

        def connection
          auth = GoogleDriveAuth.new(
            client_id: client_id,
            client_secret: client_secret,
            api_version: api_version,
            cache_path: cache_path
          )

          @client = auth.client
          @drive = auth.drive

          @connection = GoogleDriveTransfer.new(@client, @drive)

          @connection

        rescue => err
          raise Error.wrap(err, "Connection Failed")
        end

        def transfer!
          package.filenames.each { |filename| connection.upload(filename, folder_id) }

        rescue => err
          raise Error.wrap(err, "Upload Failed!")
        end

        def remove!(package)
          Logger.info "Removing backup package dated #{ package.time }..."

          connection.delete(remote_path_for(package))
        end

    end
  end
end