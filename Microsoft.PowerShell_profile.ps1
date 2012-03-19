#Requires -Version 2.0

# Add custom type and format data
split-path $MyInvocation.MyCommand.Path | foreach-object {
    $_ | join-path -child My.types.ps1xml -resolve -ea SilentlyContinue | update-typedata
    $_ | join-path -child My.formats.ps1xml -resolve -ea SilentlyContinue | update-formatdata
}

# Change the defualt prompt.
function prompt
{
    # Beep K ("over") when a command finishes after the current $BeepPreference.
    if ($BeepPreference -gt 0 -and ($h = get-history -count 1) -and $h.ExecutionTime -gt $BeepPreference) {
        $BeepTimer.Start()
    }

    # Prompt
    $(if (test-path variable:/PSDebugContext) { '[DBG]: ' } else { '' }) `
        + 'PS ' + '+' * $ExecutionContext.SessionState.Path.LocationStack($null).Count + $(Get-Location) + "`n" `
        + '>' * $nestedpromptlevel + '> '
}

# Do not beep in the prompt by default.
[timespan] $BeepPreference = 0

# Set up the BeepTimer for async beeps in prompt.
new-object System.Timers.Timer -property @{AutoReset = $false; Interval = 1} `
    | new-variable -name 'BeepTimer' -option Constant -visibility Private
$null = register-objectevent -input $BeepTimer -event 'Elapsed' -supportevent -action {
    300, 100, 300 | foreach { [Console]::Beep(800, $_); sleep -m 100 }
}

# Increase history count.
$MaximumHistoryCount = 100

# Pauses until user input
function Read-Prompt
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
            $ch = read-prompt -fore 'Yellow' '<SPACE> next page; <CR> next line; [Q] quit' {
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

    $ch = read-prompt -fore 'Yellow' '[Y] send; [N] continue; [Q] quit' {
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

# vim: set et sts=4 sw=4 ts=8:
