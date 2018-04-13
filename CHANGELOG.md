# Change Log

All notable changes to this project will be documented in this file. This
project adheres to [Semantic Versioning](http://semver.org/).

## 1.0.1 (2018-04-13)
- FIXED: to explicitly control ssh-agent avoiding zombie processes

## 0.12.2 (2018-03-19)
- NEW: add control user to wheel group, if it has access to current host

## [0.12.1](https://github.com/codingfuture/puppet-cftotalcontrol/releases/tag/v0.12.1)
- FIXED: not to pack ruby gems

## [0.12.0](https://github.com/codingfuture/puppet-cftotalcontrol/releases/tag/v0.12.0)
- NEW: version bump of cf* series

## [0.11.1](https://github.com/codingfuture/puppet-cftotalcontrol/releases/tag/v0.11.1)
- NEW: Puppet 5.x support
- NEW: Ubuntu Zesty support

## [0.11.0]
- Fixed passing of additional arguments on non-pssh invocation
- Enforced public parameter types
- Added 'ntpdate' and 'kernvercheck' mass commands
- Converted to cfauth::sudoentry
- Switched to use cfsystem::query() from PuppetDB termini
- Disabled pssh host timeout
- Changed to depend on cfsystem and uses its internal API

## [0.10.0]
- Updated CF deps to v0.10.x
- Version bump
- Fixed puppet-lint issues

## [0.9.5]
- Updated dep versions
- Fixed private key check expiration

## [0.9.4]
- Fixed to pass strict mode checking

## [0.9.3]
- A minor fix for custom host group item sorting for determined file content
- Updated metadata to support Ubuntu Xenian & Debian Stretch

## [0.9.2]
- Added a workaround for regression in Puppet 4.4.x related to default value of optional EPP parameter.

## [0.9.1]
- Added support of specific hostname for lookup of proxy hosts.

## [0.9.0]
Initial release

[0.11.0]: https://github.com/codingfuture/puppet-cftotalcontrol/releases/tag/v0.11.0
[0.10.0]: https://github.com/codingfuture/puppet-cftotalcontrol/releases/tag/v0.10.0
[0.9.5]: https://github.com/codingfuture/puppet-cftotalcontrol/releases/tag/v0.9.5
[0.9.4]: https://github.com/codingfuture/puppet-cftotalcontrol/releases/tag/v0.9.4
[0.9.3]: https://github.com/codingfuture/puppet-cftotalcontrol/releases/tag/v0.9.3
[0.9.2]: https://github.com/codingfuture/puppet-cftotalcontrol/releases/tag/v0.9.2
[0.9.1]: https://github.com/codingfuture/puppet-cftotalcontrol/releases/tag/v0.9.1
[0.9.0]: https://github.com/codingfuture/puppet-cftotalcontrol/releases/tag/v0.9.0

