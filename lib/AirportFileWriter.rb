require_relative 'AirportInfoScrapper'


class AirportFileWriter
  attr_reader :url, :scraper

 InfoGrabberMethods = [:vfr_map, :airport_diagram, :airport_diagram_pdf_link,
 :sunrise_sunset, :current_date_and_time, :metar, :taf, :notam_link,
 :location, :airport_operations, :airport_comms, :vor, :non_directional_beacon, :airport_services,
 :runway_info, :airport_ownership, :airport_ops_stats, :additional_remarks, :instrument_procedures, :nearby_airports_with_instrument_approaches,
 :other_pages, :where_to_stay, :aviation_businesses, :fixed_base_operators, :aerial_photo ]

  def initialize(scraper)
    @scraper = scraper
  end

  def write_new_file
    file_name = scraper.url[-4..-1] + ".txt"
    path = "lib/airport_files/"
    full_name = path + file_name

    airport_file = File.open(full_name, "w")

    InfoGrabberMethods.each do |method|
      rescuer(method, airport_file)
    end
    
    airport_file.close
  end

  def rescuer(method, airport_file)
    result =  begin
                scraper.send(method)
              rescue
                nil
              end
    airport_file.puts result
  end

end


# some_airport =  AirportInfoScraper.new("http://www.airnav.com/airport/kpne")
# info_writer = AirportFileWriter.new(some_airport)
# info_writer.write_new_file
