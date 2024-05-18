using VentureTutor
using ReinforcementLearning
using Flux
using Plots

const STATE_LENGTH = 103
const N_ACTIONS = 128  # As per your action space


# Define the state mapping function to return an integer index
function state_mapping(state::Vector{Integer})
	state_value = sum(state)
	return trunc(Int, state_value) % STATE_LENGTH + 1  # Ensure it maps to a valid state space index
end

# Define the state space mapping
function state_space_mapping(_)
	return Base.OneTo(STATE_LENGTH)
end

# Define the action mapping function (assume actions are already integers)
function action_mapping(action)
	return action
end

# Define the action space mapping
function action_space_mapping(_)
	return Base.OneTo(N_ACTIONS)
end

# Create a wrapped environment with state and action transformations
env = ActionTransformedEnv(
	StateTransformedEnv(
		VentureTutorEnv(),
		state_mapping = state_mapping,
		state_space_mapping = state_space_mapping
	);
	action_mapping = action_mapping,
	action_space_mapping = action_space_mapping,
)

#### Step 2: Define the Agent

α = 0.01  # Learning rate
n = 1  # Step size

# Define the tabular approximator for state-action values
approximator = TabularQApproximator(
	n_state = STATE_LENGTH,  # Directly use the state length
	n_action = N_ACTIONS     # Number of possible actions
)

learner = TDLearner(
	approximator,
	:SARS,
	α = α
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
    plot(1:episode, hook.rewards[1:episode], title="Reward Progression", xlabel="Episode",
         ylabel="Cumulative Reward", legend=false)
end every 10

savefig(plot(hook.rewards, title="Reward Progression", xlabel="Episode", ylabel="Cumulative Reward", legend=false),
       "final-reward-progression.png")
