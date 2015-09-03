require 'pry'
require 'nokogiri'
require 'open-uri'

#Testing Data:
# get_places from country -> 153 seconds
# getting state level data: Elapsed time: 38.631141 (2015-08-28-20:38)
# getting all data with rescue Elapsed time: 1174.189964

class AirNavScraper
  attr_accessor :airports

  MAIN_URL = "http://www.airnav.com"

  def initialize
    @airports = {}
  end

  def collect_urls
    country_urls = get_places("http://www.airnav.com/airports/browse.html")

    country_urls.each do |country_url|
      country_code = place_abbreviation(country_url)
      states_or_airports = get_places(country_url)

      if airport?(states_or_airports.first)
        airports[country_code] = get_places(country_url)
      else
        airports[country_code] = {}
        states_or_airports.each do |state_url|
          state = place_abbreviation(state_url)
          airports[country_code][state] = get_places(state_url)
        end
      end

    end
  end

  def get_places(containing_place_url)
    begin
      html = open(containing_place_url).read
      doc = Nokogiri::HTML(html)
      place_urls = build_hrefs(doc)
    rescue Net::ReadTimeout
      nil
    end
  end

  def airport?(url)
    /.*airport\/.*/.match(url) != nil
  end

  def place_abbreviation(url)
    /..$/.match(url).to_s.upcase
  end

  private
  def build_hrefs(doc)
    resource_names = doc.css("center a").map{|place| place['href']}.uniq.delete_if{|link| /^\?/.match(link)}
    complete_urls = resource_names.map{|locale_link| MAIN_URL + locale_link }
  end

end



start_time = Time.now
scrape = AirNavScraper.new
# scrape.scrape_all_countries
# scrape.scrape_us_index
# scrape.scrape_airports("http://www.airnav.com/airports/us/AL")
# scrape.get_states("http://www.airnav.com/airports/us")
# puts scrape.get_states("http://www.airnav.com/airports/fm").class
# puts scrape.get_countries
scrape.collect_urls
# puts scrape.airports
#puts scrape.get_places("http://www.airnav.com/airports/us/MN")


end_time = Time.new
puts "Elapsed time: #{end_time - start_time}"