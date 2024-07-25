using VentureTutor
using ReinforcementLearning
using Flux
using Plots
using JLD2
using Random
using Statistics

mutable struct CustomTDLearner <: AbstractLearner
	approximator::FluxApproximator
	target_approximator::FluxApproximator
	γ::Float64  # Discount rate
	α::Float64  # Learning rate
	update_freq::Int 
	counter::Int
end

function CustomTDLearner(approximator::FluxApproximator, γ::Float64=0.99, α::Float64=0.01, update_freq::Int=100)
	target_approximator = deepcopy(approximator)
	CustomTDLearner(approximator, target_approximator, γ, α, update_freq, 0)
end

reward_factor = 10.0
function calculate_q_target(learner::CustomTDLearner, reward::Float32, next_state_values::Matrix{Float32}, is_terminal::Bool)
    scaled_reward = reward * reward_factor
	return is_terminal ? scaled_reward : scaled_reward + learner.γ * maximum(next_state_values)
end

function RLCore.forward(learner::CustomTDLearner, state::AbstractVector{<:Real})
	state = convert(Vector{Float32}, state)
	q_values = learner.approximator.model(state)
	return q_values
end

const STATE_LENGTH = 54
const N_ACTIONS = length(VentureTutor.VIM_MOVEMENT_ACTIONS)

env = ActionTransformedEnv(
	StateTransformedEnv(
		VentureTutorEnv(),
		state_mapping = state -> vcat(convert(Vector{Float32}, state[1:2]), convert(Vector{Float32}, state[3:end]) / 255.0),
		state_space_mapping = identity
	),
	action_mapping = identity,
	action_space_mapping = _ -> Base.OneTo(N_ACTIONS),
)

α = 0.01  
update_freq = 200

nn_approximator = FluxApproximator(
	Chain(
		Dense(STATE_LENGTH, 64, relu, init=Flux.glorot_uniform),
		Dense(64, 64, relu, init=Flux.glorot_uniform),
		Dense(64, N_ACTIONS, init=Flux.glorot_uniform)
	),
	Flux.Adam(α)
)

learner = CustomTDLearner(
	nn_approximator,
	0.8,
	α,
	update_freq
)

policy = QBasedPolicy(
	learner = learner,
	explorer = EpsilonGreedyExplorer(
		kind = :exp,
		ϵ_init = 1.0,
		ϵ_stable = 0.02,
		warmup_steps = 2^12 * 10,
		decay_steps = 2^13 * 10
	)
)

capacity = 50_000
state = (Float32, STATE_LENGTH)
action = (Int, N_ACTIONS)
reward = (Float32, ())
terminal = (Bool, ())

container = CircularArraySARTSATraces(
	capacity = capacity,
	state = state,
	action = action,
	reward = reward,
	terminal = terminal
)

function sample_batch(container, batchsize)
	sample_indicies = rand(1:length(container), batchsize)
	return [container[i] for i in sample_indicies]
end

controller = InsertSampleRatioController()

trajectory = Trajectory(container, Nothing, controller)

agent = Agent(
	policy = policy,
	trajectory = trajectory
)


function bellman_update!(learner::CustomTDLearner, state, action, reward, next_state, is_terminal)
	# Convert states to Float32 column vectors
	state_col = reshape(state, :, 1)
	next_state_col = reshape(next_state, :, 1)

	# Use the target approximator to get the Q-values for the next state
	next_q_values = learner.target_approximator.model(next_state_col)
	q_target = calculate_q_target(learner, reward, next_q_values, is_terminal)


    function loss_fn(m)
        q_values = m(state_col)
        q_value = q_values[action]
        Flux.Losses.mse(q_value, q_target)
    end

    ps = learner.approximator.model
    grads = Flux.gradient(m -> loss_fn(m), ps)[1]
    Flux.Optimise.update!(learner.approximator.optimiser_state, ps, grads)

	learner.counter += 1
	if learner.counter % learner.update_freq == 0
		learner.target_approximator = deepcopy(learner.approximator)
	end
end

function RLBase.optimise!(agent::RLCore.AbstractAgent, ::PostActStage)
	policy = agent.policy
	learner = policy.learner

	trajectory_length = length(agent.trajectory.container)
	if trajectory_length == 0
		return
	end

	batch = sample_batch(agent.trajectory.container, min(64, trajectory_length))
	for transition in batch
		state = collect(transition.state)
		action_array = collect(transition.action)
		reward = transition.reward
		next_state = collect(transition.next_state)
		is_terminal = transition.terminal

		action = action_array[1]
		bellman_update!(learner, state, action, reward, next_state, is_terminal)
	end

end

function save_learner(filepath::String, learner::CustomTDLearner)
	learner_data = (
		approximator = learner.approximator,
		target_approximator = learner.target_approximator,
		γ = learner.γ,
		α = learner.α,
		update_freq = learner.update_freq,
		counter = learner.counter
	)
	@save filepath learner_data
end

function load_learner(filepath::String)
	@load filepath learner_data
	CustomTDLearner(learner_data.approximator, learner_data.target_approximator, learner_data.γ, learner_data.α, learner_data.update_freq, learner_data.counter)
end

total_reward_hook = TotalRewardPerEpisode()

stop_cond = StopAfterNEpisodes(2^15)

run(agent, env, stop_cond, total_reward_hook)

# Plot Total Reward Per Episode
rewards = total_reward_hook.rewards
plot(1:length(rewards), rewards, title="Total Reward Per Episode", xlabel="Episode", ylabel="Total Reward", legend=false)
savefig("total_reward_per_episode.png")

function moving_average(data, window_size)
	return [mean(data[max(1, i-window_size+1):i]) for i in 1:length(data)]
end

window_size = 100
moving_avg_rewards = moving_average(rewards, window_size)

plot(1:length(moving_avg_rewards), moving_avg_rewards, title="Moving Average Total Reward", xlabel="Episode", ylabel="Total Reward (Moving Avg)", legend=false)
savefig("moving_avg_total_reward.png")

# Save the learner
model_path = "learner_model.jld2"
save_learner(model_path, learner)

# Example of loading the learner
loaded_learner = load_learner(model_path)
println("LEARNER")
println(loaded_learner.approximator)
