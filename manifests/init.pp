#
# Copyright 2016-2017 (c) Andrey Galkin
#


class cftotalcontrol (
    String[1]
        $control_user = 'cftcuser',
    Optional[String[1]]
        $control_home = undef,
    Hash
        $pool_proxy = {},
    Hash
        $host_groups = {},
    Integer[1]
        $parallel = 10,
    Hash
        $standard_commands = {},
    Enum['rsa', 'ed25519']
        $ssh_key_type = 'rsa',
    Integer[4096]
        $ssh_key_bits = 4096, # for rsa
    Boolean
        $autogen_ssh_key = false,
    Integer[1]
        $ssh_old_key_days = 180,
    Optional[Hash]
        $ssh_auth_keys = undef,
    Optional[Hash]
        $extra_users = undef,
) {
    include stdlib
    include cfnetwork

    package { 'pssh': }

    if $control_user {
        if $control_home {
            $act_control_home = $control_home
        } elsif $control_user and $control_user != '' {
            $act_control_home = "/home/${control_user}"
        } else {
            $act_control_home = '/home/cftcuser'
        }

        cftotalcontrol::admin { $control_user:
            control_home      => $act_control_home,
            pool_proxy        => $pool_proxy,
            host_groups       => $host_groups,
            parallel          => $parallel,
            standard_commands => $standard_commands,
            ssh_key_type      => $ssh_key_type,
            ssh_key_bits      => $ssh_key_bits,
            autogen_ssh_key   => $autogen_ssh_key,
            ssh_old_key_days  => $ssh_old_key_days,
            ssh_auth_keys     => $ssh_auth_keys,
        }
    }

    if $extra_users {
        $extra_users.each |$admin_name, $admin_params| {
            create_resources(
                cftotalcontrol::admin,
                { "${admin_name}" => $admin_params },
                { control_scope => $admin_name }
            )
        }
    }

    file { '/etc/cfscopekeys/':
        ensure  => directory,
        recurse => true,
        purge   => true,
    }
}
