require 'rubygems'
require 'rethinkdb'
require 'yaml'

include RethinkDB::Shortcuts

host = ENV['DB_HOST'] || 'localhost'
port = ENV['DB_PORT'] || 28015

r.connect(:host => host, :port => port).repl
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
       dirs.sort.each do |dir|
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

def doc_from_header(file)
  yaml_header = read_bytes(file).split(/^---$/)[1]
  if yaml_header
    begin
      return YAML.load(yaml_header)
    rescue Psych::SyntaxError => e
      warn "#{file}: #{e}"
    end
  else
    warn "#{file} has no yaml header"
  end
  return {}
end

max_batch_size = 200
batch = []
maybe_insert_batch = lambda do |docs|
  if docs.size > 0
    puts "INSERT #{ batch.map{|b| b["file_id"]}.inspect }"
    books_tbl.insert(docs).run
    batch = []
  end
end

pattern = ARGV.first
puts "File pattern: #{pattern}"

Dir.glob_recursively(pattern) do |file|
  doc = doc_from_header(file)

  file_id = File.basename(file).sub(/\.(md|txt)$/, "")
  # puts file_id

  # Add important fields to whatever is in the yaml header
  doc["file_id"] = file_id
  doc["title"] ||= file_id
  doc["size_bytes"] = File.size(file)

  # Clean up title by removing dup whitespace
  doc["title"].gsub!(/\s+/, " ")

  batch << doc

  maybe_insert_batch[batch] if batch.size >= max_batch_size
end

maybe_insert_batch[batch]