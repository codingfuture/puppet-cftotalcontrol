
define cftotalcontrol::internal::ssh_port (
    $hostname,
    $ports,
    $control_scope = undef,
) {
    include cfauth
    
    if $control_scope {
        $portuser = "${control_scope}_proxy"
        
        if !defined(Group[$portuser]) {
            group { $portuser:
                ensure => present,
                tag    => 'cftotalcontrol',
            } ->
            user { $portuser:
                gid            => $portuser,
                groups         => ['ssh_access'],
                home           => "/home/${portuser}",
                managehome     => true,
                shell          => '/bin/sh',
                purge_ssh_keys => true,
                tag            => 'cftotalcontrol',
                require        => Group[$portuser],
            }
        }
    } else {
        $portuser = $cfauth::admin_user
    }
    
    $portstr = join($ports,'p')
    $service = "cftc${portuser}${portstr}"
    
    # Virtual as may overlap
    if !defined(Cfnetwork::Describe_service[$service]) {
        cfnetwork::describe_service { $service:
            server => prefix($ports, 'tcp/'),
        }
    }
    if !defined(Cfnetwork::Client_port["any:${service}"]) {
        cfnetwork::client_port { "any:${service}":
            user => $portuser,
        }
    }
}