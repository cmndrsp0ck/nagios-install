### Nagios Install

---
This script can be used directly on a Droplet or by using user-data to pull it and supply arguments. Both the Nagios server and Nagios NRPE server have separate scripts. This should allow for quick and easy deployment of monitoring on Ubuntu nodes. 

* nagios-install.sh - *controller node*
* nrpe-install.sh - *client node*

### Getting Started

---
#### Nagios Server

* Start by creating a new Droplet.
* You're going to select the option for 'User Data'.
* We're going to curl the raw file using a git repo, then execute and pass along your contact email and your password to access the Nagios control panel.

It should look like this:

		#cloud-config
		runcmd:
			- [ curl, -Lk, gitlab.trekmode.com/barajasfab/nagios-install/raw/master/nagios-install.sh, -o, nagios-install.sh]
			- [ /bin/bash, ./nagios-install.sh, user@somedomain.com, 'Password']

Please note, the password should be surrounded by single quotes.

* At this point, you'll want to check the server to make sure that nagios is set up by going to http://ipaddress/nagios. You'll be prompted for the username "nagiosadmin' and the password you passed to the script in your user data.

#### Nagios client (*server to monitor*)

* Same deal as before, begin creating a new Droplet.
* Select the option to allow 'User Data'.
* Run the curl command and store the nrpe-install.sh file. Pass along the private IP belinging to your Nagios server so that it can talk to the node.

Here's an example:

		#cloud-config
		runcmd:
			- [ curl, -Lk, https://gitlab.trekmode.com/barajasfab/nagios-install/raw/master/nrpe-install.sh, -o, nrpe-install.sh]
			- [ /bin/bash, ./nrpe-install.sh, private_ip]

This will  set up basic configuration settings. You can now jump back over to the Nagios server to configure settings required to communicate with the nodes you're going to be monitoring.

### Configure nodes on Nagios

---
You're going to be setting up individual nodes within Nagios's configuration so that it can execute remote plugins through the NRPE server. Log into your Nagios server via SSH and change directories to **/usr/local/nagios/etc/servers**. At this point you'll see a file listed as *sample.cfg.txt*

* copy the file but name it whatever you intend to list the host as in Nagios: `cp sample.cfg.txt node_name.cfg`. 
* Open the file with your preferred text editor. In my case, that's vim. You should see the following page:

		define host {
			use                             linux-server
			host_name                       web1
			alias                           application node
			address                         10.134.9.156
			max_check_attempts              5
			check_period                    24x7
			notification_interval           30
			notification_period             24x7
		}
		define service {
			use                             generic-service
			host_name                       web1
			service_description             loadavg
			check_command                   check_nrpe!check_load
			max_check_attempts              5
			check_interval                  5
			retry_interval                  3
			check_period                    24x7
			notification_interval           30
			notification_period             24x7
			notification_options            w,c,r
		}

* You'll want to change the *host_name* (in both the host and service blocks), and the *address*. Save and exit.
* Restart Nagios: `service nagios restart`

The configuration will take effect right away and if you head over to the Nagios panel, select **Hosts** or **Services**, and you will see the output for the localhost as well as your node. More nodes can be set up using the section for **Nagios client** and you would just need to set up a new .cfg file for each host. If you can add more services to monitor as well but for this set up, we're just running a quick ping test and checking loadavg on the remote nodes. You can set up external commands that would allow you to receive the alerts and when critical, spin up new Droplets in instances such as large amounts of incoming traffic.
