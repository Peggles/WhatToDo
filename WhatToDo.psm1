function Start-WhatToDo {
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -Path $_ -PathType Leaf) { return $true }
            else { throw [System.IO.FileNotFoundException] "Cannot find the file '$($_)'." }
        })]
        [string]$ConfigurationPath
    )

    $ScriptConfig = Import-PowerShellDataFile -Path $ConfigurationPath -ErrorAction Stop
    $ExitScript = $false
    $ListDate = Get-Date
    $TaskList = New-Object -TypeName 'System.Collections.ArrayList'
    $TaskList = [System.Collections.ArrayList](Import-WhatToDoTaskList -Path $ScriptConfig.TaskListFile -Date $ListDate)
    $MessageList = [System.Collections.Generic.List[string]]@()

    while (!$ExitScript) {
        Clear-Host

        if ((Get-Date $ListDate).Date -eq (Get-Date).Date) {
            $dateColor = 'Cyan'
        }
        elseif ((Get-Date $ListDate).Date -lt (Get-Date).Date) {
            $dateColor = 'Red'
        }
        elseif ((Get-Date $ListDate).Date -gt (Get-Date).Date) {
            $dateColor = 'Yellow'
        }
        Write-Host (Get-Date $ListDate -Format 'yyyy-MM-dd') -NoNewline -ForegroundColor $dateColor
        Write-Host " ($((Get-Date $ListDate).DayOfWeek))" -NoNewline -ForegroundColor DarkGray
        Write-Host " $(Get-Date $ListDate -UFormat '%V')" -ForegroundColor DarkGray
        Write-Host

        $overdueTasks = $TaskList | Where-Object {
            ($_.DueDate.Date -lt (Get-Date).Date) -and
            (!$_.Completed)
        } | Sort-Object -Property DueDate, CreationDate, Description

        if (($overdueTasks | Measure-Object).Count -gt 0) {
            Write-Host ('-' * 20) -ForegroundColor DarkRed
            Write-Host "Overdue tasks [$(($overdueTasks | Measure-Object).Count)]" -ForegroundColor DarkRed
            $overdueTasks | ForEach-Object {
                Write-Host "$($_.Description) ($(Get-Date $_.DueDate -Format 'd\/M'))" -ForegroundColor DarkGray
            }
            Write-Host ('-' * 20) -ForegroundColor DarkRed
            Write-Host
        }

        $index = 0
        $TaskList = [System.Collections.ArrayList](Get-WhatToDoSortedTaskList -TaskList $TaskList)
        $TaskList | Where-Object { $_.DueDate.Date -eq $ListDate.Date } | ForEach-Object {
            $index++
            # Index.
            Write-Host '[' -NoNewline -ForegroundColor DarkGray
            Write-Host $index -NoNewline -ForegroundColor Gray
            Write-Host '] ' -NoNewline -ForegroundColor DarkGray

            # Priority/completed.
            if ($_.Completed) {
                Write-Host 'DONE' -NoNewline -ForegroundColor Yellow
            }
            else {
                Write-Host $_.Priority -NoNewline -ForegroundColor Yellow
            }
            Write-Host ' - ' -NoNewline -ForegroundColor DarkGray

            # Description.
            Write-Host $_.Description -NoNewline
            Write-Host ' (' -NoNewline -ForegroundColor DarkGray

            # Time estimate.
            Write-Host $_.EstimateMinutes -NoNewline -ForegroundColor Green
            Write-Host ')' -ForegroundColor DarkGray
        }

        if ($index -eq 0) {
            Write-Host 'No tasks.' -ForegroundColor DarkGray
        }

        if (($MessageList | Measure-Object).Count -gt 0) {
            Write-Host
            $MessageList | ForEach-Object {
                Write-Host $_ -ForegroundColor Yellow
            }
        }
        $MessageList.Clear()

        Write-Host
        $UserCommand = Read-Host '$'
        Write-Host

        if ($UserCommand -match '^add ([a-zA-Z]) (\d+) (.+)$') {
            [void]$TaskList.Add([PSCustomObject]@{
                Priority = ($Matches.1).ToUpper()
                EstimateMinutes = $Matches.2
                Description = ($Matches.3).Trim()
                CreationDate = Get-Date
                DueDate = Get-Date $ListDate
            })
            Save-WhatToDoTaskList -TaskList $TaskList -FilePath $ScriptConfig.TaskListFile
            $MessageList.Add("Added task '$(($Matches.3).Trim())'.")
        }
        elseif ($UserCommand -match '^edit (\d+) ([a-zA-Z]) (\d+) (.+)$') {
            $tempIndex = $Matches.1
            $currentTasks = ($TaskList | Where-Object { $_.DueDate.Date -eq $ListDate.Date })

            if (($tempIndex -ge 1) -and ($tempIndex -le ($currentTasks | Measure-Object).Count)) {
                $task = [PSCustomObject]$currentTasks[$tempIndex-1]
                $oldDescription = $task.Description
                $TaskList = [System.Collections.ArrayList]($TaskList | Where-Object { $_ -ne $task })
                $task.Priority = ($Matches.2).ToUpper()
                $task.EstimateMinutes = $Matches.3
                $task.Description = $Matches.4
                $TaskList.Add($task)
                Save-WhatToDoTaskList -TaskList $TaskList -FilePath $ScriptConfig.TaskListFile
                $MessageList.Add("Edited task '$($oldDescription)'.")
            }
            else {
                $MessageList.Add("Invalid task index: $($tempIndex)")
            }
        }
        elseif ($UserCommand -match '^edit (\d+) (.+)$') {
            $tempIndex = $Matches.1
            $currentTasks = ($TaskList | Where-Object { $_.DueDate.Date -eq $ListDate.Date })

            if (($tempIndex -ge 1) -and ($tempIndex -le ($currentTasks | Measure-Object).Count)) {
                $task = [PSCustomObject]$currentTasks[$tempIndex-1]
                $oldDescription = $task.Description
                $TaskList = [System.Collections.ArrayList]($TaskList | Where-Object { $_ -ne $task })
                $task.Description = $Matches.2
                $TaskList.Add($task)
                Save-WhatToDoTaskList -TaskList $TaskList -FilePath $ScriptConfig.TaskListFile
                $MessageList.Add("Edited task '$($oldDescription)'.")
            }
            else {
                $MessageList.Add("Invalid task index: $($tempIndex)")
            }
        }
        elseif ($UserCommand -match '^remove (\d+)$') {
            $tempIndex = $Matches.1
            $currentTasks = ($TaskList | Where-Object { $_.DueDate.Date -eq $ListDate.Date })

            if (($tempIndex -ge 1) -and ($tempIndex -le ($currentTasks | Measure-Object).Count)) {
                $task = [PSCustomObject]$currentTasks[$tempIndex-1]
                $TaskList = [System.Collections.ArrayList]($TaskList | Where-Object { $_ -ne $task })
                Save-WhatToDoTaskList -TaskList $TaskList -FilePath $ScriptConfig.TaskListFile
                $MessageList.Add("Removed task '$($task.Description)'.")
            }
            else {
                $MessageList.Add("Invalid task index: $($tempIndex)")
            }
        }
        elseif ($UserCommand -match '^done (\d+)$') {
            $tempIndex = $Matches.1
            $currentTasks = ($TaskList | Where-Object { $_.DueDate.Date -eq $ListDate.Date })

            if (($tempIndex -ge 1) -and ($tempIndex -le ($currentTasks | Measure-Object).Count)) {
                $task = [PSCustomObject]$currentTasks[$tempIndex-1]
                if (!$task.Completed) {
                    $TaskList = [System.Collections.ArrayList]($TaskList | Where-Object { $_ -ne $task })
                    $task.Completed = $true
                    $task.CompletionDate = Get-Date
                    $TaskList.Add($task)
                    Save-WhatToDoTaskList -TaskList $TaskList -FilePath $ScriptConfig.TaskListFile
                    $MessageList.Add("Completed task '$($task.Description)'.")
                }
                else {
                    $MessageList.Add('That task is already completed.')
                }
            }
            else {
                $MessageList.Add("Invalid task index: $($tempIndex)")
            }
        }
        elseif ($UserCommand -match '^undone (\d+)$') {
            $tempIndex = $Matches.1
            $currentTasks = ($TaskList | Where-Object { $_.DueDate.Date -eq $ListDate.Date })

            if (($tempIndex -ge 1) -and ($tempIndex -le ($currentTasks | Measure-Object).Count)) {
                $task = [PSCustomObject]$currentTasks[$tempIndex-1]
                if ($task.Completed) {
                    $TaskList = [System.Collections.ArrayList]($TaskList | Where-Object { $_ -ne $task })
                    $task.Completed = $false
                    $task.CompletionDate = $null
                    $TaskList.Add($task)
                    Save-WhatToDoTaskList -TaskList $TaskList -FilePath $ScriptConfig.TaskListFile
                    $MessageList.Add("Un-completed task '$($task.Description)'.")
                }
                else {
                    $MessageList.Add("That task isn't completed.")
                }
            }
            else {
                $MessageList.Add("Invalid task index: $($tempIndex)")
            }
        }
        elseif ($UserCommand -match '^move (\d+) (\d{4}-\d{2}-\d{2})$') {
            $tempIndex = $Matches.1
            $newDueDate = Get-Date $Matches.2
            $currentTasks = ($TaskList | Where-Object { $_.DueDate.Date -eq $ListDate.Date })
            if (($tempIndex -ge 1) -and ($tempIndex -le ($currentTasks | Measure-Object).Count)) {
                $task = [PSCustomObject]$currentTasks[$tempIndex-1]
                $TaskList | Where-Object { $_ -eq $task } | ForEach-Object {
                    $_.DueDate = $newDueDate
                    $_.DueDate
                }
                Save-WhatToDoTaskList -TaskList $TaskList -FilePath $ScriptConfig.TaskListFile
                $MessageList.Add("Moved task '$($task.Description)' to $(Get-Date $newDueDate -Format 'yyyy-MM-dd').")
            }
            else {
                $MessageList.Add("Invalid task index: $($tempIndex)")
            }
        }
        elseif ($UserCommand -match '^move (\d+) (\d{1,2})$') {
            $tempIndex = $Matches.1
            $newDueDate = Get-Date -Day $Matches.2
            $currentTasks = ($TaskList | Where-Object { $_.DueDate.Date -eq $ListDate.Date })
            if (($tempIndex -ge 1) -and ($tempIndex -le ($currentTasks | Measure-Object).Count)) {
                $task = [PSCustomObject]$currentTasks[$tempIndex-1]
                $TaskList | Where-Object { $_ -eq $task } | ForEach-Object {
                    $_.DueDate = $newDueDate
                    $_.DueDate
                }
                Save-WhatToDoTaskList -TaskList $TaskList -FilePath $ScriptConfig.TaskListFile
                $MessageList.Add("Moved task '$($task.Description)' to $(Get-Date $newDueDate -Format 'yyyy-MM-dd').")
            }
            else {
                $MessageList.Add("Invalid task index: $($tempIndex)")
            }
        }
        elseif ($UserCommand -match '^move (\d+)$') {
            $tempIndex = $Matches.1
            $moveDays = 0

            # Move task to next workday.
            do {
                $moveDays++
                $newDueDate = (Get-Date $ListDate).AddDays($moveDays)
            }
            while (
                ((Get-Date $ListDate).AddDays($moveDays).DayOfWeek -eq 0) -or
                ((Get-Date $ListDate).AddDays($moveDays).DayOfWeek -gt 5)
            )

            $currentTasks = ($TaskList | Where-Object { $_.DueDate.Date -eq $ListDate.Date })
            if (($tempIndex -ge 1) -and ($tempIndex -le ($currentTasks | Measure-Object).Count)) {
                $task = [PSCustomObject]$currentTasks[$tempIndex-1]
                $TaskList | Where-Object { $_ -eq $task } | ForEach-Object {
                    $_.DueDate = $newDueDate
                    $_.DueDate
                }
                Save-WhatToDoTaskList -TaskList $TaskList -FilePath $ScriptConfig.TaskListFile
                $MessageList.Add("Moved task '$($task.Description)' to $(Get-Date $newDueDate -Format 'yyyy-MM-dd').")
            }
            else {
                $MessageList.Add("Invalid task index: $($tempIndex)")
            }
        }
        elseif ($UserCommand -match '^load (\d{4}-\d{2}-\d{2})$') {
            $ListDate = Get-Date $Matches.1
            $TaskList = Import-WhatToDoTaskList -Path $ScriptConfig.TaskListFile -Date $ListDate
        }
        elseif ($UserCommand -match '^load (\d{1,2})$') {
            $ListDate = Get-Date -Day $Matches.1
            $TaskList = Import-WhatToDoTaskList -Path $ScriptConfig.TaskListFile -Date $ListDate
        }
        elseif ($UserCommand -match '^load (\+|\-{1})(\d+)$') {
            $shiftDays = [int]($Matches.1 + [int]$Matches.2)
            $ListDate = (Get-Date $ListDate).AddDays($shiftDays)
            $TaskList = Import-WhatToDoTaskList -Path $ScriptConfig.TaskListFile -Date $ListDate
        }
        elseif ($UserCommand -eq 'load') {
            $ListDate = Get-Date
            $TaskList = Import-WhatToDoTaskList -Path $ScriptConfig.TaskListFile -Date $ListDate
        }
        elseif (($UserCommand -eq 'calendar') -or ($UserCommand -eq 'cal')) {
            $futureTasks = $TaskList | Where-Object {
                $_.DueDate.Date -gt (Get-Date) -and $_.DueDate -le (Get-Date).AddDays(14)
            } | Sort-Object -Property DueDate, Priority, CreationDate, Description

            if (($futureTasks | Measure-Object).Count -gt 0) {
                Write-Host "Future tasks within 14 days [$(($futureTasks | Measure-Object).Count)]" -ForegroundColor DarkCyan
                $futureTasks | ForEach-Object {
                    Write-Host "- $($_.Description)" -NoNewline
                    Write-Host " ($((Get-Date $_.DueDate).DayOfWeek.ToString().Substring(0, 3)) $(Get-Date $_.DueDate -Format 'd\/M'))" -ForegroundColor DarkYellow
                }
            }
            else {
                Write-Host 'No tasks the following 14 days.' -ForegroundColor DarkGray
            }
            Write-Host
            Read-Host 'Press <Enter> to exit calendar view'
        }
        elseif ($UserCommand -eq 'save') {
            Save-WhatToDoTaskList -TaskList $TaskList -FilePath $ScriptConfig.TaskListFile
        }
        elseif ($UserCommand -eq 'exit') {
            $ExitScript = $true
        }
        else {
            $MessageList.Add("Invalid command: '$($UserCommand)'")
        }

        Write-Host
    }
}
Export-ModuleMember -Function Start-WhatToDo

