# WhatToDo
PowerShell to-do list module.

----

### Get started ###
1. Create a new directory that will store the configuration and task files.
2. Run "Initialize-WhatToDo" and enter the path to the newly created directory.
3. Run "Start-WhatToDo" and enter the path to the configuration file that was created in the WhatToDo directory.
4. Enjoy productivity!

```powershell
Import-Module -Name WhatToDo
```

```powershell
Initialize-WhatToDo -DirectoryPath 'path\to\whattodo\directory'
```

```powershell
Start-WhatToDo -ConfigurationPath 'path\to\whattodo\directory\WhatToDo-Config.psd1'
```

----

### Set default parameter value to auto-include configuration file for Start-WhatToDo ###
1. Edit your PS profile.
2. Add the default parameter value anywhere in your PS profile.

```powershell
code $profile
```

```powershell
$PSDefaultParameterValues['Start-WhatToDo:ConfigurationPath'] = 'path\to\whattodo\directory\WhatToDo-Config.psd1'
```

Now you can run "Start-WhatToDo" without including a value for the ConfigurationPath parameter.
```powershell
Start-WhatToDo
```
