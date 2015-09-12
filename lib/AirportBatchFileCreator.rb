require 'timeout'
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
    existing_files = Dir["./lib/airport_files/*"].map{|txt_file| /[\d\w]+\.txt/.match(txt_file)[0][0..-5].downcase}
    not_yet_grabbed = urls.select do |url|
                        ident = /\/[\d\w]+$/.match(url)[0][1..-1].downcase
                        !existing_files.include?(ident)
                      end

    urls.each do |url|
      begin
        Timeout.timeout( 6 ) do
          airport = AirportInfoScraper.new(url)
          writer = AirportFileWriter.new(airport)
          writer.write_new_file
        end
        sleep(3)
      rescue Timeout::Error
        next
      rescue
        next
      end
    end
  end
end

# TESTING HOW LONG 4 PAGES TAKE TO DETERMINE THE LENGTH OF THE TIMEOUT------------
# links = ["http://www.airnav.com/airport/CZPC", "http://www.airnav.com/airport/kdxr", "http://www.airnav.com/airport/kpne", "http://www.airnav.com/airport/kbos"]

# start_time = Time.now
# batch_creator = AirportBatchFileCreator.new(links)
# batch_creator.batch_create
# end_time = Time.now
# elapsed = end_time - start_time
# puts "#{elapsed} second to complete #{links.count} pages." #8.481718 second to complete 4 pages.
# --------------------------------------------------------------------------------

# puts Dir["./lib/airport_files/*"].count # Return an array of all the files in a directory

url_array = LinksFromHash.new(AllAirportUrls)
url_array.grab_links
links = url_array.all_links
# links = ["http://www.airnav.com/airport/KBOS","http://www.airnav.com/airport/CZPC","http://www.airnav.com/airport/KDXR","http://www.airnav.com/airport/KPNE","http://www.airnav.com/airport/KPHL"]
batch_creator = AirportBatchFileCreator.new(links)
p batch_creator.batch_create

# batch_creator = AirportBatchFileCreator.new(["http://www.google.com"])
# batch_creator.batch_create


# p existing_files = Dir["./lib/airport_files/*"].map{|txt_file| /[\d\w]+\.txt/.match(txt_file)[0][0..-5].downcase}