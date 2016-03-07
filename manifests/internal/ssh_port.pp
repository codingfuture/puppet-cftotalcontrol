
define cftotalcontrol::internal::ssh_port (
    $hostname,
    $ports,
) {
    include cfauth
    
    $portstr = join($ports,'p')
    $service = "cftc${cfauth::admin_user}${portstr}"
    
    # Virtual as may overlap
    @cfnetwork::describe_service { $service:
        server => prefix($ports, 'tcp/'),
        tag => 'cftotalcontrol',
    }
    @cfnetwork::client_port { "any:${service}":
        user => $cfauth::admin_user,
        tag => 'cftotalcontrol',
    }
}