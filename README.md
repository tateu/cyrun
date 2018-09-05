# cyrun
For the Electra iOS 11 Jailbreaks.

cyrun is comprised of an executable and bash script. It will

* Enable/disable the cycriptListenerTweak dylib file (which loads Cyript and runs a CYListenServer on port 8556)
* Write the App bundleIdentifier or Process Executable Name to the tweak filter plist
* Kill the App/Process and, if it is an App, they will be relaunched automatically by Cyrun. Other, non App processes, may need to be manually launched if iOS does not handle that on it's own like it does for SpringBoard and backboardd.
* If enabled successfully, the bash script will then run `cycript -r 127.0.0.1:8556`

It is meant to be used alongside [cycriptListenerTweak](https://github.com/tateu/cycriptListenerTweak).

# INSTALLATION

	# From SSH or terminal as root
	cd ~
	# download https://electrarepo64.coolstar.org/debs/ncurses_6.1_iphoneos-arm.deb
	# download http://apt.saurik.com/debs/readline_6.0-8_iphoneos-arm.deb
	# download http://apt.saurik.com/debs/cycript_0.9.594_iphoneos-arm.deb
	# download https://electrarepo64.coolstar.org/debs/ldid_2_1.2.2-coolstar_iphoneos-arm.deb
	# download http://www.tateu.net/repo/files/net.tateu.cycriptlistenertweak_1.0.0_iphoneos-arm.deb
	# download http://www.tateu.net/repo/files/net.tateu.cyrun_1.0.4_iphoneos-arm.deb
	dpkg -i ncurses_6.1_iphoneos-arm.deb
	dpkg -i readline_6.0-8_iphoneos-arm.deb
	dpkg -i cycript_0.9.594_iphoneos-arm.deb
	dpkg -i ldid_2_1.2.2-coolstar_iphoneos-arm.deb
	dpkg -i net.tateu.cycriptlistenertweak_1.0.0_iphoneos-arm.deb
	dpkg -i net.tateu.cyrun_1.0.4_iphoneos-arm.deb

The newest versions of cyrun and cycriptListenerTweak can be found on [my repo in Cydia](http://www.tateu.net/repo/).

And then you can use the bash script to sign the Cycript binaries with the correct Electra entitlements

	cyrun -s

Then you can load Cycript into SpringBoard. SpringBoard will be terminated and auto restart

	cyrun -n SpringBoard -e

Or you can unload Cycript from SpringBoard. SpringBoard will be terminated and auto restart

	cyrun -n SpringBoard -d

Or you can load and auto unloaded Cycript from the iOS Mail App. Mail will be terminated and auto restart. When you ?exit Cycript, it will be killed and unloaded.

	cyrun -n Mail -e -d

Or you can load and auto unloaded Cycript from backboardd. backboardd will be terminated and auto restart. When you ?exit Cycript, it will be killed and unloaded.

	cyrun -x backboardd -e -d

The '-n' command takes an AppName, ExecutableName, IconName or LocalizedName.

You can use a bundleIdentifier instead of an App name with `'-b com.apple.springboard'`

You can also turn off the 'ask to continue' prompts with '-f'

	cyrun -b com.apple.mobilemail -e -d -f

You can also load a Cycript scipt file

	cyrun -b com.apple.mobilemail -e -d -f -c /path/to/script.cy

If you try to enable Cycript for an App that is not SpringBoard while your device is passcode locked, you will see a warning message, since it will most likely fail for most Apps.

Unfortunately, some things still do not work correctly, possibly (most likely) due to the fact we are using Substitute on iOS 11 and not Substrate.

	@import com.saurik.substrate.MS;
	// the above succeeds without error but trying to use any of the functions it imports results in errors such as
	// throw new Error("*** _require(class_getInstanceMethod(_class, sel)):../ObjectiveC/Library.mm(2711):Selector_callAsFunction_type") /* type@[native code] hookMessage */
	@import net.limneos.classdumpdyld;
	// the above succeeds without error but trying to use any of the functions it imports results in errors such as
	// throw #"-[NSBundle isKindOfClass:]: unrecognized selector sent to instance 0x10110c1a0"
