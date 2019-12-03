@{
GUID = '1a790611-20ec-4c91-9580-8189c6892bdf'
Author = 'Heath Stewart'
Description = 'Extensions to $profile'
ModuleVersion = '1.0'
PowerShellVersion = '2.0'
ModuleToProcess = 'My.psm1'
TypesToProcess = 'My.types.ps1xml'
FormatsToProcess = 'My.format.ps1xml'
FunctionsToExport = @(
    'Get-Cultures'
    'Get-FileHash'
    'Join-Object'
    'Measure-Group'
    'Select-RegexGroups'
    'Select-Unique'
    'Test-Elevated'
    'page'
    'pick'
    'slow'
)
}
