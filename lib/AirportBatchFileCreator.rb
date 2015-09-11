require_relative 'AirportURLS'
require_relative 'LinksFromHash'
require_relative 'AirportInfoScrapper'
require_relative 'AirportFileWriter'

class AirportBatchFileCreator
  attr_reader :urls

  def initialize(url_array)
    @urls = url_array
  end

  def batch_create
    urls.each do |url|
      airport = AirportInfoScraper.new(url)
      writer = AirportFileWriter.new(airport)
      writer.write_new_file
    end
  end

end


# url_array = LinksFromHash.new(AllAirportUrls)
# url_array.grab_links
# links = url_array.all_links

# links = ["http://www.airnav.com/airport/CZPC"]

# batch_creator = AirportBatchFileCreator.new(links)
# batch_creator.batch_create
# puts Dir["./lib/airport_files/*"].count # Return an array of all the files in a directory

# def missing_airports(links_array)
#   files_found = Dir["./lib/airport_files/*"]
#   [].tap do |missing_files|
#     links_array.each do |link|
#       if files_found
#         "http://www.airnav.com/airport/KGEY"
#       end
#     end
#   end
# end

# def airport_from_txt(txt_file)
#   /[\d\w]+\.txt/.match(txt_file)[0][0..-5]
# end

# def airnav_prefixer(id)
#   "http://www.airnav.com/airport/" + id
# end

# def files_to_url(arr)
#   arr.map do |file_name|
#     ident = airport_from_txt(file_name)
#     airnav_prefixer(ident)
#   end
# end

# p missing_airports(links)

# p airport_from_txt("./lib/airport_files/Z95.txt")
# p airport_from_txt("./lib/airport_files/KSMX.txt")

# p airnav_prefixer("KSMX")

# files_found = Dir["./lib/airport_files/*"]
# p files_to_url( files_found )
