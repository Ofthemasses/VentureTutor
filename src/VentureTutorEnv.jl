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
    UInt8('e'),
    UInt8('E'),
    UInt8('%'),
    UInt8('_'),
]

mutable struct VentureTutorEnv <: AbstractEnv 
    instance::VimDocumentInstance
    comp_document::String
    view_range::UInt8 
	inputs::UInt16 
    reward::Float64
    document_size::UInt32
	target_row::UInt16
	target_col::UInt16
end

function VentureTutorEnv()
	view_range::UInt8 = 16
	inputs::UInt16 = 0
    documentInstance = VimDocumentInstance()
    # Initialize state
    Threads.@spawn run_update_state(documentInstance)
    return VentureTutorEnv(documentInstance, "test2", view_range, inputs, 0.0, 50, 0, 0)
end

function RLBase.reset!(env::VentureTutorEnv)
    env.target_row, env.target_col = get_random_point(env.instance.contents)
    reset(env.instance)
    env.inputs = 0
    env.reward = 0.0
    return nothing
end

function RLBase.is_terminated(env::VentureTutorEnv)
	return env.reward > 0 || env.inputs == 10
end

function RLBase.reward(env::VentureTutorEnv) 
    return env.reward
end 

function RLBase.act!(env::VentureTutorEnv, a::Int)
    _step!(env, a)
end

function _step!(env::VentureTutorEnv, action)
    env.inputs += 1
    action_char = VIM_MOVEMENT_ACTIONS[action]
    send(env.instance, Char(action_char))
	
	if env.target_row == env.instance.row - 1&& env.target_col == env.instance.col - 1
        env.reward = 10 / env.inputs
    end
    nothing
end

RLBase.action_space(env::VentureTutorEnv) = Base.OneTo(length(VentureTutor.VIM_MOVEMENT_ACTIONS))

# 20 character document, sequence of keys
function RLBase.state(env::VentureTutorEnv, ::Observation, ::DefaultPlayer)
	current_readings = map_string_to_integers(env.instance.contents)
	return vcat(env.instance.col - 1, env.instance.row - 1, env.target_col, env.target_row, current_readings)
end

function RLBase.state_space(env::VentureTutorEnv) 
    ranges = [typemin(T) .. typemax(T) for T in [UInt16, UInt16, UInt16, UInt16, fill(UInt8, env.document_size)...]]
	return foldl(×, ranges)
end

function get_random_point(document_content::Vector{Char})
    if isempty(document_content)
        return [0,0]
    end
    rows = []
    current_row = []
    row_index = 0
    col_index = 0

    for char in document_content
        if char == '\n'
            row_to_push = isempty(current_row) ? [(row_index,0)] : current_row
            push!(rows, current_row)
            current_row = []
            row_index += 1
            col_index = 0
        else
            push!(current_row, (row_index, col_index))
            col_index += 1
        end
    end

    if !isempty(current_row)
        push!(rows, current_row)
    end

    all_points = vcat(rows...)

    rand_point = rand(all_points[2:end])
    return rand_point
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
