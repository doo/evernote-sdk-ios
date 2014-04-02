"Simple" Evernote SDK for iOS version 2.0 
=========================================

**HEADS-UP!** This fork of the SDK is unofficial and a work in progress. Although most of the "public" objects are fairly stable, changes are being made overall quite frequently. Some things might well not work as you expect. Your feedback is very valued. 

Also note: the "Sample App" in this SDK bundle isn't actually a sample app. Please don't bother with it. Thanks!

What this is
------------
A simple, workflow-oriented library built on the Evernote Cloud API. It's designed to make common tasks a piece of cake!

Installing 
----------

### Register for an Evernote API key (and secret)...

You can do this on the [Evernote Developers portal page](http://dev.evernote.com/documentation/cloud/).

### ...OR get a Developer Token

You can also just test-drive the SDK against your personal production Evernote account, if you're afraid of commitment and don't like sandboxes. [Get a developer token here](https://www.evernote.com/api/DeveloperToken.action). Make sure to use the alternate setup instructions given in the "Modify Your App Delegate" section below. 

### Include the code

You have a few options:

- Copy the evernote-sdk-ios folder into your Xcode project.
- [I DON'T KNOW IF THIS WORKS RIGHT NOW] Build the evernote-sdk-ios as a static library and include the .h's and .a. (Make sure to add the `-ObjC` flag to your "Other Linker flags" if you choose this option). 
More info [here](http://developer.apple.com/library/ios/#technotes/iOSStaticLibraries/Articles/configuration.html#/apple_ref/doc/uid/TP40012554-CH3-SW2). 

### Link with frameworks

evernote-sdk-ios depends on some frameworks, so you'll need to add them to any target's "Link Binary With Libraries" Build Phase.
Add the following frameworks in the "Link Binary With Libraries" phase

- Security.framework
- MobileCoreServices.framework
- libxml2.dylib

![Add '${SDKROOT}/usr/include/libxml2'](LinkLibraries.png)

### Add header search path

Add `${SDKROOT}/usr/include/libxml2` to your header search path.

![Add '${SDKROOT}/usr/include/libxml2'](AddHeaderSearchPath.png)


### Modify your application's main plist file

Create an array key called URL types with a single array sub-item called URL Schemes. Give this a single item with your consumer key prefixed with 'en-'

	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string></string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>en-<consumer key></string>
			</array>
		</dict>
	</array>
	
### Add the header file to any file that uses the Evernote SDK

    #import "ENSDK.h"

### Modify your AppDelegate

First you set up the ENSession, configuring it with your consumer key and secret. 

The SDK supports the Yinxiang Biji (Evernote China) service by default. Please make sure your consumer key has been [activated](http://dev.evernote.com/support/) for the China service.

Do something like this in your AppDelegate's `application:didFinishLaunchingWithOptions:` method.

	- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
	{
		// Initial development is done on the sandbox service
		// When you want to connect to production, just pass "nil" for "optionalHost"
		NSString *SANDBOX_HOST = BootstrapServerBaseURLStringSandbox;
    
		// Fill in the consumer key and secret with the values that you received from Evernote
		// To get an API key, visit http://dev.evernote.com/documentation/cloud/
		NSString *CONSUMER_KEY = @"your key";
		NSString *CONSUMER_SECRET = @"your secret";
    
		[ENSession setSharedSessionConsumerKey:CONSUMER_KEY
		  						consumerSecret:CONSUMER_SECRET
							      optionalHost:SANDBOX_HOST];		
	}

ALTERNATE: If you are using a Developer Token to access *only* your personal, production account, then *don't* set a consumer key/secret (or the sandbox environment). Instead, give the SDK your developer token and Note Store URL (both personalized and available from [this page](https://www.evernote.com/api/DeveloperToken.action)). Replace the setup call above with the following. 

        [ENSession setSharedSessionDeveloperToken:@"the token string"
                                     noteStoreUrl:@"the url that you got from us"];


Do something like this in your AppDelegate's `application:openURL:sourceApplication:annotation:` method. If the method doesn't exist, add it.

	- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
		BOOL didHandle = [[ENSession sharedSession] handleOpenURL:url];
		// ... 
		return canHandle;
	}

Now you're good to go.

Using the Evernote SDK
----------------------

### Authenticate

You'll need to authenticate the `ENSession`, passing in your view controller.

A normal place to do this would be a "link to Evernote" button action.

    ENSession *session = [ENSession sharedSession];
    [session authenticateWithViewController:self completion:^(NSError *error) {
        if (error) {
            // authentication failed :(
            // show an alert, etc
            // ...
        } else {
            // authentication succeeded :)
            // do something now that we're authenticated
            // ... 
        } 
    }];

Calling authenticateWithViewController:completion: will start the OAuth process. ENSession will open a new modal view controller, to display Evernote's OAuth web page and handle all the back-and-forth OAuth handshaking. When the user finishes this process, Evernote's modal view controller will be dismissed.

### Hello, world.

To create a new note with no user interface, you can just do this:

    ENNote * note = [[ENNote alloc] initWithString:@"Hello, Evernote!"];
	note.title = @"My First Note";
    [[ENSession sharedSession] uploadNote:note completion:^(ENNoteRef * noteRef, NSError * uploadNoteError) {
		if (noteRef) {
			// It worked! You can use this note ref to share the note or otherwise find it again.
			...
		} else {
			NSLog(@"Couldn't upload note. Error: %@", uploadNoteError);
		}
	}];

This creates a new, plaintext note, with a title, and uploads it to the user's default notebook. 

### Adding Resources

Let's say you'd like to create a note with an image that you have. That's easy too. You just need to create an `ENResource` that represents the image data, and attach it to the note before uploading:

	ENNote * note = [[ENNote alloc] initWithString:@"This note has an image in it."];
	note.title = @"My Image Note";
	ENResource * resource = [[ENResource alloc] initWithImage:myImage]; // myImage is a UIImage object.
	[note addResource:resource]
	[[ENSession sharedSession] uploadNote:note completion:^(ENNoteRef * noteRef, NSError * uploadNoteError) {
		// same as above...
	}];

You aren't restricted to images; you can use any kind of file. Just use the appropriate initializer for `ENResource`. You'll need to know the data's MIME type to pass along.

### Sending To Evernote with UIActivityViewController

[This object works when a session is authenticated already. Note that it's a big work in progress with crummy UI for right now!]

iOS provides a handy system `UIActivityViewController` that you can create and use when a user taps an "action" or "share" button in your app. The Evernote SDK provides a drop-in `UIActivity` subclass (`ENSendToEvernoteActivity`) that you can use. This will do the work of creating resources and note contents (based on the activity items), and presents a view controller that lets the user choose a notebook, add tags, edit the title, etc. Just do this:

	ENSendToEvernoteActivity * evernoteActivity = [[ENSendToEvernoteActivity alloc] init];
	activity.noteTitle = @"Default Note Title";
	//...
	UIActivityViewController * avc = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:@[evernoteActivity]];
    [self presentViewController:avc animated:YES completion:nil];
    // etc
    
### What else is in here?

The high level functions include those on `ENSession`, and you can look at `ENNote`, `ENResource`, `ENNotebook` for simple models of these objects as well. 

Coming soon: discussion of "Advanced" access to underlying "EDAM" object layer.

FAQ
---

### What iOS versions are supported?

This version of the SDK is designed for iOS 7 (and above). The current public version of the SDK in Evernote's repo supports back to iOS 5.

### Does the Evernote SDK support ARC?

Obvi. (To use the SDK in a non-ARC project, please use the -fobjc-arc compiler flag on all the files in the Evernote SDK.)

### What if I want to do more than the meager few functions offered on ENSession?

ENSession is a really broad, workflow-oriented abstraction layer. It's currently optimized for the creation and upload of new notes, but not a whole lot more. You can get closer to the metal, but it will require a fair bit of understanding of Evernote's object model and API. 

First off, import `ENSDKAdvanced.h` instead of (or in addition to) `ENSDK.h`. Then ask an authenticated session for its `-primaryNoteStore`. You can look at the header for `ENNoteStoreClient` to see all the methods offered on it, with block-based completion parameters. Knock yourself out. This note store client won't work with a user's business data or shared notebook data directly; you can get note store clients for those destinations by asking for `-businessNoteStore` and `-noteStoreForLinkedNotebook:`  More info is currently beyond the scope of this README but check out the full developer docs. 

### Where can I find out more about the Evernote service, API, and object model for my more sophisticated integration?

Please check out the [Evernote Developers portal page](http://dev.evernote.com/documentation/cloud/).
Apple style docs are [here](http://dev.evernote.com/documentation/reference/ios/).
