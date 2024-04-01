export VentureTutorEnv

mutable struct VentureTutorEnv <: AbstractEnv 
    instance::VimDocumentInstance
    comp_document::String
    view_range::UInt8 # This should only be a small value, may change to UInt16 if it is to much trouble converting data types in julia
	inputs::UInt16 # total inputs since last min lines
	min_incorrect_lines::UInt16
	incorrect_lines::UInt16
    reward::Float64
# I shouldn't need two documents    b::VimDocumentInstance
end

function VentureTutorEnv()
	incorrect_lines::UInt16 = compare_file_score()
	view_range::UInt8 = 16
	inputs::UInt16 = 0
    documentInstance = VimDocumentInstance()
    # Initialize state
    update_state(documentInstance)
    return VentureTutorEnv(documentInstance, "test2", view_range, inputs, incorrect_lines, incorrect_lines, 0.0)
end

function RLBase.reset!(env::VentureTutorEnv)
    send(env.instance, "gg")
    sleep(5)
    shutdown_server(env.instance.server)
    incorrect_lines::UInt16 = compare_file_score()
    env.min_incorrect_lines = incorrect_lines
    env.incorrect_lines = incorrect_lines
    env.inputs = 0
    env.reward = 0.0
    return nothing
end

function RLBase.is_terminated(env::VentureTutorEnv)
    return env.min_incorrect_lines == 0
end

# How this gets called is a little bit of a mystery to me
function RLBase.reward(env::VentureTutorEnv) 
    return env.reward
end 

function (env::VentureTutorEnv)(a::Int)
    _step!(env, a)
end

function _step!(env::VentureTutorEnv, action)
    # Ignore z, \, Z, Q, :
    if action in [122, 92 , 90, 81, 58] 
        return
    end
	env.incorrect_lines = compare_file_score()
    env.inputs += 1
    send(env.instance, Char(action))
    send(env.instance, Char(27))
    send(env.instance, ":w\n")
    if (env.incorrect_lines < env.min_incorrect_lines)
        diff = env.min_incorrect_lines - env.incorrect_lines
        env.min_incorrect_lines = env.incorrect_lines
        env.reward = diff * 100.0 / env.inputs
        env.inputs = 0
    else
        env.reward = 0.0
    end
    nothing
end

RLBase.action_space(env::VentureTutorEnv) = Base.OneTo(128)
RLBase.state(env::VentureTutorEnv) = (env.instance.line, env.instance.row, env.instance.col)
RLBase.state_space(env::VentureTutorEnv) = Space((1:65535, 1:65535, 1:65535))

function compare_file_score()::UInt16
	incorrect_lines::UInt16 = 0
	open("../test/VimEmulator.cpp") do comp_file
		open("../test/Curr.cpp") do curr_file
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
