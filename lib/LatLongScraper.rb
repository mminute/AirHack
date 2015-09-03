require 'pry'
require 'nokogiri'
require 'open-uri'



class LatLongScraper
  def get_latitude_longitude(airport_url)
    html = open(airport_url).read
    doc = Nokogiri::HTML(html)
    doc.search("[text()*='Lat/Long']").first.parent.children[1].content
  end
end

scraper = LatLongScraper.new
p scraper.get_latitude_longitude("http://www.airnav.com/airport/CZPC")