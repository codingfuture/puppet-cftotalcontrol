
class cftotalcontrol (
    $pool_proxy = {},
    $control_user = 'cftcuser',
    $control_home = '/home/cftcuser',
    $host_groups = {},
    $parallel = 10,
    $mass_commands = {},
    $ssh_key_type = 'rsa',
    $ssh_key_bits = 4096,
    $autogen_ssh_key = false,
    $ssh_old_key_days = 180,
) {
    include stdlib
    include cfnetwork
    
    package { 'pssh': }
    $ssh_dir = "${control_home}/.ssh"
    $ssh_config = "${ssh_dir}/cftotalcontrol_config"
    $ssh_idkey = "${ssh_dir}/cftc_id_${ssh_key_type}"

    # Only interested in nodes with cfauth class
    # See https://github.com/dalen/puppet-puppetdbquery/pull/88
    #$node_cfauth = query_resources(false, "Class['cfauth']", true)
    # workaround
    $node_cfauth = (query_resources(false, "Class['cfauth']", false).reduce({}) |$m, $r|{
        $cn = $r['certname']
        merge($m, { $cn => $r['parameters'] })
    })
    
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
        $m + { $v[0] => $v[1] }
    }
    
    # Build Bash-friendly aliases
    $node_alias = ($node_cfauth.map |$n, $o|{
        [$n, regsubst($n, '\.', '_', 'G')]
    }).reduce({}) |$m, $v| {
        merge($m, { $v[0] => $v[1] })
    }
    
    # Mass commands
    $mass_commands_all = $mass_commands + {
        'aptupdate'    => 'sudo /usr/bin/apt-get update',
        'aptupgrade'   => 'sudo DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get dist-upgrade -o Dpkg::Options::="--force-confold" -qf',
        'puppetdeploy' => 'sudo /opt/puppetlabs/puppet/bin/puppet agent --test',
    }
    
    # create user
    if $control_user != 'root' {
        group { $control_user:
            ensure => present,
        } ->
        user { $control_user:
            ensure     => present,
            gid        => $control_user,
            home       => $control_home,
            managehome => true,
            shell      => '/bin/bash',
        } ->
        file { $control_home:
            ensure => directory,
            owner  => $control_user,
            group  => $control_user,
            mode   => '0700',
        }
    }

    # Bash aliases
    file { 'cftotalcontrol_bash_aliases':
        ensure  => file,
        path    => "${control_home}/.bash_aliases",
        owner   => $control_user,
        group   => $control_user,
        content => '',
        replace => false,
    } ->    
    file_line {'cftotalcontrol_include_aliases':
        line => "source ${control_home}/.cftotalcontrol_aliases",
        path => "${control_home}/.bash_aliases",
    }

    file { "${control_home}/.cftotalcontrol_aliases":
        owner   => $control_user,
        group   => $control_user,
        content => epp('cftotalcontrol/bash_aliases.epp')
    }

    # SSH configs
    file { 'cftotalcontrol_ssh_dir':
        ensure => directory,
        path   => $ssh_dir,
        owner   => $control_user,
        group   => $control_user,
        mode   => '0700',
    } ->
    file { $ssh_config:
        owner   => $control_user,
        group   => $control_user,
        mode   => '0600',
        content => epp('cftotalcontrol/ssh_config.epp')
    }
    
    # Parallel SSH per group host file
    $node_groups.each |$grp, $nodes| {
        file { "${ssh_dir}/cftchosts_$grp":
            content => join($nodes, "\n")
        }
    }
    
    # Parallel SSH all host file
    file { "${ssh_dir}/cftchostsall":
        content => join(keys($node_cfauth), "\n")
    }
    
    # SSH ports
    $ssh_ports = prefix(unique(values($node_cfauth).reduce([]) |$m, $cfauth| {
        $ssh_port = any2array($cfauth['sshd_ports'])[0]
        $m + [$ssh_port]
    }), 'tcp/')
    cfnetwork::describe_service { 'cftcssh':
        server => $ssh_ports,
    }
    cfnetwork::client_port { 'any:cftcssh':
        user => $control_user,
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
        @@cftotalcontrol::internal::ssh_port { "${::trusted['certname']}_${nodename}":
            hostname => $nodename,
            ports    => unique($ports),
        }
    }
    
    # Generate key
    file { "${ssh_idkey}.pub":
        owner   => $control_user,
        group   => $control_user,
        mode   => '0600',
        content => '',
        replace => false,
    }
    file { '/etc/cftckey':
        ensure => link,
        target => "${ssh_idkey}.pub",
    }
    
    if $autogen_ssh_key {
        exec { 'cftotalcontrol_genkey':
            command => "/usr/bin/ssh-keygen -q -t ${ssh_key_type} -b ${ssh_key_bits} -P '' -f $ssh_idkey",
            creates => $ssh_idkey,
            user    => $control_user,
            group   => $control_user,
            require => File[$ssh_dir],
            before  => File['/etc/cftckey'],
        }
    }
}
