#
# Copyright 2016 (c) Andrey Galkin
#


class cftotalcontrol::auth (
    $control_scope = [],
) {
    include cfauth

    Cftotalcontrol::Internal::Ssh_port <<| hostname == $::trusted['certname'] |>>

    $admin_user = $cfauth::admin_user
    $control_scope_arr = any2array($control_scope)
    $control_scope_arr.each |$cs| {
        cftotalcontrol::internal::scope_anchor{ $cs: }
    }

    $tc_keys = query_facts("Class['cftotalcontrol']", [
        'cf_totalcontrol_key',
        'cf_totalcontrol_scope_keys'
    ])

    $tc_keys.each |$node, $f| {
        $factkey = $f['cf_totalcontrol_key']

        if $factkey {
            ssh_authorized_key { "${admin_user}-cftc@${node}":
                user    => $admin_user,
                type    => $factkey['type'],
                key     => $factkey['key'],
                require => User[$admin_user],
            }
        }

        $scope_keys = $f['cf_totalcontrol_scope_keys']

        if is_hash($scope_keys) {
            $scope_keys.each |$cs, $scopekey| {
                # If scope match - add admin access
                if $cs in $control_scope_arr {
                    ssh_authorized_key { "${admin_user}-${cs}@${node}":
                        user    => $admin_user,
                        type    => $scopekey['type'],
                        key     => $scopekey['key'],
                        require => User[$admin_user],
                    }
                }
            }
        }
    }
}
