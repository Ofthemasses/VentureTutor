using VentureTutor
using ReinforcementLearning
using Plots


env = VentureTutorEnv()  # Ensure this is instantiated properly

hook = TotalRewardPerEpisode()

stats = run(
    RandomPolicy(),
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
