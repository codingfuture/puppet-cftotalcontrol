
class cftotalcontrol::auth {
    include cfauth
    
    $admin_user = $cfauth::admin_user
    
    $tc_keys = query_facts("Class['cftotalcontrol']", ['cf_totalcontrol_key'])
    
    $tc_keys.each |$node, $f| {
        $factkey = $f['cf_totalcontrol_key']
        ssh_authorized_key { "${admin_user}@${node}":
            user    => $admin_user,
            type    => $factkey['type'],
            key     => $factkey['key'],
            require => User[$admin_user],
        }
    }
}
