require 'fig/parser'

module Fig
  class Repository
    def initialize(os, local_repository_dir, remote_repository_url, remote_repository_user=nil, update=false, update_if_missing=true)
      @os = os
      @local_repository_dir = local_repository_dir
      @remote_repository_url = remote_repository_url
      @remote_repository_user = remote_repository_user
      @update = update
      @update_if_missing = update_if_missing
      @parser = Parser.new

      @overrides = {}
      if File.exist?('fig.properties')
        File.readlines('fig.properties').each do |line|
          descriptor, path = line.strip.split('=')
          @overrides[descriptor] = path
        end
      end
    end

    def clean(package_name, version_name) 
      dir = File.join(@local_repository_dir, package_name)
      dir = File.join(dir, version_name) if version_name
      FileUtils.rm_rf(dir)
    end

    def list_packages
      results = []
      if File.exist?(@local_repository_dir)
        @os.list(@local_repository_dir).each do |package_name|
          @os.list(File.join(@local_repository_dir, package_name)).each do |version_name|
            results << "#{package_name}/#{version_name}"
          end
        end
      end
      results
    end

    def list_remote_packages
      @os.download_list(@remote_repository_url)
    end

    def publish_package(package_statements, package_name, version_name, tags) 
      tags.each { |tag| raise "Not a valid tag: #{tag}" unless tag =~ /[a-zA-Z0-9]+/ }

      temp_dir = temp_dir_for_package(package_name, version_name)
      @os.clear_directory(temp_dir)
      fig_file = File.join(temp_dir, ".fig")
      content = bundle_resources(package_statements).map do |statement| 
        if statement.is_a?(Publish)
          nil
        elsif statement.is_a?(Archive) || statement.is_a?(Resource)
          if statement.is_a?(Resource) && !is_url?(statement.url)
            archive_name = statement.url
            archive_remote = "#{remote_dir_for_package(package_name, version_name)}/#{statement.url}"
          else
            archive_name = statement.url.split("/").last
            archive_remote = "#{remote_dir_for_package(package_name, version_name)}/#{archive_name}"
          end
          if is_url?(statement.url)
            archive_local = File.join(temp_dir, archive_name)
            @os.download(statement.url, archive_local)
          else
            archive_local = statement.url
          end
          @os.upload(archive_local, archive_remote, @remote_repository_user)
          statement.class.new(archive_name).unparse('')
        else
          statement.unparse('')
        end
      end.select {|s|not s.nil?}
      @os.write(fig_file, content.join("\n").strip)
      @os.upload(fig_file, remote_fig_file_for_package(package_name, version_name), @remote_repository_user)
      tags.each do |tag|
        tag_file = File.join(temp_dir, "#{tag}.tag")
        File.open(tag_file, "w") { |f| f << version_name } 
        @os.upload(tag_file, remote_tag_file(package_name, tag), @remote_repository_user)
      end
