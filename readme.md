# Development environment bootstrap

This site bootstrap is designed to be used with [Varying Vagrants Vagrant](https://github.com/10up/varying-vagrant-vagrants/).

To get started:

1. If you don't already have it, clone the [Vagrant repo](https://github.com/10up/varying-vagrant-vagrants/) (perhaps into your `~/Vagrants/` directory, you may need to create it if it doesn't already exist)
2. Install the Vagrant hosts updater: `vagrant plugin install vagrant-hostsupdater`
3. Clone this branch of this repo into the `www` directory of your Vagrant as `www/site-name`
4. If your Vagrant is running, from the Vagrant directory run `vagrant halt`
5. Followed by `vagrant up --provision`.  Perhaps a cup of tea now? The initial provisioning may take a while.
6. If you want the user uploaded files, you'll need to download these separately

Then you can visit:
* [http://site-name.dev/](http://site-name.dev/)

