require 'fileutils'
require 'ftools'
require 'uri'
require 'net/http'
require 'open4'
require 'tempfile'

module Fig
 class OS
   def list(dir)
     Dir.entries(dir) - ['.','..']
   end

   def exist?(path)
     File.exist?(path)
   end

   def mtime(path)
     File.mtime(path)
   end

   def read(path)
     File.read(path)
   end

   def write(path, content)
     File.open(path, "w") { |f| f << content }
   end

   SUCCESS = 0
   NOT_MODIFIED = 3
   NOT_FOUND = 4

   def download(url, path)
     FileUtils.mkdir_p(File.dirname(path))
     uri = URI.parse(url)
     case uri.scheme
     when "ftp"
       ftp = Net::FTP.new(uri.host)
       ftp.login
       if File.exist?(path) && ftp.mtime(uri.path) <= File.mtime(path)
         return false
       else 
         puts "downloading #{url}"
         ftp.getbinaryfile(uri.path, path, 256*1024)
         return true
       end
     when "http"
       http = Net::HTTP.new(uri.host)
       puts "downloading #{url}"
       File.open(path, "w") do |file|
         http.get(uri.path) do |block|
           file.write(block)
         end
       end
     when "ssh"
       # TODO need better way to do conditional download
#       timestamp = `ssh #{uri.user + '@' if uri.user}#{uri.host} "ruby -e 'puts File.mtime(\\"#{uri.path}\\").to_i'"`.to_i
       out = nil
       timestamp = File.exist?(path) ? File.mtime(path).to_i : 0 
       tempfile = Tempfile.new("tmp")
       status = Open4::popen4("ssh #{uri.user + '@' if uri.user}#{uri.host} \"fig-download #{timestamp} #{uri.path}\"") do |pid, stdin, stdout, stderr|
          $stderr.puts "downloading #{url}"
          err = stderr.read
          while bytes = stdout.read(4096) do
            tempfile.write(bytes)
          end
          $stderr.print err
       end
       tempfile.close
       case $?.exitstatus
       when NOT_MODIFIED
         tempfile.delete
         return false
       when NOT_FOUND
         tempfile.delete
         raise "File not found: #{uri}"
       when SUCCESS
         FileUtils.mv(tempfile.path, path)
         return true
       else
         tempfile.delete
         $stderr.puts "Unable to download file: #{$?.exitstatus}"
         exit 1
       end
     else
       raise "Unknown protocol: #{url}"
     end
   end

   def download_resource(url, dir)
     FileUtils.mkdir_p(dir)
     download(url, File.join(dir, URI.parse(url).path.split('/').last))
   end

   def download_archive(url, dir)
     FileUtils.mkdir_p(dir)
     basename = URI.parse(url).path.split('/').last
     path = File.join(dir, basename)
     download(url, path)
     case basename
     when /\.tar\.gz$/
       fail unless system "tar -C #{dir} -zxf #{path}"
     when /\.tgz$/
       fail unless system "tar -C #{dir} -zxf #{path}"
     when /\.tar\.bz2$/
       fail unless system "tar -C #{dir} -jxf #{path}"       
     when /\.zip$/
       fail unless system "unzip -q -d #{dir} #{path}"
     else
       raise "Unknown archive type: #{basename}"
     end
   end

   def upload(local_file, remote_file, user)
     puts "uploading #{local_file} to #{remote_file}"
     uri = URI.parse(remote_file)
     if uri.scheme == "ssh"
       dir = uri.path[0, uri.path.rindex('/')]
       cmd = "mkdir -p #{dir} && cat > #{uri.path}"
       fail unless system "cat #{local_file} | ssh #{uri.user + '@' if uri.user}#{uri.host} '#{cmd}'"
     else
       fail unless system "curl -p -T #{local_file} --create-dirs --ftp-create-dirs #{remote_file}"
     end
   end

   def clear_directory(dir)
     FileUtils.rm_rf(dir)
     FileUtils.mkdir_p(dir)
   end

   def exec(dir,command)
     Dir.chdir(dir) { raise "Command failed" unless system command }
   end

   def copy(source, target)
     FileUtils.mkdir_p(File.dirname(target))
     File.copy(source, target)
     target
   end

   def log_info(msg)
     puts msg
   end
 end
end
