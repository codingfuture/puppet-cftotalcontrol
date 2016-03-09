
class cftotalcontrol (
    $control_user = 'cftcuser',
    $control_home = "/home/${control_user}",
    $pool_proxy = {},
    $host_groups = {},
    $parallel = 10,
    $standard_commands = {},
    $ssh_key_type = 'rsa',
    $ssh_key_bits = 4096,
    $autogen_ssh_key = false,
    $ssh_old_key_days = 180,
    $extra_users = {},
) {
    include stdlib
    include cfnetwork
    
    package { 'pssh': }
    
    if $control_user {
        cftotalcontrol::admin { $control_user:
            control_home => $control_home,
            pool_proxy => $pool_proxy,
            host_groups => $host_groups,
            parallel => $parallel,
            standard_commands => $standard_commands,
            ssh_key_type => $ssh_key_type,
            ssh_key_bits => $ssh_key_bits,
            autogen_ssh_key => $autogen_ssh_key,
            ssh_old_key_days => $ssh_old_key_days,
        }
    }
    
    $extra_users.each |$admin_name, $admin_params| {
        create_resources(
            cftotalcontrol::admin,
            { "$admin_name" => $admin_params },
            { control_scope => $admin_name }
        )
    }
    
    file { "/etc/cfscopekeys/":
        ensure  => directory,
        recurse => true,
        purge   => true,
    }
}
