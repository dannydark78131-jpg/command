#Requires -Version 5.1
#  insopti PowerPlan 1.1.1
#  Downloads the selected insopti power plan (.pow) from the official GitHub
#  release, imports it and activates it. No remote code is executed; the
#  downloaded profile is verified to be non-empty and its SHA256 is logged.
#  Original author: https://guns.lol/inso.vs | For personal use only.

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Insopti {
    param(
        [string]$Message,
        [ConsoleColor]$Color = 'White',
        [switch]$NoNewline
    )
    if ($NoNewline) { Write-Host $Message -ForegroundColor $Color -NoNewline }
    else { Write-Host $Message -ForegroundColor $Color }
}

function Write-Log {
    param(
        [string]$Type,
        [string]$Message,
        [string]$Extra = "",
        [ConsoleColor]$TypeColor = 'White',
        [ConsoleColor]$MessageColor = 'White',
        [ConsoleColor]$ExtraColor = 'White'
    )
    $time = Get-Date -Format "HH:mm:ss"
    Write-Insopti " [" -Color Blue -NoNewline
    Write-Insopti $Type -Color $TypeColor -NoNewline
    Write-Insopti "] [" -Color Blue -NoNewline
    Write-Insopti $time -Color DarkGray -NoNewline
    Write-Insopti "] " -Color Blue -NoNewline
    Write-Insopti $Message -Color $MessageColor -NoNewline
    if ($Extra -ne "") { Write-Insopti " $Extra" -Color $ExtraColor }
    else { Write-Insopti "" }
}

function Show-DynamicCountdown {
    param(
        [int]$Seconds = 2,
        [string]$Message = "Continuing",
        [ConsoleColor]$IconColor = [ConsoleColor]::Yellow,
        [ConsoleColor]$TextColor = [ConsoleColor]::DarkGray
    )
    $cursorPos = $Host.UI.RawUI.CursorPosition
    for ($i = $Seconds; $i -gt 0; $i--) {
        $Host.UI.RawUI.CursorPosition = $cursorPos
        Write-Insopti " [" -NoNewline -Color Blue
        Write-Insopti "~" -NoNewline -Color $IconColor
        Write-Insopti "] " -NoNewline -Color Blue
        Write-Insopti "$Message in $i second" -NoNewline -Color $TextColor
        if ($i -gt 1) { Write-Insopti "s" -NoNewline -Color $TextColor }
        Write-Insopti "...                    " -Color $TextColor
        Start-Sleep -Seconds 1
    }
    $Host.UI.RawUI.CursorPosition = $cursorPos
    Write-Insopti "                                                      "
    $Host.UI.RawUI.CursorPosition = $cursorPos
}

function Show-Banner {
    Write-Insopti ""
    Write-Insopti "  ==================================================" -Color DarkCyan
    Write-Insopti "   insopti PowerPlan 1.1.1" -Color Cyan
    Write-Insopti "   Optimized power plan import" -Color DarkGray
    Write-Insopti "  ==================================================" -Color DarkCyan
    Write-Insopti ""
}

function Test-Administrator {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Show-ExitMenu {
    Write-Log -Type "+" -TypeColor Green -Message "Thanks for using this tool !"
    Write-Log -Type "+" -TypeColor Green -Message "Enter your choice:"
    Write-Insopti ""
    Write-Insopti " [" -Color Blue -NoNewline
    Write-Insopti "1" -Color White -NoNewline
    Write-Insopti "] Exit" -Color Blue
    Write-Insopti " [" -Color Blue -NoNewline
    Write-Insopti "2" -Color White -NoNewline
    Write-Insopti "] Go to Discord" -Color Blue
    Write-Insopti " > " -Color Cyan -NoNewline
    $choice = Read-Host
    switch ($choice) {
        "1" { Exit-Script }
        "2" { Open-Discord }
        default {
            Write-Log -Type "!" -TypeColor Yellow -Message "Invalid choice." -MessageColor Yellow
            Show-DynamicCountdown -Seconds 2 -Message "Retrying" -IconColor Yellow
            Clear-Host
            Show-ExitMenu
        }
    }
}

function Open-Discord {
    param([string]$URL = "https://guns.lol/inso.vs")
    try {
        Start-Process -FilePath $URL
        $Host.UI.RawUI.CursorPosition = @{ X = 0; Y = ($Host.UI.RawUI.CursorPosition.Y - 1) }
        Write-Log -Type "+" -TypeColor Green -Message "Guns profile page has been opened successfully." -MessageColor Green
    } catch {
        Write-Log -Type "!" -TypeColor Red -Message "Error opening the page: $($_.Exception.Message)" -MessageColor Red
    }
    Show-DynamicCountdown -Seconds 2 -Message "Closing" -IconColor Green
    Exit-Script
}

function Exit-Script {
    Clear-Host
    Write-Log -Type "!" -TypeColor Yellow -Message "Script terminated." -MessageColor Yellow
    $dotCount = 0
    while ($dotCount -lt 3) {
        $Host.UI.RawUI.CursorPosition = @{ X = 0; Y = ($Host.UI.RawUI.CursorPosition.Y) }
        Write-Insopti " [" -Color Blue -NoNewline
        Write-Insopti "!" -Color Yellow -NoNewline
        Write-Insopti "] Closing the script$('.' * ($dotCount + 1))     " -Color Yellow -NoNewline
        Start-Sleep -Milliseconds 300
        $dotCount++
    }
    exit
}

function Invoke-PowerPlanImport {
    $planPath = Join-Path $env:TEMP 'insopti.pow'

    if (-not (Test-Administrator)) {
        Write-Log -Type "!" -TypeColor Red -Message "Administrator rights are required to import a power plan. Run this tool as administrator." -MessageColor Red
        Show-DynamicCountdown -Seconds 3 -Message "Opening menu"
        Show-ExitMenu
        return
    }

    $Host.UI.RawUI.WindowTitle = "[https://guns.lol/inso.vs] | Import an optimized power plan designed for maximum system responsiveness and the lowest possible latency."
    $Host.UI.RawUI.BackgroundColor = "Black"
    Clear-Host
    Show-Banner

    Write-Insopti " [" -Color Blue -NoNewline
    Write-Insopti "+" -Color Green -NoNewline
    Write-Insopti "] " -Color Blue -NoNewline
    Write-Insopti "Select" -Color White -NoNewline
    Write-Insopti " the appropriate power plan for your CPU tuning profile:" -Color White
    Write-Insopti " [" -Color Blue -NoNewline
    Write-Insopti "+" -Color Green -NoNewline
    Write-Insopti "] " -Color Blue -NoNewline
    Write-Insopti "This will" -Color White -NoNewline
    Write-Insopti " determine how Windows manages your processor frequency.`n" -Color White -NoNewline
    Write-Insopti "`n [" -Color Blue -NoNewline
    Write-Insopti "1" -Color White -NoNewline
    Write-Insopti "] " -Color Blue -NoNewline
    Write-Insopti "Static OC mode " -Color White -NoNewline
    Write-Insopti "(For users with manual fixed CPU frequency and Precision Boost disabled)." -Color DarkGray
    Write-Insopti " [" -Color Blue -NoNewline
    Write-Insopti "2" -Color White -NoNewline
    Write-Insopti "] " -Color Blue -NoNewline
    Write-Insopti "Dynamic boost mode " -Color White -NoNewline
    Write-Insopti "(For all other users with Precision Boost/Turbo BIOS settings enabled (usually by default)." -Color DarkGray
    Write-Insopti "`n [" -Color Blue -NoNewline
    Write-Insopti "+" -Color Green -NoNewline
    Write-Insopti "] " -Color Blue -NoNewline
    Write-Insopti "Select" -Color White -NoNewline
    Write-Insopti " an option to continue " -Color White -NoNewline
    Write-Insopti "[" -Color Blue -NoNewline
    Write-Insopti "1" -Color White -NoNewline
    Write-Insopti "/" -Color Cyan -NoNewline
    Write-Insopti "2" -Color White -NoNewline
    Write-Insopti "]" -Color Blue -NoNewline
    Write-Insopti ":" -Color Blue -NoNewline
    Write-Insopti " " -Color DarkGray -NoNewline
    $planChoice = Read-Host

    if ($planChoice -eq "1") {
        $planURL = "https://github.com/insovs/insopti-PowerPlan/releases/download/v1/insopti.pow"
        $planName = "insopti PowerPlan"
    } elseif ($planChoice -eq "2") {
        $planURL = "https://github.com/insovs/insopti-PowerPlan/releases/download/v1/insopti-idle.pow"
        $planName = "insopti-idle"
    } else {
        Write-Log -Type "!" -TypeColor Yellow -Message "Invalid choice. Operation cancelled." -MessageColor Yellow
        Show-DynamicCountdown -Seconds 2 -Message "Returning to menu"
        Show-ExitMenu
        return
    }

    try {
        Invoke-WebRequest -Uri $planURL -OutFile $planPath -UseBasicParsing -ErrorAction Stop
        if (-not (Test-Path -LiteralPath $planPath) -or (Get-Item -LiteralPath $planPath).Length -eq 0) {
            throw "The power plan download failed or produced an empty file."
        }
        $planHash = (Get-FileHash -LiteralPath $planPath -Algorithm SHA256).Hash

        Clear-Host
        Show-Banner
        Write-Log -Type "+" -TypeColor Green -Message "Downloaded plan SHA256:" -Extra $planHash -ExtraColor DarkGray
        Write-Log -Type "+" -TypeColor Green -Message "This will go import and activate the optimized '$planName'."
        Write-Log -Type "+" -TypeColor Green -Message "The following optimizations will be applied by doing this:"
        Write-Log -Type "+" -TypeColor Green -Message "Maximize system performance and responsiveness." -MessageColor DarkGray
        Write-Log -Type "+" -TypeColor Green -Message "Disable CPU power throttling and latency mitigation features." -MessageColor DarkGray
        Write-Log -Type "+" -TypeColor Green -Message "Optimize USB power management and sleep state settings." -MessageColor DarkGray
        Write-Insopti "`n [" -Color Blue -NoNewline
        Write-Insopti "?" -Color Green -NoNewline
        Write-Insopti "] " -Color Blue -NoNewline
        Write-Insopti "Import the power plan " -Color White -NoNewline
        Write-Insopti "? " -Color White -NoNewline
        Write-Insopti "[" -Color Blue -NoNewline
        Write-Insopti "Y" -Color Green -NoNewline
        Write-Insopti "/" -Color Cyan -NoNewline
        Write-Insopti "N" -Color Red -NoNewline
        Write-Insopti "]" -Color Blue -NoNewline
        Write-Insopti ": " -Color Blue -NoNewline
        $confirm = Read-Host

        if ($confirm -notin @("Y", "y")) {
            $Host.UI.RawUI.CursorPosition = @{ X = 0; Y = ($Host.UI.RawUI.CursorPosition.Y - 1) }
            Write-Log -Type "!" -TypeColor Yellow -Message "Operation cancelled by user." -MessageColor Yellow
            Show-DynamicCountdown -Seconds 2 -Message "Returning to menu"
            return
        }

        $Host.UI.RawUI.CursorPosition = @{ X = 0; Y = ($Host.UI.RawUI.CursorPosition.Y - 1) }
        Write-Log -Type "+" -TypeColor Green -Message "Import of the $planName.. please wait."

        $importOutput = (& powercfg -import $planPath 2>&1 | Out-String)
        $importExitCode = $LASTEXITCODE
        if ($importExitCode -ne 0) {
            throw "powercfg -import failed: $($importOutput.Trim())"
        }

        $guidPattern = '([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})'
        $planGuid = $null
        if ($importOutput -match $guidPattern) { $planGuid = $matches[1] }

        if (-not $planGuid) {
            foreach ($line in (& powercfg -list)) {
                if ($line -match $guidPattern) {
                    $candidateGuid = $matches[1]
                    if ($line -match [regex]::Escape($planName)) {
                        $planGuid = $candidateGuid
                        break
                    }
                }
            }
        }
        if (-not $planGuid) { throw "The imported '$planName' scheme GUID could not be determined." }

        & powercfg -setactive $planGuid | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "powercfg -setactive failed." }
        Start-Sleep -Milliseconds 500

        $active = (& powercfg -getactivescheme | Out-String)
        if ($active -notmatch [regex]::Escape($planGuid)) {
            throw "The power plan was imported but could not be verified as active."
        }

        Write-Insopti " [" -NoNewline -Color Blue
        Write-Insopti "+" -NoNewline -Color Green
        Write-Insopti "] [" -NoNewline -Color Blue
        Write-Insopti "$(Get-Date -Format 'HH:mm:ss')" -NoNewline -Color DarkGray
        Write-Insopti "] " -NoNewline -Color Blue
        Write-Insopti "$planName" -NoNewline -Color Blue
        Write-Insopti " successfully " -NoNewline -Color White
        Write-Insopti "imported" -NoNewline -Color Green
        Write-Insopti " & " -NoNewline -Color White
        Write-Insopti "activated" -NoNewline -Color Green
        Write-Insopti " ! " -NoNewline -Color White
        Write-Insopti "(GUID : $planGuid)" -Color DarkGray
        Start-Process "control.exe" -ArgumentList "powercfg.cpl"

        $hideAttributes = @(
            '2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226',
            '2a737441-1930-4402-8d77-b2bebba308a3 d4e98f31-5ffe-4ce1-be31-1b38b384c009',
            '2a737441-1930-4402-8d77-b2bebba308a3 0853a681-27c8-4100-a2fd-82013e970683',
            '54533251-82be-4824-96c1-47b60b740d00 465e1f50-b610-473a-ab58-00d1077dc418',
            '54533251-82be-4824-96c1-47b60b740d00 619b7505-003b-4e82-b7a6-4dd29c300971',
            '54533251-82be-4824-96c1-47b60b740d00 be337238-0d82-4146-a960-4f3749d470c7'
        )
        foreach ($attribute in $hideAttributes) {
            $parts = $attribute.Split(' ')
            & powercfg -attributes $parts[0] $parts[1] -ATTRIB_HIDE | Out-Null
        }

        foreach ($sleepAttr in @('48e6b7a6-50f5-4782-a5d4-53bb8f07e226', 'd4e98f31-5ffe-4ce1-be31-1b38b384c009')) {
            & powercfg /SETACVALUEINDEX $planGuid 2a737441-1930-4402-8d77-b2bebba308a3 $sleepAttr 0 | Out-Null
            & powercfg /SETDCVALUEINDEX $planGuid 2a737441-1930-4402-8d77-b2bebba308a3 $sleepAttr 0 | Out-Null
        }
    } catch {
        Write-Log -Type "!" -TypeColor Red -Message "An error has occurred: $($_.Exception.Message)" -MessageColor Red
        Show-DynamicCountdown -Seconds 3 -Message "Continuing" -IconColor Red
    } finally {
        Remove-Item -LiteralPath $planPath -Force -ErrorAction SilentlyContinue
        Show-ExitMenu
    }
}

Invoke-PowerPlanImport
