$script:CommonParameters = @(
    'Debug'
    'ErrorAction'
    'ErrorVariable'
    'OutBuffer'
    'OutVariable'
    'PipelineVariable'
    'Verbose'
    'WarningAction'
    'WarningVariable'
 )

$script:Resources = data {
    convertfrom-stringdata @'
        Elevate = Start PowerShell as an elevated process.
        ValueSet = Setting ({0}) {1} : {2} to {3}
        ValueDel = Deleting ({0}) {1} : {2}
'@
}

function Enable-FusionLog
{
    [CmdletBinding(DefaultParameterSetName='All')]
    param
    (
        [Parameter(ParameterSetName='All')]
        [switch] $All = $true,

        [Parameter(ParameterSetName='Specific')]
        [switch] $ForceLog,

        [Parameter(ParameterSetName='Specific')]
        [switch] $LogFailures,

        [Parameter(ParameterSetName='Specific')]
        [switch] $LogResourceBinds,

        [Alias("Path")]
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string] $LogPath
    )

    if ($PSCmdlet.ParameterSetName -eq 'All')
    {
        $ForceLog = $All
        $LogFailures = $All
        $LogResourceBinds = $All

        $null = $PSBoundParameters.Remove('All')
        $PSBoundParameters['ForceLog'] = $ForceLog
        $PSBoundParameters['LogFailures'] = $LogFailures
        $PSBoundParameters['LogResourceBinds'] = $LogResourceBinds
    }

    $views = @(,[Microsoft.Win32.RegistryView]::Registry32)
    if ([Environment]::Is64BitOperatingSystem)
    {
        $views += [Microsoft.Win32.RegistryView]::Registry64
    }

    foreach ($view in $views)
    {
        $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', $view)
        try
        {
            $key = $base.CreateSubKey('SOFTWARE\Microsoft\Fusion', 'ReadWriteSubTree')
            try
            {
                foreach ($param in $PSBoundParameters.GetEnumerator())
                {
                    if ($script:CommonParameters -notcontains $param.Key)
                    {
                        $value = $param.Value
                        if ($value -is [bool] -or $value -is [switch])
                        {
                            $value = if ($value) { 1 } else { 0 }
                        }

                        if ($value -eq '' -or $value -eq 0)
                        {
                            write-verbose ($Resources.ValueDel -f $key.View, $key.Name, $param.Key)
                            $key.DeleteValue($param.Key, $false)
                        }
                        else
                        {
                            write-verbose ($Resources.ValueSet -f $key.View, $key.Name, $param.Key, $value)
                            $key.SetValue($param.Key, $value)
                        }
                    }
                }
            }
            finally
            {
                $key.Dispose()
            }
        }
        catch [System.UnauthorizedAccessException]
        {
            write-error $_.Exception.Message -category 'PermissionDenied' -recommend $Resources.Elevate
            break
        }
        catch
        {
            $PSCmdlet.ThrowTerminatingError($_)
            break
        }
        finally
        {
            $base.Dispose()
        }
    }
}

function Disable-FusionLog
{
    [CmdletBinding(DefaultParameterSetName='All')]
    param
    (
        [Parameter(ParameterSetName='All')]
        [switch] $All = $true,

        [Parameter(ParameterSetName='Specific')]
        [switch] $ForceLog,

        [Parameter(ParameterSetName='Specific')]
        [switch] $LogFailures,

        [Parameter(ParameterSetName='Specific')]
        [switch] $LogResourceBinds
    )

    if ($PSCmdlet.ParameterSetName -eq 'All')
    {
        $ForceLog = $All
        $LogFailures = $All
        $LogResourceBinds = $All

        $null = $PSBoundParameters.Remove('All')
        $PSBoundParameters['ForceLog'] = $ForceLog
        $PSBoundParameters['LogFailures'] = $LogFailures
        $PSBoundParameters['LogResourceBinds'] = $LogResourceBinds
    }

    $params = @{}

    # Negate the switch value to pass to Enable-FusionLog
    foreach ($param in $PSBoundParameters.GetEnumerator())
    {
        if ($script:CommonParameters -notcontains $param.Key)
        {
            $value = $param.Value
            if ($value -is [bool] -or $value -is [switch])
            {
                $value = !$value
            }

            $params[$param.Key] = $value
        }
    }

    foreach ($param in $params.GetEnumerator())
    {
        $PSBoundParameters[$param.Key] = $param.Value
    }

    Enable-FusionLog @PSBoundParameters
}
