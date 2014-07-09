require 'rubygems'
require 'rethinkdb'
require 'yaml'

include RethinkDB::Shortcuts

r.connect(:host => 'localhost', :port => 28015).repl
books_tbl = r.db('research').table('books')

def read_bytes(filename, bytes=4096*4)
  File.open(filename) do |file|
    return file.read(bytes)
  end
end

class Dir
  def self.glob_recursively( pattern, &block )
     begin
       glob(pattern, &block)
       dirs = glob('*').select { |f| File.directory? f }
       dirs.each do |dir|
         # Do not process symlink
         next if File.symlink? dir
         chdir dir
         glob_recursively(pattern, &block)
         chdir '..'
       end
     rescue SystemCallError => e
       # STDERR
       warn "ERROR: #{pwd} - #{e}"
     end
  end
end

pattern = ARGV.first
puts "File pattern: #{pattern}"
Dir.glob_recursively(pattern) do |file|
  file_id = file.sub(/\.md$/, "")
  puts file_id
  yaml_header = read_bytes(file).split(/^---$/)[1]
  if yaml_header
    begin
      doc = YAML.load(yaml_header)
    rescue Psych::SyntaxError => e
      puts "WARNING: #{e}"
      doc = {}
    end
    puts "  #{doc["year"]}"
    doc["title"] ||= file
    doc["archive_org_id"] ||= file
    doc["title"] = doc["title"].gsub(/\s+/, " ")
    doc["size_bytes"] = File.size(file)

    existing_filter = books_tbl.get_all(file_id, {"index" => "archive_org_id"})
    existing_count = existing_filter.run.count

    if existing_count == 0
      puts "  (inserted)"
      result = books_tbl.insert(doc).run
      if result["inserted"] != 1
        puts result.inspect
      end
    elsif existing_count == 1
      puts "  (updated)"
      result = existing_filter.update(doc)
    else
      puts "WARNING: Ignored existing entry #{file_id} with #{existing_count}"
    end
  end
end
