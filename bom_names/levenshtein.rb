require 'levenshtein'

BOM_NAMES = File.read('bom_pronunciation_guide_names.txt').split
OTHER_NAMES = File.read(ARGV[0]).split

# Find lowest Levenstein distance for each name
result = BOM_NAMES.inject({}) do |accum, bname|
  min = 100
  indices = []
  OTHER_NAMES.each_with_index do |wname, index|
    distance = Levenshtein.distance(wname, bname)
    if distance < min
      indices = [index]
      min = distance
    elsif distance == min
      indices << index
    end
  end

  accum[bname] = [min].concat(indices.map { |i| OTHER_NAMES[i] })
  accum
end

# Sort by Levenshtein distance
sorted = result.sort { |a, b| a[1][0] <=> b[1][0] }

# Output results
sorted.each { |name, values| puts "#{name}: #{values[1..-1].join(', ')} (#{values[0]})" }
