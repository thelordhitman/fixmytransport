# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  def google_maps_key
    MySociety::Config.get('GOOGLE_MAPS_API_KEY', '')
  end
  
  def transport_mode_radio_buttons
    tags = []
    available_modes = TransportMode.active.find(:all)
    tags << %Q[<div id="transport-mode-radio">]
    tags << %Q[<div class="transport-mode">] 
    available_modes.each do |transport_mode| 
      tag = radio_button_tag 'transport_mode_id', transport_mode.id, params[:transport_mode_id] == transport_mode.id.to_s, {:class => 'transport-mode'}
      tag += label_tag "transport_mode_id_#{transport_mode.id}", transport_mode.name
      tag = %Q[<div class="transport-bg-#{transport_mode.css_name}">#{tag}</div>]
      tags << tag
    end
    tags << "</div>"
    tags << "</div>"
    tags.join("\n")
  end
  
  def location_type_radio_buttons(campaign)
    tags = []
    location_types = { 'Stop' => 'Stop', 
                       'StopArea' => 'Station', 
                       'Route' => 'Route'}
              
    location_types.keys.sort.each do |location_class|
      checked = campaign.location_type == location_class
      tag = radio_button 'campaign', 'location_type', location_class, {:class => 'location-type'}
      tag += location_types[location_class]
      tags << tag
    end
    tags.join("\n")
  end
  
  # options:
  #  no_jquery - don't include a tag for the main jquery js file
  def map_javascript_include_tags(options={})
    tags = []
    unless options[:no_jquery]
      tags << javascript_include_tag('jquery-1.4.2.min.js')
    end
    tags << javascript_include_tag('OpenLayers.js')
    tags << "<script src=\"http://maps.google.com/maps?file=api&amp;v=2&amp;sensor=false&amp;key=#{google_maps_key}\" type=\"text/javascript\"></script>"
    tags << javascript_include_tag('map.js')
    tags.join("\n")
  end
  
  def icon_style(location, lon, lat, zoom, small, map_height, map_width)
    top = Map.lat_to_y_offset(lat, location.lat, zoom, map_height) - (icon_height(small) / 2)
    left = Map.lon_to_x_offset(lon, location.lon, zoom, map_width) - (icon_width(small) / 2)
    "position: absolute; top: #{top}px; left: #{left}px;"
  end
  
  def icon_height(small)
    small ? SMALL_ICON_HEIGHT : LARGE_ICON_HEIGHT
  end
  
  def icon_width(small)
    small ? SMALL_ICON_WIDTH : LARGE_ICON_WIDTH
  end
  
  def stop_js_coords(stop, main=true, small=false, link_type=:location, location=nil)
    location = (location or stop)
    { :lat => stop.lat, 
      :lon => stop.lon,
      :id => stop.id, 
      :url => map_link_url(location, link_type),
      :description => location.description, 
      :icon => stop_icon(stop, main, small),
      :height => icon_height(small), 
      :width => icon_width(small) }
  end
  
  def stop_icon(location, main=false, small=false)
    name = ''
    if location.is_a? Route
      if location.transport_mode_name == 'Train'
        name = 'train'
      elsif location.transport_mode_name == 'Tram/Metro'
        name = 'tram'
      elsif location.transport_mode_name == 'Ferry' 
        name = 'ferry'
      else
        name = 'bus'
      end
    else
      if location.respond_to?(:area_type) && location.area_type == 'GRLS'
        name = 'train'
      elsif location.respond_to?(:area_type) && location.area_type == 'GTMU'
        name = 'tram'
      elsif location.respond_to?(:area_type) && location.area_type == 'GFTD'
        name = 'ferry'
      else
        name = 'bus'
      end
    end
    name += '-main' if main
    name += '-sm' if small 
    return name
  end
  
  def route_segment_js(route)
    segments_js = route.route_segments.map do |segment| 
      [stop_js_coords(segment.from_stop, main=true, small=true), 
       stop_js_coords(segment.to_stop, main=true, small=true), segment.id]
    end
    segments_js.to_json
  end
  
  def location_stops_js(locations, main, small, link_type)
    array_content = []
    locations.each do |location|
      if location.is_a? Route or location.is_a? SubRoute
        if location.show_as_point
          array_content << stop_js_coords(location, main, false, link_type)
        elsif location.is_a? Route and link_type == :problem
          array_content <<  location.points.map{ |stop| stop_js_coords(stop, main, true, link_type, location) } 
        else 
          array_content <<  location.points.map{ |stop| stop_js_coords(stop, main, true, link_type) } 
        end
      else
       array_content << stop_js_coords(location, main, small, link_type) 
      end
    end
    array_content.to_json
  end
  
  def terminus_text(route)
    text = ''
    return text if route.stops.empty?
    terminuses = route.terminuses
    if terminuses.empty?
      terminuses = [route.stops.first]
    end
    stop_names = []
    terminus_links = []
    terminuses.each do |stop| 
      stop_name = stop.name_without_suffix(route.transport_mode)
      stop_area = stop.area
      link_text = stop_name
      if stop_name != stop_area
        link_text += " in #{stop_area}"
      end
      terminus_links << link_to(link_text, location_url(stop)) unless stop_names.include? link_text
      stop_names << link_text
    end
    if terminus_links.size > 1
      text += "Between " 
      text += terminus_links.to_sentence(:last_word_connector => ' and ') 
    else
      text += "From "
      text += terminus_links.first
    end
    text += "."    
  end
  
  def stop_name_for_admin(stop)
    name = stop.full_name
    if ! stop.street.blank?
      name += " #{t(:on_street, :street => stop.street)}"
    end 
    name += " #{t(:in_locality, :locality => stop.locality_name)} (#{stop.id})"
    name
  end
  
  def departures_link(stop)
    modes = stop.transport_mode_names
    if modes.include? 'Bus' or modes.include? 'Coach' or modes.include? 'Ferry'
      return link_to(t(:live_departures), "http://mytraveline.mobi/departureboard?stopCode=#{stop.atco_code}")
    else
      return "&nbsp;"
    end
  end
  
  def transport_direct_link(stop)
    return link_to(t(:transport_direct), "http://www.transportdirect.info/web2/journeyplanning/StopInformationLandingPage.aspx?et=si&id=fixmytransport&st=n&sd=#{stop.atco_code}")
  end
  
  def external_search_link(text)
    "http://www.google.co.uk/search?ie=UTF-8&q=#{CGI.escape(text)}"
  end
  
  def on_or_at_the(location)
    if location.is_a? Route or location.is_a? SubRoute
      return t(:on_the)
    elsif location.is_a?(StopArea) && ['GRLS', 'GTMU'].include?(location.area_type)
      return t(:at)
    else 
      return t(:at_the)
    end
  end
  
  def at_the_location(location)
    location_string = "#{on_or_at_the(location)} #{location.name}"
    if location.is_a?(Stop) && location.transport_mode_names.include?('Bus')
      location_string += " bus/tram stop"
    end
    location_string
  end
  
  def readable_location_type(location)
    if location.is_a? Stop or location.is_a? StopArea
      
      # some stops could be bus or tram/metro - call these stops
      if location.is_a?(StopArea) 
        if location.area_type == 'GBCS'
          return 'bus/coach station'
        end
      end
      transport_mode_names = location.transport_mode_names
      if transport_mode_names.include? 'Train' or transport_mode_names == ['Tram/Metro']
        return "station"
      end
      if transport_mode_names.include? 'Bus'
        return "stop"
      end
    end
    if location.is_a? TramMetroRoute
      return 'route'
    end
    if location.is_a? SubRoute
      return 'route'
    end
    location.class.to_s.tableize.singularize.humanize.downcase
  end
  
  def org_names(problem, method, connector, wrapper_start='<strong>', wrapper_end='</strong>')
    return '' unless problem
    names = problem.send(method).map{ |org| "#{wrapper_start}#{org.name}#{wrapper_end}" }
    names.to_sentence(:last_word_connector => connector, :two_words_connector => " #{connector} ")
  end
  
  def update_url(update)
    problem_url(update.problem, :anchor => "update_#{update.id}")
  end
  
  def pte_link(pte)
    link_to(pte.name, pte.wikipedia_url, :target => '_blank')
  end
  
  def responsible_name_type(location)
    if location.pte_responsible? 
      responsible = location.passenger_transport_executive.name
    else
      responsible = "#{t(:the)} #{t(location.responsible_organization_type)}"
    end
  end
  
  def location_path(location)
    if location.is_a? Stop
      return stop_path(location.locality, location)
    elsif location.is_a? StopArea
      if StopAreaType.station_types.include?(location.area_type)
         return station_path(location.locality, location)
       elsif StopAreaType.ferry_terminal_types.include?(location.area_type)
         return ferry_terminal_path(location.locality, location)
       else
         return stop_area_path(location.locality, location)
      end
    elsif location.is_a? Route
      return route_path(location.region, location)
    end
    raise "Unknown location type: #{location.class}"
  end
  
  def location_url(location, attributes={})
   if location.is_a? Stop
     return stop_url(location.locality, location, attributes)
   elsif location.is_a? StopArea
     if StopAreaType.station_types.include?(location.area_type)
       return station_url(location.locality, location, attributes)
     elsif StopAreaType.bus_station_types.include?(location.area_type)
       return bus_station_url(location.locality, location, attributes)
     elsif StopAreaType.ferry_terminal_types.include?(location.area_type)
       return ferry_terminal_url(location.locality, location, attributes)
     else
       return stop_area_url(location.locality, location, attributes)
     end
   elsif location.is_a? Route
     return route_url(location.region, location, attributes)
   end
   raise "Unknown location type: #{location.class}"
  end
  
  def map_link_url(location, link_type)
    if link_type == :location
      return location_url(location)
    elsif link_type == :problem
      return new_problem_url(:location_id => location.id, :location_type => location.type)
    else
      raise "Unknown link_type in map_link_url: #{link_type}"
    end
  end
  
  def short_date(date)
    return date.strftime("%e %b %Y").strip
  end
  
end
