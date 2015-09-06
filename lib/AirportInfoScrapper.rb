require 'pry'
require 'nokogiri'
require 'open-uri'



class AirportInfoScraper
  attr_reader :doc

  def initialize(airport_url)
    html = open(airport_url).read
    @doc = Nokogiri::HTML(html)
  end

  def location
    location_info = doc.search("[text()*='Location']").first.next_element.css('tr')[1..-1]
    {}.tap do |location_info_hash|
      location_info.each do |row|
        if row.children[1].children.count > 1
          attribute_value = [].tap do |attribute_values|
                                row.children[1].children.each do |child|
                                  attribute_values << child.content unless child.content == ""
                                end
                              end
        else
          attribute_value = row.children[1].children.first.content
        end

        location_info_hash[location_attribute(row)] = attribute_value
      end
    end
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

  def metar
    metar_data = doc.search("[text()*='METAR']").first.parent.parent.css('tr')[2..-1]

    {}.tap do |metar_data_hash|
      metar_data.each do |row|
        metar_data_hash[metar_airport(row)] = metar_content(row)
      end
    end
  end

  def taf
    taf_data = doc.search("[text()*='TAF']").last.parent.next_element.children.first.children[1].children[1..-2]

    {}.tap do |taf_data_hash|
      taf_data.each do |row|
        if row.children.first
          taf_data_hash[taf_airport(row)] = taf_content(row)
        end
      end
    end
  end

  def notam
    doc.search("[text()*='NOTAMs']")[2].parent.attributes['href'].content
  end

  # Helper Methods
  def location_attribute(row)
    row.children.first.children.first.content[0..-2]
  end

  def sunrise_sunset_content(info)
    info.children.first.children.first.content
  end

  def metar_airport(row)
    row.css('td font').first.children.first.children.first.content
  end

  def metar_content(row)
    row.css('td font')[1].content.gsub("\n", "").gsub("$", "").strip
  end

  def taf_airport(row)
    row.children.first.children.first.children.first.children.first.content
  end

  def taf_content(row)
    row.children.last.children.last.children.first.content.gsub(" \n", "")
  end

end

scraper = AirportInfoScraper.new("http://www.airnav.com/airport/KPNE")
# p scraper.latitude_longitude
# p scraper.vfr_map
# p scraper.airport_diagram
# p scraper.airport_diagram_pdf_link
# p scraper.sunrise_sunset
# p scraper.current_date_and_time
# p scraper.metar
# p scraper.taf
# p scraper.notam
p scraper.location




# scraper2 = AirportInfoScraper.new("http://www.airnav.com/airport/CZPC")
# p scraper2.latitude_longitude

# "http://www.airnav.com/airport/KBOS"
# Airport w/o sectional map, airport diagram "http://www.airnav.com/airport/CZPC"