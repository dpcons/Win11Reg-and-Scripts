# Imposta il percorso della cartella da svuotare
$targetFolder = "C:\Windows\System32\AppLocker"

# Verifica se la cartella esiste
if (-Not (Test-Path $targetFolder)) {
    Write-Host "La cartella specificata non esiste: $targetFolder"
    exit
}

# Carica la funzione MoveFileEx da kernel32.dll per pianificare la cancellazione al riavvio
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class Win32 {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool MoveFileEx(string lpExistingFileName, string lpNewFileName, int dwFlags);
}
"@

# Costanti per MoveFileEx
$MOVEFILE_DELAY_UNTIL_REBOOT = 0x00000004

# Elimina file e pianifica la cancellazione se in uso
Get-ChildItem -Path $targetFolder -Recurse -Force | ForEach-Object {
    try {
        if ($_.PSIsContainer) {
            Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction Stop
        } else {
            Remove-Item -Path $_.FullName -Force -ErrorAction Stop
        }
    } catch {
        # Se il file è in uso, pianifica la cancellazione al riavvio
        Write-Host "File in uso, pianifico la cancellazione al riavvio: $($_.FullName)"
        [Win32]::MoveFileEx($_.FullName, $null, $MOVEFILE_DELAY_UNTIL_REBOOT) | Out-Null
    }
}

Write-Host "Pulizia completata. Alcuni file potrebbero essere eliminati al prossimo riavvio."

# Write-Host "Riavvio in corso..."
# Restart-Computer -Force
