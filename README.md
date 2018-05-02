# Ubuntu-Mini-Respin

This is an attempt to recreate Minibuntu/Ubuntu Mini Remix.

The scripts create a new install ISO based on a server ISO with as few dependencies as possible.

A script is provided to create a Virtualbox VM and boot the ISO. 
The ISO is set to run unattended and by the end of the process you should have a running, fully configured Ubuntu VM

# Pre-requisites

You will need already VirtualBox installed if you want to test out the iso in a VM.

    sudo apt install virtualbox

Or you could load it onto a USB and test the LiveCD/LiveUSB.

It is also a good idea to install the *apt-cacher-ng* package. 
The *apt-cacher-ng* package will act as a caching proxy, so you can build the customised ISO several times and only have to download the packages once.

    sudo apt-get install apt-cacher-ng

Once that process is finished, you should be able to open up http://127.0.0.1:3142 in a web browser to verify it is installed.

The short version of the instructions on that page are:

    echo 'Acquire::http { Proxy "http://127.0.0.1:3142"; };' | sudo tee --append /etc/apt/apt.conf.d/00aptproxy
    sudo apt-get update

You can see stats at http://127.0.0.1:3142/acng-report.html

# Making Your Customisations

The `test1` directory has a file called `config` which holds the customisations
that we want to apply to the Minimal Ubuntu CD. You can make your own
directories, so that you can build multiple, different, customised ISO files.

Here are the contents of the `config` file:

```
# Config file used by the customise_iso script
username=fred
password=abc123
rootpassword=abc123
hostname=ubuntu
timezone=Australia/Brisbane
proxy=http://172.17.120.172:3142
base_system=lubuntu-desktop
orig_iso=/tmp/mini_17.04.iso
new_iso=/tmp/custom.iso
packages="rcs, build-essential"
late_command='sh /copyit'
```

The compulsory lines are *username*, *password*, *hostname*, *timezone*,
*proxy*, *base_system*, *orig_iso*, *new_iso* and *packages*.

The *username*, *password*, *hostname* and *timezone* should be obvious. The
*proxy* is the URL of your caching proxy. The *orig_iso* is the absolute
location of the Minimal Ubuntu CD on your system. The *new_iso* is the
absolute location of the customised ISO that will be created.

You need to choose a specific Ubuntu distribution to customise. This is
done with the *base_system* line. According to
[this web page](https://help.ubuntu.com/16.04/installation-guide/amd64/apbs04.html#preseed-pkgsel),
the available options are:
*    standard (standard tools)
*    ubuntu-desktop
*    kubuntu-desktop
*    edubuntu-desktop
*    lubuntu-desktop
*    ubuntu-gnome-desktop
*    xubuntu-desktop
*    ubuntu-mate-desktop
*    lamp-server
*    print-server (print server)

If you want extra packages installed, list them as comma-separated
names on the *packages* line.

In the `test1` directory, there is a subdirectory called `cdrom`. Anything
in this directory is included at the top-level of the `initrd` on the
customised ISO image. These files will be visible in the root directory
during the installation process.

The *late_command* line contains a command which runs during the installation
process. You can use this to do extra customisations which are not already
covered. Have a look at the `test1/cdrom/copyit` and `test1/cdrom/rc.local`
scripts. These copy the VirtualBox Guest Additions to the VM's hard disk,
and then install the Guest Additions on the first boot from the hard disk.

# Running the Scripts

Assuming that you have downloaded the Minimal Ubuntu CD to
`/tmp/mini_17.04.iso`, you can now run the `customise_iso` script
to build the customised ISO at `/tmp/custom.iso`:

```
$ ./customise_iso test1
Unpacking /tmp/mini_17.04.iso
Adding test1/preseed.cfg: 8 blocks
Adding extra files from test1/cdrom: 15902 blocks
Generating /tmp/custom.iso
```

With the customised ISO now generated, you can start a VirtualBox VM and
install the system with the `vbox_boot` script:

```
$ ./vbox_boot test1
0%...10%...20%...30%...40%...50%...60%...70%...80%...90%...100%
Virtual machine 'test1' is created and registered.
UUID: 1d36dc56-06dc-4184-bfc1-2c63936c460c
Settings file: '/d/VirtualBox/test1/test1.vbox'
0%...10%...20%...30%...40%...50%...60%...70%...80%...90%...100%
Medium created. UUID: 10d89167-76ee-49b3-88c0-cf239fa95f7f
Name:            test1
Groups:          /
Guest OS:        Ubuntu (64-bit)
UUID:            1d36dc56-06dc-4184-bfc1-2c63936c460c
Config file:     /d/VirtualBox/test1/test1.vbox
Snapshot folder: /d/VirtualBox/test1/Snapshots
Log folder:      /d/VirtualBox/test1/Logs
Hardware UUID:   1d36dc56-06dc-4184-bfc1-2c63936c460c
Memory size:     512MB
< lots more details of the VM omitted >

Waiting for VM "test1" to power on...
VM "test1" has been successfully started.
```

A new VM window will appear, the ISO will boot and the Ubuntu system
will be installed.

# Things to Do

This is still a work in progress, but it's probably a good starting-off
point for you to make your own changes. Some things to add:

* Separate scripts for launching the install in VMware etc.
* More customisations to add the user, key etc. as required by Vagrant
* Another script to shut down the VM and package up a Vagrant box

Yes, I know that this could all be done with Packer. Feel free to show me
how! I just wanted to try doing it with a couple of simple shell scripts :-)

P.S. I borrowed most of the ideas and the shell code from other Github
repositories and from various web pages. I wish I had kept track of the
sources, so my apologies to those people who wrote the original code.







recreate.sh is from  https://github.com/Blitznote/debase/issues/2
build.manifest is from https://github.com/Blitznote/debase/blob/master/17.04/amd64/build.manifest

bash ./recreate.sh            # creates the configuration file needed below

apt-get -q update
apt-get -y install multistrap # run this after recreate.sh!

multistrap -f multistrap.conf # assembles an Ubuntu baseimage (aka "stage 1")



Keep in mind you will get installed more than necessary:

Ubuntu's maintainers sometimes add requirements to packages which are not really requirements, but should've been marked as suggestions instead. Uninstall something like mount or libudev1.
As Docker/rkt/runC images are not used for interactive systems, you don't need packages like login or askpass.
… nor are – for example – any translation files (*.po *.mo) needed if you're fine with a default locale. (Most DevOps will debug or browse manpages using a separate installation anyway.)
Pruning those packages and deleting those excess files is something I do on a case-by-case basis. In a gist, everything that's not in the supplied build.manifest has been removed using apt remove…. This will yield a list of said cruft and uninstall it:

excess=($(comm -23 <(apt-mark showmanual | sort -u) <(cat build.manifest | cut -f 1)))
for pkg in ${excess[@]}; do
  apt-get remove "${pkg}"
done






# Run multistrap to generate the rootfs
sudo multistrap --file multistrap.conf
