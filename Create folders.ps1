# Script developped by Julien Muggli - 2022
# Updated to support unlimited folder depth via Name + Level columns - 2024
# Added folder tree preview before creation - 2025
# In case of questions, please contact me on GitHub: https://github.com/Liozon
$ScriptVersion = 2.0

Clear-Host
Write-Host "Script developped by Julien Muggli - 2022 - v$ScriptVersion" -ForegroundColor Cyan
Write-Host
Write-Host "In case of questions, please contact me on GitHub: https://github.com/Liozon" -ForegroundColor Cyan
Write-Host " "

# Import the CSV file
# Expected columns: Name (folder name) and Level (1 = root, 2 = child of last level-1, etc.)
# Example:
#   Name                  ; Level
#   1. Legal              ; 1
#   a. Contracts          ; 2
#   i. Signed             ; 3
#   2. Project management ; 1
$Folders = Import-Csv FolderNames.csv -Delimiter ';'

$FoldersCount = $Folders.Count

# ─── FOLDER TREE PREVIEW ────────────────────────────────────────────────────

function Show-FolderTree {
    param (
        [Parameter(Mandatory)]
        [array]$FolderList
    )

    Write-Host "Folder structure preview:" -ForegroundColor Yellow
    Write-Host ""

    # We need to track, for each level, whether there are more siblings coming
    # so we can draw the correct tree characters (├── vs └──).
    # Strategy: for each row, look ahead to find if there is another sibling
    # at the same level before the next item of a higher (lower number) level.

    $total = $FolderList.Count

    for ($i = 0; $i -lt $total; $i++) {
        $name = $FolderList[$i].Name
        $level = [int]$FolderList[$i].Level

        if ([string]::IsNullOrWhiteSpace($name) -or $level -lt 1) { continue }

        # Determine if this item has a sibling after it at the same level
        # (i.e., no ancestor-level item appears before the next same-level item)
        $hasNextSibling = $false
        for ($j = $i + 1; $j -lt $total; $j++) {
            $nextLevel = [int]$FolderList[$j].Level
            if ($nextLevel -lt $level) { break }          # parent-level item → no more siblings
            if ($nextLevel -eq $level) { $hasNextSibling = $true; break }
        }

        # Build the prefix for levels above this one.
        # For each ancestor level (1 to level-1), we check whether that ancestor
        # still has siblings coming → if yes, draw │   otherwise draw spaces.
        $prefix = ""
        for ($lvl = 1; $lvl -lt $level; $lvl++) {

            # Does the ancestor at $lvl still have a sibling after position $i?
            $ancestorHasSibling = $false
            for ($j = $i + 1; $j -lt $total; $j++) {
                $nextLevel = [int]$FolderList[$j].Level
                if ($nextLevel -lt $lvl) { break }
                if ($nextLevel -eq $lvl) { $ancestorHasSibling = $true; break }
            }

            if ($ancestorHasSibling) {
                $prefix += "│   "
            }
            else {
                $prefix += "    "
            }
        }

        # Choose the branch character for this item
        if ($level -eq 1) {
            # Root-level items get no prefix, just the connector
            if ($hasNextSibling) {
                $branch = "├── "
            }
            else {
                $branch = "└── "
            }
            $line = $branch + $name
        }
        else {
            if ($hasNextSibling) {
                $branch = "├── "
            }
            else {
                $branch = "└── "
            }
            $line = $prefix + $branch + $name
        }

        # Colour by depth level
        switch ($level) {
            1 { Write-Host $line -ForegroundColor White }
            2 { Write-Host $line -ForegroundColor Cyan }
            3 { Write-Host $line -ForegroundColor Green }
            4 { Write-Host $line -ForegroundColor Yellow }
            default { Write-Host $line -ForegroundColor Gray }
        }
    }

    Write-Host ""
}

# Draw the tree before asking the user
Show-FolderTree -FolderList $Folders

# ─── CONFIRMATION PROMPT ────────────────────────────────────────────────────

$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "The script will create $FoldersCount folders in the current directory."
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "No folder will be created."
$cancel = New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel", "No folder will be created."
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no, $cancel)

$title = "Creating folder structure"
$message = @"
WARNING: this script will create $FoldersCount folders (all depth levels included).
Existing folders will be left untouched.
Would you like to run the folder creation script?
"@

# ─── FUNCTIONS ──────────────────────────────────────────────────────────────

function startScript() {
    $result = $host.ui.PromptForChoice($title, $message, $options, 1)
    switch ($result) {
        0 { Write-Host "Starting script..."; createFolders }
        1 { Write-Host "Operation cancelled"; closeScript }
        2 { Write-Host "Operation cancelled"; closeScript }
    }
}

function createFolders() {
    # $parentPaths stores the last known path for each level.
    # Index 1 = last level-1 folder, index 2 = last level-2 folder, etc.
    $parentPaths = @{}
    $lineNumber = 2

    foreach ($row in $Folders) {
        $name = $row.Name
        $level = [int]$row.Level

        if ([string]::IsNullOrWhiteSpace($name) -or $level -lt 1) {
            $lineNumber++
            continue
        }

        # Build the full path
        if ($level -eq 1) {
            $fullPath = $name
        }
        else {
            $parentLevel = $level - 1
            if (-not $parentPaths.ContainsKey($parentLevel)) {
                Write-Host "Error on line $lineNumber`: no parent found for level $level folder '$name'. Check that a level $parentLevel folder exists above it." -ForegroundColor Red
                $lineNumber++
                continue
            }
            $fullPath = Join-Path $parentPaths[$parentLevel] $name
        }

        # Register this path as the last known path for its level
        $parentPaths[$level] = $fullPath

        # Create the folder
        try {
            New-Item -Path $fullPath -ItemType Directory -Force | Out-Null
            $indent = "  " * ($level - 1)
            Write-Host "$indent[L$level] $fullPath" -ForegroundColor Green
        }
        catch {
            Write-Host "Error on line $lineNumber ('$fullPath'): $_" -ForegroundColor Red
        }

        $lineNumber++
    }

    closeScript
}

function closeScript() {
    Write-Host " "
    Write-Host "This window will close automatically in 10 seconds..." -ForegroundColor Green
    $seconds = 10
    1..$seconds | ForEach-Object {
        $percent = $_ * 100 / $seconds
        Write-Progress -Activity "Closing" -Status "Closing window in $($seconds - $_) seconds..." -PercentComplete $percent
        Start-Sleep -Seconds 1
    }
}

startScript