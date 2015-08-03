require 'pry'
require 'nokogiri'
require 'open-uri'
require 'pry'


class AirNavScraper

  MAIN_URL = "http://www.airnav.com"

  def initialize
    @airports = {}
  end

  def get_countries
    html = open("http://www.airnav.com/airports/browse.html").read
    doc = Nokogiri::HTML(html)
    country_urls = build_hrefs(doc)
    country_urls.each do |country_url|
      get_states(country_url)
    end   
  end

  def get_states(country_url)
    html = open(country_url).read
    doc = Nokogiri::HTML(html)
    states_or_airports = build_hrefs(doc)

    if /.*airports.*/.match(states_or_airports.first)
      # There is a list of states for this country.
      # Get the links to the states and proceed to the airports
      states_or_airports.each do |state|
        get_airports(state)
      end
    else # Country without states.  Go directly to airports
      get_airports(country_url)
    end
  end

  def get_airports(state_url)
    html = open(state_url).read
    doc = Nokogiri::HTML(html)
    airport_urls = build_hrefs(doc)
    binding.pry
    # take the last letters of the state_url as a key and build an array of all
    # the airport urls as a value
  end

  private
  def build_hrefs(doc)
    resource_names = doc.css("center a").map{|place| place['href']}.uniq.delete_if{|link| /^\?/.match(link)}
    complete_urls = resource_names.map{|locale_link| MAIN_URL + locale_link }
  end

end

scrape = AirNavScraper.new
# scrape.scrape_all_countries
# scrape.scrape_us_index
# scrape.scrape_airports("http://www.airnav.com/airports/us/AL")
# scrape.get_states("http://www.airnav.com/airports/us")
puts scrape.get_states("http://www.airnav.com/airports/fm")