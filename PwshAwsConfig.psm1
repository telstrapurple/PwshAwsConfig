<#
.SYNOPSIS
A collection of functions for managing AWS CLI config and credentials.

.DESCRIPTION
A collection of functions for managing AWS CLI config and credentials.
#>

<#
.SYNOPSIS
Create IAM credentials for a new AWS account.

.DESCRIPTION
Create IAM credentials for a new AWS account. This will create a record in your
~/.aws/credentials file to represent an IAM user in the given AWS account, by
reading the AWS Access Key ID and AWS Secret Access Key from a console prompt
or CSV file. This will silently ignore if the account already exists. To edit
an existing account, use Edit-AwsAccount.

.PARAMETER AccountName
The name of the AWS account. This is purely for your own convenience to
distinguish between multiple AWS accounts

.PARAMETER AccessKeyCsvPath
An optional path to a .csv file containing the AWS Access Key ID and AWS Secret
Access Key to use

.EXAMPLE
The example below creates a new record in your ~/.aws/credentials file for
work:iam with the supplied AWS Access Key ID and AWS Secret Access Key.

PS C:> New-AwsAccount -AccountName work
AWS Access Key ID: ********************
AWS Secret Access Key: ****************************************

.EXAMPLE
The example below creates a new record in your ~/.aws/credentials file for
work:iam by reading the AWS Access Key ID and AWS Secret Access Key from the
supplied CSV file.

PS C:> New-AwsAccount -AccountName work -AccessKeyCsvPath my.user_accessKeys.csv
#>
Function New-AwsAccount
{
    Param(
        [Parameter(Mandatory)] [string] $AccountName,
        [string] $AccessKeyCsvPath
    )

    $credentialName = "$AccountName`:iam"

    If (Test-AwsProfile -Profile $credentialName)
    {
        Write-Information "Account already exists"
        Return
    }

    NewOrEdit-AwsAccount -AccountName $AccountName -AccessKeyCsvPath $AccessKeyCsvPath
}

<#
.SYNOPSIS
Edit IAM credentials for an existing AWS account.

.DESCRIPTION
Edit IAM credentials for an existing AWS account. This will edit a record in
your ~/.aws/credentials file which represents an IAM user in the given AWS
account, by reading the AWS Access Key ID and AWS Secret Access Key from a
console prompt or CSV file. This will fail if the account does not exist. To
create a new account, use New-AwsAccount.

.PARAMETER AccountName
The name of the AWS account. This is purely for your own convenience to
distinguish between multiple AWS accounts

.PARAMETER AccessKeyCsvPath
An optional path to a .csv file containing the AWS Access Key ID and AWS Secret
Access Key to use

.EXAMPLE
The example below edits the record in your ~/.aws/credentials file for work:iam
with the supplied AWS Access Key ID and AWS Secret Access Key.

PS C:> Edit-AwsAccount -AccountName work
AWS Access Key ID: ********************
AWS Secret Access Key: ****************************************

.EXAMPLE
The example below edits the record in your ~/.aws/credentials file for work:iam
by reading the AWS Access Key ID and AWS Secret Access Key from the supplied
CSV file.

PS C:> Edit-AwsAccount -AccountName work -AccessKeyCsvPath my.user_accessKeys.csv
#>
Function Edit-AwsAccount
{
    Param(
        [Parameter(Mandatory)] [string] $AccountName,
        [string] $AccessKeyCsvPath
    )

    $credentialName = "$AccountName`:iam"

    If (-not (Test-AwsProfile -Profile $credentialName))
    {
        Throw "No existing account $AccountName exists. Use New-AwsAccount to create a new account"
    }

    NewOrEdit-AwsAccount -AccountName $AccountName -AccessKeyCsvPath $AccessKeyCsvPath
}

<#
.SYNOPSIS
Create a new role for an existing AWS account.

.DESCRIPTION
Create a new role an an existing AWS account. This will create a new record in
your ~/.aws/config file which represents a role in the given AWS account with
the supplied role ARN. The role can be backed by either an IAM credential or an
MFA credential. This will fail if the associated credential does not exist.

