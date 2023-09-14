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

    $recurringTasks = Get-WhatToDoRecurringTasks -TaskList $TaskList -RecurringTasksConfig $ScriptConfig.RecurringTasks
    if (($recurringTasks | Measure-Object).Count -gt 0) {
            $recurringTasks | ForEach-Object {
            $tempTask = $_
            if ((($TaskList | Where-Object { ($_.Description -eq $tempTask.Description) -and ($_.DueDate -eq $tempTask.DueDate) }) | Measure-Object).Count -eq 0) {
                $TaskList.Add($tempTask)
            }
        }
        Save-WhatToDoTaskList -TaskList $TaskList -FilePath $ScriptConfig.TaskListFile
    }

    while (!$ExitScript) {
        Clear-Host

        if ((Get-Date $ListDate).Date -eq (Get-Date).Date) { $dateColor = 'Cyan' }
        elseif ((Get-Date $ListDate).Date -lt (Get-Date).Date) { $dateColor = 'Red' }
        elseif ((Get-Date $ListDate).Date -gt (Get-Date).Date) { $dateColor = 'Yellow' }

        if ((Get-Date $ListDate).Date -eq (Get-Date).Date) { Write-Host 'Today ' -NoNewline }
        elseif ((Get-Date $ListDate).Date -eq (Get-Date).Date.AddDays(1)) { Write-Host 'Tomorrow ' -NoNewline }
        elseif ((Get-Date $ListDate).Date -eq (Get-Date).Date.AddDays(-1)) { Write-Host 'Yesterday ' -NoNewline }
        Write-Host "$((Get-Date $ListDate).DayOfWeek.ToString().Substring(0, 3)) " -NoNewline -ForegroundColor $dateColor

        if ((Get-Date $ListDate).Year -eq (Get-Date).Year) {
            Write-Host "$(Get-Date $ListDate -Format 'd\/M')" -NoNewline -ForegroundColor $dateColor
        }
        else {
            Write-Host "$(Get-Date $ListDate -Format 'yyyy-MM-dd')" -NoNewline -ForegroundColor $dateColor
        }

        Write-Host " [$(Get-Date $ListDate -UFormat '%V')]" -ForegroundColor DarkGray
        Write-Host

        $overdueTasks = (
            $TaskList |
            Where-Object { ($_.DueDate.Date -lt (Get-Date).Date) -and (!$_.Completed) } |
            Sort-Object -Property DueDate, CreationDate, Description
        )

        if (($overdueTasks | Measure-Object).Count -gt 0) {
            Write-Host ('-' * 20) -ForegroundColor DarkGray
            Write-Host "Overdue tasks [$(($overdueTasks | Measure-Object).Count)]" -ForegroundColor Red

            $overdueTasks | Where-Object { $_.Description.Length -gt 0 } | ForEach-Object {
                Write-Host '- ' -NoNewline -ForegroundColor Gray
                Write-Host "$($_.Description)" -NoNewline
                Write-Host " ($((Get-Date $_.DueDate).DayOfWeek.ToString().Substring(0, 3)) $(Get-Date $_.DueDate -Format 'd\/M'))" -ForegroundColor DarkGray
            }

            Write-Host ('-' * 20) -ForegroundColor DarkGray
            Write-Host
        }

        $index = 0
        # Convert task list to array list and sort it (if it contains more than 1, otherwise skip conversion).
        if (($TaskList | Measure-Object).Count -gt 1) {
            $TaskList = [System.Collections.ArrayList]($TaskList | Sort-Object -Property Completed, Priority, EstimateMinutes, CreationDate, Description)
        }
        $TaskList | Where-Object { $_.DueDate.Date -eq $ListDate.Date } | ForEach-Object {
            $index++
            Write-Host '[' -NoNewline -ForegroundColor DarkGray
            Write-Host $index -NoNewline -ForegroundColor Gray
            Write-Host '] ' -NoNewline -ForegroundColor DarkGray

            $estimateHours = [Math]::Floor($_.EstimateMinutes / 60)
            $estimateMinutes = $_.EstimateMinutes - ($estimateHours * 60)

            if ($_.Completed) {
                Write-Host 'DONE' -NoNewline -ForegroundColor DarkGreen
                Write-Host ' - ' -NoNewline -ForegroundColor DarkGray
                Write-Host $_.Description -NoNewline -ForegroundColor DarkGray
                Write-Host ' (' -NoNewline -ForegroundColor DarkGray
                if (($estimateHours -gt 0) -and ($estimateMinutes -gt 0)) {
                    Write-Host "$($estimateHours)h " -NoNewline -ForegroundColor DarkGray
                    Write-Host "$($estimateMinutes)m" -NoNewline -ForegroundColor DarkGray
                }
                elseif ($estimateHours -gt 0) {
                    Write-Host "$($estimateHours)h" -NoNewline -ForegroundColor DarkGray
                }
                elseif ($estimateMinutes -ge 0) {
                    Write-Host "$($estimateMinutes)m" -NoNewline -ForegroundColor DarkGray
                }
                Write-Host ')' -ForegroundColor DarkGray
            }
            else {
                Write-Host $_.Priority -NoNewline -ForegroundColor Yellow
                Write-Host ' - ' -NoNewline -ForegroundColor DarkGray
                Write-Host $_.Description -NoNewline
                Write-Host ' (' -NoNewline -ForegroundColor DarkGray
                if (($estimateHours -gt 0) -and ($estimateMinutes -gt 0)) {
                    Write-Host "$($estimateHours)h " -NoNewline -ForegroundColor Green
                    Write-Host "$($estimateMinutes)m" -NoNewline -ForegroundColor Green
                }
                elseif ($estimateHours -gt 0) {
                    Write-Host "$($estimateHours)h" -NoNewline -ForegroundColor Green
                }
                elseif ($estimateMinutes -ge 0) {
                    Write-Host "$($estimateMinutes)m" -NoNewline -ForegroundColor Green
                }
                Write-Host ')' -ForegroundColor DarkGray
            }
        }

        if ($index -gt 0) {
            Write-Host
            Write-Host 'Remaining: ' -NoNewline -ForegroundColor Gray

            $totalEstimateMinutes = 0
            $remainingEstimateMinutes = 0

            $TaskList | Where-Object { $_.DueDate.Date -eq $ListDate.Date } | ForEach-Object {
                $totalEstimateMinutes += $_.EstimateMinutes
                if (!$_.Completed) { $remainingEstimateMinutes += $_.EstimateMinutes }
            }

            $remainingEstimateHours = [Math]::Floor($remainingEstimateMinutes / 60)
            $remainingEstimateMinutes -= $remainingEstimateHours * 60

            if (($remainingEstimateHours -gt 0 -and $remainingEstimateMinutes -gt 0)) {
                Write-Host "$($remainingEstimateHours)h " -NoNewline -ForegroundColor DarkGreen
                Write-Host "$($remainingEstimateMinutes)m" -NoNewline -ForegroundColor DarkGreen
            }
            elseif ($remainingEstimateHours -gt 0) {
                Write-Host "$($remainingEstimateHours)h" -NoNewline -ForegroundColor DarkGreen
            }
            elseif ($remainingEstimateMinutes -ge 0) {
                Write-Host "$($remainingEstimateMinutes)m" -NoNewline -ForegroundColor DarkGreen
            }
            Write-Host ' / ' -NoNewline -ForegroundColor DarkGray

            $totalEstimateHours = [Math]::Floor($totalEstimateMinutes / 60)
            $totalEstimateMinutes -= $totalEstimateHours * 60

            if (($totalEstimateHours -gt 0) -and ($totalEstimateMinutes -gt 0)) {
                Write-Host "$($totalEstimateHours)h $($totalEstimateMinutes)m" -NoNewline -ForegroundColor DarkGray
            }
            elseif ($totalEstimateHours -gt 0) {
                Write-Host "$($totalEstimateHours)h" -NoNewline -ForegroundColor DarkGray
            }
            elseif ($totalEstimateMinutes -ge 0) {
                Write-Host "$($totalEstimateMinutes)m" -NoNewline -ForegroundColor DarkGray
            }
            Write-Host
        }
        else {
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

        if ($UserCommand.Length -gt 0) {
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
                    if (!$task.Completed) {
                        $TaskList.Remove(($TaskList | Where-Object { $_ -eq $task }))
                        Save-WhatToDoTaskList -TaskList $TaskList -FilePath $ScriptConfig.TaskListFile
                    }
                    else {
                        $MessageList.Add('Cannot remove a completed task.')
                    }
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
                $futureDays = 7
                $futureTasks = $TaskList | Where-Object {
                    ($_.DueDate.Date -gt (Get-Date)) -and
                    ($_.DueDate -le (Get-Date).AddDays($futureDays)) -and
                    (!$_.Completed)
                } | Sort-Object -Property DueDate, Priority, CreationDate, Description

                if (($futureTasks | Measure-Object).Count -gt 0) {
                    Write-Host "Upcoming tasks [$(($futureTasks | Measure-Object).Count)]" -ForegroundColor DarkCyan
                    $futureTasks | ForEach-Object {
                        if ((Get-Date $_.DueDate).Date -eq (Get-Date).Date.AddDays(1)) {
                            Write-Host '- ' -NoNewline -ForegroundColor Gray
                            Write-Host "$($_.Description)" -NoNewline
                            Write-Host " (Tomorrow, $((Get-Date $_.DueDate).DayOfWeek.ToString().Substring(0, 3)) $(Get-Date $_.DueDate -Format 'd\/M'))" -ForegroundColor Yellow
                        }
                        else {
                            Write-Host '- ' -NoNewline -ForegroundColor Gray
                            Write-Host "$($_.Description)" -NoNewline
                            Write-Host " ($((Get-Date $_.DueDate).DayOfWeek.ToString().Substring(0, 3)) $(Get-Date $_.DueDate -Format 'd\/M'))" -ForegroundColor DarkYellow
                        }
                    }
                }
                else {
                    Write-Host "No upcoming tasks next $($futureTasks) days." -ForegroundColor DarkGray
                }
                Write-Host
                Read-Host 'Press <Enter> to exit calendar view'
            }
            elseif (($UserCommand -eq 'directory') -or ($UserCommand -eq 'dir')) {
                Invoke-Item (Split-Path -Path $ScriptConfig.TaskListFile -Parent)
            }
            # elseif ($UserCommand -eq 'save') {
            #     Save-WhatToDoTaskList -TaskList $TaskList -FilePath $ScriptConfig.TaskListFile
            # }
            elseif ($UserCommand -eq 'help') {
                Write-Host "### Help ###" -ForegroundColor DarkCyan

                Write-Host "`n# Add a task" -ForegroundColor DarkYellow
                Write-Host 'Syntax: add <priority> <estimate_time> <description>' -ForegroundColor DarkGray
                Write-Host 'add a 15 Test task' -NoNewline
                Write-Host " # Add a task with priority 'A', estimate time of 15 minutes, and description 'Test task'." -ForegroundColor DarkGreen
                Write-Host 'add b 1h Another test task' -NoNewline
                Write-Host " # Add a task with priority 'B', estimate time of 1 hour, and description 'Another test task'." -ForegroundColor DarkGreen
                Write-Host 'add c 2.5h Yet another test task' -NoNewline
                Write-Host " # Add a task with priority 'C', estimate time of 2.5 hours, and description 'Yet another test task'." -ForegroundColor DarkGreen

                Write-Host "`n# Edit a task" -ForegroundColor DarkYellow
                Write-Host 'Syntax: edit <index>' -ForegroundColor DarkGray
                Write-Host 'edit 2' -NoNewline
                Write-Host " # Edit task number 2." -ForegroundColor DarkGreen

                Write-Host "`n# Remove a task" -ForegroundColor DarkYellow
                Write-Host 'Syntax: remove <index>' -ForegroundColor DarkGray
                Write-Host 'remove 1' -NoNewline
                Write-Host " # Remove task number 1." -ForegroundColor DarkGreen

                Write-Host "`n# Complete a task" -ForegroundColor DarkYellow
                Write-Host 'Syntax: done <index>' -ForegroundColor DarkGray
                Write-Host 'done 4' -NoNewline
                Write-Host " # Complete task number 4." -ForegroundColor DarkGreen

                Write-Host "`n# Un-complete a task" -ForegroundColor DarkYellow
                Write-Host 'Syntax: undone <index>' -ForegroundColor DarkGray
                Write-Host 'undone 4' -NoNewline
                Write-Host " # Un-complete task number 4." -ForegroundColor DarkGreen

                Write-Host "`n# Move a task to another day" -ForegroundColor DarkYellow
                Write-Host 'Syntax: move <index> <yyyy-MM-dd>' -ForegroundColor DarkGray
                Write-Host 'Syntax: move <index> <dd>' -ForegroundColor DarkGray
                Write-Host 'Syntax: move <index>' -ForegroundColor DarkGray
                Write-Host 'move 1 2024-01-25' -NoNewline
                Write-Host ' # Move task number 1 to date 2024-01-25.' -ForegroundColor DarkGreen
                Write-Host 'move 5 11' -NoNewline
                Write-Host ' # Move task number 5 to day 11 (of current month).' -ForegroundColor DarkGreen
                Write-Host 'move 3' -NoNewline
                Write-Host ' # Move task number 3 to next workday.' -ForegroundColor DarkGreen

                Write-Host "`n# Load another day's task list" -ForegroundColor DarkYellow
                Write-Host 'Syntax: load <yyyy-MM-dd>' -ForegroundColor DarkGray
                Write-Host 'Syntax: load <dd>' -ForegroundColor DarkGray
                Write-Host 'Syntax: load +<days>' -ForegroundColor DarkGray
                Write-Host 'Syntax: load -<days>' -ForegroundColor DarkGray
                Write-Host 'Syntax: load' -ForegroundColor DarkGray
                Write-Host 'load 2024-01-25' -NoNewline
                Write-Host ' # Load task list for date 2024-01-25.' -ForegroundColor DarkGreen
                Write-Host 'load 17' -NoNewline
                Write-Host ' # Load task list for day 17 (of current month).' -ForegroundColor DarkGreen
                Write-Host 'load +1' -NoNewline
                Write-Host " # Load next day's task list (relative to currently loaded task list)." -ForegroundColor DarkGreen
                Write-Host 'load -3' -NoNewline
                Write-Host ' # Load task list from 3 days ago (relative to currently loaded task list).' -ForegroundColor DarkGreen
                Write-Host 'load' -NoNewline
                Write-Host " # Load today's task list." -ForegroundColor DarkGreen

                Write-Host "`n# View upcoming tasks" -ForegroundColor DarkYellow
                Write-Host 'calendar'
                Write-Host 'cal'

                Write-Host "`n# Open the directory that contains the configuration file" -ForegroundColor DarkYellow
                Write-Host 'directory'
                Write-Host 'dir'

                Write-Host "`n# Exit WhatToDo" -ForegroundColor DarkYellow
                Write-Host 'exit'

                Read-Host "`nPress <Enter> to exit help view"
            }
            elseif ($UserCommand -eq 'exit') {
                $ExitScript = $true
            }
            else {
                $MessageList.Add("Invalid command: '$($UserCommand)'")
                $MessageList.Add("Type help to show available commands.")
            }
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

    RecurringTasks = @(
        <#@{
            DueDate = @{
                Month = 1, 4, 10
                Day = 8, 19, 25
                Weekday = 'Monday', 'Friday'
                FirstWeekdayOfMonth = 'Tuesday'
                SecondWeekdayOfMonth = 'Wednesday', 'Friday'
                ThirdWeekdayOfMonth = 'Thursday'
                FourthWeekdayOfMonth = 'Monday'
            }

            Task = @{
                Priority = 'A'
                EstimateMinutes = 30
                Description = 'Test task'
            }
        }#>
    )
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
        [System.Collections.ArrayList]$TaskList,
        [Parameter(Mandatory)]
        $RecurringTasksConfig
    )

    $tempTaskList = New-Object -TypeName 'System.Collections.ArrayList'

    foreach ($task in $RecurringTasksConfig) {
        $configuredDueDateSettings = 0
        $matchingDueDateSettings = 0

        if (($task.DueDate.Month | Measure-Object).Count -gt 0) {
            $configuredDueDateSettings++
            if ((Get-Date).Month -in $task.DueDate.Month) {
                $matchingDueDateSettings++
            }
        }

        if (($task.DueDate.Day | Measure-Object).Count -gt 0) {
            $configuredDueDateSettings++
            if ((Get-Date).Day -in $task.DueDate.Day) {
                $matchingDueDateSettings++
            }
        }

        if (($task.DueDate.Weekday | Measure-Object).Count -gt 0) {
            $configuredDueDateSettings++
            if ((Get-Date).DayOfWeek -in $task.DueDate.Weekday) {
                $matchingDueDateSettings++
            }
        }

        if ($task.DueDate.FirstWeekdayOfMonth) {
            $configuredDueDateSettings++
            if (((Get-Date).Day -le 7) -and
                ((Get-Date).DayOfWeek -in $task.DueDate.FirstWeekdayOfMonth)) {
                $matchingDueDateSettings++
            }
        }

        if ($task.DueDate.SecondWeekdayOfMonth) {
            $configuredDueDateSettings++
            if (((Get-Date).Day -gt 7) -and
                ((Get-Date).Day -le 14) -and
                ((Get-Date).DayOfWeek -in $task.DueDate.SecondWeekdayOfMonth)) {
                $matchingDueDateSettings++
            }
        }

        if ($task.DueDate.ThirdWeekdayOfMonth) {
            $configuredDueDateSettings++
            if (((Get-Date).Day -gt 14) -and
                ((Get-Date).Day -le 21) -and
                ((Get-Date).DayOfWeek -in $task.DueDate.ThirdWeekdayOfMonth)) {
                $matchingDueDateSettings++
            }
        }

        if ($task.DueDate.FourthWeekdayOfMonth) {
            $configuredDueDateSettings++
            if (((Get-Date).Day -gt 21) -and
                ((Get-Date).DayOfWeek -in $task.DueDate.LastWeekdayOfMonth)) {
                $matchingDueDateSettings++
            }
        }

        # Write-Host "Configured due-date settings: $($configuredDueDateSettings)"
        # Write-Host "Matching due-date settings: $($matchingDueDateSettings)"

        if (($configuredDueDateSettings -gt 0) -and ($matchingDueDateSettings -eq $configuredDueDateSettings)) {
            if (($TaskList | Where-Object { ($_.Description -ceq $task.Task.Description) -and ((Get-Date $_.DueDate).Date -eq (Get-Date).Date) } | Measure-Object).Count -eq 0) {
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
                    Write-Error "Failed to add recurring task. $($Error[0])"
                    Read-Host 'Press <Enter> to continue'
                }
            }
        }
    }

    # Read-Host 'DEBUG'
    return $tempTaskList
}
