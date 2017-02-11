#
# Copyright 2016-2017 (c) Andrey Galkin
#


class cftotalcontrol::auth (
    Variant[String[1], Array[String[1]]]
        $control_scope = [],
) {
    include cfauth

    Cftotalcontrol::Internal::Ssh_port <<| hostname == $::trusted['certname'] |>>

    $admin_user = $cfauth::admin_user
    $control_scope_arr = any2array($control_scope)
    $control_scope_arr.each |$cs| {
        cftotalcontrol::internal::scope_anchor{ $cs: }
    }

    $tc_keys = puppetdb_query([ 'from', 'facts',
        ['extract', ['certname', 'name', 'value'],
            ['and',
                ['in', 'name',
                    ['array', ['cf_totalcontrol_scope_keys', 'cf_totalcontrol_key']]
                ],
                ['null?', 'value', false]
            ],
        ],
    ])

    $tc_keys.each |$f| {
        $node = $f['certname']

        if $f['name'] == 'cf_totalcontrol_key' {
            $factkey = $f['value']
            ssh_authorized_key { "${admin_user}-cftc@${node}":
                user    => $admin_user,
                type    => $factkey['type'],
                key     => $factkey['key'],
                require => User[$admin_user],
            }
        } elsif $f['name'] == 'cf_totalcontrol_scope_keys' {
            $scope_keys = $f['value']

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
