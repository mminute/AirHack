require_relative 'AirportBatchFileCreator'

class AirportFilePresenceVerifier
  attr_reader :links_array, :file_path

  def initialize(links_array, file_path)
    @links_array = links_array
    @file_path = file_path
  end

  def missing_airports_finder
    files_found = Dir[ file_path ]
    files_translated_to_url = files_to_url( files_found )
    [].tap do |missing_files|
      links_array.each do |link|
        if !files_translated_to_url.include?( link )
          missing_files << link
        end
      end
    end
  end

  def missing_location_data
    files_found = Dir[ file_path ]
    [].tap do |no_location|
      files_found.each do |path_and_file|
        reader = IO.readlines( path_and_file )[0]
        if !reader.include?(":location")
          no_location << path_and_file
        end
      end
    end
  end

  def airport_from_txt(txt_file)
    /[\d\w]+\.txt/.match(txt_file)[0][0..-5]
  end

  def airnav_prefixer(id)
    "http://www.airnav.com/airport/" + id
  end

  def files_to_url(arr)
    arr.map do |file_name|
      ident = airport_from_txt(file_name)
      airnav_prefixer(ident)
    end
  end

end

url_array = LinksFromHash.new(AllAirportUrls)
url_array.grab_links
links = url_array.all_links

find_the_missing = AirportFilePresenceVerifier.new(links, "./lib/airport_files/*")

# p find_the_missing.missing_location_data

# reader = IO.readlines("./lib/airport_files/kpne.txt")
# puts reader[0].include?(":location")
