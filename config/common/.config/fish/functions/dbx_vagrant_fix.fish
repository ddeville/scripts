function dbx_vagrant_fix --description "Fix vagrant/vmware when it gets stalled"
    echo "restarting vagrant-vmware-utility"
    sudo launchctl stop com.vagrant.vagrant-vmware-utility
    sudo launchctl start com.vagrant.vagrant-vmware-utility
end
