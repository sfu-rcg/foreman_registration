# ForemanRegistration

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

    gem 'foreman_registration', :git => "https://github.com/sfu-rcg/foreman_registration.git"

After that you'll need to create the bundle for foreman, as foreman user run
from the *FOREMAN_DIR*:


    $ bundle --deploy

Or install it yourself as:

    $ gem install foreman_registration

## Foreman 1.1

In order to work, the foreman application must be the following two lines commented out.

config/routes.rb

    # match '*a', :to => 'errors#routing'

config/routes/v1.rb

    # match '*other', :to => 'home#route_error'


## Usage

    $ curl -u admin:secret -H 'accept:application/json' http://0.0.0.0:3000/api/register