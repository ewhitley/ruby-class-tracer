module ClassTraceUtils

  require 'set'
  require 'ostruct'
  require 'json'

=begin
variable
   - name
   - types []

classname
   - instance instance_vars []
   - methods []
      - method name
         - calling variables []
           - default (can't seem to get ahold of this easily)
           - nilable
         - returns []
         - line variables []

using a ruby set to automatically handle the duplication of types

=end


  class ClassTracker
    
    attr_accessor :classes, :archive_path, :date_generated, :date_updated, :times_run, :monitored_classes, :named_like, :start_time, :end_time, :trace_duration

    def initialize(options = {})
      @archive_path = options[:archive_path] || 'json.txt'
      @monitored_classes = options[:monitored_classes] || nil
      @named_like = options[:named_like] || nil

      @date_generated = Time.now
      @date_updated = Time.now
      @times_run = 1

      @classes = {}
      @trace_point = self.trace_point
      @tracer = self.tracer

    end

   def trace_point 
      # configure our TracePoint
      # we're going to use this to capture RETURN value types from methods
      # let's check out the returns and see if we can figure out the data type
      trace_point = TracePoint.new(:return, :call) do |t|
        trace_point.disable
        #print "."
        class_name = "#{t.defined_class}".delete('[#<>]').sub("Class:","")
        if monitored_classes.include?(class_name) || (class_name =~ /#{@named_like}/ unless @named_like == nil)
          event = "#{t.event}".delete('[:]')
          method = "#{t.method_id}"
          variable_scope = "#{event}"
          variable_name = "return"
          if variable_scope == "return"
            variable = t.return_value
            addClassInfo(class_name, method, event, variable_scope, variable_name, variable)
          elsif variable_scope == "call"
            #req     #required argument
            #opt     #optional argument with default
            #rest    #rest of arguments as array
            #keyreq  #reguired key argument (2.1+)
            #key     #key argument with default argument
            #keyrest #rest of key arguments as Hash
            #block   #block parameter
            o_method = eval("method(:#{t.method_id})", t.binding)
            o_method.parameters.each do |k,p|
              arg_type = "#{k}"
              variable_name = "#{p}"
              variable = t.binding.local_variable_get(p)
              addClassInfo(class_name, method, event, variable_scope, variable_name, variable, arg_type)
            end
          end
        end
        trace_point.enable
      end
      trace_point
    end

    def tracer
      # configure our tracer
      # we're going to use this to capture INSTANCE and LOCAL variables for classes and methods
      tracer = lambda do |event, file, line, id, binding, class_name|
        #print "."
        class_name = "#{class_name}"
        if (monitored_classes.include?(class_name)  || (class_name =~ /#{@named_like}/ unless @named_like == nil) ) && ["call", "line"].include?(event)
          me = binding.eval("self")
          binding.eval("instance_variables + local_variables").inject({}) do |vars, name|
            variable_scope = "instance"
            method = "#{id}"
            begin
              variable = me.instance_variable_get("#{name}")
              variable_scope = "instance"
            rescue
              variable = binding.local_variable_get("#{name}")
              variable_scope = "local"
            end
            addClassInfo(class_name, method, event, variable_scope, name, variable)
          end
        end
      end
      tracer
    end

    def start
      puts "Starting trace"
      puts "Tracing."
      @start_time = Time.now
      @trace_duration = 0
      set_trace_func @tracer
      @trace_point.enable
    end

    def stop
      set_trace_func nil
      @trace_point.disable
      @end_time = Time.now
      @trace_duration = @end_time - @start_time
      puts ""
      puts "Trace complete"
    end

    def last_trace_duration
      if @trace_duration != nil
        puts Time.at(@trace_duration).utc.strftime("%H:%M:%S") #=> "01:00:00"
      else
        "No trace record found"
      end
    end

    def addClassInfo(class_name, method, event, variable_scope, variable_name, variable, optional = nil)
      variable_type = get_var_type(variable)
      if @classes[class_name] == nil
         @classes[class_name] = ClassProfile.new(class_name, method, event, variable_scope, variable_name, variable_type, optional)
      else
         @classes[class_name].addMethodSignature(method, event, variable_scope, variable_name, variable_type, optional)
      end
    end

    def self.restoreFromArchive(file)
      begin
        json = File.read(file)
        from_json(json)
      rescue
        puts "Unable to find file #{file}. Please check file path/name. Creating new Class Tracker."
        ClassTracker.new(archive_path: file)
      end
    end

    def archive(archive_path = nil)
      archive_path ||= @archive_path
      archive_path ||= "json.txt"
      File.open(archive_path, "w") do |f|
        f.puts self.to_json
      end
      puts "Archived profile to '#{@archive_path}'"
    end

    def self.from_json(json)
      json = JSON.parse(json)

      archive = json["archive"]
      archive_path = json["archive_path"]

      ct = ClassTracker.new(archive_path: archive_path)

      ct.date_generated = json["date_generated"] if json["date_generated"]
      ct.date_generated ||= Time.now
      ct.date_updated = json["date_updated"] if json["date_updated"]
      ct.times_run = json["times_run"] if json["times_run"]
      ct.monitored_classes = json["monitored_classes"] if json["monitored_classes"]
      ct.named_like = json["named_like"] if json["named_like"]

      ct.start_time = json["start_time"] if json["start_time"]
      ct.end_time = json["end_time"] if json["end_time"]
      ct.trace_duration = json["trace_duration"] if json["trace_duration"]


      json["classes"].each do |c|
        class_name = c[1]["class_name"] if c[1]["class_name"]
        if class_name != nil
          aclass = ClassProfile.new(class_name)
          c[1]["instance_vars"].each do |k,i|
            variable_name = k
            variable_scope = "instance"
            i["types"].each do |t|
              variable_type = t
              aclass.addMethodSignature(nil, nil, variable_scope, variable_name, variable_type)
            end
          end 
          c[1]["methods"].each do |mk,m|
            method = mk
            m["local_vars"].each do |mvk, mv|
              variable_name = mvk
              variable_scope = "local"
              event = "local"
              mv["types"].each do |t|
                variable_type = t
                aclass.addMethodSignature(method, event, variable_scope, variable_name, variable_type)
              end
            end
            m["calling_vars"].each do |mvk, mv|
              variable_name = mvk
              variable_scope = "call"
              event = "call"
              required = mv["required"]
              arg_type = mv["arg_type"]
              mv["types"].each do |t|
                variable_type = t
                aclass.addMethodSignature(method, event, variable_scope, variable_name, variable_type, arg_type)
              end
            end
            m["return_types"].each do |t|
              variable_name = "return"
              variable_scope = "return"
              event = "return"
              variable_type = t
              aclass.addMethodSignature(method, event, variable_scope, variable_name, variable_type)
            end
          end 
          ct.classes[class_name] = aclass
        end
      end

      ct
    end

    def to_json(*a)
      {
        "json_class"   => self.class.name,
        "archive_path"   => @archive_path,
        "classes" => @classes,
        "date_generated" => @date_generated,
        "date_updated" => Time.now,
        "times_run" => @times_run + 1,
        "monitored_classes" => @monitored_classes,
        "named_like" => @named_like,
        "start_time" => @start_time,
        "end_time" => @end_time,
        "trace_duration" => @trace_duration
      }.to_json(*a)
    end

    def report
      class_list = @classes
      puts "=========================="
      class_list.each do |c_name, c_val|
        puts "--------------------------"
        puts "CLASS: #{c_val.class_name}"
        puts "--------------------------"
        if !c_val.instance_vars.empty?
          puts "  Instance Variables:"
          c_val.instance_vars.each do |i_name, i_val|
            types = i_val.types.collect{|t| t }.join(", ")
            nilable = i_val.nilable ? "  (NILABLE)" : ""
            puts "    - #{i_name} : #{types}#{nilable}"
          end
        end
        if !c_val.methods.empty?
          puts "  Methods:"
          c_val.methods.each do |m_name, m_val|
            return_types = m_val.return_types.collect{|t| t }.join(", ")
            return_types = return_types.empty? ? return_types : "RETURNS: (#{return_types})"
            return_nilable = ""
            puts "    - #{m_name} : #{return_types}#{return_nilable}"
            if !m_val.calling_vars.empty?
              puts "       - Calling Variables : "
              m_val.calling_vars.each do |c_name, c_val|
                types = c_val.types.collect{|t| t }.join(", ")
                nilable = c_val.nilable ? "  (NILABLE)" : ""
                arg_type = c_val.arg_type ? " [#{c_val.arg_type}] " : ""
                puts "          #{c_name} : #{types}#{nilable}#{arg_type}"
              end
            end
            if !m_val.local_vars.empty?
              puts "       - Local Variables : "
              m_val.local_vars.each do |l_name, l_val|
                types = l_val.types.collect{|t| t }.join(", ")
                nilable = l_val.nilable ? "  (NILABLE)" : ""
                arg_type = l_val.arg_type ? " [#{l_val.arg_type}] " : ""
                puts "          #{l_name} : #{types}#{nilable}#{arg_type}"
              end
            end
          end
        end
      end
      puts "=========================="
    end

    private

    #NOTE: intentionally NOT making this smart and recursive
    #  I don't want this iterating forever for things that have json, etc.
    #  I just need some basic high-level type information
    def get_var_type(var)
      className = var.class.name
      if className == "Array"
        classNames = var.collect{|x| 
          if x.class.name == "Hash"
            vnames = x.collect{|k2,v2| v2.class.name}.uniq.join(",")
            "Hash:'#{vnames}'"
          else
            x.class.name 
          end
          }.uniq.join(",")
        className  = "Array[#{classNames}]"
      elsif className == "Hash"
           var.each do |key, val|
              val_class = val.class.name
              if val_class == "Array"
                val_class = val.collect{|x| x.class.name }.uniq.join(",")
                val_class  = "Array[#{val_class}]"
              end
              className = "Hash:[#{val_class}]"
           end
      end
      className
    end

    class VariableProfile
      attr_accessor :name, :types, :nilable, :arg_type
      def initialize(name, type, arg_type = nil)
        @name = name
        @types = Set.new [type]
        @arg_type = arg_type
        if type == "NilClass"
          @nilable  = true
        else
          @nilable = false
        end
      end
      def addType(type)
        @types << type
        if type == "NilClass"
          @nilable = true
        end
      end
      def to_json(*a)
        {
          "name"  => @name,
          "nilable" => @nilable,
          "types" => @types.to_a,
          "required" => @required,
          "arg_type" => @arg_type
        }.to_json(*a)
      end

    end

    class MethodProfile
      attr_accessor :name, :local_vars, :return_types, :calling_vars
      def initialize(name, variable_scope, variable_type, variable_name, arg_type = nil)
        @name = name
        @local_vars = {}
        @calling_vars = {}
        @return_types = Set.new []
        addVariable(variable_scope, variable_type, variable_name, arg_type)
      end
      def addVariable(variable_scope, variable_type, variable_name, arg_type = nil)
        if variable_scope == "local"
          if @local_vars[variable_name] == nil
            @local_vars[variable_name] = VariableProfile.new(variable_name, variable_type, arg_type)
          else
            @local_vars[variable_name].addType(variable_type)
          end
        elsif variable_scope == "call"
          if @calling_vars[variable_name] == nil
            @calling_vars[variable_name] = VariableProfile.new(variable_name, variable_type, arg_type)
          else
            @calling_vars[variable_name].addType(variable_type)
          end
        elsif  variable_scope == "return"
          @return_types << variable_type
        end
      end
      def to_json(*a)
        {
          "name"  => @name,
          "local_vars" => @local_vars,
          "calling_vars" => @calling_vars,
          "return_types" => @return_types.to_a
        }.to_json(*a)
      end

    end

    class ClassProfile
      attr_accessor :class_name, :instance_vars, :methods
      def initialize(class_name, method = nil, event = nil, variable_scope = nil, variable_name = nil, variable_type = nil, arg_type = nil)
        @class_name = class_name
        @instance_vars = {}
        @methods = {}
        if class_name && method && event && variable_scope && variable_name && variable_type
          addMethodSignature(method, event, variable_scope, variable_name, variable_type, arg_type)
        end
      end

      def addMethodSignature(method, event, variable_scope, variable_name, variable_type, arg_type = nil)
        if variable_scope == "instance"
          if @instance_vars[variable_name] == nil
            @instance_vars[variable_name] = VariableProfile.new(variable_name, variable_type, arg_type)
          else
            @instance_vars[variable_name].addType(variable_type)
          end
        elsif ["local", "return", "call"].include?(variable_scope)
          if @methods[method] == nil
            @methods[method] = MethodProfile.new(method, variable_scope, variable_type, variable_name, arg_type)
          else
            @methods[method].addVariable(variable_scope, variable_type, variable_name, arg_type)
          end
        end
      end

      def to_json(*a)
        {
          "class_name"  => @class_name,
          "instance_vars" => @instance_vars,
          "methods" => @methods
        }.to_json(*a)
      end

    end

  end

end
