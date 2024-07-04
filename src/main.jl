using VentureTutor
using ReinforcementLearning
using Flux
using Plots

struct CustomTDLearner <: AbstractLearner
    approximator::FluxApproximator
    optimizer::Flux.Adam
    γ::Float64
end

function calculate_q_target(learner::CustomTDLearner, reward, next_state_values, is_terminal)
    if is_terminal
        return reward
    else
        return reward + learner.γ * maximum(next_state_values)
    end
end

function (learner::CustomTDLearner)(state, action, reward, next_state, is_terminal)
    println("Action received in learner: ", action)
    state = convert(Vector{Float32}, state)
    next_state = convert(Vector{Float32}, next_state) 

    q_values = learner.approximator.model(state)
    println("Q-values: ", q_values)

    # Ensure action index is within bounds
    valid_action = clamp(action, 1, length(q_values))
    q_value = q_values[valid_action]

    next_state_values = learner.approximator.model(next_state)
    q_target = calculate_q_target(learner, reward, next_state_values, is_terminal)

    loss = Flux.mse(q_value, q_target)

    gradients = Flux.gradient(() -> loss, params(learner.approximator.model))
    Flux.Optimise.update!(learner.optimizer, params(learner.approximator.model), gradients)
end

function RLCore.forward(learner::CustomTDLearner, state::Vector{Float64})
    state = convert(Vector{Float32}, state)
    return learner.approximator.model(state)
end

function update!(learner::CustomTDLearner, env, state, action, reward, next_state, is_terminal)
    state = convert(Vector{Float32}, state)
    next_state = convert(Vector{Float32}, next_state)

    state_values = learner.approximator.model(state)
    next_state_values = learner.approximator.model(next_state)
    target = calculate_q_target(learner, reward, next_state_values, is_terminal)
    state_values[clamp(action, 1, length(state_values))] = target

    loss = Flux.mse(state_values[clamp(action, 1, length(state_values))], target)
    gradients = Flux.gradient(() -> loss, params(learner.approximator.model))
    Flux.Optimise.update!(learner.optimizer, params(learner.approximator.model), gradients)
end

println("Action Space Length: ", length(VentureTutor.VIM_MOVEMENT_ACTIONS))

const STATE_LENGTH = 52
const N_ACTIONS = length(VentureTutor.VIM_MOVEMENT_ACTIONS)

function state_mapping(state::Vector{Any})
    state_vector = convert(Vector{Float32}, state[3:end]) / 255.0
    return vcat(convert(Vector{Float32}, state[1:2]), state_vector)
end

function state_space_mapping(_)
    ;
end

function action_mapping(action)
    return action
end

function action_space_mapping(_)
    return Base.OneTo(N_ACTIONS)
end

env = ActionTransformedEnv(
    StateTransformedEnv(
        VentureTutorEnv(),
        state_mapping = state_mapping,
        state_space_mapping = state_space_mapping
    );
    action_mapping = action_mapping,
    action_space_mapping = action_space_mapping,
)

α = 0.01
n = 1

nn_approximator = FluxApproximator(
    model = Chain(
        Dense(STATE_LENGTH, 64, relu),
        Dense(64, 64, relu),
        Dense(64, N_ACTIONS)
    ),
    optimiser = Flux.ADAM(α)
)

learner = CustomTDLearner(
    nn_approximator,
    Flux.ADAM(0.01),
    0.99
)

policy = QBasedPolicy(
    learner = learner,
    explorer = EpsilonGreedyExplorer(0.1)
)

hook = TotalRewardPerEpisode()

stats = run(
    policy,
    env,
    StopAfterNEpisodes(1000),
    hook
)

@gif for episode in 1:length(hook.rewards)
    plot(1:episode, hook.rewards[1:episode], title="Reward Progression",
        xlabel="Episode",
        ylabel="Cumulative Reward", legend=false, ylims=(0, 10))
end every 10

savefig(plot(hook.rewards, title="Reward Progression", xlabel="Episode",
    ylabel="Cumulative Reward", legend=false),
    "final-reward-progression.png")

