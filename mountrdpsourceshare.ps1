#
# use this script on a remote machine while connected via RDP
# it connects to a shared folder of the source machine(via ip). 
# helpful in enviroments with a dynamic source ip and problems to resolve the %clientname% variable
#

$del_lw_l = @'
cmd.exe /C net use l: /delete
'@

function Pause

{
   Read-Host 'Weiter mit ENTER Taste…' | Out-Null
}


$openconnection=$true
if ((Test-Path W:)) {
    Write-host "Laufwerk l: ist bereits im System vorhanden. `r`nTrotzdem neu verbinden? (Std Antwort Ja)" -ForegroundColor Yellow 
    $Readhost = Read-Host " ( j / n ) " 
    Switch ($ReadHost) 
     { 
       J {Write-host "Ja, Neu Verbinden"; $openconnection=$true; Invoke-Expression -Command:$del_lw_l} 
       N {Write-Host "Nein, Abbruch"; $openconnection=$false} 
       Default {Write-Host "Std, Neu Verbinden"; $openconnection=$true; Invoke-Expression -Command:$del_lw_l} 
     } 
}
if ($openconnection) {
    if (((Get-WinEvent -LogName "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational" | Where-Object { $_.Message | Select-String -Pattern "$env:USERNAME" } | select-object -First 1).message) -match 'Quellnetzwerkadresse: (.*)\.') {
        Write-Host 'RDP Client Name gefunden.' $env:Clientname
        Write-Host 'RDP Client IP gefunden. '$matches[1]'' 
        $CLIENTIP = $matches[1]
        $message = "Bitte hier die Zugangsdaten eingeben: `r`nFormat: <Computername\StickUser> `r`n`r`nEs werden die Zugangsdaten der lokalen Arbeitsstation benötigt.`r`n`r`nEs wird das freigegebene Laufwerk l$ des RDP-Clientsystems verbunden."
        if (New-PSDrive -Name "l" -PSProvider "Filesystem" -Root "\\$CLIENTIP\l`$" -Description "USB Stick" -Scope Global -Credential (Get-Credential -Message $message -UserName $env:Clientname'\LocalFolderUser' ) -Persist ) { 
            Write-Host 'Verbindung erfolgreich hergestellt'
            Pause 
        }
        else {
            Write-Host 'Verbindung konnte nicht hergestellt werden.' -ForegroundColor Red
            Pause
        }
    }
    else {
    Write-Host 'Client IP konnte nicht ermittelt werden.' -ForegroundColor Red
    Pause
    }
}
