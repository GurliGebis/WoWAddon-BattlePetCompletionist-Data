Clear-Host

$scriptFolder = $PSScriptRoot

function Generate-FromFolder {
    param(
        [string]$targetFolder
    )

    $sourceFolder = Join-Path $targetFolder "Source"
    $templateFile = Join-Path $scriptFolder "TemplateData.lua"

    if (-not (Test-Path $templateFile))
    {
        Write-Host "Template file not found: $templateFile" -ForegroundColor Red
        return 1
    }

    $template = Get-Content -Path $templateFile -Raw

    if (-not (Test-Path $sourceFolder))
    {
        Write-Host "Source folder not found: $sourceFolder - skipping" -ForegroundColor Yellow
        return 0
    }

    # Get all JSON files in the Source folder
    $jsonFiles = Get-ChildItem -Path $sourceFolder -Filter "*.json"

    if ($jsonFiles.Count -eq 0)
    {
        Write-Host "No JSON files found in $sourceFolder" -ForegroundColor Yellow
        return 0
    }

    Write-Host "Found $($jsonFiles.Count) JSON file(s) to process in $targetFolder" -ForegroundColor Cyan

    foreach ($jsonFile in $jsonFiles)
    {
        $expansionName = [System.IO.Path]::GetFileNameWithoutExtension($jsonFile.Name)
        $addonFolder = Join-Path $targetFolder "BattlePetCompletionist_$expansionName"

        Write-Host "`nProcessing: $expansionName (target: $targetFolder)" -ForegroundColor Yellow

        # Check if addon folder exists
        if (-not (Test-Path $addonFolder -PathType Container))
        {
            Write-Host "  Addon folder not found: $addonFolder - skipping" -ForegroundColor Red
            continue
        }

        # Read and parse JSON data
        $jsonData = Get-Content -Path $jsonFile.FullName | ConvertFrom-Json
        $stringBuilder = [System.Text.StringBuilder]::new()

        $stringBuilder.Append("{") | Out-Null

        $mapAdded = $false;

        foreach ($map in $jsonData)
        {
            $stringBuilder.Append("[$($map.map)]={") | Out-Null

            $petAdded = $false

            foreach ($pet in $map.pets)
            {
                $stringBuilder.Append("[$($pet.id)]=`"") | Out-Null

                $alreadyAddedList = @{}

                foreach ($coordinate in $pet.coordinates)
                {
                    $key = "$($coordinate.Split(' ')[0].Split('.')[0])-$($coordinate.Split(' ')[1].Split('.')[0])"

                    if ($alreadyAddedList.ContainsKey($key))
                    {
                        continue;
                    }
                    else
                    {
                        $alreadyAddedList[$key] = $key
                    }

                    $x = $coordinate.Split(' ')[0].Replace(".", "")
                    $y = $coordinate.Split(' ')[1].Replace(".", "")

                    while ($x.Length -lt 3)
                    {
                        $x = "0$($x)"
                    }

                    while ($y.Length -lt 3)
                    {
                        $y = "0$($y)"
                    }

                    $stringBuilder.Append($x).Append($y) | Out-Null
                }

                $petAdded = $true
                $stringBuilder.Append("`",") | Out-Null
            }

            if ($petAdded)
            {
                $stringBuilder.Remove($stringBuilder.Length - 1, 1) | Out-Null
            }

            $mapAdded = $true
            $stringBuilder.Append("},") | Out-Null
        }

        if ($mapAdded)
        {
            $stringBuilder.Remove($stringBuilder.Length - 1, 1) | Out-Null
        }

        $stringBuilder.Append("}") | Out-Null

        # Generate Data.lua file
        $result = $template.Replace("{DATA}", $stringBuilder.ToString())

        $outputFile = Join-Path $addonFolder "Data.lua"
        $result | Out-File -FilePath $outputFile -Encoding utf8

        Write-Host "  Generated: $outputFile" -ForegroundColor Green
    }

    return 0
}

Write-Host "Starting pet data update..." -ForegroundColor Cyan

$classicFolder = Join-Path $scriptFolder "Classic"
$retailFolder  = Join-Path $scriptFolder "Retail"

# Run Classic first
Generate-FromFolder -targetFolder $classicFolder

# Then Retail
Generate-FromFolder -targetFolder $retailFolder

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "All processing complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
