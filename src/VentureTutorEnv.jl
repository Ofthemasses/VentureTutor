export VentureTutorEnv

const VIM_TYPE_MAP = Dict(
	' ' => 0,
	'\t' => 1,
	'\n' => 2,
	';' => 3,
	',' => 4,
	'.' => 5,
	':' => 6,
	'(' => 7,
	')' => 8,
	'[' => 9,
	']' => 10,
	'{' => 11,
	'}' => 12,
	'\'' => 13,
	'"' => 14,
	'`' => 15
)

const VIM_MOVEMENT_ACTIONS = [
    UInt8('h'),
    UInt8('j'),
    UInt8('k'),
    UInt8('l'),
    UInt8('0'),
    UInt8('$'),
    UInt8('^'),
    UInt8('w'), 
    UInt8('W'),
    UInt8('b'),
    UInt8('B'),
    UInt8('('),
    UInt8(')'), 
    UInt8('{'),
    UInt8('}'), 
    UInt8('['), 
    UInt8(']'),
    UInt8('e'),
    UInt8('E'),
    UInt8('%'),
    UInt8('-'),
    UInt8('_'),
    UInt8('+'),
    UInt8('|')
]


mutable struct VentureTutorEnv <: AbstractEnv 
    instance::VimDocumentInstance
    comp_document::String
    view_range::UInt8 # This should only be a small value, may change to UInt16 if it is to much trouble converting data types in julia
	inputs::UInt16 # total inputs since last min lines
    reward::Float64
    document_size::UInt32
	target::UInt16
end

function VentureTutorEnv()
	view_range::UInt8 = 16
	inputs::UInt16 = 0
    documentInstance = VimDocumentInstance()
    # Initialize state
    Threads.@spawn run_update_state(documentInstance)
    return VentureTutorEnv(documentInstance, "test2", view_range, inputs, 0.0, 50, 0)
end

function RLBase.reset!(env::VentureTutorEnv)
    println("Beginning Reset")
    env.target = rand(1:env.document_size)
    reset(env.instance)
    println("Finished Document Reset")
    env.inputs = 0
    env.reward = 0.0
    return nothing
end

function RLBase.is_terminated(env::VentureTutorEnv)
	return env.reward > 0 || env.inputs == env.target
end

# How this gets called is a little bit of a mystery to me
function RLBase.reward(env::VentureTutorEnv) 
    return env.reward
end 

function RLBase.act!(env::VentureTutorEnv, a::Int64)
    _step!(env, a)
end

function _step!(env::VentureTutorEnv, action)
    env.inputs += 1
    action_char = VIM_MOVEMENT_ACTIONS[action]
    send(env.instance, Char(action_char))
    print(Char(action_char))
	if env.target == env.instance.col * (env.instance.row + 1)
        env.reward = 5 / env.inputs
    end
    nothing
end

RLBase.action_space(env::VentureTutorEnv) = Base.OneTo(length(VIM_MOVEMENT_ACTIONS))
# 20 character document, sequence of keys
function RLBase.state(env::VentureTutorEnv, ::Observation, ::DefaultPlayer)
	current_readings = map_string_to_integers(env.instance.contents)
	return vcat(env.instance.col * (env.instance.row + 1), env.target, current_readings)
end

function RLBase.state_space(env::VentureTutorEnv) 
    ranges = [typemin(T) .. typemax(T) for T in [UInt16, UInt16, fill(UInt8, env.document_size)...]]
	return foldl(×, ranges)
end


function is_word_character(c::Char)
    return isletter(c) || c == '_'
end

function is_non_word_character(c::Char)
	return occursin(r"\W", string(c)) && !(c in [' ', '\t', '\n', ';',
',', '.', ':', '(', ')', '[', ']', '{', '}', '\'', '"', '`'])
end

function char_to_type(c::Char)
	if haskey(VIM_TYPE_MAP, c)
		return VIM_TYPE_MAP[c]
	elseif is_word_character(c)
		return 16
	elseif is_non_word_character(c)
		return 17
	else
		return 18 
	end
end

function tokenize_string(s::Vector{Char})
	tokens = []
	buffer = ""
	for c in s
		if is_word_character(c)
			buffer *= c
		else
			if !isempty(buffer)
				push!(tokens, buffer)
				buffer = ""
			end
			push!(tokens, string(c))
		end
	end
	if !isempty(buffer)
		push!(tokens, buffer)
	end
	return tokens
end

function map_string_to_integers(s::Vector{Char})
	tokens = tokenize_string(s)
	mapped_integers = []
	for token in tokens
		if length(token) == 1
			push!(mapped_integers, char_to_type(token[1]))
		else
			for _ in 1:length(token)
				push!(mapped_integers, 16)
			end
		end
	end
	return mapped_integers
end

