#Requires -Version 2.0

function ConvertTo-Hex {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline=$true)]
        [byte[]] $Bytes,

        [Parameter(Position=0)]
        [string] $Delimiter = ', ',

        [Parameter()]
        [switch] $NoBrackets
    )

    begin {
        $delim = ''
        $out = new-object System.Text.StringBuilder

        if (!$NoBrackets) {
            $null = $out.Append('{')
            if ($Delimiter.IndexOf(' ') -ge 0) {
                $null = $out.Append(' ');
            }
        }
    }

    process {
        foreach ($b in $Bytes) {
            $null = $out.Append($delim).AppendFormat('0x{0:x2}', $b)
            $delim = $Delimiter
        }
    }

    end {
        if (!$NoBrackets) {
            if ($Delimiter.IndexOf(' ') -ge 0) {
                $null = $out.Append(' ');
            }
            $null = $out.Append('}')
        }

        $out.ToString()
    }
}

function Get-Cultures
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0)]
        [System.Globalization.CultureTypes] $Type = 'AllCultures'
    )

    [System.Globalization.CultureInfo]::GetCultures($Type) `
        | script:add-type 'System.Globalization.CultureInfo#Developer'
}

if ($PSVersionTable.PSVersion -lt '4.0')
{
# Version-compatible copy for dowwnlevel platforms
function Get-FileHash
{
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(ParameterSetName = 'Path', Mandatory = $true, Position = 0)]
        [Parameter(ParameterSetName = 'Stream')]
        [string[]] $Path,

        [Parameter(ParameterSetName = 'LiteralPath', Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('PSPath')]
        [string[]] $LiteralPath,

        [Parameter(ParameterSetName = 'Stream', Mandatory = $true)]
        [System.IO.Stream] $InputStream,

        [ValidateSet('SHA1', 'SHA256', 'SHA384', 'SHA512', 'MACTripleDES', 'MD5', 'RIPEMD160')]
        [string] $Algorithm = 'SHA256'
    )

    begin
    {
        [System.Security.Cryptography.HashAlgorithm] $hasher = $null
    }

    process
    {
        if ($PSCmdlet.ParameterSetName -eq 'Stream')
        {
            if (!$hasher)
            {
                $hasher = [System.Security.Cryptography.HashAlgorithm]::Create($Algorithm)
            }

            $buffer = $hasher.ComputeHash($InputStream)
            $hash = [BitConverter]::ToString($buffer) -replace '-', ''

            $returnObj = new-object PSCustomObject -property @{
                Algorithm = $Algorithm;
                Hash = $hash.ToUpperInvariant();
                Path = if ($Path) { $Path } else { $null };
            }

            # Use the same type name as PowerShell v4 and newer
            $returnObj.PSObject.TypeNames.Insert(0, "Microsoft.Powershell.Utility.FileHash")

            $returnObj
        }
        else
        {
            $providerPaths = @()
            if ($PSCmdlet.ParameterSetName -eq "LiteralPath")
            {
                $providerPaths += resolve-path -literalPath $LiteralPath | select-object -expand ProviderPath
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'Path')
            {
                $providerPaths += resolve-path -path $Path | select-object -expand ProviderPath
            }

            foreach ($providerPath in $providerPaths)
            {
                if (test-path -literalPath $providerPath -pathType Container)
                {
                    continue
                }

                try
                {
                    $InputStream = [System.IO.File]::OpenRead($providerPath)
                    get-filehash -inputStream $InputStream -path $providerPath -algorithm $Algorithm
                }
                catch [Exception]
                {
                    $message = "The file '{0}' cannot be read: {1}" -f $providerPath, $_
                    write-error -message $message -category ReadError -errorId 'FileReadError' -targetObject $providerPath
                    return
                }
                finally
                {
                    if ($InputStream)
                    {
                        $InputStream.Close()
                    }
                }
            }
        }
    }
}
}

function Join-Object
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        [string] $KeyName,

        [Parameter(Position=1)]
        [string] $PropertyName = "Property",

        [Parameter(Position=2)]
        [string] $ValueName = "Value",

        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        $InputObject
    )

    begin
    {
        $OutputObject = @{$KeyName = $null}
    }

    process
    {
        if ($InputObject.$KeyName -ne $OutputObject.$KeyName)
        {
            if ($OutputObject.$KeyName)
            {
                New-Object PSObject -Property $OutputObject
            }

            $OutputObject = @{$KeyName = $_.$KeyName; $_.$PropertyName = $_.$ValueName}
        }
        else
        {
            $OutputObject[$_.$PropertyName] = $_.$ValueName
        }
    }

    end
    {
        if ($OutputObject.$KeyName)
        {
            New-Object PSObject -Property $OutputObject
        }
    }
}

function Measure-Group
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string[]] $Group,

        [Parameter(Mandatory=$true, Position=1)]
        [string] $Property,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        $InputObject,

        [Parameter()]
        [switch] $Average,

        [Parameter()]
        [switch] $Count,

        [Parameter()]
        [switch] $Maximum,

        [Parameter()]
        [switch] $Minimum,

        [Parameter()]
        [switch] $Sum
    )

    begin
    {
        $Objects = @()
    }

    process
    {
        $Objects += $InputObject
    }

    end
    {
        [hashtable[]] $ExpandedProperties = foreach ($p in $Group) { @{l=$p; e={$_.Group[0].$p}.GetNewClosure()} }
        if ( $Average ) { $ExpandedProperties += @{l="Average"; e={$_.Pivot.Average}} }
        if ( $Count ) { $ExpandedProperties += @{l="Count"; e={$_.Pivot.Count}} }
        if ( $Maximum ) { $ExpandedProperties += @{l="Maximum"; e={$_.Pivot.Maximum}} }
        if ( $Minimum ) { $ExpandedProperties += @{l="Minimum"; e={$_.Pivot.Minimum}} }
        if ( $Sum ) { $ExpandedProperties += @{l="Sum"; e={$_.Pivot.Sum}} }

        $Objects | group-object $Group | select-object *, @{l="Pivot"; e={
            $_.Group | measure-object $Property -Average:$Average -Maximum:$Maximum -Minimum:$Minimum -Sum:$Sum
        }} | select-object $ExpandedProperties
    }
}

function Select-RegexGroups
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [Microsoft.PowerShell.Commands.MatchInfo[]] $Match
    )

    begin
    {
        $Cache = @{}
    }

    process
    {
        foreach ($m in $Match)
        {
            if (-not $Cache.Contains($m.Pattern))
            {
                $re = new-object System.Text.RegularExpressions.Regex $m.Pattern
                $indexes = $re.GetGroupNumbers()
                $names = $re.GetGroupNames() | where-object { $indexes -notcontains $_ }

                $Cache.Add($m.Pattern, $names)
            }
            else
            {
                $names = $Cache[$m.Pattern]
            }

            if ($names)
            {
                foreach ($sub in $m.Matches)
                {
                    $groups = @{}
                    foreach ($name in $names)
                    {
                        $groups.$name = $sub.Groups[$name].Value
                    }

                    new-object PSObject -property $groups
                }
            }
        }
    }
}

function Select-Unique
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string[]] $Property,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        $InputObject,

        [Parameter()]
        [switch] $AsHashtable,

        [Parameter()]
        [switch] $NoElement
    )

    begin
    {
        $Keys = @{}
    }

    process
    {
        $InputObject | foreach-object {

            $o = $_
            $k = $Property | foreach-object -begin {
                    $s = ''
                } -process {
                    # Delimit multiple properties like group-object does.
                    if ( $s.Length -gt 0 )
                    {
                        $s += ', '
                    }

                    $s += $o.$_ -as [string]
                } -end {
                    $s
                }

            if ( -not $Keys.ContainsKey($k) )
            {
                $Keys.Add($k, $null)
                if ( -not $AsHashtable )
                {
                    $o
                }
                elseif ( -not $NoElement )
                {
                    $Keys[$k] = $o
                }
            }
        }
    }

    end
    {
        if ( $AsHashtable )
        {
            $Keys
        }
    }
}

function Test-Elevated
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [switch] $Impersonating
    )

    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent($Impersonating)
    if (!$id)
    {
        return $false
    }

    $p = new-object System.Security.Principal.WindowsPrincipal $id
    $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Page output one screen at a time
filter page ( [int] $lines = $($Host.UI.RawUI.WindowSize.Height - 1) )
{
    begin
    {
        [int] $i = 0
        $message = '<SPACE> next page; <CR> next line; [Q] quit'

        if ($Host.UI.SupportsVirtualTerminal) {
            $message = "`e[93m$message`e[0m"
            $Host.UI.Write("`e[?1049h")
        }
    }
    process
    {
        $_
        if ( ++$i -eq $lines )
        {
            $ch = script:write-prompt -fore 'Yellow' $message {
                process { 13,32 -contains $_.VirtualKeyCode -or $_.Character -ieq 'q' }
            }
            switch ( $ch )
            {
                # Display the next line
                { $ch.VirtualKeyCode -eq 13 } { --$i; break }

                # Display the next page
                { $ch.VirtualKeyCode -eq 32 } { $i = 0; break }

                # Quit
                { $ch.Character -ieq 'q' }
                {
                    if ($Host.UI.SupportsVirtualTerminal) {
                        $Host.UI.WriteLine("`e[?1049l")
                    }

                    #throw (new-object System.Management.Automation.HaltCommandException)
                    return
                }
            }
        }
    }
    end
    {
        $message = '[Q] quit'
        if ($Host.UI.SupportsVirtualTerminal) {
            $message = "`e[93m$message`e[0m"
        }

        $null = script:write-prompt -fore 'Yellow' $message {
            process { $_.Character -ieq 'q' }
        }

        if ($Host.UI.SupportsVirtualTerminal) {
            $Host.UI.WriteLine("`e[?1049l")
        }
    }
}

