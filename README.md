# cftotalcontrol

## Description

The modules creates a special CodingFuture Total Control (CFTC) user in a system whose special public key
is added to [cfauth](https://forge.puppetlabs.com/codingfuture/cfauth) admin user access.

This module requires PuppetDB support, see [cfpuppetserver module](https://forge.puppetlabs.com/codingfuture/cfpuppetserver).
All configuration is dynamically created based on facts and resources from PuppetDB.

It is possible to configure SSH proxy hosts to access internal remote hosts.

Details of `cftotalcontrol`:
* creates a special user (`cftc` by default)
* upon login to account
    * secure SSH key generation is automatically started (please add password)
    * SSH agent is started and SSH key is added to it
    * SSH key age is checked and warning is generated, if key needs to be regenerated
* key generation procedures
    * old key is renamed with UNIX timestamp postfix
    * new key is generated with required characteristics
    * automatic new key provisioning is done, if old key exists
* daily cron job is setup to check for outdated keys (useful for backup total control hosts)
* special bash commands are automatically added:
    * `cftc_ssh` - wrapper around `ssh` to use CFTC configuration
    * `cftc_scp` - wrapper around `scp` to use CFTC configuration
    * `cftc_gen_key` - manually regenerate SSH key
    * `cftc_add_key` - manually add key (called on logon)
    * `cftc_deploy_key` - proper procedure to provision newly generated key when old key exists
    * `cftc_check_old_key` - manually check, if private key is too old
    * `ssh_masscmd {cmd}` - sequentially invoke `{cmd}` on all hosts
    * `ssh_mass_{stdcmd} {args}` - sequentially invoke standard command (`{stdcmd}`) on all hosts
    * `pssh_masscmd {cmd}` - invoke `{cmd}` on all hosts in parallel
    * `pssh_mass_{stdcmd} {args}` - invoke standard command (`{stdcmd}`) on all hosts in parallel
* Standard commands (`{stdcmd}` above):
    * `aptupdate` = `sudo /usr/bin/apt-get update`
    * `aptupgrade` = `sudo DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get dist-upgrade -o Dpkg::Options::="--force-confold" -qf`
    * `puppetdeploy` = `sudo /opt/puppetlabs/puppet/bin/puppet agent --test`
* Special environment variables:
    * `CFTC_SSHCONF="$cftotalcontrol::control_home/.ssh/cftotalcontrol_config"`
    * `PSSH_COUNT=$cftotalcontrol::parallel`
    * `PSSH_OPTS=-i`
    * `SSH_OPTS=`
    * `SCP_OPTS=`


## Technical Support

* [Example configuration](https://github.com/codingfuture/puppet-test)
* Commercial support: [support@codingfuture.net](mailto:support@codingfuture.net)

## Setup

* Add `cftotalcontrol` class to host with Total Control user
* Add `cftotalcontrol::auth` class to all other hosts (preferably, use common Hiera config)

Please use [librarian-puppet](https://rubygems.org/gems/librarian-puppet/) or
[cfpuppetserver module](https://forge.puppetlabs.com/codingfuture/cfpuppetserver) to deal with dependencies.

There is a known r10k issue [RK-3](https://tickets.puppetlabs.com/browse/RK-3) which prevents
automatic dependencies of dependencies installation.

## Examples

Please check [codingufuture/puppet-test](https://github.com/codingfuture/puppet-test) for
example of a complete infrastructure configuration and Vagrant provisioning.

## Implicitly created resources

```yaml
cfnetwork::describe_services:
    cftc{dynamic_part}:
        server: SSH ports for known outgoing SSH connections
cfnetwork::client_ports:
    cftc{dynamic_part}:
        user:
            - cftc user for main host
            - adminaccess cfauth proxy hosts
```

## Class parameters

## `cftotalcontrol` class

Add this class to host with CFTC user.

* `pool_proxy = {}`
* `control_user = 'cftcuser'`
* `control_home = '/home/cftcuser'`
* `host_groups = {}`
* `parallel = 10` - parallel ssh session default
* `standard_commands = {}` - standard commands to add to the default list
* `ssh_key_type = 'rsa'` - SSH key type, you may want to use 'ed25519'.
* `ssh_key_bits = 4096` - SSH key bit length, ignored for ed25519.
* `autogen_ssh_key = false` - Automatically generate key with no password for testing purposes.
* `ssh_old_key_days = 180` - key age in days for generating startup & cron warnings

## `cftotalcontrol::auth` class

Add to every slave host. Basically, add to all hosts.
