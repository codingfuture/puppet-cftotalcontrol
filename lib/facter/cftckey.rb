Facter.add('cf_totalcontrol_key') do
    setcode do
        if File.exists? '/etc/cftckey'
            keycomp = File.read('/etc/cftckey').split(/\s+/)
            {
                'type' => keycomp[0],
                'key' => keycomp[1],
            }
        end
    end 
end
