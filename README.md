# cftotalcontrol

## Description

The module creates a special CodingFuture Total Control (CFTC) user in a system whose special public key
is added to [cfauth](https://forge.puppetlabs.com/codingfuture/cfauth) admin user access on all infrastructure hosts.

This module requires PuppetDB support, see [cfpuppetserver module](https://forge.puppetlabs.com/codingfuture/cfpuppetserver).
All configuration is dynamically created based on facts and resources from PuppetDB.

It is possible to configure SSH proxy hosts to access internal remote hosts. It is also possible to have control users limited to a set of hosts (scope).*Note: instead of relatively insecure SSH Agent forwarding, a much more secure SSH Port forwarding is used to avoid possible exposure of SSH private keys on remote and intermediate hosts.*

*Note: there are other means for orchestration like [MCollective](https://puppetlabs.com/mcollective), but such approaches have quite doubtful security and do not support interactive prompts.*

## Concept

Overall idea is to avoid direct admin access to infrastructure servers, but use special CFTC user accounts
on secure hosts. This way it is much easier to control and audit infrastructure access, especially from outside.
**Note: for safety/high availability reasons, it is recommended to have at least two hosts with CFTC user accounts.**

Control user and `$cfauth::admin_user` can be the same account, but it's better to separate those as CFTC user
has heavy Bash pollution with commands and default actions on startup.

There are two types of CFTC users:
* **Total Control** - like "root" for whole infrastructure. Unrestricted access to `$cfauth::admin_user` accounts on any host
* **Scoped Control** - the same, but only to limited set of hosts, for which the scope is assigned through `cftotalcontrol::auth::control_scope` parameter. **Such user name is matched against the scope name.**
    * If proxy hosts are used then a highly restricted access to specially created proxy user is granted as well
    * *Note 1: it's possible to assign more than one scope per host*
    * *Note 2: by current implementation limitation, only a single hop of proxy hosts is supported for Scoped Control. Meanwhile, Total Control can have many proxy hosts in chain to the target host*

It's possible to access each host individually or run a single command on a all hosts or on a limited **group of hosts**.
A command can run both sequentially in interactive connections or in parallel with output printed after each host finishes execution.

Usually, there is a standard set of commands admin execute on all hosts like puppet deployment, package info update or system upgrades. For this reason, there is a special feautre of "Standard Commands". The predefined list (below) can be easily extended with custom commands.

Upon logon to CFTC user account, Bash scripts automatically detect if a key needs to be generated. Otherwise, SSH agent is started and existing key is added prompting you for password, if needed. It is important to use only CTFC commands below as they use a special SSH client configuration aware of proxy hosts and identity keys. *Note: for convenience unknown host keys are automatically accepted, but MITM attacks are still detected with known hosts.*

A good procedure is to regularly update SSH private key and its password. For this purpose, there is an automatic reminder upon logon and through daily cron, if CFTC detects the key is too old (configurable, half year by default).

*Key regeneration automatically launches **proper sequence of Puppet deployment** to properly export authorization key and update on all controlled and proxy hosts*

**Details of `cftotalcontrol` - to be assigned only to hosts with CFTC users:**
* creates a special user (`cftcuser` by default)
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
    * `ssh_${hostname} [$cmd]` - logon to specific host
    * `ssh_${hostname}_{stdcmd} [args]` - invoke standard command (`{stdcmd}`) on specific host
    * `ssh_masscmd {cmd}` - sequentially invoke `{cmd}` on all hosts
    * `ssh_mass_{stdcmd} [args]` - sequentially invoke standard command (`{stdcmd}`) on all hosts
    * `pssh_masscmd {cmd}` - invoke `{cmd}` on all hosts in parallel
    * `pssh_mass_{stdcmd} [args]` - invoke standard command (`{stdcmd}`) on all hosts in parallel
    * `sshgrp_{group}_*` and `psshgrp_{group}_*` - the same as mass commands, but limited to specific group of hosts
* Standard commands (`{stdcmd}` above):
    * `aptupdate` = `sudo /usr/bin/apt-get update`
    * `aptdistupgrade` = `sudo DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get dist-upgrade -o Dpkg::Options::="--force-confold" -qf`
    * `aptautoremove` = `sudo DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get autoremove`
    * `puppetdeploy` = `sudo /opt/puppetlabs/puppet/bin/puppet agent --test`
    * `ntpdate` = `sudo /opt/codingfuture/bin/cf_ntpdate`
    * `kernvercheck` = `/opt/codingfuture/bin/cf_kernel_version_check`
* Special environment variables:
    * `CFTC_SSHCONF="$cftotalcontrol::control_home/.ssh/cftotalcontrol_config"` - DO NOT CHANGE
    * `PSSH_COUNT=$cftotalcontrol::parallel` - number of max parallel host processing (can be overridden)
    * `PSSH_OPTS=-i` - custom parallel-ssh options (can be overridden)
    * `SSH_OPTS=` - custom SSH options (can be overridden)
    * `SCP_OPTS=` - custom SCP options (can be overridden)

**Details of `cftotalcontrol::auth` - to be asssigned to all hosts:**
* queries PuppetDB for SSH authorization keys (happens on Puppet Server during catalog compilation)
* for each SSH auth key
    * if Total Control user key
        * add the key to $cfauth::admin_user account
    * else Scope Control user key
        * if this host is a proxy
            * create user with scope name with "_proxy" postfix
            * restrict user to only port forwarding and puppet deploy (for new key provisioning)
        * else
            * create user with scope name
        * add the key to created scope user


## Technical Support

* [Example configuration](https://github.com/codingfuture/puppet-test)
* Free & Commercial support: [support@codingfuture.net](mailto:support@codingfuture.net)

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

See details above.

* `pool_proxy = {}`. Key => "proxy.hostname" pairs. Key formats:
    * "${cf_location}/${cf_location_pool}"
    * "${cf_location}"
    * "${certname}"
* `control_user = 'cftcuser'`
* `control_home = undef` - default under `/home/$control_user`
* `host_groups = {}` - define custom host host groups to generate `(p)sshgrp_*` commands
    - array - enumeration of hosts by actual name
    - string - Puppet DB query for dynamic discovery
* `parallel = 10` - parallel ssh session default
* `standard_commands = {}` - standard commands to add to the default list
* `ssh_key_type = 'rsa'` - SSH key type, you may want to use 'ed25519'.
* `ssh_key_bits = 4096` - SSH key bit length, ignored for ed25519.
* `autogen_ssh_key = false` - automatically generate key with no password (avoid, unless really needed)
* `ssh_old_key_days = 180` - key age in days for generating startup & cron warnings
* `ssh_auth_keys = undef` - hash of extra `name => ssh_authorized_key` definitions for user
* `extra_users = undef` - hash of scoped control admins `scope => cftotalcontrol::admin`
    - the parameters are the same for this class, except for `$extra_users` itself

## `cftotalcontrol::auth` class

See details above.

* `control_scope = []` - string or array of string with global identifiers of applied control scopes. See above.

## `cftotalcontrol::admin` type

Initialized based on `cftotalcontrol::extra_users` parameter. All parameters are the same as for `cftotalcontrol`, except removed `extra_users`.
* `control_scope = undef` - control scope of admin user, if any.