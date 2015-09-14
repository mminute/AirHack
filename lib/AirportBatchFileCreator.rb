require 'timeout'
require 'pry'
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

    not_yet_grabbed.each do |url|
      begin
        Timeout.timeout( 30 ) do
          airport = AirportInfoScraper.new(url)
          writer = AirportFileWriter.new(airport)
          writer.write_new_file
        end
        sleep(5)
      rescue
        next
      end
    end
  end
end

# url_array = LinksFromHash.new(AllAirportUrls)
# url_array.grab_links
# links = url_array.all_links

# batch_creator = AirportBatchFileCreator.new(links)
# p batch_creator.batch_create
