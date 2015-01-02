# Given a directory full of the rdf-files at http://www.gutenberg.org/wiki/Gutenberg:Feeds
# this script will process the rdf files and produce a CSV file with various metadata such
# as book title, author's name, author's birth year, language, and download location of the
# book.
#
# Example Usage:
# $ find . -name "*.rdf" | xargs -n 1 ruby gutenberg-rdf2csv.rb | tee guten.meta.csv
#
# Example Output:
# ./epub/31781/pg31781.rdf	31781	http://www.gutenberg.org/files/31781/31781.txt	http://mirrors.xmission.com/gutenberg/3/1/7/8/31781/31781.txt	The Bibliography of Walt Whitman	Frank Shay	1888	en
# ./epub/31782/pg31782.rdf	31782	http://www.gutenberg.org/files/31782/31782.txt	http://mirrors.xmission.com/gutenberg/3/1/7/8/31782/31782.txt	The Poniard's Hilt	Eugène Sue	1804	en
# ./epub/31783/pg31783.rdf	31783	http://www.gutenberg.org/files/31783/31783.txt	http://mirrors.xmission.com/gutenberg/3/1/7/8/31783/31783.txt	Was General Thomas Slow at Nashville?	Henry V. (Henry Van) Boynton	1835	en


require "gutenberg_rdf"

def subdirs(pair)
  dir, file = pair.split("/", 2)
  (dir.split("")[0..-2] + [dir, file]).join("/")
end

def path_from_uri(uri)
  if uri =~ %r|^http://www.gutenberg.org/dirs/(.+)$|
    return $1
  elsif uri =~ %r|^http://www.gutenberg.org/files/(.+)$|
    return subdirs($1)
  elsif uri =~ %r|^http://www.gutenberg.org/ebooks/(.+)\.txt\.utf-8|
    return subdirs($1 + "/" + $1 + "-8.txt")
  else
    # not working for us
  end
end

for path in ARGV
  book = GutenbergRdf.parse(path)
  author = book.authors.first

  ebooks = book.ebooks.sort_by do |x|
    [
      x.uri.scan(/\.txt/).first || "",
      x.uri.include?("-8.txt") ||
        x.uri.include?("utf-8") ||
        x.uri.include?("license") ||
        x.uri.include?("readme") ? 0 : 1
    ]
  end
  uri = (ebooks.last.uri rescue nil)

  dl = "http://mirrors.xmission.com/gutenberg/#{path_from_uri(uri)}"

  row = [
    path,
    book.id,
    uri,
    dl,
    (book.title rescue nil),
    (author.fullname rescue nil),
    (author.birthdate rescue nil),
    (book.language rescue nil)
  ]

  puts row.join("\t")
end
