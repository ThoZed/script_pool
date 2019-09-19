#check_msxasmobiledevice.ps1
#
# use this script to check the sync status of ActiveSync devices
# requires devicelist
# start with l as argument to start device discovery

#read first parameter
param (
    [string]$arg1
)

# set list of devices to monitor
# user as SamAccountName
# deviceid as extracted with argument l
$devices = @(
    [pscustomobject]@{user='androiduser';deviceid='androidt849494964'}
    [pscustomobject]@{user='user'; deviceid='deviceiddeviceiddeviceid'}
)

#
# set threshold
$warningthreshold = '12'
$criticalthreshold = '24'

#
# set timezone adjustment hours
$timezone = 2


# prereq
# PSSnapin Load
if ( (Get-PSSnapin -Name Microsoft.Exchange.Management.PowerShell.E2010 -ErrorAction SilentlyContinue) -eq $null )
{
    Add-PsSnapin Microsoft.Exchange.Management.PowerShell.E2010
}

#
# Create list with all MobileDeviceStatistics for each mailbox extend output with mailbox and mailboxUser
function getdevicelist ()
{
$timeoffset = "2"
$UserList = Get-CASMailbox -Filter {hasactivesyncdevicepartnership -eq $true -and -not displayname -like "CAS_{*"} | Get-Mailbox
$UserList | foreach { 
$User = $_
return Get-MobileDeviceStatistics -Mailbox $_} | ft @{l='Mailbox';e={$User.SamAccountName}},@{l='MailboxUser';e={[regex]::Match($_.Identity,'^.+/(.+)/ExchangeActiveSyncDevices/.+').Captures.groups[1].value}},DeviceModel,DeviceID,@{l='LastSuccessSync';e={(Get-date($_.LastSuccessSync)).AddHours($timeoffset)}}
}

#
# get specific device
function get_device ($user,$deviceid)
{
$device = Get-MobileDeviceStatistics -Mailbox $user | Where-Object -FilterScript {$_.DEviceID -eq $deviceid } 
return $device
}

# get timespan to lastsync
function get_timespan($device)
{
$lastsync = Get-Date ($device.LastSuccessSync).AddHours($timezone)
$now      = Get-Date
$timespan = New-TimeSpan $lastsync $now
return $timespan
}

#
# figure out status of device
# 0 eq OK
# 1 eq WARN
# 2 eq CRIT
# 3 eq UNKNOWN
function get_statuscode($timespan)
{
    $status = 3
    if ($timespan -le (New-TimeSpan -Hours $warningthreshold ))
    {
        $status = "0"
    }
    elseif($timespan -le (New-TimeSpan -Hours $criticalthreshold ))
    {
        $status = "1"
    }
    else
    {
        $status = "2"
    }
return $status
}

#
# final check with nrpe,mrpe conform output
# in output also <<<local>>> is added. this allows you to run this script as plugin
# so you are able to set cache_age options
function check_msxasmobiledevice($targetuser, $targetdeviceid)
{
    Begin
    {
    }
    Process
    {
        $targetdevice = get_device $targetuser $targetdeviceid
        $svc_desc = $targetdevice.DeviceType + " " + $targetdevice.DeviceOS + " Serial:" + $targetdevice.DeviceID + " Benutzer:" + ([regex]::Match($targetdevice.Identity,'^.+/(.+)/ExchangeActiveSyncDevices/.+').Captures.groups[1].value) + " LastSync:" + $targetdevice.LastSuccessSync.AddHours($timezone)
        $timespan = get_timespan($targetdevice)
        $svc_status = get_statuscode($timespan)
        $svc_value = "lastsync=" + ((get_timespan($targetdevice)).TotalHours) + ";$warningthreshold;$criticalthreshold"
        $svc_name = "mobile_" + $targetdeviceid.Substring($targetdeviceid.Length - 2) + "_"+ $targetuser
    }
    End
    {
        Write-Host $svc_status $svc_name $svc_value $svc_desc 
    }
}


# check if l is present to output available devices. otherwise use monitoring script mode.
if ($arg1 -eq 'l')
{
    getdevicelist
}
else
{
    Write-Host "<<<local>>>"
    foreach ($device in $devices)
    {
        check_msxasmobiledevice $device.user $device.deviceid;
    }
}