# eos-flash-tools

This repo contains the various flashing tools that aid in the image flashing process, but that do not live on the image itself.

## eos-usb-reflash

We are taking advantage of the `eos-factory-test` service in order to automatically detect and run a new reflashing system. The system works as described [on its wiki page](https://phabricator.endlessm.com/w/field/automatic_usb_reflash/).

### How to regenerate the necessary files
Here are descriptions of the three files required on a drive to run this system.

- `Endless_Factory_Test.tar`. This is a compressed folder that contains `start.sh`, the shell script that sets up the initramfs, and `initramfs-3.13.0-27.generic.img`, the compressed initramfs.
- `Endless_Factory_Test.tar.sha256`, the sha256 checksum.
- *.img.gz, the images that are to be flashed on the machine.
_Note: If two images are to be flashed (in the case of a Sqwerty with 2 images, the image that will be flashed on the eMMC should have "disk1" in the name, as in "eos2.2.disk1.img.gz". The image for the SD card should similarly have "disk2" in the name. Any image that contains neither of these strings will be assumed to be an image that should be flashed for a single storage device machine)._

For convenience (until we have this set up for continuous integration / releases to S3), built files have been committed to eos-usb-reflash/usb-files under an architecture-specific directory.

Here are instructions to generate these files from this repo.
- Checkout the master version of this repo.
- Build an initramfs using the included image.
```
    # cd eos-usb-reflash
    # cp -R 99reflash /usr/lib/dracut/modules.d/ 
    # cd factory-test
    # dracut -f --modules "reflash" initramfs.img $(uname -r)
    # cd ..
```
- Package `factory-test` into an uncompressed tar archive without the top-level directory, using: 
```
    # tar -C factory-test -c . -f Endless_Factory_Test.tar
```
- Make the sha256 checksum of that tar archive.
```
    # sha256sum Endless_Factory_Test.tar > Endless_Factory_Test.tar.sha256
```

- Finally, the files `Endless_Factory_Test.tar` and `Endless_Factory_Test.tar.sha256` should be copied into the root directory of a USB Drive.

