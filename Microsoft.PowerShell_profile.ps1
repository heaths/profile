#Requires -Version 2.0

# Add custom type and format data
split-path $MyInvocation.MyCommand.Path | foreach-object {
    if (($path = join-path $_ My.types.ps1xml) -and (test-path $path)) { $path | update-typedata }
    if (($path = join-path $_ My.format.ps1xml) -and (test-path $path)) { $path | update-formatdata }
}

# Change the defualt prompt.
function global:prompt
{
    # Beep K ("over") when a command finishes after the current $BeepPreference.
    if ($BeepPreference -gt 0 -and ($h = get-history -count 1) -and $h.ExecutionTime -gt $BeepPreference) {
        $Profile_BeepTimer.Start()
    }

    # Show if debugging in the prompt.
    if ($PSDebugContext) {
        &$Profile_WritePrompt 'DBG' 'Red'
    }

    # Show current location in the prompt.
    write-host $('PS ' + $PWD)

    # Show current repo branch in the prompt.
    if ($repo = &$Profile_GetBranch -and $repo.Branch) {
        &$Profile_WritePrompt $repo.Branch 'Cyan'
    }

    # Show the nesting and default separators in the prompt.
    '+' * $ExecutionContext.SessionState.Path.LocationStack($null).Count + '>' * $NestedPromptLevel + '> '
}

# Do not beep in the prompt by default.
[timespan] $BeepPreference = 0

# Set up the BeepTimer for async beeps in prompt.
if (-not (test-path variable:\Profile_BeepTimer)) {
new-object System.Timers.Timer -property @{AutoReset = $false; Interval = 1} `
    | new-variable Profile_BeepTimer -option Constant -visibility Private
$null = register-objectevent $Profile_BeepTimer -event Elapsed -supportevent -action {
    300, 100, 300 | foreach { [Console]::Beep(800, $_); start-sleep -m 100 }
}
}

# Increase history count.
$MaximumHistoryCount = 100

# Private functions

if (-not (test-path variable:\Profile_WritePrompt)) {
new-variable Profile_WritePrompt -option Constant -visibility Private -scope Private -value {

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
}

if (-not (test-path variable:\Profile_GetBranch)) {
new-variable Profile_GetBranch -option Constant -visibility Private -value {

    if ($dir = &$Profile_GetRepo) {

        $repo = new-object PSObject -property @{ 'Branch' = $null; 'SCM' = $dir.SCM }

        switch ($dir.SCM) {
            'Git' {
                $branch = if (($path = join-path $dir 'HEAD') -and (test-path $path)) {
                    resolve-path $path | get-content
                }

                if ($branch -match 'ref: refs/heads/(?<b>[\w_\.\-/]+)') {
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
}

if (-not (test-path variable:\Profile_GetRepo)) {
new-variable Profile_GetRepo -option Constant -visibility Private -value {

    if ((test-path env:GIT_DIR) -and (test-path $env:GIT_DIR -pathtype 'Container')) {
        return (resolve-path $env:GIT_DIR | add-member -type NoteProperty -name 'SCM' -value 'Git' -passthru)
    }

    &$Profile_SearchParent {

        if (($gd = join-path $dir '.git') -and (test-path $gd -pathtype 'Container')) {
            # check if git repository
            return (resolve-path $gd | add-member -type NoteProperty -name 'SCM' -value 'Git' -passthru)

        } elseif (test-path $gd -pathtype 'Leaf') {
            # check if git submodule
            if ((resolve-path $gd | get-content) -match 'gitdir: (?<d>.+)') {
                # join-path simply concatenates both paths so use path.combine if gitdir is absolute
                if (($gd = [io.path]::combine($dir, $Matches['d'])) -and (test-path $gd -pathtype 'Container')) {
                    return (resolve-path $gd | add-member -type NoteProperty -name 'SCM' -value 'Git' -passthru)
                }
            }

        } elseif (($gd = join-path $dir '.hg') -and (test-path $gd)) {
            # check if hg repository
            return (resolve-path $gd | add-member -type NoteProperty -name 'SCM' -value 'Hg' -passthru)
        }
    }
}
}

if (-not (test-path variable:\Profile_SearchParent)) {
new-variable Profile_SearchParent -option Constant -visibility Private -value {

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [scriptblock] $Filter
    )

    $dir = resolve-path .

    while ($dir) {

        # pass the path to the filter script
        if ($out = &$Filter $dir) {
            return $out
        }

        $dir = if (($parent = split-path $dir -parent) -and (test-path $parent)) {
            resolve-path $parent
        }
    }
}
}

# vim: set et sts=4 sw=4 ts=8:
