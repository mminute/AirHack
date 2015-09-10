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

links = ["http://www.airnav.com/airport/CZPC"]

batch_creator = AirportBatchFileCreator.new(links)
batch_creator.batch_create
puts Dir["./lib/airport_files/*"].count # Return an array of all the files in a directory