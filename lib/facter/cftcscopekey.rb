#
# Copyright 2016-2018 (c) Andrey Galkin
#

Facter.add('cf_totalcontrol_scope_keys') do
    setcode do
        Dir.glob('/etc/cfscopekeys/*').reduce({}) do |ret, f|
            keycomp = File.read(f).split(/\s+/)
            
            if keycomp.size >= 2
                s = File.basename(f)
                ret[s] = {
                    'type' => keycomp[0],
                    'key' => keycomp[1],
                }
            end
            ret
        end
    end 
end
