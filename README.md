# foreman_registration

A custom Foreman plugin used to Register and Manage node records and associated their certificates.

## Installation

You must first define a `Puppet CA` Smart Proxy in Foreman. Then...

Add this line to your application's Gemfile:

    gem 'foreman_registration', :git => "https://github.com/sfu-rcg/foreman_registration.git"

After that you'll need to create the bundle for foreman, as foreman user run
from the *FOREMAN_DIR*:

    bundle install

Restart Foreman:

    touch tmp/restart.txt

## Configuration

IP Access Restrictions for the API can be configured via Foreman Settings

## Usage

####\#register [POST] via /api/register
- registers a new node
- required params: ‘login’, 'name', 'environment_id', 'hostgroup_id', ‘mac’
- will validate against duplicate node names and mac addresses and return 403

####\#reset [POST] via /api/reset
- revokes a known host’s certificate
- required params: ‘login’, 'name'
- unknown certs still return 200 but get logged differently
- returns 403 if authorization fails; will validate that the login is authorized to perform action on ‘name’

####\#decommission [POST] via /api/decommission
- revokes a known host’s certificate and destroys the Foreman record
- required params: ‘login’, 'name'
- returns 403 if authorization fails; will validate that the login is authorized to perform action on ‘name’

####\#registration\_status [GET] via /api/registration\_status\
- searches registration status via certname
- required params: ‘certname’
- returns the JSON hash: hostname, last_report, and whether or not the clients certificate exists
- always returns 200 and Hash

####\#reg\_environments [GET] via /api/reg_environments
- required params: ‘login’
- returns JSON list (Array) of Environment objects
- ALL Environments are retuned regardless of ‘login'

####\#reg\_hostgroups [GET] via /api/reg_hostgroups
- required params: ‘login’
- returns JSON list (Array) of Hostgroup objects; filtered list!
- only Hostgroups the ‘login' is authorized to see are returned

Example:

    curl -H "Content-type:application/json" -XPOST -s -d '{ "name": "foo.bar.com", "certname": "foo.bar.com", "environment_id": "1", "hostgroup_id": 1, "mac": "ff:ff:ff:ff:ff:ff", "login": "user"}' -k -u user:pass "https://myforemaninstall.com/api/register"

## Copyright

_2014 Simon Fraser University_

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.