#
# Copyright 2016 (c) Andrey Galkin
#

Facter.add('cf_totalcontrol_key') do
    setcode do
        if File.exists? '/etc/cftckey'
            keycomp = File.read('/etc/cftckey').split(/\s+/)
            
            if keycomp.size < 2
                nil
            else
                {
                    'type' => keycomp[0],
                    'key' => keycomp[1],
                }
            end
        end
    end 
end
