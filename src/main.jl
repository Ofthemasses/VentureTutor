using VentureTutor
using ReinforcementLearning


env = VentureTutorEnv()  # Ensure this is instantiated properly

# Select a predefined agent
# For illustration, let's say we are using a DQN-based approach (suitable for environments with high-dimensional state spaces)
# Note: Make sure to choose an agent that aligns with your environment's state and action spaces
# This is just an example; the actual instantiation may vary based on the
# environment and desired agent configuration

# Run the experiment for a specified number of episodes
run(
    RandomPolicy(),
    env,
    StopAfterNEpisodes(100),
    TotalRewardPerEpisode()
)