function Import-WhatToDoTaskList {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$Path,
        [Parameter(Mandatory)]
        [DateTime]$Date
    )

    $tempTaskList = New-Object -TypeName 'System.Collections.ArrayList'

    Get-Content -Path $Path | ForEach-Object {
        if ($_ -match '^\(([A-Z])\) (\d{4}-\d{2}-\d{2}) (.+) est:(\d+) due:(\d{4}-\d{2}-\d{2})$') {
            try {
                $priority = $Matches.1
                $creationDate = $Matches.2
                $description = $Matches.3
                $estimateMinutes = $Matches.4
                $dueDate = $Matches.5
    
                if ($description.Length -gt 0) {
                    [void]$tempTaskList.Add([PSCustomObject]@{
                        Completed = $false
                        Priority = $priority.ToUpper()
                        CompletionDate = $null
                        Description = $description
                        EstimateMinutes = $estimateMinutes
                        CreationDate = Get-Date $creationDate
                        DueDate = Get-Date $dueDate
                    })
                }
            }
            catch {
                throw "Failed to import un-completed task. $($Error[0])"
            }
        }
        elseif ($_ -match '^x \(([A-Z])\) (\d{4}-\d{2}-\d{2}) (\d{4}-\d{2}-\d{2}) (.+) est:(\d+) due:(\d{4}-\d{2}-\d{2})$') {
            try {
                $priority = $Matches.1
                $completionDate = $Matches.2
                $creationDate = $Matches.3
                $description = $Matches.4
                $estimateMinutes = $Matches.5
                $dueDate = $Matches.6
    
                if ($description.Length -gt 0) {
                    [void]$tempTaskList.Add([PSCustomObject]@{
                        Completed = $true
                        Priority = $priority.ToUpper()
                        CompletionDate = Get-Date $completionDate
                        Description = $description
                        EstimateMinutes = $estimateMinutes
                        CreationDate = Get-Date $creationDate
                        DueDate = Get-Date $dueDate
                    })
                }
            }
            catch {
                throw "Failed to import completed task. $($Error[0])"
            }
        }
    }

    return $tempTaskList
}