.PARAMETER AccountName
The name of the AWS account that the role is for. Must be an account that you
previously created via New-AwsAccount

.PARAMETER RoleName
The name of the role to create. This is purely for your own convenience to
distinguish between multiple roles

.PARAMETER RoleArn
The ARN of the role to create

.PARAMETER UseIam
Use this flag to specify that the role uses your IAM credentials. Defaults to
using your MFA credentials

.EXAMPLE
The example below creates a new record in your ~/.aws/config file for a
ReadOnly role for the work account which authenticates with IAM credentials.

PS C:> New-AwsRole `
    -AccountName work `
    -RoleName readonly `
    -RoleArn arn:aws:iam::000000000000:role/ReadOnly `
    -UseIam

.EXAMPLE
The example below creates a new record in your ~/.aws/config file for a
PowerUsers role for the work account which authenticates with MFA credentials.

PS C:> New-AwsRole `
    -AccountName work `
    -RoleName poweruser `
    -RoleArn arn:aws:iam::000000000000:role/PowerUsers
#>
Function New-AwsRole
{
    Param(
        [Parameter(Mandatory)] [string] $AccountName,
        [Parameter(Mandatory)] [string] $RoleName,
        [Parameter(Mandatory)] [string] $RoleArn,
        [switch] $UseIam
    )

    If ($UseIam)
    {
        $sourceProfile = "$AccountName`:iam"
        If (-not (Test-AwsProfile -Profile $sourceProfile))
        {
            throw "No existing account $AccountName exists. Use New-AwsAccount to create a new account"
        }
    }
    Else
    {
        $sourceProfile = "$AccountName`:mfa"
        If (-not (Test-AwsProfile -Profile $sourceProfile))
        {
            throw "No existing account $AccountName exists. Use New-AwsAccount to create a new account"
        }
    }

    $profile = "$AccountName`:$RoleName"

    aws configure --profile $profile set role_arn $RoleArn
    aws configure --profile $profile set source_profile $sourceProfile
}

<#
.SYNOPSIS
Set the current AWS profile

.DESCRIPTION
Set the current AWS profile by setting the AWS_PROFILE environment variable. If
no profile is supplied, displays a list of available profiles.

.PARAMETER Profile
The name of the profile to use. If not supplied, displays a list of available
profiles

.EXAMPLE
The example below sets the current AWS profile to the work:poweruser profile
previously created via New-AwsRole

PS C:> Set-AwsProfile -Profile work:poweruser

.EXAMPLE
The example below displays a list of available profiles, and then prompts the
user for their selection.

PS C:> Set-AwsProfile
Set AWS Profile
Please select from your available AWS profiles
[0] work:iam    [1] work:mfa    [2] work:readonly   [3] work:poweruser
[?] Help
#>
Function Set-AwsProfile
{
    Param(
        [string] $Profile
    )

    If (-not $Profile)
    {
        $hotkeys = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        $index = 0
        $profiles = aws configure list-profiles | Sort-Object
        $options = $profiles | % {
            $hotkey = $hotkeys[$index++]
            [System.Management.Automation.Host.ChoiceDescription]::new("&$hotkey`b$_", $_)
        }
        $selection = $Host.UI.PromptForChoice(
            "Set AWS Profile",
            "Please select from your available AWS profiles",
            $options, -1
        )
        $Profile = $profiles[$selection]
    }

    $env:AWS_PROFILE = $Profile
}

<#
.SYNOPSIS
Create a new AWS session.

.DESCRIPTION
Create a new AWS session for the given profile. This will create an MFA
profile if required, refresh the associated MFA credentials, and set the
current profile (by setting the AWS_PROFILE environment variable).

.PARAMETER Profile
The name of the profile to use. Defaults to the current AWS profile (stored in
the AWS_PROFILE environment variable) if set, or displays a list of available
profiles if not set

.PARAMETER Code
The value provided by the MFA device

.PARAMETER Arn
The ARN of the MFA device

.EXAMPLE
The example below starts a new session for the work PowerUser profile. In this
case, no MFA credentials were previously set up, so the user is prompted for
the MFA Device ARN and MFA code.

