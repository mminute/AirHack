require 'pry'
require 'nokogiri'
require 'open-uri'
require 'pry'

class AirportInfoScraper
  attr_reader :doc

  def initialize(airport_url)
    html = open(airport_url).read
    @doc = Nokogiri::HTML(html)
  end

  def location
    location_info = table_selector("'Location'").css('tr')[1..-1]

    hash_contents_processor = Proc.new do |row,info_hash|
                          if row.children[1].children.count > 1
                            attribute_value = location_lat_long_values(row)
                          else
                            attribute_value = row.children[1].children.first.content
                          end
                          info_hash[location_attribute(row)] = attribute_value
                        end

    create_info_hash(location_info, &hash_contents_processor)
  end

  def airport_operations
    ops_info_rows = table_selector("'Airport Operations'").children[1..-2]

    hash_contents_processor = Proc.new do |row,info_hash|
                          if row.children.count > 1
                            info_hash[info_key(row)] = airport_operations_value(row)
                          end
                        end
    create_info_hash(ops_info_rows, &hash_contents_processor)
  end

  def airport_comms
    begin
      comms_info_table = table_selector("'Airport Communications'")
      comms_info_rows  = comms_info_table.children[1..-2]

      hash_contents_processor = Proc.new do |row,info_hash|
                            if row.children.first
                              info_hash[info_key(row)] = info_value(row)
                            end
                          end
      comms_info = create_info_hash(comms_info_rows, &hash_contents_processor)

      if comms_info_table.next_element.name == "ul"
        comms_info['Notes'] = [].tap do |all_notes|
          comms_info_table.next_element.children.css('li').each do |item|
            all_notes << item.children.first.content.gsub("\n", "")
          end
        end
        comms_info
      end

    rescue
      nil
    end
  end

  def vor
    begin
      vor_data_rows = table_selector("'Nearby radio navigation aids'").children[2..-2]

      hash_contents_processor = Proc.new do |row,info_hash|
                              if row.children.count > 0
                                info_hash[vor_key(row)] = vor_value(row)
                              end
                            end
      create_info_hash(vor_data_rows, &hash_contents_processor)
    rescue
      nil
    end
  end

  def non_directional_beacon
    begin
      ndb_rows = doc.search("[text()*='NDB']").first.parent.parent.children[3..-2]

      hash_contents_processor = Proc.new do |row,info_hash|
                                if row.children.count > 0
                                  info_hash[non_directional_beacon_name(row)] = non_directional_beacon_value(row)
                                end
                              end

      create_info_hash(ndb_rows, &hash_contents_processor)
    rescue
      nil
    end
  end

  def airport_services
    begin
      services_rows = table_selector("'Airport Services'").children[1..-2]

      hash_contents_processor = Proc.new do |row,info_hash|
                      if row.children.count > 0
                        info_hash[info_key(row)] = info_value(row)
                      end
                    end
      create_info_hash(services_rows, &hash_contents_processor)
    rescue
      nil
    end
  end

  def runway_info
    runway_name_element = doc.search("[text()*='Runway Information']").first.next_element
    found_runway = true

    {}.tap do |runway_collector|
      while found_runway
        runway_info_table = runway_name_element.next_element
        runway_rows = runway_info_table.children[1..-2]
        runway_collector[runway_name_element.content] = runway_info_value(runway_rows)

        if more_runway_tables?(runway_info_table)
          runway_name_element = runway_info_table.next_element
        else
          found_runway = false
        end
      end
    end
  end

  def airport_ownership
    ownership_rows = table_selector("'Airport Ownership'").children[1..-2]

    hash_contents_processor = Proc.new do |row,info_hash|
                if row.children.count > 0
                  ownership_values = [].tap do |data|
                                        row.children.last.children.each do |datum|
                                          data << datum.content
                                        end
                                     end
                  info_hash[info_key(row)] = ownership_values.delete_if{|i| i == ""}
                end
              end
    create_info_hash(ownership_rows, &hash_contents_processor)
  end

  def airport_ops_stats
    begin
      table_data = table_selector("'Airport Operational Statistics'").css('td tr td')
      clean_data = table_data.children.map{|datum| datum.content}.delete_if{|item| /^\xC2\xA0$|\*/.match(item) }
      time_period = table_data.css('font').children.last.content

      {}.tap do |info_hash|
        i=0
        while i <= clean_data[0..-2].count-1
          if /Aircraft operations/.match(clean_data[i])
            split_entry = clean_data[i].split(": ")
            info_hash[ split_entry[0]+":" ] = split_entry[1]
            i+=1
          else
            if clean_data[i][0..-1].to_i > 0
              info_hash[ clean_data[i+1] ] = clean_data[i]
            else
              info_hash[ clean_data[i] ] = clean_data[i+1]
            end
            i+=2
          end
        end
        info_hash["Time Period"] = time_period
      end
    rescue
      nil
    end
  end

  def additional_remarks
    remarks_rows = table_selector("'Additional Remarks'").children[1..-2]

    [].tap do |collector|
      remarks_rows.each do |row|
        if row.children.count > 0
          collector << info_value(row)
        end
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
      table_selector("'CAUTION: Diagram may not be current'").next_element.attributes['src'].value[2..-1]
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
    metar_data_rows = doc.search("[text()*='METAR']").first.parent.parent.css('tr')[2..-1]
    hash_contents_processor = Proc.new{|row,info_hash| info_hash[metar_airport(row)] = metar_content(row) }
    create_info_hash(metar_data_rows, &hash_contents_processor)
  end

  def taf
    taf_data_rows = doc.search("[text()*='TAF']").last.parent.next_element.children.first.children[1].children[1..-2]

    hash_contents_processor = Proc.new do |row,info_hash|
                            if row.children.first
                              info_hash[taf_airport(row)] = taf_content(row)
                            end
                          end
    create_info_hash(taf_data_rows, &hash_contents_processor)
  end

  def notam
    doc.search("[text()*='NOTAMs']")[2].parent.attributes['href'].content
  end

  # Helper Methods
  def create_info_hash(rows, &hash_contents_processor)
    {}.tap do |info_hash|
      rows.each do |row|
        hash_contents_processor.call(row, info_hash)
      end
    end
  end

  def location_attribute(row)
    row.children.first.children.first.content[0..-2]
  end

  def location_lat_long_values(row)
    [].tap do |values_array|
      row.children[1].children.each do |child|
        values_array << child.content unless child.content == ""
      end
    end
  end

  def info_key(row)
    row.children.first.children.first.content[0..-2]
  end

  def airport_operations_value(row)
    if row.children[1].children.count > 1
      entries = row.children[1].children.map do |property|
                  property.content.strip
                end
      entries.delete_if{|item| item == ""}
    else
      row.children[1].children.first.content
    end
  end

  def info_value(row)
    row.children.last.children.first.content
  end

  def vor_key(row)
    row.children.first.children.first.children.first.content
  end

  def vor_value(row)
    {
      vor_name: navigation_property(row,2),
      vor_link: navigation_link(row),
      vor_radial_distance: vor_radial_distance(row),
      vor_freq: navigation_property(row,4),
      vor_var: navigation_property(row,6)
    }
  end

  def navigation_property(row,idx)
    row.children[idx].children.first.content
  end

  def vor_radial_distance(row)
    row.children.first.children[1].content.sub(" ", "")
  end

  def navigation_link(row)
    "www.airnav.com" + row.children.first.children.first.attributes['href'].value
  end

  def non_directional_beacon_name(row)
    row.children.first.children.first.children.first.content
  end

  def non_directional_beacon_value(row)
    {
      ndb_link: navigation_link(row),
      ndb_heading_distance: navigation_property(row,2),
      ndb_feq: navigation_property(row,4),
      ndb_var: navigation_property(row,6),
      ndb_id: navigation_property(row,8),
      ndb_morse_code: non_directional_beacon_morse_code(row)
    }
  end

  def non_directional_beacon_morse_code(row)
    row.children[9].children.last.content
  end

  def runway_info_value(rows)
    hash_contents_processor = Proc.new do |row,info_hash|
                              if row.children.count > 0 && row.children.first.children.first != nil
                                runway_data = row.children.last.children.first
                                info_hash[ info_key(row) ] = if row.children.last.children.count > 0
                                                                      runway_data.content
                                                                    end
                              end
                            end
    create_info_hash(rows, &hash_contents_processor)
  end

  def more_runway_tables?(runway_info)
    /Runway/.match(runway_info.next_element.content) && runway_info.next_element.next_element.name == 'table'
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

  def table_selector(search)
    doc.search("[text()*=#{search}]").first.next_element
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
# p scraper.location
# p scraper.airport_operations
# p scraper.airport_comms
# p scraper.table_selector("'Airport Communications'")
# p scraper.vor
# p scraper.non_directional_beacon
# p scraper.airport_services
# p scraper.runway_info
# p scraper.airport_ownership
# p scraper.airport_ops_stats
p scraper.additional_remarks


# scraper2 = AirportInfoScraper.new("http://www.airnav.com/airport/CZPC")
# p scraper2.latitude_longitude

# "http://www.airnav.com/airport/KBOS"
# Airport w/o sectional map, airport diagram "http://www.airnav.com/airport/CZPC"