function Get-WhatToDoSortedTaskList {
    param(
        [Parameter(Mandatory)]
        [System.Collections.ArrayList]$TaskList
    )

    return ($TaskList | Sort-Object -Property Completed, Priority, EstimateMinutes, CreationDate, Description)
}

function Save-WhatToDoTaskList {
    param(
        [Parameter(Mandatory)]
        [System.Collections.ArrayList]$TaskList,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath
    )

    $content = ''
    if (($TaskList | Measure-Object).Count -gt 0) {
        $TaskList | Where-Object { $_.Description.Length -gt 0 } | ForEach-Object {
            if ($_.Completed) {
                $content += "x ($($_.Priority)) $(Get-Date $_.CompletionDate -Format 'yyyy-MM-dd') $(Get-Date $_.CreationDate -Format 'yyyy-MM-dd') $($_.Description) est:$($_.EstimateMinutes) due:$(Get-Date $_.DueDate -Format 'yyyy-MM-dd')`n"
            }
            else {
                $content += "($($_.Priority)) $(Get-Date $_.CreationDate -Format 'yyyy-MM-dd') $($_.Description) est:$($_.EstimateMinutes) due:$(Get-Date $_.DueDate -Format 'yyyy-MM-dd')`n"
            }
        }
    }
    Set-Content -Path $FilePath -Value $content.Trim() -Encoding 'utf8'
}

