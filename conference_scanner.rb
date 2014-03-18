require 'open-uri'
require 'thread'
require 'debugger'

THREAD_COUNT = 5  # Number of threads to retrieve pages simultaneously
RETRY_LIMIT = 2   # Number of times to retry a link before giving up
START_YEAR = 1971 # 1971 is first year conference reports are available at LDS.org
END_YEAR = 2013
MONTHS = ['04', '10'] # April, October
PHRASES = {'Joseph Smith' => /Joseph Smith/i, # Key should be the CSV header, value the regex to match
           'Book of Mormon' => /Book of Mormon/i,
           'Jesus Christ' => /Jesus Christ|Jesus|Christ|Savior/i}
HEADERS = "Conference Date,#{PHRASES.keys.join(',')}"

link_mutex = Mutex.new
results = {}

START_YEAR.upto(END_YEAR) do |year|
  MONTHS.each do |month|
    results["#{year}-#{month}"] = {}
    PHRASES.keys.each { |key| results["#{year}-#{month}"][key] = 0 }

    page = open("https://www.lds.org/general-conference/sessions/#{year}/#{month}?lang=eng").read
    links = page.scan(/<td class="print">\s*<a href="(https:\/\/www.lds.org\/general-conference\/print\/#{year}\/#{month}.+?)" class="print">/m).flatten
    threads = []
    THREAD_COUNT.times do |thread_id|
      threads << Thread.new do
        while links.size > 0

          link = nil
          link_mutex.synchronize { link = links.pop if links.size > 0 }

          if link
            retries = 0
            begin
              # puts "#{thread_id}: Visiting #{link}"
              page = open(link).read
              page = page[/<div\s*id="primary">.+?<p uri=(.+)<p uri=/im, 1] # Grabs #primary and omits last paragraph
              page.gsub!(/(<[A-Z\/][A-Z0-9]*[^>]*>)/i) # Strip out any html
              PHRASES.keys.each do |key|
                phrase_count = page.scan(PHRASES[key]).size
                results["#{year}-#{month}"][key] += phrase_count
              end
            rescue StandardError => e
              retries += 1
              retry if retries <= RETRY_LIMIT
            end
          end
        end
      end
    end
    threads.map(&:join)
  end
end

puts HEADERS
results.keys.each do |key|
  year, month = key.split('-')
  row = ["#{month}/#{year}"]
  PHRASES.keys.each { |phrase| row << results[key][phrase] }
  puts row.join(',')
end

