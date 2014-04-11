require 'mechanize'
require 'thread'

THREAD_COUNT = 5
PHRASES = {'Joseph Smith' => /Joseph Smith/i, # Key should be the CSV header, value the regex to match
           'Book of Mormon' => /Book of Mormon/i,
           'Jesus Christ' => /Jesus Christ|Jesus|Christ|Savior/i}
HEADERS = "Conference Date,#{PHRASES.keys.join(',')}"
ROOT_URL = "https://archive.org/search.php?query=%28collection%3Aconferencereport%20OR%20mediatype%3Aconferencereport%29%20AND%20-mediatype%3Acollection&sort=date&page=1"
MONTHS_HASH = {'january' => '01',
               'february' => '02',
               'march' => '03',
               'april' => '04',
               'may' => '05',
               'june' => '06',
               'july' => '07',
               'august' => '08',
               'september' => '09',
               'october' => '10',
               'november' => '11',
               'december' => '12' }

results = {}
threads = []
mutex = Mutex.new
agent = Mechanize.new
agent.get(ROOT_URL)

while true
  current_root_page = agent.page
  links = agent.page.links.select { |link| link.text =~ /^Conference Report/i }
  THREAD_COUNT.times do |thread_id|
    threads << Thread.new do
      while links.size > 0
        link = nil
        mutex.synchronize { link = links.pop if links.size > 0 }

        if link
          link.text =~ /Annual\s+Conference\s*(\w+?)\s+(\d+)/
          year = $2
          month = MONTHS_HASH[$1 && $1.downcase]
          date = "#{year}-#{month}"
          puts "Date: #{date}"
          next if results[date]
          puts "Visiting #{link.text}..."
          agent.click(link)
          full_text_link = agent.page.links.detect { |l| l.text =~ /^Full Text/i }
          next unless full_text_link
          puts "Full Text link found"
          agent.click(full_text_link)
          full_text = agent.page.body
          full_text.gsub!(/(church|in\s+the\s+name)\s+of\s+(jesus\s+)?christ/i, '')
          results[date] = {}
          PHRASES.keys.each do |key|
            results[date][key] = 0
          end
          PHRASES.keys.each do |key|
            phrase_count = agent.page.body.scan(PHRASES[key]).size
            results[date][key] += phrase_count
          end
        end
      end
    end
  end
  threads.each { |t| t.join }

  next_link = current_root_page.link_with(text: 'Next')
  break unless next_link
  puts "Visiting #{next_link.text}"
  agent.click(next_link)
end

puts HEADERS
results.keys.each do |key|
  year, month = key.split('-')
  row = ["#{year}/#{month}"]
  PHRASES.keys.each { |phrase| row << results[key][phrase] }
  puts row.join(',')
end