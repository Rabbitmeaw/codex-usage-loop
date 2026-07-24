using System.Text.Json;

while (Console.ReadLine() is { } line)
{
    using var document = JsonDocument.Parse(line);
    var root = document.RootElement;
    if (root.TryGetProperty("method", out var method)
        && method.GetString() == "initialize")
    {
        Console.WriteLine("""{"id":1,"result":{"serverInfo":{"name":"fake-codex"}}}""");
    }
    else if (root.TryGetProperty("method", out method)
        && method.GetString() == "account/rateLimits/read")
    {
        var id = root.GetProperty("id").GetInt32();
        Console.WriteLine(JsonSerializer.Serialize(new
        {
            id,
            result = new
            {
                rateLimits = new
                {
                    primary = new { remainingPercent = 72, windowDurationMins = 300 },
                    secondary = new { usedPercent = 19, windowDurationMins = 10080 }
                }
            }
        }));
    }
}
