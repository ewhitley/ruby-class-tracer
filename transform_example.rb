require_relative 'ClassTracer.rb'


#For this one we're not going to profile anything.
#We're just going to load an existing archived profile and transform it out
#You could / should probably do this with some sort of templating system like mustache

class_archive = "SimpsonsProfile.txt"
class_tracer = ClassTraceUtils::ClassTracer.restoreFromArchive(class_archive)


#Format our output

#just in case you want to only show certain classes
limit_to_classes = []

def suggest_types(types, nilable = nil)

	newTypes = Set.new []

	swift_type_suggestions = {
		"TrueClass" => "Boolean", 
		"FalseClass" => "Boolean",
		"Fixnum" => "Int",
		"Array[]" => "[AnyObject]",
		"NilClass" => "AnyObject"
	}

	if types.is_a? Set
		types = types.to_a
	end

	types.each do |t|
		next if t == "NilClass" && types.count > 1
		next if t == "Array[]" && types.select{|t2| t2 =~ /^Array/ && t != t2 }.collect{|t2| t}.count > 0
		next if t == "Hash" && types.select{|t2| t2 =~ /^Hash/ && t != t2 }.collect{|t2| t}.count > 0
		if t =~ /^Array\[/
			/\[(?<data_type>.*)\]/ =~ t
			data_types = data_type.split(",")
			#we can have arrays of multiple types
			data_types.each do |data_type|
				data_type = swift_type_suggestions[data_type] || data_type
				data_type = "[#{data_type}]"
				newTypes << data_type
			end
			next
		end
		if t =~ /^Hash:/
			/:\[(?<data_type>.*)\]/ =~ t
			data_type = swift_type_suggestions[data_type] || data_type
			data_type = "[String: #{data_type}]"
			#yeah, I know - but this is a demo of possible approaches, not an actual tool
			# and chances are it's a string hash key, soooo....
			newTypes << data_type
			next
		end
		newT = swift_type_suggestions[t] || t 
		newTypes << newT
	end

	newTypes.to_a

end

class_list = class_tracer.classes
class_list.each do |c_name, c_val|

	if limit_to_classes.count > 0
		if !limit_to_classes.include?(c_name)
			next
		end
	end

	class_vars = {}
	class_vars[:instance] = []
	class_vars[:methods] = []


	#super redundant code here

	if !c_val.instance_vars.empty?
	  c_val.instance_vars.each do |i_name, i_val|
	  	i_vars = {}
	  	i_vars[:name] = i_name
	  	suggested_types = suggest_types(i_val.types, i_val.nilable)
	    type = suggested_types.collect{|t| t}.join(", ")
	    if suggested_types.count > 1
	    	type = "AnyObject"
	    	if suggested_types.index{|s| s =~ /\[/ && s !~ /\:/}
	    		type = "[#{type}]"
	    	end
	    	i_vars[:comments] = " '#{i_name}' has multiple types. Defaulting to AnyObject CHOOSE FROM *** ( #{suggested_types} ) ***  "
	    end
	    nilable = i_val.nilable ? "?" : ""
	    i_vars[:def] = "    var #{i_name} : #{type}#{nilable}"
	    class_vars[:instance] << i_vars
	  end
	end

	if !c_val.methods.empty?
	  c_val.methods.each do |m_name, m_val|

		method_vars = {}
		method_vars[:method] = {}
		method_vars[:return] = {}
		method_vars[:call] = {}
		method_vars[:local] = {}
		method_vars[:calling_args] = ""

	  	method_returns = ""
	    calling_args = ""

	  	return_types = suggest_types(m_val.return_types, nil)
	    return_type = return_types.collect{|t| t }.join(", ")
	    method_vars[:return][:name] = "RETURN"
	    if return_types.count > 1
	    	return_type = "AnyObject"
	    	if return_types.index{|s| s =~ /\[/ && s !~ /\:/}
	    		return_type = "[#{return_type}]"
	    	end
	    	method_vars[:return][:comments] = " Returns multiple types. Defaulting to AnyObject. CHOOSE FROM *** ( #{return_types} ) ***  "
	    end
	    return_nilable = m_val.return_types.select{ |t| t != "NilClass" }.collect{|t| t }.size > 0 ? "?" : ""
    	if return_types.index{|s| s =~ /\[/ && s !~ /\:/}
    		return_nilable = " //Return can be empty array"
    	end

	    return_type = "#{return_type}#{return_nilable}"
		method_vars[:return][:def] = return_type


	    if !m_val.calling_vars.empty?
	      args_ar = []
	      m_val.calling_vars.each do |c_name, c_val|
	      	method_vars[:call][c_name] = {}
	  		types = suggest_types(c_val.types, nil)
	    	type = types.collect{|t| t }.join(", ")
		    if types.count > 1
		    	type = "AnyObject"
		    	if types.index{|s| s =~ /\[/ && s !~ /\:/}
		    		type = "[#{type}]"
		    	end
		    	method_vars[:call][c_name][:comments] = " Param '#{c_name}' contains multiple types. Defaulting to AnyObject. CHOOSE FROM *** ( #{types} ) ***  "
		    end
	        nilable = c_val.nilable || c_val.arg_type == "[opt]" ? "?" : ""
	    	if types.index{|s| s =~ /\[/ && s !~ /\:/}
	    		nilable = " = []"
	    	elsif types.index{|s| s =~ /\[/ && s =~ /\:/}
	    		nilable = " = [:]"
	    	end
	        arg_type = c_val.arg_type ? " [#{c_val.arg_type}] " : ""
	        method_vars[:call][c_name][:def] = "#{c_name}: #{type}#{nilable}"
	        args_ar << "#{c_name}: #{type}#{nilable}"
	      end
	      calling_args = args_ar.join(", ")
	      calling_args = "(#{calling_args})"
	    end

	    if !m_val.local_vars.empty?
	      m_val.local_vars.each do |l_name, l_val|
	      	method_vars[:local][l_name] = {}
	  		types = suggest_types(l_val.types, nil)
	    	type = types.collect{|t| t }.join(", ")
		    if types.count > 1
		    	type = "AnyObject"
		    	if types.index{|s| s =~ /\[/ && s !~ /\:/}
		    		type = "[#{type}]"
		    	end
		    	method_vars[:local][l_name][:comments] = " '#{l_name}' has multiple types. Defaulting to AnyObject. CHOOSE FROM *** ( #{types} ) ***  "
		    end
	        arg_type = l_val.arg_type ? " [#{l_val.arg_type}] " : ""
	        nilable = l_val.nilable || arg_type == "opt" ? "?" : ""
	        method_vars[:local][l_name][:def] = "#{l_name}: #{type}#{nilable}"
	      end
	    end

	    func_type = m_val.calling_vars.empty? ? "var " : "func "
	    method_vars[:method][:def] = "#{func_type}#{m_name}#{calling_args}" + (return_type.empty? ? "" :  " -> #{return_type}")

		class_vars[:methods] << method_vars

	  end
	end

	#draw our "pseudo-Swift"
	puts ""
	puts "class #{c_val.class_name}"
	puts "{"
	class_vars[:instance].each do |i|
	  if i[:comments] != nil
      	puts "    /// FIXME: #{i[:comments]}" if i[:comments] != nil
	  end
	  puts i[:def]
	end	
    puts ""
    class_vars[:methods].each do |i|
      i[:call].each do |name, var|
      	puts "    /// FIXME: #{var[:comments]}" if var[:comments] != nil
      	puts "    /// :param: #{name}" 
      end
      if i[:return] != nil
      	puts "    /// FIXME: #{i[:return][:comments]}" if i[:return][:comments] != nil
      	puts "    /// :returns: #{i[:return][:def]}" 
      end
      puts "    #{i[:method][:def]}"
      puts "    {"
      i[:local].each do |name, var|
      	puts "        /// FIXME: #{var[:comments]}" if var[:comments] != nil
      	puts "        #{i[:local][name][:def]}" 
      end
      puts "    }"
      puts ""
    end
	puts "}"
end



