#
# Copyright 2016-2019 (c) Andrey Galkin
#


class cftotalcontrol (
    Variant[String[1], Boolean]
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
    Cfsystem::Keytype
        $ssh_key_type = 'rsa',
    Cfsystem::Rsabits
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

    $control_user_act = $control_user ? {
        true => 'cftcuser',
        default => $control_user,
    }

    if $control_user =~ String[1] {
        if $control_home {
            $act_control_home = $control_home
        } else {
            $act_control_home = "/home/${control_user}"
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
