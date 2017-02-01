#
# Copyright 2016-2017 (c) Andrey Galkin
#


define cftotalcontrol::admin (
    String[1]
        $control_user = $title,
    String[1]
        $control_home = "/home/${title}",
    Hash
        $pool_proxy = $cftotalcontrol::pool_proxy,
    Hash
        $host_groups = {},
    Integer[1]
        $parallel = $cftotalcontrol::parallel,
    Hash
        $standard_commands = $cftotalcontrol::standard_commands,
    Enum['rsa', 'ed25519']
        $ssh_key_type = $cftotalcontrol::ssh_key_type,
    Integer[4096]
        $ssh_key_bits = $cftotalcontrol::ssh_key_bits,
    Boolean
        $autogen_ssh_key = $cftotalcontrol::autogen_ssh_key,
    Integer[1]
        $ssh_old_key_days = $cftotalcontrol::ssh_old_key_days,
    Optional[String[1]]
        $control_scope = undef,
    Optional[Hash]
        $ssh_auth_keys = undef,
) {
    $ssh_dir = "${control_home}/.ssh"
    $ssh_config = "${ssh_dir}/cftotalcontrol_config"
    $ssh_idkey = "${ssh_dir}/cftc_id_${ssh_key_type}"

    if $control_scope {
        $control_scope_q = " and Cftotalcontrol::Internal::Scope_anchor['${control_scope}']"
    } else {
        $control_scope_q = ''
    }

    # Only interested in nodes with cftotalcontrol::auth [of specific scope] class
    $node_cfauth = (query_resources(
        "Class['cftotalcontrol::auth']${control_scope_q}",
        "Class['cfauth']",
        false
    ).reduce({}) |$m, $r|{
        $cn = $r['certname']
        merge($m, { $cn => $r['parameters'] })
    })
    $node_order = sort(keys($node_cfauth))

    # Known facts
    $node_facts = query_facts("Class['cfauth']", [
        'cf_location',
        'cf_location_pool',
        'domain',
        'hostname',
    ])

    # Build groups
    $node_groups = ($host_groups.map |$g, $q| {
        if is_array($q) {
            [$g, $q]
        } else {
            [$g, query_nodes($q)]
        }
    }).reduce({}) |$m, $v| {
        $m + { $v[0] => sort($v[1]) }
    }

    # Build Bash-friendly aliases
    $node_alias = ($node_cfauth.map |$n, $o|{
        [$n, regsubst($n, '\.', '_', 'G')]
    }).reduce({}) |$m, $v| {
        merge($m, { $v[0] => $v[1] })
    }

    # Mass commands
    $standard_commands_all = $standard_commands + {
        'aptupdate'      => 'sudo /usr/bin/apt-get update',
        'aptdistupgrade' => 'sudo DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get dist-upgrade -o Dpkg::Options::="--force-confold" -qf',
        'aptautoremove'  => 'sudo DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get autoremove',
        'puppetdeploy'   => 'sudo /opt/puppetlabs/puppet/bin/puppet agent --test',
    }

    # create user
    if $control_user in ['root', $cfauth::admin_user] {
        # the user must already exist
    } else {
        group { $control_user:
            ensure => present,
        } ->
        user { $control_user:
            ensure         => present,
            gid            => $control_user,
            groups         => ['ssh_access'],
            home           => $control_home,
            managehome     => true,
            shell          => '/bin/bash',
            purge_ssh_keys => true,
        } ->
        file { $control_home:
            ensure => directory,
            owner  => $control_user,
            group  => $control_user,
            mode   => '0700',
        } ->
        file { "${control_home}/.bashrc":
            owner  => $control_user,
            group  => $control_user,
            mode   => '0700',
            source => '/etc/skel/.bashrc',
        } ->
        file { "${control_home}/.profile":
            owner  => $control_user,
            group  => $control_user,
            mode   => '0700',
            source => '/etc/skel/.profile',
        }
        file {"/etc/sudoers.d/${control_user}":
            group   => root,
            owner   => root,
            mode    => '0400',
            replace => true,
            content => "
${control_user}   ALL=(ALL:ALL) NOPASSWD: /opt/puppetlabs/bin/puppet agent --test
",
            require => Package['sudo'],
        }
        if $ssh_auth_keys {
            create_resources(
                ssh_authorized_key,
                prefix($ssh_auth_keys, "${control_user}@"),
                {
                    user => $control_user,
                    'type' => 'ssh-rsa',
                    require => User[$control_user],
                }
            )
        }
        if $cfauth::admin_auth_keys {
            create_resources(
                ssh_authorized_key,
                prefix($cfauth::admin_auth_keys, "${control_user}/cfauth@"),
                {
                    user => $control_user,
                    'type' => 'ssh-rsa',
                    require => User[$control_user],
                }
            )
        }
    }

    # Bash aliases
    file { "cftc_bash_aliases@${control_user}":
        ensure  => file,
        path    => "${control_home}/.bash_aliases",
        owner   => $control_user,
        group   => $control_user,
        content => '',
        replace => false,
    } ->
    file_line {"cftc_include_aliases@${control_user}":
        line => "source ${control_home}/.cftotalcontrol_aliases",
        path => "${control_home}/.bash_aliases",
    }

    file { "${control_home}/.cftotalcontrol_aliases":
        owner   => $control_user,
        group   => $control_user,
        content => epp('cftotalcontrol/bash_aliases.epp', {
            ssh_config            => $ssh_config,
            ssh_idkey             => $ssh_idkey,
            ssh_dir               => $ssh_dir,
            ssh_key_type          => $ssh_key_type,
            ssh_key_bits          => $ssh_key_bits,
            ssh_old_key_days      => $ssh_old_key_days,
            standard_commands_all => $standard_commands_all,
            node_order            => $node_order,
            node_alias            => $node_alias,
            node_groups           => $node_groups,
            parallel              => $parallel,
        })
    }

    # SSH configs
    file { "cftc_ssh_dir@${control_user}":
        ensure => directory,
        path   => $ssh_dir,
        owner  => $control_user,
        group  => $control_user,
        mode   => '0700',
    } ->
    file { $ssh_config:
        owner   => $control_user,
        group   => $control_user,
        mode    => '0600',
        content => epp('cftotalcontrol/ssh_config.epp', {
            ssh_dir       => $ssh_dir,
            ssh_config    => $ssh_config,
            ssh_idkey     => $ssh_idkey,
            node_order    => $node_order,
            node_cfauth   => $node_cfauth,
            node_facts    => $node_facts,
            pool_proxy    => $pool_proxy,
            control_scope => $control_scope,
        })
    }

    # Parallel SSH per group host file
    $node_groups.each |$grp, $nodes| {
        file { "${ssh_dir}/cftchosts_${grp}":
            content => join($nodes, "\n")
        }
    }

    # Parallel SSH all host file
    file { "${ssh_dir}/cftchostsall":
        content => join($node_order, "\n")
    }

    # SSH ports
    $ssh_ports = prefix(unique(values($node_cfauth).reduce([]) |$m, $cfauth| {
        $ssh_port = any2array($cfauth['sshd_ports'])[0]
        $m + [$ssh_port]
    }), 'tcp/')
    if size($ssh_ports) > 0 {
        cfnetwork::describe_service { "cftcssh${control_user}":
            server => $ssh_ports,
        }
        cfnetwork::client_port { "any:cftcssh${control_user}":
            user => $control_user,
        }
    }

    # Export outgoing proxy ports
    $proxy_ports = $node_cfauth.reduce({}) |$memo, $kv| {
        $nodename = $kv[0]
        $cfauth_params = $kv[1]
        $loc = $node_facts[$nodename]['cf_location']
        $locpool = $node_facts[$nodename]['cf_location_pool']
        $ssh_port = any2array($cfauth_params['sshd_ports'])[0]
        $proxy_host = pick_default(
            $pool_proxy["${loc}/${locpool}"],
            $pool_proxy[$loc]
        )

        if is_string($proxy_host) and $proxy_host != '' {
            if has_key($memo, $proxy_host) {
                merge($memo, { $proxy_host => [$ssh_port] + $memo[$proxy_host] })
            } else {
                merge($memo, { $proxy_host => [$ssh_port] })
            }
        } else {
            $memo
        }
    }

    $proxy_ports.each |$nodename, $ports| {
        @@cftotalcontrol::internal::ssh_port { "${::trusted['certname']}_${nodename}_${control_user}":
            hostname      => $nodename,
            ports         => sort(unique($ports)),
            control_scope => $control_scope,
            key_certname  => $::trusted['certname'],
        }
    }

    # Generate key
    file { "${ssh_idkey}.pub":
        owner   => $control_user,
        group   => $control_user,
        mode    => '0600',
        content => '',
        replace => false,
    }

    if $control_scope {
        file { "/etc/cfscopekeys/${control_scope}":
            ensure => link,
            target => "${ssh_idkey}.pub",
        }
    } else {
        file { '/etc/cftckey':
            ensure => link,
            target => "${ssh_idkey}.pub",
        }
    }

    if $autogen_ssh_key {
        exec { "cftc_genkey@${control_user}":
            command => "/usr/bin/ssh-keygen -q -t ${ssh_key_type} -b ${ssh_key_bits} -P '' -f ${ssh_idkey}",
            creates => $ssh_idkey,
            user    => $control_user,
            group   => $control_user,
            require => File["cftc_ssh_dir@${control_user}"],
        }
    }

    # Cron to check for outdated key
    cron { "cftc_outdated_key@${control_user}":
        command => "bash -c '. ${control_home}/.cftotalcontrol_aliases && cftc_check_old_key'",
        user    => $control_user,
        hour    => 12,
        minute  => 0,
    }
}