# Select which objects to send through the pipeline
filter pick
{
    # Display the object in the host using its default formatting
    $_ | out-default

    $ch = script:write-prompt -fore 'Yellow' '[Y] send; [N] continue; [Q] quit' {
        process { 'y','n','q' -icontains $_.Character }
    }
    if ( $ch.Character -ieq 'y' ) { $_ }
    elseif ( $ch.Character -ieq 'q' ) { break }
}

# Sleep between objects in the pipeline
filter slow ( [int] $tempo = 100 )
{
    $_
    start-sleep -milliseconds $tempo
}

function which
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string[]] $Name
    )

    Get-Command -Type Application, ExternalScript, Script @PSBoundParameters
}


# Private functions

function write-prompt
{

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $message,

        [Parameter(Mandatory = $true, Position = 1)]
        [scriptblock] $filter,

        [Parameter()]
        [consolecolor] $ForegroundColor = $Host.UI.RawUI.ForegroundColor,

        [Parameter()]
        [consolecolor] $BackgroundColor = $Host.UI.RawUI.BackgroundColor
    )

    # Skip if not running in the console host.
    if ( -not $Host.UI.RawUI.ReadKey ) { return }

    # Store the cursor position before displaying the prompt
    $current = $Host.UI.RawUI.CursorPosition
    $Host.UI.Write($ForegroundColor, $BackgroundColor, $message)

    try
    {
        while ( $true )
        {
            $ch = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            if ( $ch | &$filter ) { return $ch }
        }
    }
    finally
    {
        # Clear the current line(s) and reset the cursor position
        $space = new-object System.Management.Automation.Host.BufferCell
        $space.Character = ' '
        $space.ForegroundColor = $Host.UI.RawUI.ForegroundColor
        $space.BackgroundColor = $Host.UI.RawUI.BackgroundColor

        $line = new-object System.Management.Automation.Host.Rectangle
        $line.Top = $current.Y;
        $line.Bottom = $Host.UI.RawUI.CursorPosition.Y
        $line.Left = $current.X;
        $line.Right = $Host.UI.RawUI.BufferSize.Width

        $Host.UI.RawUI.SetBufferContents($line, $space)
        $Host.UI.RawUI.CursorPosition = $current
    }
}

function add-type
{

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string[]] $Type,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $InputObject
    )

    process
    {
        $InputObject | foreach-object {
            for ( $i = 0; $i -lt $Type.length; ++$i ) {
                $_.PSTypeNames.Insert($i, $Type[$i])
            }

            $_
        }
    }
}
