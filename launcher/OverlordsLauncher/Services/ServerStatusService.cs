using System.Diagnostics;
using System.Net.Sockets;
using OverlordsLauncher.Models;

namespace OverlordsLauncher.Services;

public sealed class ServerStatusService
{
    public async Task<ServerStatus> CheckAsync(
        string host,
        int lobbyPort,
        int searchPort,
        CancellationToken cancellationToken = default)
    {
        var cleanHost = host.Trim();
        if (string.IsNullOrWhiteSpace(cleanHost))
        {
            return new ServerStatus
            {
                IsOnline = false,
                Host = host,
                SummaryText = "No server host configured"
            };
        }

        var lobbyTask = ProbePortAsync(cleanHost, lobbyPort, cancellationToken);
        var searchTask = ProbePortAsync(cleanHost, searchPort, cancellationToken);
        await Task.WhenAll(lobbyTask, searchTask).ConfigureAwait(false);

        var (lobbyOk, lobbyMs) = lobbyTask.Result;
        var (searchOk, searchMs) = searchTask.Result;

        var isOnline = lobbyOk || searchOk;
        var latency = lobbyOk ? lobbyMs : searchMs;

        string summary;
        if (lobbyOk && searchOk)
        {
            summary = $"Online ({latency} ms)";
        }
        else if (lobbyOk)
        {
            summary = $"Lobby Online ({latency} ms • Search offline)";
        }
        else if (searchOk)
        {
            summary = $"Search Online ({latency} ms • Lobby offline)";
        }
        else
        {
            summary = "Offline / Unreachable";
        }

        return new ServerStatus
        {
            IsOnline = isOnline,
            LobbyReachable = lobbyOk,
            SearchReachable = searchOk,
            LatencyMs = latency,
            Host = cleanHost,
            CheckedAt = DateTimeOffset.UtcNow,
            SummaryText = summary
        };
    }

    private static async Task<(bool Reachable, int ElapsedMs)> ProbePortAsync(
        string host,
        int port,
        CancellationToken cancellationToken)
    {
        if (port is <= 0 or > 65535)
        {
            return (false, 0);
        }

        var sw = Stopwatch.StartNew();
        try
        {
            using var client = new TcpClient();
            using var cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            cts.CancelAfter(TimeSpan.FromMilliseconds(2200));
            await client.ConnectAsync(host, port, cts.Token).ConfigureAwait(false);
            sw.Stop();
            return (true, (int)Math.Max(1, sw.ElapsedMilliseconds));
        }
        catch
        {
            return (false, 0);
        }
    }
}
