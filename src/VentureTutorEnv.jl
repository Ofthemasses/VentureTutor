export VentureTutorEnv

mutable struct VentureTutorEnv <: AbstractEnv 
    instance::VimDocumentInstance
    comp_document::String
    view_range::UInt8 # This should only be a small value, may change to UInt16 if it is to much trouble converting data types in julia
	inputs::UInt16 # total inputs since last min lines
	min_incorrect_lines::UInt16
	incorrect_lines::UInt16
    reward::Float64
    document_size::UInt32
# I shouldn't need two documents    b::VimDocumentInstance
end

function VentureTutorEnv()
	incorrect_lines::UInt16 = compare_file_score()
	view_range::UInt8 = 16
	inputs::UInt16 = 0
    documentInstance = VimDocumentInstance()
    # Initialize state
    Threads.@spawn run_update_state(documentInstance)
    return VentureTutorEnv(documentInstance, "test2", view_range, inputs, incorrect_lines, incorrect_lines, 0.0, 50)
end

function RLBase.reset!(env::VentureTutorEnv)
    println("Beginning Reset")
    reset(env.instance)
    println("Finished Document Reset")
    incorrect_lines::UInt16 = compare_file_score()
    env.min_incorrect_lines = incorrect_lines
    env.incorrect_lines = incorrect_lines
    env.inputs = 0
    env.reward = 0.0
    return nothing
end

function RLBase.is_terminated(env::VentureTutorEnv)
    return env.min_incorrect_lines == 0 || env.inputs > 20
end

# How this gets called is a little bit of a mystery to me
function RLBase.reward(env::VentureTutorEnv) 
    return env.reward
end 

function RLBase.act!(env::VentureTutorEnv, a::Int)
    _step!(env, a)
end

function _step!(env::VentureTutorEnv, action)
	env.incorrect_lines = compare_file_score()
    env.inputs += 1

    if action in [122, 92 , 90, 81, 58, 33, 85, 117, 47, 63, 75, 0,1,2,3,4,5,6,7,9,10,11,12,14,15,16,18,19,20,21,22,23,24,25,26,28,29,30,31]
        return
    end
    send(env.instance, Char(action))
    print(Char(action))
    # Could be changed to grab buffer
    if env.incorrect_lines < env.min_incorrect_lines
        diff = env.min_incorrect_lines - env.incorrect_lines
        env.min_incorrect_lines = env.incorrect_lines
        env.reward = diff * 100.0 / env.inputs
        env.inputs = 0
    else
        env.reward = 0
    end
    nothing
end

RLBase.action_space(env::VentureTutorEnv) = Base.OneTo(128)
# 20 character document, sequence of keys
function RLBase.state(env::VentureTutorEnv)
	basic_fields = [getfield(env.instance, field) for field in [:row, :col, :mode]]
	current_readings = codeunits(read_curr(env))
	target_readings = codeunits(read_target(env))
	return vcat(basic_fields, current_readings, target_readings)
end

function RLBase.state_space(env::VentureTutorEnv) 
    ranges = [typemin(T) .. typemax(T) for T in [UInt16, UInt16, UInt8, fill(UInt8, env.document_size*2)...]]
	return foldl(×, ranges)
end

function compare_file_score()::UInt16
	incorrect_lines::UInt16 = 0

    output_filepath = "/home/finlay/Documents/VentureTutor/test/output"
    MAX_RETRIES = 5

    retries = 0
    while !isfile(output_filepath)
        sleep(1)
        retries += 1
        if (retries == MAX_RETRIES)
            error("Hit maximum retries trying to check for output file")
        end
    end

	open("/home/finlay/Documents/VentureTutor/test/VimEmulator.cpp") do comp_file
		open(output_filepath) do curr_file
			comp_line = readline(comp_file, keep=true)
			curr_line = readline(curr_file, keep=true)
			
			while !eof(comp_file) || !eof(curr_file)
				if cmp(comp_line, curr_line) != 0
					incorrect_lines += 1
				end

				if !eof(comp_file)
					comp_line = readline(comp_file, keep=true)
				else
					comp_line = ""
				end
				
				if !eof(curr_file)
					curr_line = readline(curr_file, keep=true)
				else
					curr_line = ""
				end
			end
		end
	end
	return incorrect_lines
end

function read_curr(env::VentureTutorEnv)
	return read_chars_and_fill("/home/finlay/Documents/VentureTutor/test/Curr.cpp", env.instance.row, env.document_size)
end

function read_target(env::VentureTutorEnv)
	return read_chars_and_fill("/home/finlay/Documents/VentureTutor/test/VimEmulator.cpp", env.instance.row, env.document_size)
end

function read_chars_and_fill(file_path::String, start_line::UInt16, num_chars::UInt32)
	# Open the file in read mode
	chars_collected = ""
	open(file_path, "r") do file
		current_line_num = 1

		# Loop through each line in the file
		for line in eachline(file)
			if current_line_num >= start_line
				# Calculate how many characters we still need to fulfill the requirement
				chars_needed = num_chars - length(chars_collected)
				if chars_needed <= 0
					break
				end

				actual_chars_to_add = min(chars_needed, length(line))
				chars_collected *= line[1:actual_chars_to_add]

				# Add newline characters, considering the limit of chars_needed
				if actual_chars_to_add > 0 && length(chars_collected) < num_chars
					chars_collected *= "\n"
				end
				if length(chars_collected) >= num_chars
					break
				end
			end
			current_line_num += 1
		end

		# If we did not collect enough characters, fill with '\0'
		chars_needed = num_chars - length(chars_collected)
		if chars_needed > 0
			chars_collected *= "\0" ^ chars_needed
		end
	end

	return chars_collected
end

function convert_string_to_tuple_padded(str::String)
	# Convert string to array of UInt8
	bytes = Vector{UInt8}(str)

	# Determine the length to fill with zeros (if needed)
	fillLength = max(0, 100 - length(bytes))

	# Append zeros if the length is less than the maximum length
	resizedBytes = if fillLength > 0
		append!(bytes, zeros(UInt8, fillLength))
	elseif length(bytes) > maxLength
		# If the byte array is longer than maxLength, truncate it
		bytes[1:maxLength]
	else
		bytes
	end

	# Convert the array to a tuple
	return Tuple(resizedBytes)
end

function compare_viewport(env::VentureTutorEnv)
    lines = []
    open("../test/VimEmulator.cpp") do comp_file
        line = 0
        comp_line = readline(comp_file, keep=true)
        while !eof(comp_file)
            line += 1
            if env.instance.line > line
                continue
            end
            if line > env.instance.line + 8
                break
            end
            push!(lines, convert_string_to_tuple_padded(comp_line)...)
        	comp_line = readline(comp_file, keep=true)
        end
    end
	return tuple(lines...)
end



