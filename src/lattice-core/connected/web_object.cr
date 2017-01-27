module Lattice::Connected

  class WebObject
    INSTANCES = Hash(UInt64, self).new      # all instances of any WebObject, across all subclasses
    @@instances = Hash(String, UInt64).new  # individual instances of this class (CardGame, City, etc)
    class_property instances

    property subscribers = [] of HTTP::WebSocket   # Each instance has its own subcribers.
    property name : String
    
    # simple debugging catch early on if we are forgetting to clean up after ourselves.
    def self.display_all
      "There are a total of #{INSTANCES.size} WebObjects with a total of #{INSTANCES.values.flat_map(&.subscribers).size} subscribers"
    end

    def content
    end

    # a new thing must have a name, and that name must be unique so we can
    # find them across instances.
    def initialize(@name : String)
      INSTANCES[self.object_id] = self
      @@instances[@name] = self.object_id
    end

    # A subscriber, with the _session_id_ given, has oassed in an action
    def subscriber_action(data, session_id)
      puts "#{self.class}(#{self.name}) just received #{data} from session #{session_id}"
    end

    # a socket has requested a subscription to this object.  This means it will send & receive
    # messages across the _socket_ passed.  It is the initial handshake to a user  
    # It is the initial handshake between client and server.
    def subscribe( socket : HTTP::WebSocket )
      subscribers << socket unless subscribers.includes? socket
    end

    # delete a subscription for _socket_
    def unsubscribe( socket : HTTP::WebSocket)
      subscribers.delete(socket)
    end

    # Called during page rendering prep as a spinup for an object.  Instantiate a new 
    # object (if requested), return the javascript and object for rendering.
    def self.preload(name : String, session_id : String, create = true)
      existing = @@instances.fetch(name,nil)
      if existing
        target = INSTANCES[existing]
      else
        target = new(name)
      end
      return { javascript(session_id,target), target }
    end

    def self.js_var
      "#{self.to_s.split("::").last.downcase}Socket"
    end
   
    # The dom id .i.e <div id="abc"> for this object.  When later parsing this value
    # the system will look for the largest valued number in the dom_id, so it is ok
    # to use values like "clock24-11929238" which would return 11929238.
    def dom_id
      "#{self.class.to_s.split("::").last.downcase}-#{object_id}"
    end

    # this creates a connection back to the serverm immediately calls back with a session_id
    # and the element ids to which to subscribe.
    def self.javascript(session_id : String, target : _)
      javascript = <<-JS
      #{js_var} = new WebSocket("ws:" + location.host + "/connected_object");
      #{js_var}.onmessage = function(evt) { handleSocketMessage(evt.data) };
      #{js_var}.onopen = function(evt) {
        evt.target.send( JSON.stringify( 
          {"subscribe":{sessionID: "#{session_id}",
           ids:  [].map.call(document
            .querySelectorAll("[data-connect]"),
              function(el){return el.id})   }}
           ));
      }
      JS
    end

    def self.subclasses
      {{@type.all_subclasses}}
    end

  end



end
