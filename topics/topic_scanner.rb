require 'mechanize'
require 'tempfile'
require 'yaml'

puts `date`
$print = true if ARGV.include?('-p')
$full_scan = true if ARGV.include?('-f') # || Time.now.hour == 16
AGENTS = ['Mac Safari', 'Windows Mozilla', 'Linux Firefox']

WORKSPACE = File.expand_path(File.dirname(__FILE__)) + '/'
CURRENT_LIST_FILENAME = WORKSPACE + 'topic_list.txt'
RESULT_FILE = WORKSPACE + 'result.txt'
TOPIC_CONTENT_PATH = WORKSPACE + 'content/'
URL = 'https://www.lds.org/topics'

$content_changes = false
$topic_changes = false
letters = ('a'..'z').to_a
results = letters.inject({}) { |hash, letter| hash[letter] = []; hash }

def url(letter)
  URL + "?letter=#{letter}"
end

def print_changes_between(ary1, ary2)
  changes_between(ary1, ary2).each do |topic|
    puts topic
  end
  puts
end

def changes_between(ary1, ary2)
  ary1 - ary2
end

def read_topic_list
  YAML.load(File.read(CURRENT_LIST_FILENAME))
end

def scan_topic_pages(page, topics)
  topics.each do |topic|
    puts "Getting #{topic} page..." if $print
    topic_page = page.link_with(text: topic).click
    primary_section = topic_page.at('#primary')
    next if primary_section.nil?
    text = ''
    primary_section.traverse { |node| text.concat(node.inner_text) if node.attributes.keys.include?('uri') }
    filename = TOPIC_CONTENT_PATH + topic + '.txt'
    if File.exists?(filename)
      file = Tempfile.new('topic')
      file.write(text)
      file.close
      diff = `diff '#{file.path}' '#{filename}'`
      if !diff.empty?
        $content_changes = true
        File.open(RESULT_FILE, 'a') { |f| f.write("Change in #{topic}:\n#{diff}\n\n") }
      end
    else
      File.open(filename, 'w') { |f| f.write(text) }
    end
  end
end

while letter = letters.shift
  agent = Mechanize.new { |a| a.user_agent_alias = AGENTS[rand(3)] }
  puts "Getting #{letter} page..." if $print
  page = agent.get(url(letter))
  topics_html = page.at('.topics')
  topic_titles = topics_html.children.map { |child| child.at('a').text }
  results[letter] = topic_titles
  scan_topic_pages(page, topic_titles) if $full_scan
end

previous = read_topic_list

results.each do |letter, current|
  if current != previous[letter]
    $topic_changes = true
    if $print
      puts "Change on page #{url(letter)}"
      puts "Added:"
      print_changes_between(current, previous[letter])
      puts "Removed:"
      print_changes_between(previous[letter], current)
    else
      File.open(RESULT_FILE, 'a') do |f|
        f.write("Added:\n")
        f.write(changes_between(current, previous[letter]).join("\n"))
        f.write("\nRemoved:\n")
        f.write(changes_between(previous[letter], current).join("\n"))
        f.write("\n\n\n\n")
      end
    end
  end
end

`/usr/bin/notify-send 'Topic Change Detected'` if $topic_changes || $content_changes
if $topic_changes
  File.rename(CURRENT_LIST_FILENAME, "#{CURRENT_LIST_FILENAME}-pre#{Time.now.strftime('%Y-%m-%d_%H:%M')}.txt")
  File.open(CURRENT_LIST_FILENAME, 'w') { |f| f.write(results.to_yaml) }
end
`/usr/bin/notify-send Done`
