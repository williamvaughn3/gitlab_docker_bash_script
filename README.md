# gitlab_docker_bash_script

```
########################################################"
## Quick and Dirty Bash Script for Gitlab install     ##"
## Using Docker and GitLab with Omnibus packages      ##"
##                                                    ##"
##    Did this for a specific purpose....             ##"
##                                                    ##"
##   However....                                      ##"
##   For other quick options see:                     ##"
##                                                    ##"
##   HashiCorp vagrant vault, as well as tf / packer  ##"
##   or some of Jeff Geerings Work for awesome        ##"
##   Ansible Resources                                ##"
########################################################"

Usage: gl_docker_install.sh <"temp password">"

Change Password afterward



```

##### IP Validation
Didn't do input validation for IPs addresses.  1st IP is default, or enter the full ip that will be associated.

set_git_ip function ommits interfaces: [ Tunnel, lo, bridge, doc, vir, veth, vm ]
(needed for my use case) when providing acceptable input parameters.

Default IP  is first returned not matching the above list 

Validation if value exists in the /tmp/ipaddr.txt does occur.


Not perfect, but works for what I need it to.