function Initialize-WhatToDo {
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -Path $_ -PathType Container) { return $true }
            else { throw "Cannot find the directory '$($_)'." }
        })]
        [string]$DirectoryPath
    )

    $taskListFilePath = Join-Path -Path $DirectoryPath -ChildPath 'tasks.todo'
    $configFilePath = Join-Path -Path $DirectoryPath -ChildPath 'WhatToDo-Config.psd1'

    if (!(Test-Path -Path $configFilePath)) {
        $configFileContent = @"
@{
    TaskListFile = '$($taskListFilePath)'
}
"@
        try {
            New-Item -Path $configFilePath -ItemType File -Value $configFileContent -Confirm
        }
        catch {
            throw "Failed to create configuration file in directory '$($DirectoryPath)'. $($Error[0])"
        }

        if (!(Test-Path -Path $taskListFilePath)) {
            try {
                New-Item -Path $taskListFilePath -ItemType File -Confirm
            }
            catch {
                throw "Failed to create task list file in directory '$($DirectoryPath)'. $($Error[0])"
            }
        }
        else {
            Write-Error "WhatToDo task list already exists in that directory. Task list file path is '$($taskListFilePath)'."
        }
    }
    else {
        Write-Error "WhatToDo has already been set up in that directory. Configuration file path is '$($configFilePath)'."
    }
}
Export-ModuleMember -Function Initialize-WhatToDo
