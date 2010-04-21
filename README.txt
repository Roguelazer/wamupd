Requirements:
   * ruby-dbus (not a gem)
   * algorithms
   * dnsruby

Running:
   * Make a config.yaml file containing useful parameters in normal YAML
     style:
      - hostname: the hostname of this machine
      - zone: the zone to write to
      - dns_server: the dns server that controls the above zone
      - dns_port: the port to talk to
      - dnssec_key_name: the key name for DNSSEC. Do not specify if you're
        not using DNSSEC
      - dnssec_key_hmac: the key value for DNSSEC.
      - ttl: the standard TTL to use.
      - transport: either "tcp" or "udp"
    * Run with "bin/wamupd -c /path/to/config.yaml -A -a -i
    * Use the -v flag if you want verbosity.

Terminating:
    * The program listens for SIGINT and cleans up when it is signaled.
    * Cleanup takes ~10 seconds.