PS C:> New-AwsSession -Profile work:poweruser
MFA Device ARN: arn:aws:iam::000000000000:mfa/my.user
MFA Code: ******

.EXAMPLE
The example below starts a new session for the currently selected profile
(stored in the AWS_PROFILE environment variable), which has an associated MFA
credential already configured. The user is prompted for a fresh MFA code.

PS C:> New-AwsSession
MFA Code: ******
#>
Function New-AwsSession
{
    Param(
        [string] $Profile = $env:AWS_PROFILE,
        [string] $Code,
        [string] $Arn
    )

    If (-not $Profile)
    {
        Set-AwsProfile
        $Profile = $env:AWS_PROFILE
    }

    If ($Profile -match ":iam$")
    {
        Write-Information "IAM accounts do not need credentials refreshed"
        Return
    }

    $mfaCredentialName = If ($Profile -match ":mfa$")
    {
        $Profile
    }
    Else
    {
        aws configure --profile $Profile get source_profile
    }

    Invoke-WithoutProfile {
        Update-MfaCredentials `
            -MfaCredentialName $mfaCredentialName `
            -Code $Code `
            -Arn $Arn
    }

    Set-AwsProfile -Profile $Profile
}


# Private functions

Function NewOrEdit-AwsAccount
{
    Param(
        [Parameter(Mandatory)] [string] $AccountName,
        [string] $AccessKeyCsvPath
    )

    $credentialName = "$AccountName`:iam"

    If ($AccessKeyCsvPath)
    {
        If (-not (Test-Path $AccessKeyCsvPath))
        {
            Throw "Unknown filepath: $AccessKeyCsvPath"
        }

        $csv = Import-Csv -Path $AccessKeyCsvPath
        $key = $csv."Access key ID"
        $secret = $csv."Secret access key"
    }
    Else
    {
        $key = Read-Host -MaskInput -Prompt "AWS Access Key ID"
        $secret = Read-Host -MaskInput -Prompt "AWS Secret Access Key"
    }

    aws configure --profile $credentialName set aws_access_key_id $key
    aws configure --profile $credentialName set aws_secret_access_key $secret
}

Function Update-MfaCredentials
{
    Param(
        [Parameter(Mandatory)] [string] $MfaCredentialName,
        [string] $Code,
        [string] $Arn
    )

    $iamCredentialName = $MfaCredentialName -replace ':mfa',':iam'

    If (Test-AwsProfile -Profile $MfaCredentialName)
    {
        $Arn = aws configure --profile $MfaCredentialName get mfa_device_arn
    }
    ElseIf (-not $Arn)
    {
        $Arn = Read-Host -Prompt "MFA Device ARN"
        aws configure --profile $MfaCredentialName set mfa_device_arn $Arn
    }

    If (-not $Code)
    {
        $Code = Read-Host -MaskInput -Prompt "MFA Code"
    }

    $resp = aws sts get-session-token `
        --profile $iamCredentialName `
        --serial-number $Arn `
        --token-code $Code `
        --duration-seconds 86400 # 24hrs

    If (-not $?)
    {
        Throw "Failed to get session token: $resp"
    }

    $credentials = $resp | ConvertFrom-Json | Select -ExpandProperty Credentials

    aws configure --profile $MfaCredentialName set aws_access_key_id $credentials.AccessKeyId
    aws configure --profile $MfaCredentialName set aws_secret_access_key $credentials.SecretAccessKey
    aws configure --profile $MfaCredentialName set aws_session_token $credentials.SessionToken
}

Function Test-AwsProfile
{
    Param(
        [Parameter(Mandatory)][string] $Profile
    )

    (aws configure list-profiles) -contains $Profile
}

Function Invoke-WithoutProfile
{
    Param(
        [Parameter(Mandatory)][ScriptBlock] $Block
    )

    $profile = $env:AWS_PROFILE
    $env:AWS_PROFILE = $null

    Try
    {
        & $Block
    }
    Finally
    {
        $env:AWS_PROFILE = $profile
    }
}