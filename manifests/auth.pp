
class cftotalcontrol::auth (
    $control_scope = [],
) {
    include cfauth
    
    Cftotalcontrol::Internal::Ssh_port <<| hostname == $::trusted['certname'] |>>
    
    $admin_user = $cfauth::admin_user
    $control_scope_arr = any2array($control_scope)
    
    $tc_keys = query_facts("Class['cftotalcontrol']", [
        'cf_totalcontrol_key',
        'cf_totalcontrol_scope_keys'
    ])
    
    $tc_keys.each |$node, $f| {
        $factkey = $f['cf_totalcontrol_key']
        
        if $factkey {
            ssh_authorized_key { "${admin_user}@${node}":
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
                    ssh_authorized_key { "${admin_user}@${node}/${cs}":
                        user    => $admin_user,
                        type    => $factkey['type'],
                        key     => $factkey['key'],
                        require => User[$admin_user],
                    }
                }
                
                $csuser = "${cs}_proxy"
                
                # If user got defined by imported resources above
                # then add special scope proxy user
                if defined(User[$csuser]) {
                    ssh_authorized_key { "${csuser}@${node}/${cs}":
                        user    => $csuser,
                        type    => $scopekey['type'],
                        key     => $scopekey['key'],
                        require => User[$csuser],
                        options => {
                            command => "/bin/echo 'FORBIDDEN'",
                        }
                    }
                }
            }
        }
    }
}
