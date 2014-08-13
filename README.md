# foreman_registration

A custom Foreman plugin used to Create/Register nodes. If the node already exists, simply call the CA Smart Proxy and revoke the existing certificate.

Suitable for use in scripted registrations.

## Installation

You must first define a `Puppet CA` Smart Proxy in Foreman. Then...

Add this line to your application's Gemfile:

    gem 'foreman_registration', :git => "https://github.com/sfu-rcg/foreman_registration.git"

After that you'll need to create the bundle for foreman, as foreman user run
from the *FOREMAN_DIR*:

    bundle install

Restart Foreman:

    touch tmp/restart.txt

## Usage

All params are required, and it only accepts the following attributes:

* name
* certname
* environment_id
* hostgroup_id

Example:

    curl -H "Content-type:application/json" -XPOST -s -d '{ "name": "foo.bar.com", "certname": "foo.bar.com", "environment_id": "1", "hostgroup_id": 1}' -k -u user:pass "https://myforemaninstall.com/api/register"

## Copyright

2014 Simon Fraser University