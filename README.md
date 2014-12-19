Wamupd
======

Introduction
------------

Wamupd was originally created by roguelazer - for the original application,
see http://www.roguelazer.com/code/wamupd/. This version is primarily forked
to support the stable versions of Ruby (1.9), mDNSResponder (258.18), 
Avahi (0.6.29), D-Bus (1.4.6), and FreeBSD (8.2) at the time of writing. It 
also fixes some threading issues, adds logging, rc.d support, and FreeBSD 
packaging.

Requirements
------------

 * ruby19
 * ruby-dbus *(see my fork on [GitHub](https://github.com/johnnywalker/ruby-dbus))*
 * algorithms
 * rubygems
 * dnsruby
 * logger

ruby-dbus v0.6.0 does _not_ work properly on FreeBSD due to a problem with the
initial null byte sent to D-Bus for unix socket authentication. FreeBSD
supports the SCM\_CREDS socket option, so a simple patch is required.

Installing
----------

After cloning this repository, use gmake to create the wamupd package and then 
install the resulting file:

    git clone https://github.com/johnnywalker/wamupd
    cd wamupd
    gmake
    sudo pkg_add wamupd.tbz

Once installed, create the configuration file using the distribution template
and enable the wamupd service in your /etc/rc.conf:

    cd /usr/local/etc/
    sudo cp wamupd.yaml.dist wamupd.yaml
    sudo vim wamupd.yaml (edit appropriately)
    sudo echo wamupd_enable="YES" >>/etc/rc.conf
    sudo service wamupd start

Specify custom arguments to wamupd as needed using the wamupd\_flags entry in 
/etc/rc.conf. In order to get more information on the arguments available, try this:

    sudo service wamupd stop
    sudo /usr/local/sbin/wamupd run -- -h

The default flags used are:

    wamupd_flags="-c /usr/local/etc/wamupd.yaml -A /usr/local/etc/avahi/services -a -i"

A log is created at /var/log/wamupd.log, but this only contains small amounts
of information. In order to debug your configuration, make sure the service
isn't running and then execute the /usr/local/sbin/wamupd program in the 
foreground (note: the typical arguments used are "-A -a -i" - the "--" separates
the daemon command from the script arguments):

    sudo service wamupd stop
    sudo /usr/local/sbin/wamupd run -- -A -a -i

To uninstall, simply use pkg_delete:

    sudo pkg_delete wamupd

Usage
-----

    Usage: wamupd run -- [options] service-file
        -c, --config FILE                Get configuration data from FILE
                                         If FILE is not provided, defaults to /usr/local/etc/wamupd.yaml
        -A, --avahi-services [DIRECTORY] Load Avahi service definitions from DIRECTORY
                                           If DIRECTORY is not provided, defaults to /usr/local/etc/avahi/services
                                           If the -A flag is omitted altogether, static records will not be added.
        -i, --[no-]ip-addresses          Enable/Disable Publishing A and AAAA records
        -a, --avahi                      Load Avahi services over D-BUS
        -h, --help                       Show this message

Configuration
-------------

Make a wamupd.yaml file in /usr/local/etc/ in normal YAML style. Available
parameters include:
  - hostname: the hostname of this machine
  - zone: the zone to write to
  - dns\_server: the dns server that controls the above zone
  - dns\_port: the port to talk to
  - dnssec\_key\_name: the key name for DNSSEC. Do not specify if you're
    not using DNSSEC
  - dnssec\_key\_hmac: the key value for DNSSEC.
  - ttl: the standard TTL to use.
  - transport: either "tcp" or "udp"
