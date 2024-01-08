using Godot;
using System;
using DiscordRPC;

public partial class DiscordHandler : Node
{
    private DiscordRpcClient _discordClient;

    public override void _Ready()
    {
        base._Ready();
        
        _discordClient = new DiscordRpcClient("1137542286788542474");
        _discordClient.Initialize();
    }

    public void SetDiscordStatus(string details, string state, string largeImage, string largeImageText, bool beginTimestamp)
    {
        GD.Print("C#: Setting Discord status...");
        _discordClient.SetPresence(new RichPresence()
        {
            Details = details,
            State = state,
            Assets = new Assets()
            {
                LargeImageKey = largeImage,
                LargeImageText = largeImageText,
            },
            Timestamps = new Timestamps()
            {
                Start = beginTimestamp ? DateTime.UtcNow : null
            }
        });
    }

    public void ClearDiscordStatus(bool dispose)
    {
        GD.Print($"C#: {(dispose ? "Disposing" : "Clearing")} Discord status!!");
        _discordClient.ClearPresence();
        if (dispose) _discordClient.Dispose();
    }
}
