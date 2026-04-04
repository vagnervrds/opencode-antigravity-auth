$stateDb = "C:\Users\Admin\AppData\Roaming\Antigravity\User\globalStorage\state.vscdb"
$logPath = "C:\Users\Admin\AppData\Roaming\Antigravity\logs"
$outputFile = "antigravity_models.json"

function Get-AntigravityModels {
    $result = @{
        timestamp = Get-Date -Format "o"
        models = @()
        modelPreferences = $null
        modelCredits = $null
        allowedCommands = $null
    }

    # Query SQLite database
    $query = "SELECT key, value FROM ItemTable WHERE key LIKE '%model%' OR key LIKE '%Model%' OR key LIKE '%cloud%'"
    $rows = sqlite3 $stateDb $query

    foreach ($row in $rows) {
        $parts = $row -split "\|"
        $key = $parts[0]
        $value = $parts[1]

        switch ($key) {
            "antigravity_allowed_command_model_configs" {
                if ($value) {
                    try {
                        $decoded = [System.Convert]::FromBase64String($value)
                        $text = [System.Text.Encoding]::UTF8.GetString($decoded)
                        $result.allowedCommands = $text
                    } catch {
                        $result.allowedCommands = $value
                    }
                }
            }
            "antigravityUnifiedStateSync.modelPreferences" {
                if ($value) {
                    try {
                        $decoded = [System.Convert]::FromBase64String($value)
                        $text = [System.Text.Encoding]::UTF8.GetString($decoded)
                        $result.modelPreferences = $text
                    } catch {
                        $result.modelPreferences = $value
                    }
                }
            }
            "antigravityUnifiedStateSync.modelCredits" {
                if ($value) {
                    try {
                        $decoded = [System.Convert]::FromBase64String($value)
                        $text = [System.Text.Encoding]::UTF8.GetString($decoded)
                        $result.modelCredits = $text
                    } catch {
                        $result.modelCredits = $value
                    }
                }
            }
        }
    }

    # Get latest log entries for models
    $latestLog = Get-ChildItem "$logPath\*\cloudcode.log" -ErrorAction SilentlyContinue | 
                 Sort-Object LastWriteTime -Descending | 
                 Select-Object -First 1

    if ($latestLog) {
        $modelLogs = Get-Content $latestLog.FullName -Tail 100 | 
                     Select-String "fetchAvailableModels|model" -ErrorAction SilentlyContinue
        $result.recentLogs = @($modelLogs | Select-Object -First 10)
    }

    return $result
}

# Main execution
Write-Host "Fetching Antigravity model information..." -ForegroundColor Cyan
$data = Get-AntigravityModels

# Output results
$data | ConvertTo-Json -Depth 10 | Out-File $outputFile -Encoding UTF8
Write-Host "Results saved to $outputFile" -ForegroundColor Green

# Display summary
Write-Host "`n=== Model Information ===" -ForegroundColor Yellow
Write-Host "Timestamp: $($data.timestamp)"
if ($data.modelPreferences) {
    Write-Host "Model Preferences: $($data.modelPreferences)"
}
if ($data.modelCredits) {
    Write-Host "Model Credits: $($data.modelCredits)"
}
if ($data.allowedCommands) {
    Write-Host "Allowed Commands: Available"
}
