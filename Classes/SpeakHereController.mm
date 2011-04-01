//
/*

    File: SpeakHereController.mm
Abstract: n/a
 Version: 2.4

Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
Inc. ("Apple") in consideration of your agreement to the following
terms, and your use, installation, modification or redistribution of
this Apple software constitutes acceptance of these terms.  If you do
not agree with these terms, please do not use, install, modify or
redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and
subject to these terms, Apple grants you a personal, non-exclusive
license, under Apple's copyrights in this original Apple software (the
"Apple Software"), to use, reproduce, modify and redistribute the Apple
Software, with or without modifications, in source and/or binary forms;
provided that if you redistribute the Apple Software in its entirety and
without modifications, you must retain this notice and the following
text and disclaimers in all such redistributions of the Apple Software.
Neither the name, trademarks, service marks or logos of Apple Inc. may
be used to endorse or promote products derived from the Apple Software
without specific prior written permission from Apple.  Except as
expressly stated in this notice, no other rights or licenses, express or
implied, are granted by Apple herein, including but not limited to any
patent rights that may be infringed by your derivative works or by other
works in which the Apple Software may be incorporated.

The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

Copyright (C) 2009 Apple Inc. All Rights Reserved.


*/

#import "SpeakHereController.h"
#import "ASIFormDataRequest.h"

@implementation SpeakHereController

@synthesize player;
@synthesize recorder;
@synthesize CLController;

@synthesize str_location;

@synthesize btn_record;
@synthesize btn_play;
@synthesize btn_send;

@synthesize fileDescription;
@synthesize playbackWasInterrupted;
@synthesize txtName;
@synthesize txtPrivate;
@synthesize txtPublic;
@synthesize useLocation;
@synthesize lblName;
@synthesize lblPriv;
@synthesize lblPub;
@synthesize lblLoc;
@synthesize backgroundSupported;

char *OSTypeToStr(char *buf, OSType t)
{
	char *p = buf;
	char str[4], *q = str;
	*(UInt32 *)str = CFSwapInt32(t);
	for (int i = 0; i < 4; ++i) {
		if (isprint(*q) && *q != '\\')
			*p++ = *q++;
		else {
			sprintf(p, "\\x%02x", *q++);
			p += 4;
		}
	}
	*p = '\0';
	return buf;
}

-(void)setFileDescriptionForFormat: (CAStreamBasicDescription)format withName:(NSString*)name
{
	char buf[5];
	const char *dataFormat = OSTypeToStr(buf, format.mFormatID);
	NSString* description = [[NSString alloc] initWithFormat:@"(%d ch. %s @ %g Hz)", format.NumberChannels(), dataFormat, format.mSampleRate, nil];
	fileDescription.text = description;
	[description release];	
}

- (void)locationUpdate:(CLLocation *)location {
    str_location = [NSString stringWithFormat:@"%f, %f",location.coordinate.latitude, location.coordinate.longitude];
    [str_location retain];
    //NSLog(str_location);
}

- (void)locationError:(NSError *)error {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Location Error!" message:@"Cannot retreive location. This may be because you have disabled the service." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
    [alert show];
    [alert release];
    [useLocation setOn:NO];
}

- (IBAction)locationToggle:(id)sender 
{
    if(useLocation.on)
    {
        CLController = [[CoreLocationController alloc] init];
        CLController.delegate = self;
        [CLController.locMgr startUpdatingLocation];
    }
    else
        [CLController release];
}


#pragma mark Playback routines

-(void)stopPlayQueue
{
	player->StopQueue();
	btn_record.enabled = YES;
}

-(void)pausePlayQueue
{
	player->PauseQueue();
	playbackWasPaused = YES;
}

- (void)stopRecord
{
	// Disconnect our level meter from the audio queue
//	[lvlMeter_in setAq: nil];
	
	recorder->StopRecord();
	
	// dispose the previous playback queue
	player->DisposeQueue(true);

	// now create a new queue for the recorded file
    
    /*NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentFolderPath = [searchPaths objectAtIndex: 0];
    NSString *recordFile = [documentFolderPath stringByAppendingPathComponent: @"recordedFile.caf"];
    */
    
    
    //recordFilePath = CFURLCreateStringByAddingPercentEscapes( NULL, (CFStringRef)recordFile, NULL, NULL, kCFStringEncodingUTF8 );
    
	//recordFilePath = (CFStringRef)[NSTemporaryDirectory() stringByAppendingPathComponent: @"recordedFile.caf"];
	player->CreateQueueForFile((CFStringRef)@"recordedFile.caf");
	
	// Set the button's state back to "record"
	btn_record.title = @"Record";
	btn_play.enabled = YES;
    btn_send.enabled = YES;
}

- (IBAction)play:(id)sender
{
	if (player->IsRunning())
	{
		if (playbackWasPaused) {
			OSStatus result = player->StartQueue(true);
			if (result == noErr)
				[[NSNotificationCenter defaultCenter] postNotificationName:@"playbackQueueResumed" object:self];
		}
		else
			[self stopPlayQueue];
	}
	else
	{		
		OSStatus result = player->StartQueue(false);
		if (result == noErr)
			[[NSNotificationCenter defaultCenter] postNotificationName:@"playbackQueueResumed" object:self];
	}
}

