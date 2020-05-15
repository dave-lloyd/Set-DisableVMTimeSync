# Set-DisableVMTimeSync

This script will disable time synchronization with the ESXi host for a VM based on the following KB
https://kb.vmware.com/s/article/1189

If VMwareTools are running, it will shutdown the VM and then make the changes and power the VM back on.

If VMwareTools are NOT running, you will need to shutdown the VM manually and re-run the script.

If the VM is already shutdown, it will make the changes and then power on the VM.

The following will be added to the .vmx file
* "tools.syncTime" = "FALSE"
* "time.synchronize.continue" = "FALSE"
* "time.synchronize.restore" = "FALSE"
* "time.synchronize.resume.disk" = "FALSE"
* "time.synchronize.shrink" = "FALSE"
* "time.synchronize.tools.startup" = "FALSE"
* "time.synchronize.tools.enable" = "FALSE"
* "time.synchronize.resume.host" = "FALSE"

While the VM is powered down, you would also be able to view these in the VM's advanced configuration settings.

This will be greyed out when the VM is powered on - unless using vSphere 6.5, in which case, you should be able
to view these when the VM is powered on.

To run it, first dot source the script, then run

* help Set-DisableVMTimeSync -full

or just run it with
* Set-DisableVMTimeSync -vCenter xxx.xxx.xxx.xxx -VM vmtochange
