<#
One-command offline verification. Works even when GitHub Actions cannot allocate a runner.
Usage: powershell -ExecutionPolicy Bypass -File tools/verify_release_local.ps1 -GodotPath "C:\\Godot\\Godot_v4.7.2-stable_win64_console.exe"
Use -Quick to run only the essential release gates.
Writes logs to build/local-release-verification. Does not change saves or source.
#>
param([string]$GodotPath="",[switch]$Quick,[string]$OutputDirectory="")
$ErrorActionPreference="Stop"
$root=(Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { $OutputDirectory=Join-Path $root "build\local-release-verification" }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$steps=New-Object System.Collections.Generic.List[object]
$failures=New-Object System.Collections.Generic.List[string]

function Run-Check {
    param([string]$Name,[string]$Program,[string[]]$Arguments,[int]$TimeoutSeconds=120)
    $num=$steps.Count.ToString("D2")
    $safeName=$Name -replace '[^a-zA-Z0-9_-]','_'
    $outLog=Join-Path $OutputDirectory ($num+"_"+$safeName+".stdout.log")
    $errLog=Join-Path $OutputDirectory ($num+"_"+$safeName+".stderr.log")
    Write-Host ("[VERIFY] "+$Name)
    $clock=[System.Diagnostics.Stopwatch]::StartNew()
    try {
        $process=Start-Process -FilePath $Program -ArgumentList $Arguments -WorkingDirectory $root -PassThru -NoNewWindow -RedirectStandardOutput $outLog -RedirectStandardError $errLog
        $finished=$process.WaitForExit($TimeoutSeconds*1000)
        if (-not $finished) { $process.Kill(); $process.WaitForExit() }
        $exitCode=if ($finished) { $process.ExitCode } else { 124 }
    } catch {
        ($_ | Out-String) | Set-Content -Path $errLog -Encoding UTF8
        $exitCode=127
    } finally {
        $clock.Stop()
    }
    $record=[ordered]@{name=$Name;status=$(if ($exitCode -eq 0) {"PASS"} else {"FAIL"});exit_code=$exitCode;seconds=[math]::Round($clock.Elapsed.TotalSeconds,2);stdout=$outLog;stderr=$errLog}
    $steps.Add($record)
    if ($exitCode -ne 0) { $failures.Add($Name);Write-Warning ("Failed "+$Name+" (exit "+$exitCode+"). See "+$errLog) }
    return ($exitCode -eq 0)
}

$python=Get-Command python -ErrorAction SilentlyContinue
if ($null -eq $python) { throw "Python 3 is required for dependency-free validation." }
$staticOK=Run-Check -Name "static_release_gate" -Program $python.Source -Arguments @("tools/validate_release_gate.py","--json") -TimeoutSeconds 60
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    foreach ($candidate in @("Godot_v4.7.2-stable_win64_console.exe","Godot_v4.7.2-stable_win64.exe")) {
        $candidatePath=Join-Path $root $candidate
        if (Test-Path $candidatePath) { $GodotPath=$candidatePath;break }
    }
}
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    foreach ($commandName in @("godot","godot4")) {
        $match=Get-Command $commandName -ErrorAction SilentlyContinue
        if ($null -ne $match) { $GodotPath=$match.Source;break }
    }
}
$enginePresent=(-not [string]::IsNullOrWhiteSpace($GodotPath)) -and ((Test-Path $GodotPath) -or ($null -ne (Get-Command $GodotPath -ErrorAction SilentlyContinue)))
if (-not $enginePresent) { $failures.Add("godot_executable_not_found");Write-Warning "Godot not found; pass -GodotPath for real engine tests." }
if ($staticOK -and $enginePresent) {
    $runtime=@(
        @{Name="godot_import";Script=""}
        @{Name="save_integrity";Script="smoke_save_integrity.gd"}
        @{Name="first_three_checkpoints";Script="smoke_first_three_checkpoints.gd"}
        @{Name="combat_turns";Script="smoke_combat_turns.gd"}
        @{Name="live_boss_matrix";Script="smoke_live_boss_matrix.gd"}
        @{Name="opening_balance";Script="smoke_opening_balance.gd"}
        @{Name="first_three_playable";Script="smoke_first_three_playable.gd"}
        @{Name="battle_commercial";Script="smoke_battle_commercial.gd"}
        @{Name="campaign_72_progression";Script="smoke_campaign_72.gd"}
        @{Name="world_40_layouts";Script="smoke_world_v3.gd"}
        @{Name="quest_120_world_interactions";Script="smoke_story_world_phase19_2.gd"}
        @{Name="save_and_interiors";Script="smoke_world_checkpoints.gd"}
    )
    if ($Quick) { $runtime=$runtime[0..5] }
    foreach ($item in $runtime) {
        $engineArgs=@("--headless","--path",$root)
        if ($item.Script -eq "") { $engineArgs+=@("--editor","--quit") }
        else { $engineArgs+=@("--script",("res://tools/"+$item.Script)) }
        $limit=if ($item.Name -eq "campaign_72_progression") { 300 } else { 150 }
        if (-not (Run-Check -Name $item.Name -Program $GodotPath -Arguments $engineArgs -TimeoutSeconds $limit)) { break }
    }
}
$overall=if ($failures.Count -eq 0) { "PASS" } else { "FAIL" }
$summary=[ordered]@{status=$overall;godot_path=$(if ($enginePresent) {$GodotPath} else {""});static_check_passed=$staticOK;mode=$(if ($Quick) {"quick"} else {"release"});steps=@($steps.ToArray());failures=@($failures.ToArray());timestamp=(Get-Date).ToString("o")}
$report=Join-Path $OutputDirectory "release-summary.json"
$summary | ConvertTo-Json -Depth 8 | Set-Content -Path $report -Encoding UTF8
Write-Host ("Result: "+$overall+". Report: "+$report)
if ($overall -eq "FAIL") { exit 1 }
exit 0
