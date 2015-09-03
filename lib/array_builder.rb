puts "Minnesota links"
links = File.open("lib/MN-airportsURLS.txt").readlines
p links.map{|link| link.gsub("\n","")}