- (IBAction)send:(id)sender 
{
    //POST the file to the server using ASIFormDataRequset
   	NSData *recording = [NSData dataWithContentsOfFile:(NSString*)recordFilePath]; 
    NSString *urlString = @"http://openwatch.net/uploadnocaptcha/";
    time_t unixTime = (time_t) [[NSDate date] timeIntervalSince1970];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:[NSURL URLWithString:urlString]];
    
	[request setPostValue:txtName.text forKey:@"name"];
	[request setPostValue:txtPublic.text forKey:@"public_description"];
	[request setPostValue:txtPrivate.text forKey:@"private_description"];
    if(useLocation.on)
    {
        //NSLog(str_location);
        [request setPostValue:str_location forKey:@"location"];
    }
    else
        [request setPostValue:@"None" forKey:@"location"];
    


	[request setTimeOutSeconds:20];
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_4_0
	[request setShouldContinueWhenAppEntersBackground:YES];
#endif
	[request setData:recording withFileName:[NSString stringWithFormat:@"%d.caf",unixTime] andContentType:@"audio/x-caf" forKey:@"rec_file"];    

    [request startSynchronous];
    
    NSError *error = [request error];
    if (!error) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Upload Complete" message:@"The recording was uploaded successfully to www.openwatch.net" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [alert show];
        [alert release];
    }
    else
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Upload Error" message:@"Upload failed, try again." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [alert show];
        [alert release];

    }
}



- (IBAction)record:(id)sender
{
	if (recorder->IsRunning()) // If we are currently recording, stop and save the file.
	{
		[self stopRecord];
	}
	else // If we're not recording, start.
	{
		btn_play.enabled = NO;	
        btn_send.enabled = NO;
		
		// Set the button's state to "stop"
		btn_record.title = @"Stop";
				
		// Start the recorder
		recorder->StartRecord(CFSTR("recordedFile.caf"));
		
		[self setFileDescriptionForFormat:recorder->DataFormat() withName:@"Recorded File"];
		
		// Hook the level meter up to the Audio Queue for the recorder
//		[lvlMeter_in setAq: recorder->Queue()];
	}	
}

#pragma mark AudioSession listeners
void interruptionListener(	void *	inClientData,
							UInt32	inInterruptionState)
{
	SpeakHereController *THIS = (SpeakHereController*)inClientData;
	if (inInterruptionState == kAudioSessionBeginInterruption)
	{
		if (THIS->recorder->IsRunning()) {
			[THIS stopRecord];
		}
		else if (THIS->player->IsRunning()) {
			//the queue will stop itself on an interruption, we just need to update the UI
			[[NSNotificationCenter defaultCenter] postNotificationName:@"playbackQueueStopped" object:THIS];
			THIS->playbackWasInterrupted = YES;
		}
	}
	else if ((inInterruptionState == kAudioSessionEndInterruption) && THIS->playbackWasInterrupted)
	{
		// we were playing back when we were interrupted, so reset and resume now
		THIS->player->StartQueue(true);
		[[NSNotificationCenter defaultCenter] postNotificationName:@"playbackQueueResumed" object:THIS];
		THIS->playbackWasInterrupted = NO;
	}
}

void propListener(	void *                  inClientData,
					AudioSessionPropertyID	inID,
					UInt32                  inDataSize,
					const void *            inData)
{
	SpeakHereController *THIS = (SpeakHereController*)inClientData;
	if (inID == kAudioSessionProperty_AudioRouteChange)
	{
		CFDictionaryRef routeDictionary = (CFDictionaryRef)inData;			
		//CFShow(routeDictionary);
		CFNumberRef reason = (CFNumberRef)CFDictionaryGetValue(routeDictionary, CFSTR(kAudioSession_AudioRouteChangeKey_Reason));
		SInt32 reasonVal;
		CFNumberGetValue(reason, kCFNumberSInt32Type, &reasonVal);
		if (reasonVal != kAudioSessionRouteChangeReason_CategoryChange)
		{
			/*CFStringRef oldRoute = (CFStringRef)CFDictionaryGetValue(routeDictionary, CFSTR(kAudioSession_AudioRouteChangeKey_OldRoute));
			if (oldRoute)	
			{
				printf("old route:\n");
				CFShow(oldRoute);
			}
			else 
				printf("ERROR GETTING OLD AUDIO ROUTE!\n");
			
			CFStringRef newRoute;
			UInt32 size; size = sizeof(CFStringRef);
			OSStatus error = AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &size, &newRoute);
			if (error) printf("ERROR GETTING NEW AUDIO ROUTE! %d\n", error);
			else
			{
				printf("new route:\n");
				CFShow(newRoute);
			}*/

			if (reasonVal == kAudioSessionRouteChangeReason_OldDeviceUnavailable)
			{			
				if (THIS->player->IsRunning()) {
					[THIS pausePlayQueue];
					[[NSNotificationCenter defaultCenter] postNotificationName:@"playbackQueueStopped" object:THIS];
				}		
			}

			// stop the queue if we had a non-policy route change
			if (THIS->recorder->IsRunning()) {
				[THIS stopRecord];
			}
		}	
	}
	else if (inID == kAudioSessionProperty_AudioInputAvailable)
	{
		if (inDataSize == sizeof(UInt32)) {
			UInt32 isAvailable = *(UInt32*)inData;
			// disable recording if input is not available
			THIS->btn_record.enabled = (isAvailable > 0) ? YES : NO;
		}
	}
}


- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if ([alertView tag] == 1) {    
        if (buttonIndex == 1) {
            // Enable play/send if an old file was found
            player->CreateQueueForFile((CFStringRef)@"recordedFile.caf");
            btn_play.enabled = YES;
            btn_send.enabled = YES;
        }
    }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    if (recorder->IsRunning()) // If we are currently recording, stop and save the file.
	{
		[self stopRecord];
	}
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    if (recorder->IsRunning()) // If we are currently recording, stop and save the file.
	{
		[self stopRecord];
	}
}

				
#pragma mark Initialization routines
- (void)awakeFromNib
{		
	// Allocate our singleton instance for the recorder & player object
	recorder = new AQRecorder();
	player = new AQPlayer();
    
    CLController = [[CoreLocationController alloc] init];
	CLController.delegate = self;
	[CLController.locMgr startUpdatingLocation];
    
    UIDevice* device = [UIDevice currentDevice];
    backgroundSupported = NO;
    if ([device respondsToSelector:@selector(isMultitaskingSupported)])
        backgroundSupported = device.multitaskingSupported;
    
    NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* foofile = [documentsPath stringByAppendingPathComponent:@"recordedFile.caf"];
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:foofile];
    
    if(fileExists)
    {
        UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Old Recording Found" message:@"Would you like to load it?" delegate:self cancelButtonTitle:@"No" otherButtonTitles:nil] autorelease];
        [alert setTag:1];
        [alert addButtonWithTitle:@"Yes"];
        [alert show];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
          selector:@selector(applicationWillTerminate:)
          name:UIApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
          selector:@selector(applicationDidEnterBackground:)
          name:UIApplicationDidEnterBackgroundNotification object:nil];
    
	OSStatus error = AudioSessionInitialize(NULL, NULL, interruptionListener, self);
	if (error) printf("ERROR INITIALIZING AUDIO SESSION! %d\n", error);
	else 
	{
		UInt32 category = kAudioSessionCategory_PlayAndRecord;	
		error = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
		if (error) printf("couldn't set audio category!");
									
		error = AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, propListener, self);
		if (error) printf("ERROR ADDING AUDIO SESSION PROP LISTENER! %d\n", error);
		UInt32 inputAvailable = 0;
		UInt32 size = sizeof(inputAvailable);
		
		// we do not want to allow recording if input is not available
		error = AudioSessionGetProperty(kAudioSessionProperty_AudioInputAvailable, &size, &inputAvailable);
		if (error) printf("ERROR GETTING INPUT AVAILABILITY! %d\n", error);
		btn_record.enabled = (inputAvailable) ? YES : NO;
		
		// we also need to listen to see if input availability changes
		error = AudioSessionAddPropertyListener(kAudioSessionProperty_AudioInputAvailable, propListener, self);
		if (error) printf("ERROR ADDING AUDIO SESSION PROP LISTENER! %d\n", error);

		error = AudioSessionSetActive(true); 
		if (error) printf("AudioSessionSetActive (true) failed");
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackQueueStopped:) name:@"playbackQueueStopped" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackQueueResumed:) name:@"playbackQueueResumed" object:nil];

	UIColor *bgColor = [[UIColor alloc] initWithRed:.39 green:.44 blue:.57 alpha:.5];
//	[lvlMeter_in setBackgroundColor:bgColor];
//	[lvlMeter_in setBorderColor:bgColor];
	[bgColor release];
	
	// disable the play button since we have no recording to play yet
	btn_play.enabled = NO;
    btn_send.enabled = NO;
    
	playbackWasInterrupted = NO;
	playbackWasPaused = NO;
}

# pragma mark Notification routines
- (void)playbackQueueStopped:(NSNotification *)note
{
	btn_play.title = @"Play";
//	[lvlMeter_in setAq: nil];
	btn_record.enabled = YES;
}

- (void)playbackQueueResumed:(NSNotification *)note
{
	btn_play.title = @"Stop";
	btn_record.enabled = NO;
}

#pragma mark Cleanup
- (void)dealloc
{
	[btn_record release];
	[btn_play release];
    [btn_send release];
	[fileDescription release];
    [CLController release];
	
	delete player;
	delete recorder;
	
    [txtName release];
    [txtPrivate release];
    [txtPublic release];
    [lblName release];
    [lblPriv release];
    [lblPub release];
    [lblLoc release];
    [useLocation release];
    [str_location release];
	[super dealloc];
}

@end
