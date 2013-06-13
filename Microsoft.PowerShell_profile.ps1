#Requires -Version 2.0

# Add custom type and format data
split-path $MyInvocation.MyCommand.Path | foreach-object {
    if (($path = join-path $_ My.types.ps1xml) -and (test-path $path)) { $path | update-typedata }
    if (($path = join-path $_ My.format.ps1xml) -and (test-path $path)) { $path | update-formatdata }
}

# Change the defualt prompt.
function prompt
{
    # Beep K ("over") when a command finishes after the current $BeepPreference.
    if ($BeepPreference -gt 0 -and ($h = get-history -count 1) -and $h.ExecutionTime -gt $BeepPreference) {
        $da817f7daa4f4b8db65c7e8add620143_bt.Start()
    }

    # Show if debugging in the prompt.
    if ($PSDebugContext) {
        &$da817f7daa4f4b8db65c7e8add620143_wp 'DBG' 'Red'
    }

    # Show current location in the prompt.
    write-host $('PS ' + $PWD)

    # Show current repo branch in the prompt.
    if ($repo = &$da817f7daa4f4b8db65c7e8add620143_gb -and $repo.Branch) {
        &$da817f7daa4f4b8db65c7e8add620143_wp $repo.Branch 'Cyan'
    }

    # Show the nesting and default separators in the prompt.
    '+' * $ExecutionContext.SessionState.Path.LocationStack($null).Count + '>' * $NestedPromptLevel + '> '
}

# Do not beep in the prompt by default.
[timespan] $BeepPreference = 0

# Set up the BeepTimer for async beeps in prompt.
new-object System.Timers.Timer -property @{AutoReset = $false; Interval = 1} `
    | new-variable da817f7daa4f4b8db65c7e8add620143_bt -option Constant -visibility Private
$null = register-objectevent $da817f7daa4f4b8db65c7e8add620143_bt -event Elapsed -supportevent -action {
    300, 100, 300 | foreach { [Console]::Beep(800, $_); start-sleep -m 100 }
}

# Increase history count.
$MaximumHistoryCount = 100

function Get-Cultures
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0)]
        [System.Globalization.CultureTypes] $Type = 'AllCultures'
    )

    [System.Globalization.CultureInfo]::GetCultures($Type) `
        | &$da817f7daa4f4b8db65c7e8add620143_at 'System.Globalization.CultureInfo#Developer'
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

        $Objects | group-object $Group | select-object *, @{l="Pivot"; e={$_.Group | measure-object $Property -Average:$Average -Maximum:$Maximum -Minimum:$Minimum -Sum:$Sum}} | select-object $ExpandedProperties
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

# Page output one screen at a time
filter page ( [int] $lines = $($Host.UI.RawUI.WindowSize.Height - 1) )
{
    begin { [int] $i = 0 }
    process
    {
        $_
        if ( ++$i -eq $lines )
        {
            $ch = &$da817f7daa4f4b8db65c7e8add620143_rp -fore 'Yellow' '<SPACE> next page; <CR> next line; [Q] quit' {
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
                    throw (new-object System.Management.Automation.HaltCommandException)
                }
            }
        }
    }
}

# Select which objects to send through the pipeline
filter pick
{
    # Display the object in the host using its default formatting
    $_ | out-default

    $ch = &$da817f7daa4f4b8db65c7e8add620143_rp -fore 'Yellow' '[Y] send; [N] continue; [Q] quit' {
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

# Private functions

new-variable da817f7daa4f4b8db65c7e8add620143_rp -option Constant -visibility Private -scope Private -value {

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
    write-host $message -nonewline -background $BackgroundColor -foreground $ForegroundColor

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

new-variable da817f7daa4f4b8db65c7e8add620143_wp -option Constant -visibility Private -scope Private -value {

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        $Token,

        [Parameter(Mandatory=$true, Position=1)]
        [ConsoleColor] $Foreground
    )

    write-host '[' -foreground 'Yellow' -nonewline
    write-host $Token -foreground $Foreground -nonewline
    write-host '] ' -foreground 'Yellow' -nonewline
}

new-variable da817f7daa4f4b8db65c7e8add620143_gb -option Constant -visibility Private -value {

    if ($dir = &$da817f7daa4f4b8db65c7e8add620143_gr) {

        $repo = new-object PSObject -property @{ 'Branch' = $null; 'SCM' = $dir.SCM }

        switch ($dir.SCM) {
            'Git' {
                $branch = if (($path = join-path $dir 'HEAD') -and (test-path $path)) {
                    resolve-path $path | get-content
                }

                if ($branch -match 'ref: refs/heads/(?<b>\w+)') {
                    $branch = $Matches['b']

                } elseif ($branch.length -ge 7) {
                    $branch = 'hash: ' + $branch.Substring(0, 7)

                }

                $repo.Branch = $branch
            }

            'Hg' {
                $branch = if (($path = join-path $dir 'branch') -and (test-path $path)) {
                    resolve-path $path | get-content
                }

                $repo.Branch = $branch
            }
        }

        $repo
    }
}

new-variable da817f7daa4f4b8db65c7e8add620143_gr -option Constant -visibility Private -value {

    if ((test-path env:GIT_DIR) -and (test-path $env:GIT_DIR -pathtype 'Container')) {
        return (resolve-path $env:GIT_DIR | add-member -type NoteProperty -name 'SCM' -value 'Git' -passthru)
    }

    $dir = resolve-path .

    while ($dir) {
        if (($gd = join-path $dir '.git') -and (test-path $gd -pathtype 'Container')) {
            # check if git repository
            return (resolve-path $gd | add-member -type NoteProperty -name 'SCM' -value 'Git' -passthru)

        } elseif (test-path $gd -pathtype 'Leaf') {
            # check if git submodule
            if ((resolve-path $gd | get-content) -match 'gitdir: (?<d>.+)') {
                if (($gd = join-path $dir $Matches['d']) -and (test-path $gd -pathtype 'Container')) {
                    return (resolve-path $gd | add-member -type NoteProperty -name 'SCM' -value 'Git' -passthru)
                }
            }

        } elseif (($gd = join-path $dir '.hg') -and (test-path $gd)) {
            # check if hg repository
            return (resolve-path $gd | add-member -type NoteProperty -name 'SCM' -value 'Hg' -passthru)
        }

        $dir = if (($parent = split-path $dir -parent) -and (test-path $parent)) {
            resolve-path $parent
        }
    }
}

new-variable da817f7daa4f4b8db65c7e8add620143_at -option Constant -visibility Private -value {

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
# vim: set et sts=4 sw=4 ts=8:
