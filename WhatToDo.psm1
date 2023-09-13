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
    $MessageList = [System.Collections.Generic.List[string]]@()
    $ListDate = Get-Date
    $TaskList = New-Object -TypeName 'System.Collections.ArrayList'
    $TaskList = [System.Collections.ArrayList](Import-WhatToDoTaskList -Path $ScriptConfig.TaskListFile -Date $ListDate)

    # Get-WhatToDoRecurringTasks -RecurringTasksConfig $ScriptConfig.RecurringTasks | ForEach-Object {
    #     $tempTask = $_
    #     if ((($TaskList | Where-Object { ($_.Description -eq $tempTask.Description) -and ($_.DueDate -eq $tempTask.DueDate) }) | Measure-Object).Count -eq 0) {
    #         $TaskList.Add($tempTask)
    #     }
    # }

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

        if ((Get-Date $ListDate).Date -eq (Get-Date).Date) {
            Write-Host 'Today ' -NoNewline
        }
        Write-Host "$((Get-Date $ListDate).DayOfWeek.ToString().Substring(0, 3)) " -NoNewline -ForegroundColor $dateColor
        if ((Get-Date $ListDate).Year -eq (Get-Date).Year) {
            Write-Host "$(Get-Date $ListDate -Format 'd\/M')" -NoNewline -ForegroundColor $dateColor
        }
        else {
            Write-Host "$(Get-Date $ListDate -Format 'yyyy-MM-dd')" -NoNewline -ForegroundColor $dateColor
        }
        Write-Host " [$(Get-Date $ListDate -UFormat '%V')]" -ForegroundColor DarkGray
        Write-Host

        $overdueTasks = $TaskList | Where-Object {
            ($_.DueDate.Date -lt (Get-Date).Date) -and
            (!$_.Completed)
        } | Sort-Object -Property DueDate, CreationDate, Description

        if (($overdueTasks | Measure-Object).Count -gt 0) {
            Write-Host ('-' * 20) -ForegroundColor DarkRed
            Write-Host "Overdue tasks [$(($overdueTasks | Measure-Object).Count)]" -ForegroundColor Red
            $overdueTasks | ForEach-Object {
                Write-Host "$($_.Description) ($(Get-Date $_.DueDate -Format 'd\/M'))" -ForegroundColor DarkGray
            }
            Write-Host ('-' * 20) -ForegroundColor DarkRed
            Write-Host
        }

        $index = 0
        # $TaskList = [System.Collections.ArrayList](Get-WhatToDoSortedTaskList -TaskList $TaskList)
        $TaskList = [System.Collections.ArrayList]($TaskList | Sort-Object -Property Completed, Priority, EstimateMinutes, CreationDate, Description)
        $TaskList | Where-Object { $_.DueDate.Date -eq $ListDate.Date } | ForEach-Object {
            $index++
            # Index.
            Write-Host '[' -NoNewline -ForegroundColor DarkGray
            Write-Host $index -NoNewline -ForegroundColor Gray
            Write-Host '] ' -NoNewline -ForegroundColor DarkGray

            # Priority/completed.
            if ($_.Completed) {
                Write-Host 'DONE' -NoNewline -ForegroundColor DarkGreen
            }
            else {
                Write-Host $_.Priority -NoNewline -ForegroundColor Yellow
            }
            Write-Host ' - ' -NoNewline -ForegroundColor DarkGray

            # Description.
            if ($_.Completed) {
                Write-Host $_.Description -NoNewline -ForegroundColor DarkGray
            }
            else {
                Write-Host $_.Description -NoNewline
            }
            Write-Host ' (' -NoNewline -ForegroundColor DarkGray

            # Time estimate.
            if ($_.Completed) {
                Write-Host $_.EstimateMinutes -NoNewline -ForegroundColor DarkGray
            }
            else {
                Write-Host $_.EstimateMinutes -NoNewline -ForegroundColor Green
            }
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

        if ($index -gt 0) {
            Write-Host
            Write-Host 'Total: ' -NoNewline -ForegroundColor DarkGreen
            $totalEstimateMinutes = 0
            $remainingEstimateMinutes = 0
            $TaskList | Where-Object { $_.DueDate.Date -eq $ListDate.Date } | ForEach-Object {
                $totalEstimateMinutes += $_.EstimateMinutes
                if (!$_.Completed) {
                    $remainingEstimateMinutes += $_.EstimateMinutes
                }
            }

            $remainingEstimateHours = [Math]::Floor($remainingEstimateMinutes / 60)
            $remainingEstimateMinutes -= $remainingEstimateHours * 60
            if ($remainingEstimateHours -gt 0) {
                Write-Host "$($remainingEstimateHours)h " -NoNewline -ForegroundColor DarkGreen
            }
            Write-Host "$($remainingEstimateMinutes)m / " -NoNewline -ForegroundColor DarkGreen

            $totalEstimateHours = [Math]::Floor($totalEstimateMinutes / 60)
            $totalEstimateMinutes -= $totalEstimateHours * 60
            if ($totalEstimateHours -gt 0) {
                Write-Host "$($totalEstimateHours)h " -NoNewline -ForegroundColor DarkGreen
            }
            Write-Host "$($totalEstimateMinutes)m" -ForegroundColor DarkGreen
        }

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
        }
        elseif ($UserCommand -match '^add ([a-zA-Z]) (\d+[\.,]?5?)h (.+)$') {
            [void]$TaskList.Add([PSCustomObject]@{
                Priority = ($Matches.1).ToUpper()
                EstimateMinutes = [float]($Matches.2).Replace(',', '.') * 60
                Description = ($Matches.3).Trim()
                CreationDate = Get-Date
                DueDate = Get-Date $ListDate
            })
            Save-WhatToDoTaskList -TaskList $TaskList -FilePath $ScriptConfig.TaskListFile
        }
        elseif ($UserCommand -match '^edit (\d+)$') {
            $tempIndex = $Matches.1
            $currentTasks = ($TaskList | Where-Object { $_.DueDate.Date -eq $ListDate.Date })

            if (($tempIndex -ge 1) -and ($tempIndex -le ($currentTasks | Measure-Object).Count)) {
                $task = [PSCustomObject]$currentTasks[$tempIndex-1]
                $newPriority = Read-Host 'New priority'
                $newEstimate = Read-Host 'New estimate'
                $newDescription = Read-Host 'New description'

                if (![string]::IsNullOrWhiteSpace($newPriority)) {
                    ($TaskList | Where-Object { $_ -eq $task }).Priority = $newPriority.Trim().ToUpper()
                }
                if (![string]::IsNullOrWhiteSpace($newEstimate)) {
                    ($TaskList | Where-Object { $_ -eq $task }).EstimateMinutes = $newEstimate.Trim()
                }
                if (![string]::IsNullOrWhiteSpace($newDescription)) {
                    ($TaskList | Where-Object { $_ -eq $task }).Description = $newDescription.Trim()
                }
                Save-WhatToDoTaskList -TaskList $TaskList -FilePath $ScriptConfig.TaskListFile
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
                $TaskList.Remove(($TaskList | Where-Object { $_ -eq $task }))
                Save-WhatToDoTaskList -TaskList $TaskList -FilePath $ScriptConfig.TaskListFile
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
                    ($TaskList | Where-Object { $_ -eq $task }).Completed = $true
                    ($TaskList | Where-Object { $_ -eq $task }).CompletionDate = Get-Date
                    Save-WhatToDoTaskList -TaskList $TaskList -FilePath $ScriptConfig.TaskListFile
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
                    ($TaskList | Where-Object { $_ -eq $task }).Completed = $false
                    ($TaskList | Where-Object { $_ -eq $task }).CompletionDate = $null
                    Save-WhatToDoTaskList -TaskList $TaskList -FilePath $ScriptConfig.TaskListFile
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
                ($TaskList | Where-Object { $_ -eq $task }).DueDate = $newDueDate
                Save-WhatToDoTaskList -TaskList $TaskList -FilePath $ScriptConfig.TaskListFile
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
                ($TaskList | Where-Object { $_ -eq $task }).DueDate = $newDueDate
                Save-WhatToDoTaskList -TaskList $TaskList -FilePath $ScriptConfig.TaskListFile
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
                ($TaskList | Where-Object { $_ -eq $task }).DueDate = $newDueDate
                Save-WhatToDoTaskList -TaskList $TaskList -FilePath $ScriptConfig.TaskListFile
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
                ($_.DueDate.Date -gt (Get-Date)) -and
                ($_.DueDate -le (Get-Date).AddDays(14)) -and
                (!$_.Completed)
            } | Sort-Object -Property DueDate, Priority, CreationDate, Description

            if (($futureTasks | Measure-Object).Count -gt 0) {
                Write-Host "Tasks within 14 days [$(($futureTasks | Measure-Object).Count)]" -ForegroundColor DarkCyan
                $futureTasks | ForEach-Object {
                    if ((Get-Date $_.DueDate).Date -eq (Get-Date).Date.AddDays(1)) {
                        # Tomorrow.
                        Write-Host "- $($_.Description)" -NoNewline
                        Write-Host " (Tomorrow, $((Get-Date $_.DueDate).DayOfWeek.ToString().Substring(0, 3)) $(Get-Date $_.DueDate -Format 'd\/M'))" -ForegroundColor DarkGreen
                    }
                    else {
                        Write-Host "- $($_.Description)" -NoNewline
                        Write-Host " ($((Get-Date $_.DueDate).DayOfWeek.ToString().Substring(0, 3)) $(Get-Date $_.DueDate -Format 'd\/M'))" -ForegroundColor DarkYellow
                    }
                }
            }
            else {
                Write-Host 'No tasks the following 14 days.' -ForegroundColor DarkGray
            }
            Write-Host
            Read-Host 'Press <Enter> to exit calendar view'
        }
        elseif (($UserCommand -eq 'directory') -or ($UserCommand -eq 'dir')) {
            Invoke-Item (Split-Path -Path $ScriptConfig.TaskListFile -Parent)
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

function Get-WhatToDoRecurringTasks {
    param(
        [Parameter(Mandatory)]
        $RecurringTasksConfig
    )

    #TODO: Implement recurring tasks.

    $tempTaskList = New-Object -TypeName 'System.Collections.ArrayList'

    foreach ($task in $RecurringTasksConfig) {
        if ($task.Time.Month) {
            Write-Host "Month: $($task.Time.Month)"
        }

        if ($task.Time.DayOfMonth) {
            Write-Host "Day of month: $($task.Time.DayOfMonth)"
        }

        if ($task.Time.Weekday) {
            Write-Host "Weekday: $($task.Time.Weekday)"
        }

        if ($task.Time.FirstWeekdayOfMonth) {
            Write-Host "First weekday of month: $($task.Time.FirstWeekdayOfMonth)"
        }

        if ($task.Time.SecondWeekdayOfMonth) {
            Write-Host "Second weekday of month: $($task.Time.SecondWeekdayOfMonth)"
        }

        if ($task.Time.ThirdWeekdayOfMonth) {
            Write-Host "Third weekday of month: $($task.Time.ThirdWeekdayOfMonth)"
        }

        if ($task.Time.FourthWeekdayOfMonth) {
            Write-Host "Fourth weekday of month: $($task.Time.FourthWeekdayOfMonth)"
        }

        try {
            [void]$tempTaskList.Add([PSCustomObject]@{
                Completed = $false
                Priority = $task.Task.Priority.ToUpper()
                CompletionDate = $null
                Description = $task.Task.Description
                EstimateMinutes = $task.Task.EstimateMinutes
                CreationDate = Get-Date
                DueDate = Get-Date
            })
        }
        catch {
            #TODO
        }
    }

    Read-Host 'DEBUG'
    return $tempTaskList
}
