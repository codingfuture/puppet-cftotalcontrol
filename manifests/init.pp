
class cftotalcontrol (
    $pool_proxy = {},
    $control_user = 'root',
    $control_home = '/root',
    $host_groups = {},
    $parallel = 10,
    $mass_commands = {},
) {
    include stdlib
    include cfnetwork
    
    package { 'pssh': }
    $ssh_dir = "${control_home}/.ssh"
    $ssh_config = "${ssh_dir}/cftotalcontrol_config"
    $ssh_idrsa = "${ssh_dir}/cftc_id_rsa"

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
        'aptupgrade'   => 'sudo /usr/bin/apt-get dist-upgrade -q "$@"',
        'puppetdeploy' => 'sudo opt/puppetlabs/puppet/bin/puppet agent --test "$@"',
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
    
    # Generate key
    exec { 'cftotalcontrol_genkey':
        command => "/usr/bin/ssh-keygen -q -t rsa -b 4096 -P '' -f $ssh_idrsa",
        creates => $ssh_idrsa,
        user    => $control_user,
        group   => $control_user,
        require => File[$ssh_dir],
    } ->
    file { '/etc/cftckey':
        source => "${ssh_idrsa}.pub",
    }
}