#      update_package(package_name, version_name)
    end

    def bundle_resources(package_statements)
      resources = []
      new_package_statements = package_statements.reject do |statement|
        if statement.is_a?(Resource) && !is_url?(statement.url)
          resources << statement.url
          true
        else
          false
        end
      end
      if resources.size > 0
        file = "resources.tar.gz"
        @os.create_archive(file, resources.join(' '))
        new_package_statements.unshift(Archive.new(file))
        at_exit { File.delete(file) }
      end
      new_package_statements
    end

    def load_package(package_name, version_name)
      if @update || (@update_if_missing && package_missing?(package_name, version_name))
        update_package(package_name, version_name)
      end
      read_local_package(package_name, version_name)
    end

    def update_package(package_name, version_name)
      remote_fig_file = remote_fig_file_for_package(package_name, version_name)
      local_fig_file = local_fig_file_for_package(package_name, version_name)
      begin 
        tag_file = local_tag_file(package_name, version_name)
        @os.download(remote_tag_file(package_name, version_name), tag_file)
        update_package(package_name, File.read(tag_file))
        return
      rescue NotFoundException
        # Not a tag, continue
      end
      begin
        if @os.download(remote_fig_file, local_fig_file)
          install_package(package_name, version_name)
        end
      rescue NotFoundException
        $stderr.puts "Package not found in remote repository: #{package_name}/#{version_name}"
        exit 1
      end
    end

    def read_local_package(package_name, version_name)
      tag_file = local_tag_file(package_name, version_name)
      if File.exist?(tag_file)
        read_local_package(package_name, File.read(tag_file))
      else
        dir = local_dir_for_package(package_name, version_name)
        read_package_from_directory(dir, package_name, version_name)
      end
    end 

    def read_remote_package(package_name, version_name)
      url = remote_fig_file_for_package(package_name, version_name)
      content = @os.read_url(url)
      @parser.parse_package(package_name, version_name, nil, content)
    end

    def read_package_from_directory(dir, package_name, version_name)
      file = File.join(dir, ".fig")
      if not File.exist?(file)
        file = File.join(dir, "package.fig")
      end
      if not File.exist?(file)
        raise "File not found: #{file}"
      end
      read_package_from_file(file, package_name, version_name)
    end

    def read_package_from_file(file_name, package_name, version_name)
      if not @os.exist?(file_name)
        $stderr.puts "Package not found: #{package_name}/#{version_name}" 
        exit 1
      end
      modified_time = @os.mtime(file_name)
      content = @os.read(file_name)
      @parser.parse_package(package_name, version_name, File.dirname(file_name), content)
    end

    def local_dir_for_package(package_name, version_name)
      descriptor = "#{package_name}/#{version_name}"
      dir = @overrides[descriptor]
      if dir
        $stderr.puts "override: #{descriptor}=#{dir}"
      else
        dir = File.join(@local_repository_dir, package_name, version_name)
      end
      dir
    end

    def local_tag_file(package_name, tag)
      File.join(@local_repository_dir, package_name, "#{tag}.tag")
    end

  private

    def install_package(package_name, version_name)
      begin
        package = read_local_package(package_name, version_name)
        temp_dir = temp_dir_for_package(package_name, version_name)
        @os.clear_directory(temp_dir)
        package.archive_urls.each do |archive_url|
          if not is_url?(archive_url)
            archive_url = remote_dir_for_package(package_name, version_name) + "/" + archive_url
          end
          @os.download_archive(archive_url, File.join(temp_dir))
        end
        package.resource_urls.each do |resource_url|
          if not is_url?(resource_url)
            resource_url = remote_dir_for_package(package_name, version_name) + "/" + resource_url
          end
          @os.download_resource(resource_url, File.join(temp_dir))
        end
        local_dir = local_dir_for_package(package_name, version_name)
        @os.clear_directory(local_dir)
        # some packages contain no files, only a fig file.
        if not (package.archive_urls.empty? && package.resource_urls.empty?)
          FileUtils.mv(Dir.glob(File.join(temp_dir, "*")), local_dir)
        end
        write_local_package(package_name, version_name, package)
      rescue
        $stderr.puts "install failed, cleaning up" 
        delete_local_package(package_name, version_name)
        raise
      end
    end

    def is_url?(url)
      not (/ftp:\/\/|http:\/\/|file:\/\/|ssh:\/\// =~ url).nil?
    end

    def delete_local_package(package_name, version_name)
      FileUtils.rm_rf(local_dir_for_package(package_name, version_name))
    end

    def write_local_package(package_name, version_name, package)
      file = local_fig_file_for_package(package_name, version_name)
      @os.write(file, package.unparse)
    end

    def remote_tag_file(package_name, tag)
      "#{@remote_repository_url}/#{package_name}/#{tag}.tag"
    end  

    def remote_fig_file_for_package(package_name, version_name)
      "#{@remote_repository_url}/#{package_name}/#{version_name}/.fig"
    end  

    def local_fig_file_for_package(package_name, version_name)
      File.join(local_dir_for_package(package_name, version_name), ".fig")
    end

    def remote_dir_for_package(package_name, version_name)
      "#{@remote_repository_url}/#{package_name}/#{version_name}"
    end

    def temp_dir_for_package(package_name, version_name)
      File.join(@local_repository_dir, "tmp")
    end

    def package_missing?(package_name, version_name)
      not File.exist?(local_fig_file_for_package(package_name, version_name))
    end
  end
end
