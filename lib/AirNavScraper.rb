require 'pry'
require 'nokogiri'
require 'open-uri'

#Testing Data:
# get_places from country -> 153 seconds

class AirNavScraper
  attr_reader :airports

  MAIN_URL = "http://www.airnav.com"

  def initialize
    @airports = {}
  end

  def get_countries
    html = open("http://www.airnav.com/airports/browse.html").read
    doc = Nokogiri::HTML(html)
    country_urls = build_hrefs(doc)
    country_urls.each do |country_url|
      country_code = /..$/.match(country_url).to_s
      @airports[country_code] = get_places(country_url)
    end   
  end

  def get_places(containing_place_url)
    html = open(containing_place_url).read
    doc = Nokogiri::HTML(html)
    place_urls = build_hrefs(doc)
  end




# REPLACED!!!!!
  #   def get_states(country_url)
  #   html = open(country_url).read
  #   doc = Nokogiri::HTML(html)
  #   states_or_airports = build_hrefs(doc)

  #   # if /.*airports.*/.match(states_or_airports.first)
  #   #   # There is a list of states for this country.
  #   #   # Get the links to the states and proceed to the airports
  #   #   states_or_airports.each do |state|
  #   #     get_airports(state)
  #   #   end
  #   # else # Country without states.  Go directly to airports
  #   #   get_airports(country_url)
  #   # end
  # end

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
scrape.get_countries
puts scrape.airports
end_time = Time.new
puts "Elapsed time: #{end_time - start_time}"