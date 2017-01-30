Welcome to SKIMEnabler!
=====================


Summary
---------

Skim does not work on Sierra, because Apple seriously fucked up its
PDFKit framework, on which Skim relies. A large number of users is
affected, and for several months there was no easy way out. Apple,
on their side, have not fixed the problem and appear not to care.

Like other people, I have created multiple workarounds for this problem,
which all had basically involved somehow using an older version of PDFKit.
This has side-effects mostly on the Preview App, which is why we needed
to switch back and forth between the versions of PDFKit.

This work here finally solves this problem: It provides for a preconfigured
Framework directory structure that contains the working PDFKit, and otherwise
only symbolic links, and more importantly it contains an installer script
that deploys the workaround and applies the required patches with one
simple line.

So if you have your version of Skim in your **/Applications** folder,
and have cloned / downloaded this solution, you can also ignore the
rest of this description, open to a Terminal window, go to whereever
you have downloaded the solution (where you find a file **install.sh**),
and just execute this command:

```
./install.sh
```


My prior work
-------------

This is a little patch script (and documentation) that I came up with
motivated by Andrea Alberti who contacted me because of the article I
had written [here](http://www.mnott.de/how-to-workaround-the-fucked-up-pdfkit-in-sierra/),
trying to work around the completely fucked up PDFKit implementation
that Apple is torturing its customers with - and that, most importantly,
prevents the awesome application [Skim](http://skim-app.sourceforge.net)
from working correctly. You can read more about the problem
[on the Skim forum](https://sourceforge.net/p/skim-app/bugs/1109/).

My solution was to create a wrapper script that would, before starting
Skim, replace the PDFKit by an older version (of Mavericks), then start
Skim, and then replace back the PDFKit by its current version, doing
this process:

1. Swap the default PDFKit with the Mavericks one
2. Launch Skim
3. Wait some 5 seconds
4. Swap the PDFKit back in favor of the default one

The biggest drawback of this approach was that, besides having to switch
around the PDFKit all the time, you also needed to leave System Integrity
Protection off, all the time.

Andreas Work
------------

Andrea Alberti had the idea of replacing the whole Quartz framework,
of which PDFKit is a part, by a patched version which would include
the older, working, version of PDFKit - and then to patch Skim to
refer to the older version of the Quartz framework, as well as making
sure that that older version of the Quartz framework does not suddenly
still refer to the newer version.

The drawback of this approach is, basically, that you need to have a full
copy of the Quartz framework, while what you really want is to just replace
the PDFKit inside it.

My Contribution
---------------

This is exactly what I did: I revisited what was needed: Essentially,
you have

```
/System/Library/Frameworks/Quartz.framework
```

That directory contains the PDFKit Framework:

```
/System/Library/Frameworks/Quarks.framework/Versions/Current/Frameworks/PDFKit.framework
```

Which is what we want to replace by the Mavericks version. It also
contains the binary

```
/System/Library/Frameworks/Quarks.framework/Versions/Current/Quartz
```

which has an absolute reference to

```
/System/Library/Frameworks/Quarts.framework
```

Similarly, inside the Skim.app, there are four files which contains
an absolute reference to that same location:

```
Skim.app/Contents/Frameworks/SkimNotes.framework/Versions/A/SkimNotes
Skim.app/Contents/Library/Spotlight/SkimImporter.mdimporter/Contents/MacOS/SkimImporter
Skim.app/Contents/MacOS/Skim
Skim.app/Contents/SharedSupport/skimpdf
```

What I hence did was to first of all create a **Quarks.framework**
(mind the spelling!) that consists of mostly relative symbolic links
to the real **Quartz.framework**, except for the PDFKit, where it
contains the actual Maverics version.

This directory structure is meant to be put next to the original
**Quartz.framework**.

I then shamelessly recycled a little Perl script, **patch.pl**, which
I had found somewhere on the Internet over 10 years ago and have,
unfortunately, no reference of the author - and I use that script
to patch binary files - i.e. the four files from Skim, as well as
the Quartz binary mentioned above, replacing

```
/System/Library/Frameworks/Quartz.framework
```

by


```
/Applications/Skim.app/Contents/Q.framework
```

**Note:**

User Kevin L on the Skim forum tried successfully to deploy
the **Quarks.framework** in a location that is not protected by SIP.
The only requirement is that the location is of the same string length
as the original Quartz.framework. I have hence adapted the install script
and am deploying now, unless you configure otherwise, at the top of the
script, into the Skim.app directory. I.e., instead of the "Quarks"
location I had previously used:

```
/System/Library/Frameworks/Quarks.framework
```

I now use

```
/Applications/Skim.app/Contents/Q.framework
```

You can configure that at the top of the script, and the script
checks for the identical length of the strings.

That binary patch removes the need to use **install_name_tool**, which
Andrea used, and which I did find to not work in all cases: Essentially,
we know that the reference to our library is available as plain text in
our binaries, so we can replace that string by a different string of
exactly the same length (**Quarks** instead of **Quartz**). Andrea also
saw the need to use a binary patch, and provided a Python script for
that purpose; I preferred my Perl script as I know that Perl is going
to be available, and also, have seen that script working in all sorts
of situations over a decade.

Out of interest, if you want to verify which libraries a binary, e.g.,
Skim, refers to, you can use the command **otool -L Skim**.

Finally, I wrote a litte installer, **install.sh**, which takes away
from you the whole deployment process.


Open Points
-----------

For some reason, on my system, I have observed that I don't even need
to patch the four files from Skim - which appears to make no sense, as
they contain absolute references to the original (broken) Quartz.framework.
In other words, it was sufficient for me to just deploy Quarks.framework
next to Quartz.framework, and that was it. This is something I don't yet
have enough information to make sense of, so feel free to investigate.
I chose to anyway patch the binaries of Skim, to be on the safe side.


Installation
============

Once you have downloaded the distribution from the git repository,
either using **git clone https://github.com/mnott/skimenabler** or
using the **Clone or Download - Download ZIP** menu option on the
GitHub web page, you should end up with a directory that contains,
among other things, a file **install.sh**.

If you do not have your **Skim.app** under **/Applications**, you
need to open **install.sh** in an editor and modify, towards the
top of the file, the location of Skim:

```
#
# Your Location of Skim.app
#
SKIM=/Applications/Skim.app

#
# To work, needs to be the exact same length as
#
#      /System/Library/Frameworks/Quartz.framework
#
QUARKS=/Applications/Skim.app/Contents/Q.framework

#
# Whether to check SIP
#
SIPCHECK=false

#
# Whether to check for being root
#
ROOTCHECK=false
```

You need to check for SIP only if you deploy beneath a directory
structure beneath **/System**; in that case, and also if your location
of **Skim.app** is not owned by you, you also need to check
for being root, and run the script with **sudo ./install.sh** instead
of just **./install.sh**.

Then, in a Terminal window, go to the directory where you have
**install.sh** and just run this command (though not strictly
necessary, you might want to close Skim before doing this, should
you have Skim running):

```
./install.sh
```

The program will attempt a large number of verifications, and it
will also create backups of any file it is going to patch.


Final Thoughts
==============

Remember to redo the process if you apply a system update to MacOS,
or get a new version of Skim. Also, please do check out very much in
detail before you attempt to do this on "the next version of MacOS" -
as we have no idea whether this process will make any sense there.

Before I patch a new version of Skim, or MacOS, I of course first of
all check whether the patch is still needed at all.

Also, please make sure to [let Apple know](https://bugreport.apple.com)
how much annoyed you are.


