# == Schema Information
# Schema version: 20100707152350
#
# Table name: routes
#
#  id                :integer         not null, primary key
#  transport_mode_id :integer
#  number            :string(255)
#  created_at        :datetime
#  updated_at        :datetime
#  type              :string(255)
#  name              :string(255)
#  region_id         :integer
#  cached_slug       :string(255)
#  operator_code     :string(255)
#  loaded            :boolean
#

class Route < ActiveRecord::Base
  extend ActiveSupport::Memoizable
  
  has_many :route_operators, :dependent => :destroy
  has_many :operators, :through => :route_operators, :uniq => true
  has_many :route_segments, :dependent => :destroy, :order => 'id asc'
  has_many :from_stops, :through => :route_segments, :class_name => 'Stop' 
  has_many :to_stops, :through => :route_segments, :class_name => 'Stop'
  belongs_to :transport_mode
  has_many :campaigns, :as => :location, :order => 'created_at desc'
  has_many :problems, :as => :location, :order => 'created_at desc'
  has_many :route_localities, :dependent => :destroy
  has_many :localities, :through => :route_localities
  belongs_to :region
  accepts_nested_attributes_for :route_operators, :allow_destroy => true, :reject_if => :route_operator_invalid
  accepts_nested_attributes_for :route_segments, :allow_destroy => true, :reject_if => :route_segment_invalid
  validates_presence_of :number, :transport_mode_id
  validates_presence_of :region_id, :if => :loaded?
  cattr_reader :per_page
  has_friendly_id :short_name, :use_slug => true, :scope => :region
  has_paper_trail
  
  @@per_page = 20
  
  # instance methods

  def route_operator_invalid(attributes)
    (attributes['_add'] != "1" and attributes['_destroy'] != "1") or attributes['operator_id'].blank?
  end
  
  def route_segment_invalid(attributes)
    (attributes['_add'] != "1" and attributes['_destroy'] != "1") or \
    attributes['from_stop_id'].blank? or attributes['to_stop_id'].blank?
  end
  
  def region_name
    region ? region.name : nil
  end

  def unset_terminuses(stop_ids)
     RouteSegment.update_all("from_terminus = 'f'", ["route_id = ? and from_stop_id in (?)", id, stop_ids])
     RouteSegment.update_all("to_terminus = 'f'", ["route_id = ? and to_stop_id in (?)", id, stop_ids])
   end
  
   def stop_codes
     stops.map{ |stop| stop.atco_code }.uniq
   end

   def stop_area_codes
     stop_areas = stops.map{ |stop| stop.stop_areas }.flatten
     stop_areas.map{ |stop_area| stop_area.code }.uniq
   end

   def transport_mode_name
     transport_mode.name
   end

   def area(lowercase=false)
     area = ''
     area_list = areas(all=false)
     if area_list.size > 1
       area = "Between #{area_list.to_sentence}"
     else
       area = "In #{area_list.first}" if !area_list.empty?
     end
     if !area.blank? && lowercase
       area[0] = area.first.downcase
     end
     return area
   end

   def areas(all=true)
     if all or terminuses.empty? 
       route_stop_list = stops
     else
       route_stop_list = terminuses
     end
     areas = route_stop_list.map do |stop| 
       if stop.locality.parents.empty?
         stop.locality.name
       else
         stop.locality.parents.map{ |parent_locality| parent_locality.name }
       end
     end.flatten.uniq
     areas
   end

   def description
     "#{name(from_stop=nil, short=true)} #{area(lowercase=true)}"
   end
   memoize :description

   def short_name
     name(from_stop=nil, short=true)
   end

   def name(from_stop=nil, short=false)
     return self[:name] if !self[:name].blank?
     default_name = "#{number}"
     if from_stop
       return default_name
     else
       if short
         return default_name
       else
         return "#{transport_mode_name} #{default_name}"
       end
     end
   end

   def transport_modes
     [transport_mode]
   end

   def stops_or_stations
     route_segments.map do |route_segment|
       if route_segment.from_stop_area 
         from = route_segment.from_stop_area
       else
         from = route_segment.from_stop
       end
       if route_segment.to_stop_area
         to = route_segment.to_stop_area
       else
         to = route_segment.to_stop
       end
       [from, to] 
     end.flatten.uniq
   end
   
   def stops
     route_segments.map{ |route_segment| [route_segment.from_stop, route_segment.to_stop] }.flatten.uniq
   end
    memoize :stops

   def next_stops(current)
     if current.is_a? StopArea
       outgoing_segments = route_segments.select{ |route_segment| route_segment.from_stop_area_id == current.id } 
     else
       outgoing_segments = route_segments.select{ |route_segment| route_segment.from_stop_id == current.id } 
     end
     next_stops = outgoing_segments.map do |route_segment| 
       route_segment.to_stop_area ? route_segment.to_stop_area : route_segment.to_stop 
     end
     next_stops.uniq
   end

   def previous_stops(current)
     if current.is_a? StopArea
       incoming_segments = route_segments.select{ |route_segment| route_segment.to_stop_area_id == current.id }
     else
       incoming_segments = route_segments.select{ |route_segment| route_segment.to_stop_id == current.id }
     end
     previous_stops = incoming_segments.map do |route_segment| 
       route_segment.from_stop_area ? route_segment.from_stop_area : route_segment.from_stop 
     end
     previous_stops.uniq
   end

   def terminuses
     from_terminuses = route_segments.select{ |route_segment| route_segment.from_terminus? }
     to_terminuses = route_segments.select{ |route_segment| route_segment.to_terminus? }
     from_terminuses = from_terminuses.map do |segment| 
       segment.from_stop_area ? segment.from_stop_area : segment.from_stop 
     end
     to_terminuses = to_terminuses.map do |segment|
       segment.to_stop_area ? segment.to_stop_area : segment.to_stop 
     end
     terminuses = from_terminuses + to_terminuses
     terminuses.uniq
   end
   memoize :terminuses

   def name_by_terminuses(transport_mode, from_stop=nil, short=false)
     is_loop = false
     if short
       text = ""
     else
       text = transport_mode.name
     end
     if from_stop
       if terminuses.size > 1
         terminuses = self.terminuses.reject{ |terminus| terminus == from_stop }
       else
         is_loop = true
         terminuses = self.terminuses
       end
       terminuses = terminuses.map{ |terminus| terminus.name_without_suffix(transport_mode) }.uniq
       if terminuses.size == 1
         if is_loop
           text += " towards #{terminuses.to_sentence}"
         else
           text += " towards #{terminuses.to_sentence}"
         end
       else
         text += " between #{terminuses.sort.to_sentence}"
       end
     else
       terminuses = self.terminuses.map{ |terminus| terminus.name_without_suffix(transport_mode) }.uniq
       if terminuses.size == 1
         text += " from #{terminuses.to_sentence}"
       else
         if short
           text += "#{terminuses.sort.join(' to ')}"     
         else
           text += " route between #{terminuses.sort.to_sentence}"     
         end
       end
     end 
     text
   end
   
   def responsible_organizations
     operators
   end
   
   def councils_responsible? 
     false
   end

   def pte_responsible? 
     false
   end

   def operators_responsible?
     true
   end
  
  # class methods
  
  def self.full_find(id, scope)
    find(id, 
         :scope => scope, 
         :include => [{ :route_segments => [:to_stop => :locality, :from_stop => :locality] }, 
                          { :route_operators => :operator }])
    
  end
  
  # Return routes with this number and transport mode that have a stop or stop area in common with 
  # the route given
  def self.find_all_by_number_and_common_stop(new_route, operator_id)
    stop_codes = new_route.stop_codes
    stop_area_codes = new_route.stop_area_codes
    routes = Route.find(:all, :conditions => ['number = ? 
                                         and transport_mode_id = ? 
                                         and route_operators.operator_id = ?', 
                                         new_route.number, new_route.transport_mode.id, operator_id],
                        :include => [{ :route_segments => [:from_stop, :to_stop] }, :route_operators])
    routes_with_same_stops = []
    routes.each do |route|
      route_stop_codes = route.stop_codes
      stop_codes_in_both = (stop_codes & route_stop_codes)
      if stop_codes_in_both.size > 0
        routes_with_same_stops << route
        next
      end  
      route_stop_area_codes = route.stop_area_codes
      stop_area_codes_in_both = (stop_area_codes & route_stop_area_codes)
      if stop_area_codes_in_both.size > 0
        routes_with_same_stops << route
      end
    end
    routes_with_same_stops
  end
  
  # Accepts an array of stops or an array of arrays of stops as first parameter.
  # If passed the latter, will find routes that pass through at least one stop in
  # each array.
  def self.find_all_by_stops(stops, transport_mode_id, as_terminus=false, limit=nil)
    from_terminus_clause = ''
    to_terminus_clause = ''
    condition_string = 'transport_mode_id = ?' 
    params = [transport_mode_id]
    include_param = [{ :route_segments => [:from_stop, :to_stop] }]
    joins = ''
    stops.each_with_index do |item,index|
      if as_terminus
        from_terminus_clause = "rs#{index}.from_terminus = 't' and"
        to_terminus_clause = "rs#{index}.to_terminus = 't' and"
      end
      if item.is_a? Array
        stop_id_criteria = "in (?)"
      else
        stop_id_criteria = "= ?"
      end
      joins += " inner join route_segments rs#{index} on routes.id = rs#{index}.route_id"
      condition_string += " and ((#{from_terminus_clause} rs#{index}.from_stop_id #{stop_id_criteria})"
      condition_string += " or (#{to_terminus_clause} rs#{index}.to_stop_id #{stop_id_criteria}))"
      params << item
      params << item
    end
    conditions = [condition_string] + params
    routes = find(:all, :select => "distinct routes.id",
                        :joins => joins, 
                        :conditions => conditions, 
                        :include => include_param, 
                        :limit => limit).uniq
    # The joins in the query above cause it to return instances with missing segments - 
    # remap to clean route objects
    Route.find(routes.map{ |route| route.id })
  end
  
  def self.find_existing_routes(new_route)
    operator_id = new_route.route_operators.first.operator.id
    find_all_by_number_and_common_stop(new_route, operator_id)
  end
  
  
  def self.find_without_operators(options={})
    if !options.has_key?(:order)
      options[:order] = 'number ASC'
    end
    query = 'id not in (SELECT route_id FROM route_operators)'
    params = []
    if options[:operator_code]
      query += " AND operator_code = ?"
      params << options[:operator_code]
    end
    params = [query] + params  
    find(:all, :conditions => params, 
         :limit => options[:limit], 
         :order => options[:order])
  end
  
  def self.count_without_operators(options={})
    count(:conditions => ['id not in (SELECT route_id FROM route_operators)'])
  end
  
  # finds operator codes that are associated with routes 
  # where the code isn't associated with an operator, 
  # and the route doesn't have an operator
  def self.find_codes_without_operators(options={})
    query = "SELECT operator_code, cnt FROM 
               (SELECT operator_code, count(*) as cnt
                FROM routes 
                WHERE operator_code not in 
                  (SELECT code 
                   FROM operators) 
                AND id not in 
                  (SELECT route_id
                   FROM route_operators)
                GROUP BY operator_code)
                 as tmp
             ORDER BY cnt desc"
    if options[:limit]
      query += " LIMIT #{options[:limit]}"
    end
    connection.select_rows(query)
  end
  
  def self.count_codes_without_operators()
    count(:select => 'distinct operator_code', 
          :conditions => ['operator_code not in (SELECT code FROM operators)'])
  end
  
  # Return train routes by the same operator that pass through the terminuses of this route, or
  # that have terminuses that this route passes through
  def Route.find_existing_train_routes(new_route)
    operator_id = new_route.route_operators.first.operator.id
    terminuses = new_route.terminuses
    stops = new_route.stops
    routes = []
    possible_routes = Route.find(:all, 
                                 :conditions => [ 'route_operators.operator_id = ?
                                                   and transport_mode_id = ?', 
                                                   operator_id, new_route.transport_mode_id],
                                 :include => [:route_operators, {:route_segments => [:from_stop, :to_stop]}])                                    
    possible_routes.each do |route|
      if route.terminuses.all?{ |terminus| stops.include? terminus } 
        routes << route
      end
      route_stops = route.stops
      if terminuses.all?{ |terminus| route_stops.include? terminus }
        routes << route
      end
    end
    routes
  end
  
  def self.find_from_attributes(attributes, limit=nil)
    routes = []
    if terminuses = get_terminuses(attributes[:route_number])
      first, last = terminuses
      routes = find_all_by_stop_names(first, last, attributes, limit)
    end
    routes
  end
  
  def self.find_all_by_stop_names(first, last, attributes, limit=nil)
    stop_attributes = attributes.merge(:route_number => nil)
    options = { :stops_only => true }
    results = Gazetteer.find_stops_and_stations_from_attributes(stop_attributes.merge(:area => first), options)
    first_stops = results[:results]
    results = Gazetteer.find_stops_and_stations_from_attributes(stop_attributes.merge(:name => first), options)
    first_stops += results[:results]
    results = Gazetteer.find_stops_and_stations_from_attributes(stop_attributes.merge(:area => last), options)
    last_stops = results[:results]
    results = Gazetteer.find_stops_and_stations_from_attributes(stop_attributes.merge(:name => last), options)
    last_stops += results[:results]
    Route.find_all_by_stops([first_stops, last_stops], 
                            attributes[:transport_mode_id], 
                            as_terminus=false, 
                            limit=limit)
  end
  
  def self.get_terminuses(route_name)
    if terminus_match = /^(.*)\sto\s(.*)$/.match(route_name)
      return [terminus_match[1], terminus_match[2]]
    else
      return nil
    end
  end
  
  def self.add!(route, verbose=false)
    puts "Adding #{route.number}" if verbose
    existing_routes = find_existing(route)
    if existing_routes.empty?
      route.save!
      return route
    end
    puts "got existing" if verbose
    original = existing_routes.first
    duplicates = existing_routes - [original] 
    merge_duplicate_route(route, original)
    puts "merging new" if verbose
    duplicates.each do |duplicate| 
      original = Route.find(original.id)
      puts "merging duplicates" if verbose
      if find_existing(duplicate).include? original
        merge_duplicate_route(duplicate, original) 
      end
    end
  end
  
  def self.merge!(merge_to, routes)
    transaction do
      routes.each do |route|
        next if route == merge_to
        merge_duplicate_route(route, merge_to)
      end
    end
  end
  
  def self.merge_duplicate_route(duplicate, original)
    raise "Can't merge route with campaigns: #{duplicate.inspect}" if !duplicate.campaigns.empty?
    raise "Can't merge route with problems: #{duplicate.inspect}" if !duplicate.problems.empty?
    duplicate.route_operators.each do |route_operator|
      if ! original.route_operators.detect { |existing| existing.operator == route_operator.operator }
        original.route_operators.build(:operator => route_operator.operator)
      end
    end
    non_terminuses = []
    duplicate.route_segments.each do |route_segment|
      direct_match = original.route_segments.detect do |existing| 
        (existing.from_stop == route_segment.from_stop && existing.to_stop == route_segment.to_stop)
      end     
      if direct_match    
        non_terminuses << route_segment.from_stop.id if !route_segment.from_terminus?
        non_terminuses << route_segment.to_stop.id if !route_segment.to_terminus?
      else
        to_terminus = (route_segment.to_terminus? && (original.terminuses.include? route_segment.to_stop or !original.stops.include? route_segment.to_stop))
        from_terminus = (route_segment.from_terminus? && (original.terminuses.include? route_segment.from_stop or !original.stops.include? route_segment.from_stop))
        non_terminuses << route_segment.to_stop.id if !to_terminus          
        non_terminuses << route_segment.from_stop.id if !from_terminus
        original.route_segments.build(:from_stop => route_segment.from_stop, 
                                      :to_stop => route_segment.to_stop,
                                      :from_terminus => from_terminus,
                                      :to_terminus => to_terminus)
      end
    end
    original.unset_terminuses(non_terminuses)
    duplicate.destroy
    original.save!
  end


end
