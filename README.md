# eos-flash-tools

This repo contains the various flashing tools that aid in the image flashing process, but that do not live on the image itself.

## eos-usb-reflash

We are taking advantage of the `eos-factory-test` service in order to automatically detect and run a new reflashing system. The system works as described [on its wiki page](https://github.com/endlessm/eos-documentation/wiki/USB-Reflashing). 

### How to regenerate the necessary files
Here are descriptions of the three files required on a drive to run this system.

- `Wistron_Factory_Test.tar`. This is a compressed folder that contains `start.sh`, the shell script that sets up the initramfs, and `initramfs-3.13.0-27.generic.img`, the compressed initramfs.
- `Wistron_Factory_Test.tar.sha256`, the sha256 checksum.
- *.gz, the image that is to be flashed on the machine. _Note: There should only be one image on the USB that matches this pattern._

Although our S3 servers will contain all the necessary files, here are instructions to generate these files from this repo.
- Checkout the master version of this repo.
- Build an initramfs using the included image.
    ```
    # cd eos-usb-reflash
    # cp -R 99reflash /usr/lib/dracut/modules.d/ 
    # cd factory-test
    # dracut -f --add "reflash dash drm kernel-modules resume ostree systemd base" --libdirs="/lib/i386-linux-gnu /usr/lib/i386-linux-gnu /lib/i686-linux-gnu /usr/lib/i686-linux-gnu" initramfs.img 3.13.0-27-generic
    # cd ..
    ```
- Package `factory-test` into an uncompressed tar archive without the top-level directory, using 
    ```
    # tar -C factory-test -c . -f Wistron_Factory_Test.tar
    ```
- Make the sha256 checksum of that tar archive.
    ```
    # sha256sum Wistron_Factory_Test.tar > Wistron_Factory_Test.tar.sha256
    ```

- Finally, the files `Wistron_Factory_Test.tar` and `Wistron_Factory_Test.tar.sha256` should be copied into the root directory of a USB Drive. The image that is to be flashed should also be on this drive and should have a name that ends in `.gz` (e.g. `eos-eos2-i386-i386.150112-220042.Guatemala.img.gz`).

