# Given a directory full of the rdf-files at http://www.gutenberg.org/wiki/Gutenberg:Feeds
# this script will process the rdf files and produce a CSV file with various metadata such
# as book title, author's name, author's birth year, language, and download location of the
# book.

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
