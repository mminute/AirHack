require 'pry'
require 'nokogiri'
require 'open-uri'



class AirportInfoScraper
  attr_reader :doc

  def initialize(airport_url)
    html = open(airport_url).read
    @doc = Nokogiri::HTML(html)
  end

  def latitude_longitude
    doc.search("[text()*='Lat/Long']").first.parent.children[1].content
  end

  def vfr_map
    begin
      doc.search("[text()*='Sectional chart']")[1].parent.parent.css("img").first.attributes['src'].value
    rescue
      nil
    end
  end

  def airport_diagram
    begin
      doc.search("[text()*='CAUTION: Diagram may not be current']").first.next_element.next_element.attributes['src'].value[2..-1]
    rescue
      nil
    end
  end

  def airport_diagram_pdf_link
    begin
      doc.search("[text()*='CAUTION: Diagram may not be current']").first.next_element.next_element.attributes['src'].value[2..-1]
    rescue
      nil
    end
  end



  # def rescuer(block)
  #   begin
  #     block
  #   rescue
  #     nil
  #   end
  # end

end

scraper = AirportInfoScraper.new("http://www.airnav.com/airport/KPNE")
# p scraper.latitude_longitude
# p scraper.vfr_map
# p scraper.airport_diagram
p scraper.airport_diagram_pdf_link

# scraper2 = AirportInfoScraper.new("http://www.airnav.com/airport/CZPC")
# p scraper2.latitude_longitude

# "http://www.airnav.com/airport/KBOS"
# Airport w/o sectional map, airport diagram "http://www.airnav.com/airport/CZPC"