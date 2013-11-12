# How to use this example bootstrap

1. Run a search and replace for `site-name` to whatever the subdomain for your development site will be
2. Run a search and replace for `site_name` to whatever the database name for your development site will be
3. Run a search and replace for `Site Name` to whatever the human readable name for your development site will be
4. Remove these initial instructions, leaving the "Development environment bootstrap" heading and everything below it
5. Create a deploy user on your GitHub repo, create a set of private and public keys for this user and upload the public key to GitHub. Copy the public *and private* keys for this user into the `ssh` folder of this bootstrap. Give this user pull permissions. **NOTE: You have a potential security issue if you give this user push (or GitHub admin) permissions, as you are distributing the private key for the user!**
6. Amend the "Development environment bootstrap" heading and paragraph below so it reflects your purpose for the particular development environment
7. Test everything works as expected in a [VVV](https://github.com/10up/varying-vagrant-vagrants/) context
8. Copy or `git push` to a new repo or new branch in an existing repo
9. Point people towards the `readme.md` in the repo you pushed to, so they can get going

# Development environment bootstrap

This site bootstrap is designed to be used with [Varying Vagrants Vagrant](https://github.com/10up/varying-vagrant-vagrants/) and a WordPress single site, the code for which is stored as a monolithic (or submoduled, probably) Git(Hub) repo.

To get started:

1. If you don't already have it, clone the [Vagrant repo](https://github.com/10up/varying-vagrant-vagrants/) (perhaps into your `~/Vagrants/` directory, you may need to create it if it doesn't already exist)
2. Install the Vagrant hosts updater: `vagrant plugin install vagrant-hostsupdater`
3. Clone this branch of this repo into the `www` directory of your Vagrant as `www/site-name`
4. If your Vagrant is running, from the Vagrant directory run `vagrant halt`
5. Followed by `vagrant up --provision`.  Perhaps a cup of tea now? The initial provisioning may take a while.
6. If you want the user uploaded files, you'll need to download these separately

Then you can visit:
* [http://site-name.dev/](http://site-name.dev/)

