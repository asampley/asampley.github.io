---
layout: post
title: Encrypting and the Cloud
subtitle: For files you want backed up, but quite secure from prying eyes.
---

The cloud is a very convenient location to put your stuff. Whether it's photos, videos, documents,
you name it. Now you can access it on your phone, tablet, laptop, someone else's computer if you
need to. How convenient!

There's just one glaring problem. Maybe you have some files, that you want to keep safe, in case
something should happen to your devices, but they're for your eyes only, and these ones, *you would
really like to keep this way*. If you put them on Google Drive, OneDrive, iCloud, well, they're
sorta secure? But there are two people that can see your files. You can (of course), but so can the
company that holds the servers actually holding your files. And if two people can see it, you are
now trusting the company is acting in your best interests at all times, and that they have properly
secured your files from both outside ***and*** inside threats. But today is no time for enumerating
the ways in which companies may use your data to exploit you or get you in trouble. Today, we talk
just about how to protect yourself, while keeping all the convenience you can.

# The Cloud

You would like to put your files up in the cloud, but you want to bring the two people who can see
your files down to one (you). The term for this is **End-to-End Encryption** (E2EE). This means
that no intermediary in the middle can see it, which is usually the case when your files are on the
cloud. Your cloud provider sees your files because they have a decryption key to it.

There are several cloud providers that come with their own first party support, and you should
first consider them if you are picking, for the most streamlined experience. We'll cover those
first, but fear not if you have another option in mind, I'll also cover a tool that opens up any
option, but it may not quite be as smooth.

# E2EE Out of the Box

All of these providers claim first party E2EE features. The convenience of this cannot be
overstated, and I recommend going this route if you can. ***However***, most of these require E2EE
to be turned on, so make sure to do that yourself.

And it is worth emphasizing **if you do this the company can no longer help you recover files**.
Leave a recovery code somewhere safe. A bank, a friend, a password manager, etc.

## iCloud

[iCloud Security Overview]: https://support.apple.com/en-us/102651

Apple is probably one of the best, but you'll have to make sure to turn it on first. You can see
from their [iCloud Security Overview] that the default protection is not E2EE.

> Standard data protection is the default setting for your account. Your iCloud data is encrypted,
> the encryption keys are secured in Apple data centers so we can help you with data recovery, and
> only certain data is end-to-end encrypted.

But enabling it seems to be one button press away (I don't have iCloud, number of button presses
may vary).

> Advanced Data Protection for iCloud is an optional setting that offers our highest level of cloud
> data security. If you choose to enable Advanced Data Protection, your trusted devices retain sole
> access to the encryption keys for the majority of your iCloud data, thereby protecting it using
> end-to-end encryption. Additional data protected includes iCloud Backup, Photos, Notes, and more.

I will reiterate, make sure to store your recovery key somewhere safe, even multiple somewheres if
you're feeling adventurous!

## Oh, that's it

Yeah, if you're an individual wanting to do some E2EE on your cloud, your options are pretty
limited all right. Maybe you know of another, maybe you have a favorite, if you're reading this
you probably have my number, let me know!

Now, that's not to say other companies have been sleeping. Maybe you're a business, ready to shell
out for some of the premium plans. Dropbox and Google Drive will look at your money, and realize
maybe they don't need your data after all, your direct cash will serve them well enough. I won't
go into how to enable it for those storage methods, just cause they're less accessible to those
without deeper pockets.

# Cryptomator

This is the tool, and even if you are on iCloud maybe you'd find this useful in some capacity. This
allows you to create encrypted folders. It works on Windows, macOS, Linux, Android, iOS, what more
could you want? **But it is not a cloud provider**. This just encrypts your files, and let's you
decrypt and use them like a normal folder while you have it unlocked on your computer.

Here's the theory, we just break it into two components.
- The cloud: a place where your data goes
- The encryptor: the tool that encrypts your data before it hits the cloud, and decrypts it on
  your computer so you can see it again.

Cryptomator does this by encrypting your file names, encrypting your file data, and adding a bit of
metadata to help you decrypt it back at the end. It's just regular files, so of course, you can put
those "regular files" onto the cloud again.

## Create a vault

It's honestly so simple to create an encrypted vault, it's barely worth explaining, but let's go
through it just to make sure you're convinced (this is on Windows).

![]({{ "assets/blog/encryption-and-the-cloud/cryptomator-setup-1.png" | relative_url }})

Click `Add` and then `New vault`.

![]({{ "assets/blog/encryption-and-the-cloud/cryptomator-setup-2.png" | relative_url }})

Now we pick the location. I'm going to pick my Google Drive mount, so whenever I put files there,
it immediately syncs to Google Drive, because it's a folder in Google Drive!

![]({{ "assets/blog/encryption-and-the-cloud/cryptomator-setup-3.png" | relative_url }})

Pick a strong password!

![]({{ "assets/blog/encryption-and-the-cloud/cryptomator-setup-4.png" | relative_url }})

And you're done. Unlock it with your password in cryptomator, and you'll see it exposes itself
as a regular folder, with the magic of computer science, while secretly writing everything down
and reading everything from an encrypted format.

![]({{ "assets/blog/encryption-and-the-cloud/cryptomator-setup-5.png" | relative_url }})

## Bringing it to the Cloud

Now you remember, somewhere in those steps I picked a location in my Google Drive folder, that I
set up secretly earlier that I downloaded from
[here](https://workspace.google.com/intl/en_ca/products/drive/#download)? Most cloud storage
has applications like this, and it really is just a matter of putting your vault in that synced
location.

![]({{ "assets/blog/encryption-and-the-cloud/cryptomator-google-drive-1.png" | relative_url }})

There's my new, vault I created! Let's take a look inside, on Google Drive.

![]({{ "assets/blog/encryption-and-the-cloud/cryptomator-google-drive-2.png" | relative_url }})

What a horrible mess! But back on our computer where we have it decrypted, we can use it just like
a normal folder. This is what cryptomator actually does, stores your files in an encrypted manner,
and then decrypts it for you to use it as if it weren't even there. So now you can have your cloud
and encrypt it, too.

## The Android App

Now, here's a little disclaimer about my experience. On the desktop, it's free! On your phone, it
is not. And boy oh boy was it a lot harder moving files on a phone, it's just sort of cumbersome,
hidden away, and hard to do en masse. But there are also some more features on the app, that are
perhaps necessary because of the entirely different environment for interaction.

Pros:
- They have built in integration with many cloud providers, so you don't have to set up any syncing
  yourself like on the desktop. Nice!
- They have a feature to automatically take new photos and videos, and add them to a specific
  vault! I've only covered manually dropping on the computer, so a definite boon!

Advisory:
- The photo sync only happens when you unlock your vault. Just be aware.

Cons:
- Moving files into your vault is a hassle. You can share individual files with Cryptomator, as if
  you were sending a photo to a friend, for example. But doing this bulk, couldn't find a way.
- There are no thumbnails viewing photos in the app, because, everything is done in the app. What
  a shame.

I think the experience on your phone definitely has some niceties, but also leaves some things to
be desired. And maybe there are ways to do what I wanted to do mass backing up my photos from
before I set this all up. For that, I think I'll just plug my phone into my computer and do it from
there, but I'm definitely pleased that my new photos can automatically do it, as long as I unlock
the vault every once in a while.

# Conclusion

We're still in the early days of E2EE for consumers. It's becoming more prevalent. But even if a
company can't or won't provide it for you, there are good ways to do it yourself. I like
Cryptomator, it's simple enough, and works well. In the future the landscape may change, and new
programs will come and go. But it's important to start thinking now, how you can keep your personal
information safe ***and*** backed up.
