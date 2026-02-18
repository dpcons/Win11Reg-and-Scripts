<#
.SYNOPSIS
    Export the full commit list of a git repository to a file.

.DESCRIPTION
    This script exports the complete commit history of a git repository to a file.
    Supports multiple output formats: TXT, CSV, JSON.

.PARAMETER OutputPath
    The path where the commit list will be saved. Default is "CommitList.txt"

.PARAMETER Format
    The output format: TXT, CSV, or JSON. Default is TXT

.PARAMETER RepositoryPath
    The path to the git repository. Default is current directory

.EXAMPLE
    .\ExportGitCommits.ps1
    Exports commits to CommitList.txt in current directory

.EXAMPLE
    .\ExportGitCommits.ps1 -OutputPath "C:\Commits.csv" -Format CSV
    Exports commits to CSV format

.EXAMPLE
    .\ExportGitCommits.ps1 -Format JSON -OutputPath "commits.json"
    Exports commits to JSON format
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$OutputPath,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("TXT", "CSV", "JSON")]
    [string]$Format = "TXT",
    
    [Parameter(Mandatory=$false)]
    [string]$RepositoryPath = "."
)

# Set default output path based on format if not specified
if (-not $OutputPath) {
    switch ($Format) {
        "CSV"  { $OutputPath = "CommitList.csv" }
        "JSON" { $OutputPath = "CommitList.json" }
        default { $OutputPath = "CommitList.txt" }
    }
}

# Change to repository path
Push-Location $RepositoryPath

try {
    # Check if git is available
    $gitCheck = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCheck) {
        Write-Host "Error: Git is not installed or not in PATH" -ForegroundColor Red
        exit 1
    }

    # Check if current directory is a git repository
    $isGitRepo = git rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Not a git repository" -ForegroundColor Red
        exit 1
    }

    Write-Host "Exporting commit history..." -ForegroundColor Yellow

    # Get commit history with detailed information
    $commits = git log --pretty=format:"%H|%h|%an|%ae|%ad|%s" --date=iso --all | ForEach-Object {
        $parts = $_ -split '\|', 6
        [PSCustomObject]@{
            FullHash = $parts[0]
            ShortHash = $parts[1]
            Author = $parts[2]
            Email = $parts[3]
            Date = $parts[4]
            Message = $parts[5]
        }
    }

    # Export based on format
    switch ($Format) {
        "CSV" {
            $commits | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
            Write-Host "Commits exported to CSV: $OutputPath" -ForegroundColor Green
        }
        "JSON" {
            $commits | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
            Write-Host "Commits exported to JSON: $OutputPath" -ForegroundColor Green
        }
        "TXT" {
            $output = @()
            $output += "=" * 80
            $output += "GIT COMMIT HISTORY"
            $output += "=" * 80
            $output += "Total Commits: $($commits.Count)"
            $output += "Exported: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            $output += "=" * 80
            $output += ""
            
            foreach ($commit in $commits) {
                $output += "Commit:  $($commit.FullHash)"
                $output += "Author:  $($commit.Author) <$($commit.Email)>"
                $output += "Date:    $($commit.Date)"
                $output += "Message: $($commit.Message)"
                $output += "-" * 80
            }
            
            $output | Out-File -FilePath $OutputPath -Encoding UTF8
            Write-Host "Commits exported to TXT: $OutputPath" -ForegroundColor Green
        }
    }

    Write-Host "Total commits exported: $($commits.Count)" -ForegroundColor Cyan
    Write-Host "Output file: $(Resolve-Path $OutputPath)" -ForegroundColor Cyan

} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}
