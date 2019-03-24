@{
    IncludeRules = @('*')

    ExcludeRules = @(
        'PSUseSingularNouns'
    )

    Rules = @{
        # The statement assignment alignment check applies to the hashtable
        # assignment itself and not just its properties.
        PSAlignAssignmentStatement = @{
            Enable                      = $false
            CheckHashtable              = $true
        }

        PSPlaceCloseBrace = @{
            Enable                      = $true
            IgnoreOneLineBlock          = $true
            NewLineAfter                = $false
            NoEmptyLineBefore           = $false
        }

        PSPlaceOpenBrace = @{
            Enable                      = $true
            IgnoreOneLineBlock          = $true
            NewLineAfter                = $true
            OnSameLine                  = $true
        }

        PSProvideCommentHelp = @{
            Enable                      = $true
            BlockComment                = $true
            ExportedOnly                = $true
            Placement                   = 'begin'
            VSCodeSnippetCorrection     = $false
        }

        PSUseConsistentIndentation = @{
            Enable                      = $true
            IndentationSize             = 4
            Kind                        = 'space'
            PipelineIndentation         = 'IncreaseIndentationForFirstPipeline'
        }

        # CheckOperator doesn't work with aligned hashtable assignment
        # statements (GitHub Issue #769).
        PSUseConsistentWhitespace = @{
            Enable                      = $true
            CheckInnerBrace             = $true
            CheckOpenBrace              = $true
            CheckOpenParen              = $true
            CheckOperator               = $false
            CheckPipe                   = $true
            CheckSeparator              = $true
        }
    }
}
