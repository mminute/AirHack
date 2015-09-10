require 'pry'
require 'nokogiri'
require 'open-uri'
require 'pry'

require_relative 'AirportURLS'
require_relative 'LinksFromHash'
# require_relative 'AirportFileWriter'

class AirportInfoScraper
  attr_reader :doc, :url

  def initialize(airport_url)
    @url = airport_url
    html = open(@url).read
    @doc = Nokogiri::HTML(html)
  end

  def airport_identifier
    url[-4..-1]
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
      ndb_rows = first_result_parent("'NDB'").parent.children[3..-2]

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
    runway_name_element = first_result("'Runway Information'").next_element
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
    begin
      remarks_rows = table_selector("'Additional Remarks'").children[1..-2]

      [].tap do |collector|
        remarks_rows.each do |row|
          if row.children.count > 0
            collector << info_value(row)
          end
        end
      end
    rescue
      nil
    end
  end

  def instrument_procedures
    procedures_section = table_selector("'Instrument Procedures'")
    procedures_rows = procedures_section.next_element.css('tr')

    {}.tap do |info_hash|
      section_title = nil
      procedures_rows.each do |row|
        if row.children.first.name == 'th'
          section_title = row.children.first.children.last.content
          info_hash[ section_title ] = {}
        else
          info_hash[ section_title ][ instrument_approach_name(row) ] = instrument_approach_link(row)
        end
      end
      if info_hash.keys.count > 0
        info_hash[ :warning ] = instrument_procedures_warning_text(procedures_section)
      end
    end
  end

  def nearby_airports_with_instrument_approaches
    search_results = doc.search("[text()*='nearby airports with instrument procedures:']")

    if search_results.count > 0
      current_line = search_results.first.next_element

      {}.tap do |info_hash|
        while true
          if current_line.nil? == false
            airport_link = link_prefixer(current_line.attributes['href'].value)
            airport_id = current_line.children.first.content
            airport_name = current_line.next_sibling.text[3..-1]
            info_hash[ airport_id ] = { link: airport_link, name: airport_name }
          else
            break
          end
          current_line = nearby_airport_ia_next_line(current_line)
        end
      end
    end
  end

  def other_pages
    current_table = table_selector("'Other Pages'")
    [].tap do |info|
      while current_table.name == 'table'
        info << other_page_link(current_table)
        current_table = current_table.next_element
      end
    end
  end

  def where_to_stay
    where_to_stay_search = doc.search("[text()*='Where to Stay']")
    if where_to_stay_search.count > 0
      hotel_links = where_to_stay_search.first.parent.parent.next_element.next_element.next_element.css('tr td a')
      return_hash = Hash.new { |hash, key| hash[key] = { } }

      return_hash.tap do |info_hash|
        hotel_links.each do |link_element|
          hotel_link = hotel_link(link_element)
          hotel_name = link_element.children.first.text
          if hotel?(hotel_link, hotel_name)
            distance = hotel_distance(link_element)
            hotel_price = hotel_price_for(link_element)
            info_hash[ :hotels_nearby ][ hotel_name ] = { distance: distance, link: hotel_link, price: hotel_price }
          else
            hotel_count = number_of_hotels_in(link_element)
            info_hash[ :nearby_cities_hotels ][ hotel_name ] = { link: hotel_link, count: hotel_count }
          end
        end
      end
    end
  end

  def aviation_businesses
    terminator = Proc.new do |row|
      end_of_av_biz_list?(row)
    end

    hash_contents_processor = Proc.new do |row,info_hash|
        info_hash[ airport_biz_name(row) ] = { contact_info: airport_biz_comms(row), description: airport_biz_description(row), distance: distance_to_biz(row) }
    end

    airport_businesses("'Aviation Businesses'", terminator, hash_contents_processor)
  end

  def fixed_base_operators
    terminator = Proc.new do |row|
      end_of_fbo_list?(row)
    end

    hash_contents_processor = Proc.new do |row,info_hash|
        info_hash[ airport_biz_name(row) ] = { contact_info: airport_biz_comms(row), fuel: fbo_fuel(row) }
    end

    airport_businesses("'FBO, Fuel Providers, and Aircraft Ground Support'", terminator, hash_contents_processor)
  end

  def airport_businesses(search_term, terminator, hash_contents_processor)
    begin
      first_row = first_business_entry( search_term )
      biz_entries = airport_biz_rows(first_row, &terminator)
      create_info_hash(biz_entries, &hash_contents_processor)
    rescue
      nil
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
      first_result("'Download PDF'")['href']
    rescue
      nil
    end
  end

  def aerial_photo
    begin
      image = first_result_parent("'Aerial photo'").next_element.css('img').first.attributes['src'].value
      if image.include?("no-airport-photo")
        nil
      else
        image
      end
    rescue
      nil
    end
  end

  def sunrise_sunset
    sunset_sunrise_data = first_result_parent("'Morning civil twilight'").parent

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
    date_and_time_data = first_result_parent("'Current date and time'").next_element.children.first.children[1]
    local_timezone = date_and_time_data.children[3].children.first.children.first.children.first.content[0..-3]

    {
      'Zulu (UTC)'   => date_and_time_data.children[1].children.last.children.first.children.first.content,
      local_timezone => date_and_time_data.children[3].children.last.children.first.children.first.content
    }
  end

  def metar
    metar_data_rows = first_result_parent("'METAR'").parent.css('tr')[2..-1]
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

  def notam_link
    "https://pilotweb.nas.faa.gov/PilotWeb/notamRetrievalByICAOAction.do?method=displayByICAOs&reportType=RAW&formatType=DOMESTIC&retrieveLocId=" + airport_identifier + "&actionType=notamRetrievalByICAOs"
  end

  # Helper Methods
  def create_info_hash(rows, &hash_contents_processor)
    {}.tap do |info_hash|
      rows.each do |row|
        hash_contents_processor.call(row, info_hash)
      end
    end
  end

  def link_prefixer(suffix)
    "http://www.airnav.com" + suffix
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
      begin
        row.children[1].children.first.content
      rescue
        nil
      end
      
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
    link_prefixer( row.children.first.children.first.attributes['href'].value )
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

  def instrument_approach_name(row)
    row.children[1..-1].first.children.first.content
  end

  def instrument_approach_link(row)
    begin
      row.children[1..-1].children.css('a').first.attributes['href'].value[8..-1]
    rescue
      nil
    end
  end

  def instrument_procedures_warning_text(procedures_section)
      warning_text(procedures_section,0).children.first.content + warning_text(procedures_section, 1).content + " " + warning_text(procedures_section, 3).content
  end

  def warning_text(procedures_section, idx)
    procedures_section.children.last.children[idx]
  end

  def nearby_airport_ia_next_line(current_line)
    current_line.next_sibling.next_sibling.next_sibling.next_element
  end

  def other_page_link(current_table)
    link_text = current_table.css('tr').first.children.css('td').last.children.last.children.text
    if link_text[-3..-1] == "..."
      link_text[0..-4]
    else
      link_text
    end
  end

  def hotel_link(link_element)
    link_prefixer( link_element.attributes['href'].value )
  end

  def hotel?(hotel_link, hotel_name)
    link_text = hotel_name.split(",").map{|part| part.strip.upcase.gsub(" ","+")}.join(",")
    !hotel_link.include?(link_text)
  end

  def hotel_distance(link_element)
    link_element.parent.next_element.next_element.css('font').children.first.text.delete("\xC2\xA0").to_f
  end

  def hotel_price_for(link_element)
    link_element.parent.next_element.next_element.next_element.children.first.children.text
  end

  def number_of_hotels_in(link_element)
    link_element.parent.previous_element.children.first.text.split("").delete_if{|i| i.to_i == 0}.join.to_i
  end

  def airport_biz_rows(row, &terminator)
    [].tap do |collector|
      while true
        if is_this_an_airport_biz?(row)
          collector << row
          row = row.next_element
        elsif terminator.call(row)
          break
        else
          if row == nil
            break
          else
            row = row.next_element
          end
        end
      end
    end
  end

  def end_of_av_biz_list?(row)
    begin
      row.text == "\xC2\xA0"
    rescue
      false
    end
  end

  def is_this_an_airport_biz?(current_row)
    begin
      airport_biz_name(current_row)
    rescue
      false
    end
  end

  def airport_biz_name(current_row)
    if current_row.children[1].children.text.strip.delete("\xC2\xA0") == ""
      current_row.children[1].children.last.children.first.attributes['alt'].value
    else
      current_row.children[1].children.text.strip.delete("\xC2\xA0")
    end
  end

  def airport_biz_comms(current_row)
    return_hash = Hash.new { |hash, key| hash[key] = [ ] }

    return_hash.tap do |info_hash|
      contact_info = current_row.children[5].children.css('font').children.each do |item|
        if fbo_email?(item)
          info_hash[ :email ] = fbo_email(item)
        elsif fbo_website?(item)
          info_hash[ :link ] = fbo_link(item)
        elsif fbo_radio?(item)
          info_hash[ :radio ] = item.text
        else
          info_hash[ :other ] << item.text unless ["","[","]","\n\n","\n"].include?(item.text)
        end
      end
    end
  end

  def airport_biz_description(row)
    row.children[9].children.text.delete("\n").delete("\xC2\xA0").strip
  end

  def distance_to_biz(row)
    row.children[13].text
  end

  def website_or_email?(item)
    item.text == "web site" || item.text == "email"
  end

  def fbo_email?(item)
    item.text == "email"
  end

  def fbo_website?(item)
    item.text == "web site"
  end

  def fbo_radio?(item)
    /\d\d\d\.\d\d$/.match(item.text)
  end

  def fbo_link(item)
    link_prefixer( item.attributes['href'].value )
  end

  def fbo_email(item)
    item.attributes['href'].value.split("?")[0].split(":")[1]
  end

  def fbo_fuel(current_row)
    fuel_rows = current_row.children[13].children[1].children
    {}.tap do |info_hash|
      prices = fuel_prices( fuel_rows[2] )
      fuel_types( fuel_rows[1] ).each.with_index do |type, idx|
        info_hash[ type ] = prices[ idx ]
      end
    end
  end

  def fuel_types(row)
    row.css('td').map{|td| td.children.text}.delete_if{|text| text == ""}
  end

  def fuel_prices(row)
    row.css('td').map{|td| td.children.text}.delete_if{|text| text[0] != "$"}
  end

  def end_of_fbo_list?(row)
    begin
      row.css('td a img').first.attributes['alt'].text == "Update Fuel Prices"
    rescue
      false
    end
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
    begin
      first_result(search).next_element
    rescue
      nil
    end
  end

  def first_business_entry(search)
    first_result_parent(search).parent.next_element.next_element
  end

  def first_result(search)
    doc.search("[text()*=#{search}]").first
  end

  def first_result_parent(search)
    doc.search("[text()*=#{search}]").first.parent
  end

end

scraper = AirportInfoScraper.new("http://www.airnav.com/airport/kpne")
# puts "VFR MAP"
# p scraper.vfr_map
# puts "AIRPORT DIAGRAM"
# p scraper.airport_diagram
# puts "DIAGRAM LINK"
# p scraper.airport_diagram_pdf_link
# puts "SUNRISE AND SUNSET"
# p scraper.sunrise_sunset
# puts "CURRENT DATE AND TIME"
# p scraper.current_date_and_time
# puts "METAR"
# p scraper.metar
# puts "TAF"
# p scraper.taf
# puts "NOTAM LINK"
# p scraper.notam_link
# puts "LOCATION"
# p scraper.location
# puts "AIRPORT OPERATIONS"
# p scraper.airport_operations
# puts "AIRPORT COMMUNICATIONS"
# p scraper.airport_comms
# puts "VOR"
# p scraper.vor
# puts "NON DIRECTIONAL BEACON"
# p scraper.non_directional_beacon
# puts "AIRPORT SERVICES"
# p scraper.airport_services
# puts "RUNWAY INFO"
# p scraper.runway_info
# puts "AIRPORT OWNERSHIP"
# p scraper.airport_ownership
# puts "AIRPORT OPS STATS"
# p scraper.airport_ops_stats
# puts "ADDITIONAL REMARKS"
# p scraper.additional_remarks
# puts "INSTRUMENT PROCEDURES"
# p scraper.instrument_procedures
# puts "NEARBY WITH IA"
# p scraper.nearby_airports_with_instrument_approaches
# puts "OTHER PAGES"
# p scraper.other_pages
# puts "WHERE TO STAY"
# p scraper.where_to_stay
# puts "AVIATION BUSINESSES"
# p scraper.aviation_businesses
# puts "FBO's"
# p scraper.fixed_base_operators
# puts "AERIAL PHOTO"
# p scraper.aerial_photo
# puts "AIRPORT IDENTIFIER"
# p scraper.airport_identifier

# Test Airports
# http://www.airnav.com/airport/KDXR
# http://www.airnav.com/airport/CZPC
# http://www.airnav.com/airport/KBOS

# Testing how long it takes to get all the data from an airport
# info_grabber_methods = [:vfr_map, :airport_diagram, :airport_diagram_pdf_link,
#  :sunrise_sunset, :current_date_and_time, :metar, :taf, :notam_link,
#  :location, :airport_operations, :airport_comms, :vor, :non_directional_beacon, :airport_services,
#  :runway_info, :airport_ownership, :airport_ops_stats, :additional_remarks, :instrument_procedures, :nearby_airports_with_instrument_approaches,
#  :other_pages, :where_to_stay, :aviation_businesses, :fixed_base_operators, :aerial_photo ]

#  start_time = Time.now
#  scraper = AirportInfoScraper.new("http://www.airnav.com/airport/kpne")

#  info_grabber_methods.each do |method|
#   scraper.send(method)
#  end

#  end_time = Time.now

#  elapsed_time = end_time - start_time

#  estimated_time = (elapsed_time * 4974)/(60*60)

#  puts "#{ elapsed_time }  seconds"
#  puts "Estimate #{ estimated_time } hours to complete all airports."




# a = LinksFromHash.new(AllAirportUrls)
# a.grab_links
# airport_urls = a.all_links # 4974 airport urls in an Array





# puts Dir["./lib/airport_files/*"] # Return an array of all the files in a directory

# class AirportFileMaker
# end