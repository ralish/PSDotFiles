@{
    IncludeRules = @('*')

    ExcludeRules = @(
        'PSUseSingularNouns'
    )

    Rules = @{
        # The statement assignment alignment check applies to the hashtable
        # assignment itself and not just its properties.
        PSAlignAssignmentStatement = @{
            Enable          = $false
            CheckHashtables = $true
        }

        PSPlaceCloseBrace = @{
            Enable             = $true
            IgnoreOneLineBlock = $true
            NewLineAfter       = $false
            NoEmptyLineBefore  = $false
        }

        PSPlaceOpenBrace = @{
            Enable             = $true
            IgnoreOneLineBlock = $true
            NewLineAfter       = $true
            OnSameLine         = $true
        }

        PSProvideCommentHelp = @{
            Enable    = $true
            Placement = 'begin'
        }

        PSUseConsistentIndentation = @{
            Enable          = $true
            IndentationSize = 4
            Kind            = 'space'
        }

        # CheckOperator doesn't work with aligned hashtable assignment
        # statements (GitHub Issue #769).
        PSUseConsistentWhitespace = @{
            Enable         = $true
            CheckOpenBrace = $true
            CheckOpenParen = $true
            CheckOperator  = $false
            CheckSeparator = $true
        }
    }
}