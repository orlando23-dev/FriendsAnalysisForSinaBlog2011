//
//  RunLoopsThreadHost.m
//  runloopsThread
//
//  Created by orlando ding on 12/17/11.
//  Copyright 2011 MakeDreamToFact. All rights reserved.
//

#import "RunLoopsThreadHost.h"

#pragma mark "stig framework implementation"
#import <WBUtil.h>
#import <SBJson.h>
#import <SBJsonStreamParserAdapter.h>

#pragma mark Customized framework by myself
//#import "AsynJSONRequest.h" -> extract to class later

@interface RunLoopsThreadHost (PrivateMethod)

-(void) myThreadMainMethod:(id)param;
+ (NSString*)stringFromDictionary:(NSDictionary*)dicInfo;
-(NSString *)Base64Encode:(NSData *)data;

@end

@interface RunLoopsThreadHost () <SBJsonStreamParserAdapterDelegate>
@end

@interface RunLoopsThreadHost (NSURLConnectionDelegate)
@end

@implementation RunLoopsThreadHost

@synthesize IsThreadExist = _isThreadExist;
@synthesize IsDone = _done;

#pragma mark Initialization&Destruction
-(id)init{
	if (self = [super init]) {
		self->_myhostThread = nil;
		self->_isThreadExist = NO;
	}
	return (self);
}

-(void)dealloc{
	[super dealloc];
}

#pragma mark Encoding64
-(NSString *)Base64Encode:(NSData *)data{
	//Point to start of the data and set buffer sizes
	int inLength = [data length];
	int outLength = ((((inLength * 4)/3)/4)*4) + (((inLength * 4)/3)%4 ? 4 : 0);
	const char *inputBuffer = [data bytes];
	char *outputBuffer = malloc(outLength);
	outputBuffer[outLength] = 0;
	
	//64 digit code
	static char Encode[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
	
	//start the count
	int cycle = 0;
	int inpos = 0;
	int outpos = 0;
	char temp;
	
	//Pad the last to bytes, the outbuffer must always be a multiple of 4
	outputBuffer[outLength-1] = '=';
	outputBuffer[outLength-2] = '=';
	
	/* http://en.wikipedia.org/wiki/Base64
	 Text content   M           a           n
	 ASCII          77          97          110
	 8 Bit pattern  01001101    01100001    01101110
	 
	 6 Bit pattern  010011  010110  000101  101110
	 Index          19      22      5       46
	 Base64-encoded T       W       F       u
	 */
	
	
	while (inpos < inLength){
		switch (cycle) {
			case 0:
				outputBuffer[outpos++] = Encode[(inputBuffer[inpos]&0xFC)>>2];
				cycle = 1;
				break;
			case 1:
				temp = (inputBuffer[inpos++]&0x03)<<4;
				outputBuffer[outpos] = Encode[temp];
				cycle = 2;
				break;
			case 2:
				outputBuffer[outpos++] = Encode[temp|(inputBuffer[inpos]&0xF0)>> 4];
				temp = (inputBuffer[inpos++]&0x0F)<<2;
				outputBuffer[outpos] = Encode[temp];
				cycle = 3;                  
				break;
			case 3:
				outputBuffer[outpos++] = Encode[temp|(inputBuffer[inpos]&0xC0)>>6];
				cycle = 4;
				break;
			case 4:
				outputBuffer[outpos++] = Encode[inputBuffer[inpos++]&0x3f];
				cycle = 0;
				break;                          
			default:
				cycle = 0;
				break;
		}
	}
	NSString *pictemp = [NSString stringWithUTF8String:outputBuffer];
	free(outputBuffer); 
	return pictemp;
}

#pragma mark Thread Wrapper
//TODO : ThreadMain for host thread - don't need to working
-(void) startThreadMainForRunLoop{
	if (self->_isThreadExist == YES) {
		//TODO : if thread host already existed, stop it first then startThreadMainForRunLoop
		return;
	}
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	//TODO : Mac OSX 10.5 later - autorelease for framework
	self->_myhostThread = [[[NSThread alloc] initWithTarget:self 
												 selector:@selector(startThreadMainForRunLoop:) 
													object:nil]autorelease];
	self->_isThreadExist = YES;
	//TODO : Actually to start thread status code - YES by setter of thread status
	[self->_myhostThread start];
    
	[pool drain];
}

//TODO : waiting for thread stop
-(void) startThreadMainForRunLoop:(id)param{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	//TODO : working for thread Host - for RunLoops inside
	NSLog(@"in the thread working - in run loop %d", self->_isThreadExist);
	self.IsDone = NO;
	
	//TODO : llv22@sina.com:xiandao22@
	[self fetchRequestJSON:@"https://api.weibo.com/2/statuses/public_timeline.json"
				  username:@"llv22@sina.com" 
				  password:@"xiandao22" 
				sinaappkey:@"2657678697"];
	
	/*
	 * Run Loop of Thread
	 */	
	do {
		//TODO : [NSDate distantFuture] 
		//	- You can pass this value when an NSDate object 
		//	is required to have the date argument essentially ignored.
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
	} while ( self.IsDone != YES );
	
	//TODO : Actually to start thread status code - NO by setter of thread status	
	//TODO : working for thread Host - for RunLoops outside
	NSLog(@"in the thread quitting - out of run loop %d", self->_isThreadExist);
	self->_isThreadExist = NO;
	
	[pool drain];
}

//TODO : stop thread for running loop
-(void)stopThreadMainForRunLoop{
	if (self->_myhostThread == nil || self->_isThreadExist == NO) {
		return;
	}
	//TODO : Thread stopping
	if (self.IsDone == YES) {
		return;
	}
	self.IsDone = YES;
}

#pragma mark URL generation
/**
 * Generate get URL
 */
+ (NSString*)serializeURL:(NSString *)baseUrl
                   params:(NSDictionary *)params
               httpMethod:(NSString *)httpMethod 
{	
	if ( [httpMethod isEqualToString:@"GET"] == FALSE )
		return baseUrl;
	
	NSURL* parsedURL = [NSURL URLWithString:baseUrl];
	NSString* queryPrefix = parsedURL.query ? @"&" : @"?";
	NSString* query = [RunLoopsThreadHost stringFromDictionary:params];
	
	return [NSString stringWithFormat:@"%@%@%@", baseUrl, queryPrefix, query];
}

// private
+ (NSString*)stringFromDictionary:(NSDictionary*)dicInfo
{
	NSMutableArray* pairs = [NSMutableArray array];
	for (NSString* key in [dicInfo keyEnumerator]) 
	{
		if( ([[dicInfo valueForKey:key] isKindOfClass:[NSString class]]) == FALSE)
		{
			NSLog(@"Please Use NSString for this kind of params");
			continue;
		}
		
		//NSLog(@"%@", [dicInfo objectForKey:key]);
		//NSLog(@"%@", [[dicInfo objectForKey:key]URLEncodedString]); -> why with URLEncodedString?
		[pairs addObject:[NSString stringWithFormat:@"%@=%@", key, [dicInfo objectForKey:key]]];
	}
	
	//TODO : Autorelease
	return [pairs componentsJoinedByString:@"&"];
}

#pragma mark Fetch implementation
-(void) fetchRequestJSON: (NSString*)nstrInitialURL 
				username:(NSString*)nstrUserName 
				password:(NSString*)nstrPassword
			  sinaappkey:(NSString*)nstrappkey{
	//TODO : requestURL:[NSString stringWithFormat:@"%@%@",weiboHttpRequestDomain, methodName]
	//TODO : static NSString* weiboHttpRequestDomain		= @"http://api.t.sina.com.cn/";
	//TODO : source=2657678697&page=1&count=10
	
	NSMutableDictionary *params = [NSMutableDictionary dictionaryWithCapacity:2];
	[params setObject:nstrappkey forKey:@"source"];
	[params setObject:@"1" forKey:@"page"];
	[params setObject:@"10" forKey:@"count"];
	
	//TODO : /Users/orlando/Documents/06_weiboApp/FriendsAnalysisForSinaBlog2011/CocoaSOAP/SOAPClient.m NSURLRequest -> NSMutableURLRequest [avoid single url request, then to reuse mutable request, see programming guide of NSMutableURLRequest]	
	//TODO : /Users/orlando/Documents/06_weiboApp/FriendsAnalysisForSinaBlog2011/SinaWeiBoSDK/src/src/WBRequest.m
	//TODO : http://stackoverflow.com/questions/1571336/sending-post-data-from-iphone-over-ssl-https
	//	NSString *getParams =[[NSString alloc] initWithFormat:@"source=%@&page=1&count=10", nstrappkey];
	//	NSLog(@"%@", getParams);
	
	NSString *getParams = /*[*/[[self class] stringFromDictionary:params];//autorelease];
	NSURL* hosturl = [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@", nstrInitialURL, getParams]];	
	NSMutableURLRequest *theRequest = [[[NSMutableURLRequest alloc] 
										initWithURL:hosturl
										cachePolicy:NSURLRequestReloadIgnoringCacheData 
										timeoutInterval:60.0] 
									   autorelease];
	//	NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];	
	//	NSString *postLength = [NSString stringWithFormat:@"%d", [postData length]];
    [theRequest setHTTPMethod:@"GET"];
	//TODO : http://www.chrisumbel.com/article/basic_authentication_iphone_cocoa_touch
	// create a plaintext string in the format username:password
	NSMutableString *loginString = (NSMutableString*)[@"" stringByAppendingFormat:@"%@:%@", nstrUserName, nstrPassword];
	
	//TODO : https://github.com/mattgemmell/MGTwitterEngine
	// employ the Base64 encoding above to encode the authentication tokens
	NSString *encodedLoginData = [self Base64Encode:
								  [loginString dataUsingEncoding:NSUTF8StringEncoding]
								  ];
	
	// create the contents of the header 
	NSString *authHeader = [@"Basic " stringByAppendingFormat:@"%@", encodedLoginData];// add the header to the request.  Here's the $$$!!!  
	[theRequest addValue:authHeader forHTTPHeaderField:@"Authorization"];  
	
//	[theRequest setValue:postLength forHTTPHeaderField:@"Content-Length"];
//	[theRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
	//[theRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
	//[theRequest setHTTPBody:postData];//
	//[postData retain];
	
	/* when we user https, we need to allow any HTTPS cerificates, so add the one line code,to tell teh NSURLRequest to accept any https certificate, i'm not sure about the security aspects
	 */	
//	[NSURLRequest setAllowsAnyHTTPSCertificate:YES forHost:[hosturl host]];	
//	NSURLRequest *theRequest=[NSURLRequest 
//							  requestWithURL:[NSURL URLWithString:nstrInitialURL]
//							  cachePolicy:NSURLRequestUseProtocolCachePolicy 
//							  timeoutInterval:60.0];
	
	self->username = nstrUserName;
	self->password = nstrPassword;
	
	//TODO : for calling json parser adpater and callback, just ignored synchronization
	// [Sitg's comments]
	// We don't want *all* the individual messages from the
	// SBJsonStreamParser, just the top-level objects. The stream
	// parser adapter exists for this purpose.
	adapter = [[SBJsonStreamParserAdapter alloc]init];
	adapter.delegate = self;
	assert(adapter!=nil);
	
	
	// Create a new stream parser and set our adapter as its delegate.
	parser = [[SBJsonStreamParser alloc]init];
	parser.delegate = adapter;
	assert(parser!=nil);
	
	// Normally it's an error if JSON is followed by anything but
	// whitespace. Setting this means that the parser will be
	// expecting the stream to contain multiple whitespace-separated
	// JSON documents.
	parser.supportMultipleDocuments = YES;

	//TODO : NSURLConnection delegate to username/password for default url authentication
	/*NSURLConnection *theConnection = */
	[[[NSURLConnection alloc] initWithRequest:theRequest delegate:self] autorelease];	
}

/**********2. Delegation Category**********/
#pragma mark SBJsonStreamParserAdapterDelegate methods

- (void)parser:(SBJsonStreamParser *)parser foundArray:(NSArray *)array {
    [NSException raise:@"unexpected" format:@"Should not get here"];
}

//TODO : json response format content
- (void)parser:(SBJsonStreamParser *)parser foundObject:(NSDictionary *)dict {
	NSLog(@"(void)parser:(SBJsonStreamParser *)parser foundObject:(NSDictionary *)dict\n");
	for(NSString *key in dict){
		NSLog(@"Key: %@, Value %@", key, [dict objectForKey: key]);
	}
}

#pragma mark NSURLConnectionDelegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	NSLog(@"Connection didReceiveResponse: %@ - %@", response, [response MIMEType]);
}

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
	//TODO : http://stackoverflow.com/questions/933331/how-to-use-nsurlconnection-to-connect-with-ssl-for-an-untrusted-cert
	if([protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]){
		//if(shouldAllowSelfSignedCert) {
			return YES; // Self-signed cert will be accepted
//		} else {
//			return NO;  // Self-signed cert will be rejected
//		}
		// Note: it doesn't seem to matter what you return for a proper SSL cert
		//       only self-signed certs
	}
	// If no other authentication is required, return NO for everything else
	// Otherwise maybe YES for NSURLAuthenticationMethodDefault and etc.
	return NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
	NSLog(@"Connection didReceiveAuthenticationChallenge: %@", challenge);
	//if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
//		if ([challenge.protectionSpace.host isEqualToString:@"api.weibo.com"]){
//			[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
//		}
	
	//TODO : Network credential setting
	NSURLCredential *credential = [NSURLCredential credentialWithUser:username
															 password:password
														  persistence:NSURLCredentialPersistenceForSession];
	
	[[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	NSLog(@"Connection didReceiveData of length: %u", data.length);
	
	// Parse the new chunk of data. The parser will append it to its internal buffer, then parse from where it left off in
	// the last chunk.
	SBJsonStreamParserStatus status = [parser parse:data];
	
	if (status == SBJsonStreamParserError) {
		NSLog(@"Parser error: %@", parser.error);
		self.IsDone = YES;		
	} else if (status == SBJsonStreamParserWaitingForData) {
		NSLog(@"Parser waiting for more data");
	}
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [connection release];
	//	TODO : reuse the same adapter and parser, is it possible?
	[adapter release];
	[parser release];
	self.IsDone = YES;
}

@end
