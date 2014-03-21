require 'mechanize'

names = []
('A'..'Z').each do |letter|
  next if ['W', 'X'].include?(letter)
  url = "https://en.wikipedia.org/wiki/List_of_biblical_names_starting_with_#{letter}"
  agent = Mechanize.new
  puts "Getting #{letter} page..."
  page = agent.get(url)
  names_html = page.at('#mw-content-text ul')
  names_html.children.each do |child|
    name = child.text.sub(/(?:\(.+?\))?,.+/, '').strip
    names << name if name.size > 0
  end
end
