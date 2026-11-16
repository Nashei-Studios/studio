#requires -Version 7
# What the board puts into an agent's context is untrusted text from GitHub (issue 108, finding 4). It enters
# capped and fenced: the most recent posts only, each cut at a length, the whole at a total, between markers
# that carry a random suffix per call, so a post cannot guess them and close the block early. Any marker-like
# text inside a post is neutralised as well. Post headers are the lines tools/board writes at column 0; it
# indents a body line that starts like one, so a post cannot pose as another.
# Used by board-hook.ps1 (session-start and prompt) and tested by tools/tests/board-hooks.test.ps1.

function New-BoardNonce { [guid]::NewGuid().ToString('N').Substring(0, 8) }

function Format-BoardData {
    param(
        [string]$Text,
        [string]$Tag = 'board-data',
        [int]$MaxPosts = 8,
        [int]$MaxChars = 1200,
        [int]$MaxTotal = 8000,
        [string]$ReadCmd = 'pwsh tools/board.ps1 read -n 20',
        [string]$Nonce = (New-BoardNonce)
    )
    if (-not $Text -or -not $Text.Trim()) { return '' }
    $fence = "$Tag-$Nonce"
    $clean = $Text -replace '(?i)<\s*/?\s*(board-data|work-queue)[^>]*>', '[$1]'
    # One post per "--- @user date (#id)" header; text without headers (the work queue) is one block.
    $posts = @([regex]::Split($clean, '(?m)^(?=--- @)') | Where-Object { $_.Trim() })
    $notes = @()
    if ($posts.Count -gt $MaxPosts) {
        $notes += "[$($posts.Count - $MaxPosts) earlier posts left out; read them with: $ReadCmd]"
        $posts = @($posts | Select-Object -Last $MaxPosts)
    }
    $parts = foreach ($post in $posts) {
        $p = $post.TrimEnd()
        if ($p.Length -gt $MaxChars) { $p.Substring(0, $MaxChars) + " [cut: $($p.Length - $MaxChars) more characters; read it with: $ReadCmd]" }
        else { $p }
    }
    $body = $parts -join "`n"
    if ($body.Length -gt $MaxTotal) {
        # The newest posts matter most: the cut takes from the start.
        $notes += "[$($body.Length - $MaxTotal) characters of older posts left out; read them with: $ReadCmd]"
        $body = $body.Substring($body.Length - $MaxTotal)
    }
    $lines = @("<$fence>") + $notes + @($body, "</$fence>")
    $lines -join "`n"
}
