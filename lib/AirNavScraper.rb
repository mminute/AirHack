require 'pry'
require 'nokogiri'
require 'open-uri'
require 'pry'


class AirNavScraper

  def scrape_countries
    main_airnav_url = "http://www.airnav.com"
    html = open("http://www.airnav.com/airports/us").read
    
  end

  # Modify this to accept data from scrape_countries
  def scrape_us_index
    main_airnav_url = "http://www.airnav.com"
    html = open("http://www.airnav.com/airports/us").read
    doc = Nokogiri::HTML(html)
    us_states = doc.css("center a").map{|link| link['href']}.uniq.delete_if{|link| /^\?/.match(link)}
    states_urls = us_states.map{|state_link| main_airnav_url + state_link }
    binding.pry
  end

end

scrape = AirNavScraper.new
scrape.scrape_us_index