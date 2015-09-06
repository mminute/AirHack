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
      doc.search("[text()*='Download PDF']").first['href']
    rescue
      nil
    end
  end

  def sunrise_sunset
    sunset_sunrise_data = doc.search("[text()*='Morning civil twilight']").first.parent.parent

    morning_civil_twilight = sunset_sunrise_data.children
                   sunrise = sunset_sunrise_data.next_element.children
                    sunset = sunset_sunrise_data.next_element.next_element.children
    evening_civil_twilight = sunset_sunrise_data.next_element.next_element.next_element.children


    {
      'Morning Civil Twilight (Local)' => sunrise_sunset_content(morning_civil_twilight[2]),
      'Morning Civil Twilight (Zulu)' => sunrise_sunset_content(morning_civil_twilight[4]),
      'Sunrise (Local)' => sunrise_sunset_content(sunrise[2]),
      'Sunrise (Zulu)' => sunrise_sunset_content(sunrise[4]),
      'Sunset (Local)' => sunrise_sunset_content(sunset[2]),
      'Sunset (Zulu)' => sunrise_sunset_content(sunset[4]),
      'Evening Civil Twilight (Local)' => sunrise_sunset_content(evening_civil_twilight[2]),
      'Evening Civil Twilight (Zulu)' => sunrise_sunset_content(evening_civil_twilight[4])
    } 
  end

  def current_date_and_time
    date_and_time_data = doc.search("[text()*='Current date and time']").first.parent.next_element.children.first.children[1]
    local_timezone = date_and_time_data.children[3].children.first.children.first.children.first.content[0..-3]

    {
      'Zulu (UTC)'   => date_and_time_data.children[1].children.last.children.first.children.first.content,
      local_timezone => date_and_time_data.children[3].children.last.children.first.children.first.content
    }
  end


  # Helper Methods
  def sunrise_sunset_content(doc)
    doc.children.first.children.first.content
  end

end

scraper = AirportInfoScraper.new("http://www.airnav.com/airport/KPNE")
# p scraper.latitude_longitude
# p scraper.vfr_map
# p scraper.airport_diagram
# p scraper.airport_diagram_pdf_link
# p scraper.sunrise_sunset
# p scraper.current_date_and_time

# scraper2 = AirportInfoScraper.new("http://www.airnav.com/airport/CZPC")
# p scraper2.latitude_longitude

# "http://www.airnav.com/airport/KBOS"
# Airport w/o sectional map, airport diagram "http://www.airnav.com/airport/CZPC"