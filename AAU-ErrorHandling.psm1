Function Resolve-AAUError
{
<#
.SYNOPSIS
    Enumerate error record details.

.DESCRIPTION
    Enumerate an error record, or a collection of error record, properties. By default, the details
    for the last error will be enumerated.

.PARAMETER ErrorRecord
    The error record to resolve. The default error record is the lastest one: $global:Error[0].
    This parameter will also accept an array of error records.

.PARAMETER Property
    The list of properties to display from the error record. Use "*" to display all properties.
    Default list of error properties is: Message, FullyQualifiedErrorId, ScriptStackTrace, PositionMessage, InnerException

    Below is a list of all of the possible available properties on the error record:

    Error Record:               Error Invocation:           Error Exception:                    Error Inner Exception(s):
    $_                          $_.InvocationInfo           $_.Exception                        $_.Exception.InnerException
    -------------               -----------------           ----------------                    ---------------------------
    writeErrorStream            MyCommand                   ErrorRecord                         Data
    PSMessageDetails            BoundParameters             ItemName                            HelpLink
    Exception                   UnboundArguments            SessionStateCategory                HResult
    TargetObject                ScriptLineNumber            StackTrace                          InnerException
    CategoryInfo                OffsetInLine                WasThrownFromThrowStatement         Message
    FullyQualifiedErrorId       HistoryId                   Message                             Source
    ErrorDetails                ScriptName                  Data                                StackTrace
    InvocationInfo              Line                        InnerException                      TargetSite
    ScriptStackTrace            PositionMessage             TargetSite
    PipelineIterationInfo       PSScriptRoot                HelpLink
                                PSCommandPath               Source
                                InvocationName              HResult
                                PipelineLength
                                PipelinePosition
                                ExpectingInput
                                CommandOrigin
                                DisplayScriptPosition

.PARAMETER GetErrorRecord
    Get error record details as represented by $_
    Default is to display details. To skip details, specify -GetErrorRecord:$false

.PARAMETER GetErrorInvocation
    Get error record invocation information as represented by $_.InvocationInfo
    Default is to display details. To skip details, specify -GetErrorInvocation:$false

.PARAMETER GetErrorException
    Get error record exception details as represented by $_.Exception
    Default is to display details. To skip details, specify -GetErrorException:$false

.PARAMETER GetErrorInnerException
    Get error record inner exception details as represented by $_.Exception.InnerException.
    Will retrieve all inner exceptions if there is more then one.
    Default is to display details. To skip details, specify -GetErrorInnerException:$false

.EXAMPLE
    Resolve-Error

    Get the default error details for the last error

.EXAMPLE
    Resolve-Error -ErrorRecord $global:Error[0,1]

    Get the default error details for the last two errors

.EXAMPLE
    Resolve-Error -Property *

    Get all of the error details for the last error

.EXAMPLE
    Resolve-Error -Property InnerException

    Get the "InnerException" for the last error

.EXAMPLE
    Resolve-Error -GetErrorInvocation:$false

    Get the default error details for the last error but exclude the error invocation information

.NOTES
.LINK
#>
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$false, Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullorEmpty()]
        [array]$ErrorRecord,

        [Parameter(Mandatory=$false, Position=1)]
        [ValidateNotNullorEmpty()]
        [string[]]$Property = ('Message','InnerException','FullyQualifiedErrorId','ScriptStackTrace','PositionMessage'),

        [Parameter(Mandatory=$false, Position=2)]
        [switch]$GetErrorRecord = $true,

        [Parameter(Mandatory=$false, Position=3)]
        [switch]$GetErrorInvocation = $true,

        [Parameter(Mandatory=$false, Position=4)]
        [switch]$GetErrorException = $true,

        [Parameter(Mandatory=$false, Position=5)]
        [switch]$GetErrorInnerException = $true
    )

    Begin
    {
        ## If function was called without specifying an error record, then choose the latest error that occured
        If (-not $ErrorRecord)
        {
            If ($global:Error.Count -eq 0)
            {
                # The `$Error collection is empty
                Return
            }
            Else
            {
                [array]$ErrorRecord = $global:Error[0]
            }
        }

        ## Define script block for selecting and filtering the properties on the error object
        [scriptblock]$SelectProperty = {
            Param
            (
                [Parameter(Mandatory=$true)]
                [ValidateNotNullorEmpty()]
                $InputObject,

                [Parameter(Mandatory=$true)]
                [ValidateNotNullorEmpty()]
                [string[]]$Property
            )
            [string[]]$ObjectProperty = $InputObject | Get-Member -MemberType *Property | Select-Object -ExpandProperty Name
            ForEach ($Prop in $Property)
            {
                If ($Prop -eq '*')
                {
                    [string[]]$PropertySelection = $ObjectProperty
                    Break
                }
                ElseIf ($ObjectProperty -contains $Prop)
                {
                    [string[]]$PropertySelection += $Prop
                }
            }
            Write-Output $PropertySelection
        }

        # Initialize variables to avoid error if 'Set-StrictMode' is set
        $LogErrorRecordMsg      = $null
        $LogErrorInvocationMsg  = $null
        $LogErrorExceptionMsg   = $null
        $LogErrorMessageTmp     = $null
        $LogInnerMessage        = $null
    }
    Process
    {
        ForEach ($ErrRecord in $ErrorRecord)
        {
            ## Capture Error Record
            If ($GetErrorRecord)
            {
                [string[]]$SelectedProperties = &$SelectProperty -InputObject $ErrRecord -Property $Property
                $LogErrorRecordMsg = $ErrRecord | Select-Object -Property $SelectedProperties
            }

            ## Error Invocation Information
            If ($GetErrorInvocation)
            {
                If ($ErrRecord.InvocationInfo)
                {
                    [string[]]$SelectedProperties = &$SelectProperty -InputObject $ErrRecord.InvocationInfo -Property $Property
                    $LogErrorInvocationMsg = $ErrRecord.InvocationInfo | Select-Object -Property $SelectedProperties
                }
            }

            ## Capture Error Exception
            If ($GetErrorException)
            {
                If ($ErrRecord.Exception)
                {
                    [string[]]$SelectedProperties = &$SelectProperty -InputObject $ErrRecord.Exception -Property $Property
                    $LogErrorExceptionMsg = $ErrRecord.Exception | Select-Object -Property $SelectedProperties
                }
            }

            ## Display properties in the correct order
            If ($Property -eq '*')
            {
                # If all properties were chosen for display, then arrange them in the order
                #  the error object displays them by default.
                If ($LogErrorRecordMsg)     {[array]$LogErrorMessageTmp += $LogErrorRecordMsg    }
                If ($LogErrorInvocationMsg) {[array]$LogErrorMessageTmp += $LogErrorInvocationMsg}
                If ($LogErrorExceptionMsg)  {[array]$LogErrorMessageTmp += $LogErrorExceptionMsg }
            }
            Else
            {
                # Display selected properties in our custom order
                If ($LogErrorExceptionMsg)  {[array]$LogErrorMessageTmp += $LogErrorExceptionMsg }
                If ($LogErrorRecordMsg)     {[array]$LogErrorMessageTmp += $LogErrorRecordMsg    }
                If ($LogErrorInvocationMsg) {[array]$LogErrorMessageTmp += $LogErrorInvocationMsg}
            }

            If ($LogErrorMessageTmp)
            {
                $LogErrorMessage  = 'Error Record:'
                $LogErrorMessage += "`n-------------"
                $LogErrorMsg      = $LogErrorMessageTmp | Format-List | Out-String
                $LogErrorMessage += $LogErrorMsg
            }

            ## Capture Error Inner Exception(s)
            If ($GetErrorInnerException)
            {
                If ($ErrRecord.Exception -and $ErrRecord.Exception.InnerException)
                {
                    $LogInnerMessage  = 'Error Inner Exception(s):'
                    $LogInnerMessage += "`n-------------------------"

                    $ErrorInnerException = $ErrRecord.Exception.InnerException
                    $Count = 0

                    While ($ErrorInnerException)
                    {
                        $InnerExceptionSeperator = '~' * 40

                        [string[]]$SelectedProperties = &$SelectProperty -InputObject $ErrorInnerException -Property $Property
                        $LogErrorInnerExceptionMsg = $ErrorInnerException | Select-Object -Property $SelectedProperties | Format-List | Out-String

                        If ($Count -gt 0)
                        {
                            $LogInnerMessage += $InnerExceptionSeperator
                        }
                        $LogInnerMessage += $LogErrorInnerExceptionMsg

                        $Count++
                        $ErrorInnerException = $ErrorInnerException.InnerException
                    }
                }
            }

            If ($LogErrorMessage) { $Output += $LogErrorMessage }
            If ($LogInnerMessage) { $Output += $LogInnerMessage }

            Write-Output $Output

            If (Test-Path -Path 'variable:Output'            ) { Clear-Variable -Name Output             }
            If (Test-Path -Path 'variable:LogErrorMessage'   ) { Clear-Variable -Name LogErrorMessage    }
            If (Test-Path -Path 'variable:LogInnerMessage'   ) { Clear-Variable -Name LogInnerMessage    }
            If (Test-Path -Path 'variable:LogErrorMessageTmp') { Clear-Variable -Name LogErrorMessageTmp }
        }
    }
    End {}
}