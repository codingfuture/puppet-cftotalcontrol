#
# Copyright 2016-2017 (c) Andrey Galkin
#


define cftotalcontrol::internal::ssh_port (
    String[1] $hostname,
    Array[Integer[1,65535]] $ports,
    Optional[String[1]] $control_scope = undef,
    Optional[String[1]] $key_certname = undef,
) {
    include cfauth

    if $control_scope {
        $portuser = "${control_scope}_proxy"
        $deploy_cmd='/opt/puppetlabs/bin/puppet agent --test'

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
            } ->
            file { "/home/${portuser}/forced_command.sh":
                group   => $portuser,
                owner   => $portuser,
                mode    => '0755',
                content => "#!/bin/sh
test \"\$SSH_ORIGINAL_COMMAND\" = \"sudo ${deploy_cmd}\" && sudo ${deploy_cmd}
",
            }
            cfauth::sudoentry { $portuser:
                command => $deploy_cmd,
            }
        }

        $scope_keys = puppetdb_query([
            'from', 'facts', ['extract', ['value'],
                ['and',
                    ['=', 'certname', $key_certname],
                    ['=', 'name', 'cf_totalcontrol_scope_keys'],
                ],
            ],
        ])

        if size($scope_keys) > 0 {
            $scopekey = $scope_keys[0]['value'][$control_scope]

            if $scopekey {
                ssh_authorized_key { "${control_scope}@${key_certname}":
                    user    => $portuser,
                    type    => $scopekey['type'],
                    key     => $scopekey['key'],
                    require => User[$portuser],
                    options => [
                        "command=\"/home/${portuser}/forced_command.sh\"",
                    ],
                }
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
