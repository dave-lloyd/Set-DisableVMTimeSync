#################################################
#
# Function : Set-DisableVMTimeSync
#
# Author : Dave Lloyd
#
# Purpose : Disables VM time sync with host per
# https://kb.vmware.com/s/article/1189
#
#################################################
function Set-DisableVMTimeSync {
<#
    .Synopsis
    Disables VM time sync with host
    .DESCRIPTION
    This script will disable time synchronization with the ESXi host for a VM based on the following KB
    https://kb.vmware.com/s/article/1189

    If VMwareTools are running, it will shutdown the VM and then make the changes and power the VM back on.
    If VMwareTools are NOT running, you will need to shutdown the VM manually and re-run the script.
    If the VM is already shutdown, it will make the changes and then power on the VM.

    The following will be added to the .vmx file
    "tools.syncTime" = "FALSE"
    "time.synchronize.continue" = "FALSE"
    "time.synchronize.restore" = "FALSE"
    "time.synchronize.resume.disk" = "FALSE"
    "time.synchronize.shrink" = "FALSE"
    "time.synchronize.tools.startup" = "FALSE"
    "time.synchronize.tools.enable" = "FALSE"
    "time.synchronize.resume.host" = "FALSE"

    While the VM is powered down, you would also be able to view these in the VM's advanced configuration settings.
    This will be greyed out when the VM is powered on - unless using vSphere 6.5 or later, in which case, you should 
    be able to view these when the VM is powered on.

    .PARAMETER vCenter
    The name or IP of the vCenter to connect to.
    .PARAMETER VM
    The name of the VM as it appears in the vCenter.
    .EXAMPLE
    Set-DisableVMTimeSync -vCenter 10.10.10.10 -VM TestVM
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory = $True, Position = 1)]
    [string]$vCenter,

    [Parameter(Mandatory = $True)]
    [string]$VM
)

    Clear-Host

    Write-Host "Trying to connect to the vCenter" -ForegroundColor Green
    Try {
        Connect-VIServer $vCenter -ErrorAction Stop
    } Catch {
        Write-Host "Unable to connect to the vCenter"
        Read-Host "Press ENTER to exit - powershell console will close."
        Exit
    }

    Write-Host "`nCheck 1 : Does $VM exist in vCenter." -ForegroundColor Green
    Try {
        Get-VM $VM -ErrorAction Stop | Out-Null
        Write-Host "VM $VM exists. Continuing." -ForegroundColor Cyan
    }
    
    Catch {
        Write-Host "VM $vm doesn't exist." -ForegroundColor Red
        Read-Host "`nPress ENTER to exit - powershell console will close."
        Exit
    }
    $vmToChange = Get-VM $VM
    $vmview = $vmToChange | get-view
    $vmtoolsstatus = $vmview.summary.guest.toolsRunningStatus
    $vmpowerstatus = $vmview.runtime.powerstate
 
    Write-Host "`nReview : Settings before we make any changes" -ForegroundColor Green
    $valuesBeforeChange = Get-AdvancedSetting -Entity $vmToChange.name -name *Time* | Select-Object name, value 
    $valuesBeforeChange | Out-Host

    # Array of the actual settings we want to change
    $TimeSettings = @(
        "tools.syncTime",
        "time.synchronize.continue",
        "time.synchronize.restore",
        "time.synchronize.resume.disk",
        "time.synchronize.shrink",
        "time.synchronize.tools.startup",
        "time.synchronize.tools.enable",
        "time.synchronize.resume.host"
    )

    Write-Host "`nCheck 2 : Is the VM powered on or off" -ForegroundColor Green                                                
    if ($vmpowerstatus -eq "PoweredOff") {
        Write-Host "$VM isn't powered on" -ForegroundColor Cyan
        Write-Host "`nAction : Making changes." -ForegroundColor DarkGreen
    
        ForEach ($Setting in $TimeSettings) {
            New-AdvancedSetting -Entity $vmToChange -Name $Setting -Value FALSE -Confirm:$false -Force:$true | Out-Null
            Write-Host "Setting $Setting to FALSE"
        }

        Write-Host "`nAction : Change complete." -ForegroundColor DarkGreen
        Write-Host "`nAction : Starting $VM ..."  -ForegroundColor DarkGreen       
        start-vm $vmToChange | out-null
    }
    else {
        Write-Host "$VM is currently running." -ForegroundColor Cyan
        Write-Host "`nCheck 3 : Are VMware tools running." -ForegroundColor Green
        if ($vmtoolsstatus -ne 'guestToolsRunning') {
            Write-Host "`tTools are not running." -ForegroundColor Red
            Write-Host "`tPlease shutdown $VM from within the OS, and then run this script again." -ForegroundColor Red
            Read-Host "`tPress ENTER to exit the script."
            Exit   
        }
        else {
            Write-Host "Tools are running" -ForegroundColor Cyan
            Write-Host "`nAction : Graceful shutdown ... be patient. Change will not occur until $VM is shutdown." -ForegroundColor darkgreen
            shutdown-vmguest $vmToChange -Confirm:$false | Out-Null
            # Need to wait until the VM is shutdown
            do {
                $vmview = $vmToChange | get-view
                $vmpowerstatus = $vmview.runtime.powerstate
            }
            until ($vmpowerstatus -eq "PoweredOff")
       
            Write-Host "`nAction : Shutdown complete. Making changes." -ForegroundColor DarkGreen

            ForEach ($Setting in $TimeSettings) {
                New-AdvancedSetting -Entity $vmToChange -Name $Setting -Value FALSE -Confirm:$false -Force:$true | Out-Null
                Write-Host "Setting $Setting to FALSE"
            }

        }
        Write-Host "`nAction : Starting $VM ..."  -ForegroundColor DarkGreen       
        Start-VM $vmToChange -Confirm:$false | Out-Null
    }

    Write-Host "`nConfirming Time settings in .vmx`b" -ForegroundColor Green
    $valuesAfterChange = get-vm $vmToChange | Get-AdvancedSetting -name *Time* | Select-Object name, value 
    $valuesAfterChange | Out-Host

    Write-Host "`nScript complete. Disconnecting from vCenter"
    Disconnect-VIServer -Confirm:$false
    Read-Host "Press ENTER to exit."

}
