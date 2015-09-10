class LinksFromHash
  attr_accessor :all_links
  attr_reader :hash_of_links

  def initialize(hash_of_links)
    @hash_of_links = hash_of_links
    @all_links = []
  end

  def grab_links
    hash_of_links.each do |country,state_or_array|
      if state_or_array.class == Array
        state_or_array.each{|entry| all_links << entry}
      else
        state_or_array.each{|state, airports| airports.each{|airport| all_links << airport}}
      end
    end
  end

end