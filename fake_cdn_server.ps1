# fake_cdn_server.ps1
# Serves a valid NGDP versions response on port 80 so the WoW client
# does not show the "network data source" error popup.
#
# play.bat starts this hidden in the background before the user launches
# the WoW client. The hosts file redirects legion.fstorm.eu -> 127.0.0.1
# so all CDN version checks land here instead of going to the internet.

$bodyText = "## seqn`r`nRegion!STRING:0|BuildConfig!HEX:16|CDNConfig!HEX:16|BuildId!DEC:0|VersionsName!STRING:0|ProductConfig!HEX:16`r`nus|c23a2f39506457c036d70547b805a3e7|e7a17048eaf5d62036567e581449dc68|26365|7.3.5.26365|`r`n"
$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($bodyText)

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add('http://+:80/')

try {
    $listener.Start()
} catch {
    # Port 80 unavailable (e.g. already in use). Exit silently — the
    # error popup will still appear but the game will work normally.
    exit
}

while ($listener.IsListening) {
    try {
        $ctx = $listener.GetContext()
        $ctx.Response.StatusCode      = 200
        $ctx.Response.ContentType     = 'text/plain'
        $ctx.Response.OutputStream.Write($bodyBytes, 0, $bodyBytes.Length)
        $ctx.Response.Close()
    } catch {
        # Ignore individual request errors, keep serving
    }
}
