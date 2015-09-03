require 'pry'
require 'nokogiri'
require 'open-uri'

class AirportLinkGetter
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


scrape = AirportLinkGetter.new
scrape.collect_urls
puts scrape.airports