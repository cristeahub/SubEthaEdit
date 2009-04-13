//
//  SEPAppController.m
//  SubEthaEdit
//
//  Created by Dominik Wagner on 09.04.09.
//  Copyright 2009 TheCodingMonkeys. All rights reserved.
//

#import "SEPLogger.h"
#import "SEPAppController.h"
#import "SEPDocument.h"
#import "DocumentModeManager.h"


@implementation SEPAppController

@synthesize testNSTextStorage,testFoldableTextStorage, testFoldableTextStorageOneFolding, testFoldableTextStorageEveryOtherLineFolding, numberOfRepeats;

- (void)setupLogFile {
	NSString *appName = [[[[NSBundle mainBundle] bundlePath] lastPathComponent] stringByDeletingPathExtension];
	NSString *appDir = [[@"~/Library/Logs/" stringByExpandingTildeInPath] stringByAppendingPathComponent:appName];
	[[NSFileManager defaultManager] createDirectoryAtPath:appDir attributes:nil];
	
    int sequenceNumber = 0;
	NSString *name;
	do {
		sequenceNumber++;
		name = [NSString stringWithFormat:@"Perflog-%@-%@-%d.log", [[NSCalendarDate date] descriptionWithCalendarFormat:@"%Y-%m-%d--%H-%M"], [[NSProcessInfo processInfo] hostName], sequenceNumber];
		name = [appDir stringByAppendingPathComponent:name];
	} while ([[NSFileManager defaultManager] fileExistsAtPath:name]);

    [[NSFileManager defaultManager] createFileAtPath:name contents:[NSData data] attributes:nil];
    logFileHandle = [[NSFileHandle fileHandleForWritingAtPath:name] retain];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[self setupLogFile];

	[SEPLogger registerLogger:self];
	[SEPLogger logWithFormat:@"------ start up (v%@)-----\n", [[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleVersion"]];
	NSProcessInfo *info = [NSProcessInfo processInfo];
	[SEPLogger logWithFormat:@"%@, %d cpus, %d MB, %@\n",[info hostName],[info activeProcessorCount],[info physicalMemory] / 1024 / 1024,[info operatingSystemVersionString]];
	self.testNSTextStorage 								= YES;
	self.testFoldableTextStorage						= NO;
	self.testFoldableTextStorageOneFolding				= NO;
	self.testFoldableTextStorageEveryOtherLineFolding	= NO;
	self.numberOfRepeats = 3;
	
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"RunTestsAtStart"]) {
		[self performSelector:@selector(runTests:) withObject:nil afterDelay:2];
	}
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
	[logFileHandle closeFile];
	[logFileHandle release];
}

- (void)getAverage:(double *)anAverage deviance:(double *)aDeviance ofArray:(NSArray *)anArray {
	*anAverage = [[anArray valueForKeyPath:@"@avg.self"] doubleValue];
	double variance = 0.0;
	for (NSNumber *value in anArray) {
		variance += pow([value doubleValue] - *anAverage,2);
	}
	variance = variance / [anArray count];
	*aDeviance = sqrt(variance);
}

// returns throughput Average
- (void)reportTotal:(NSArray *)anArray {
	double average = 0.0;
	double deviance = 0.0;
	[self getAverage:&average deviance:&deviance ofArray:anArray];
	double ninetyFivePercentConfidenceInterval = (deviance * 2) / average * 100.0;

	[SEPLogger logWithFormat:@"----------------------------------------------------------------------\n"];
	[SEPLogger logWithFormat:@"-- Total (avg of mode avgs) || (min:%@ | max:%@) %@ | +/-%@ \n",
		[NSString stringWithFormat:@"%03.1fkb/s",[[anArray valueForKeyPath:@"@min.self"] doubleValue] / 1024.0],
		[NSString stringWithFormat:@"%03.1fkb/s",[[anArray valueForKeyPath:@"@max.self"] doubleValue] / 1024.0],
		[[NSString stringWithFormat:@"%03.1fkb/s",average / 1024.0] stringByLeftPaddingUpToLength:12],
		[[NSString stringWithFormat:@"%.1f %%",ninetyFivePercentConfidenceInterval] stringByLeftPaddingUpToLength:8]];
	[SEPLogger logWithFormat:@"----------------------------------------------------------------------\n"];
}


// returns throughput Average
- (double)reportModeTimingArray:(NSArray *)anArray {
	double average = 0.0;
	double deviance = 0.0;
	[self getAverage:&average deviance:&deviance ofArray:anArray];
	double ninetyFivePercentConfidenceInterval = (deviance * 2) / average * 100.0;

	[SEPLogger logWithFormat:@"||%@ | +/-%@ ",
		[[NSString stringWithFormat:@"%03.1fkb/s",average / 1024.0] stringByLeftPaddingUpToLength:12],
		[[NSString stringWithFormat:@"%.1f %%",ninetyFivePercentConfidenceInterval] stringByLeftPaddingUpToLength:8]];

	return average;
}


// returns throughput
- (double)reportTimingArray:(NSArray *)anArray forByteLength:(double)byteLength {
	double average = 0.0;
	double deviance = 0.0;
	[self getAverage:&average deviance:&deviance ofArray:anArray];

	double ninetyFivePercentConfidenceInterval = (deviance * 2) / average * 100.0;
	double throughPut = byteLength / average;

	[SEPLogger logWithFormat:@"||%@ |%@ | +/-%@ ",
		[[NSString stringWithFormat:@"%03.3fs",average] stringByLeftPaddingUpToLength:8],
		[[NSString stringWithFormat:@"%03.1fkb/s",throughPut / 1024.0] stringByLeftPaddingUpToLength:12],
		[[NSString stringWithFormat:@"%.1f %%",ninetyFivePercentConfidenceInterval] stringByLeftPaddingUpToLength:8]];
	return throughPut;
}

- (void)testFileAtPath:(NSString *)aFilePath recordThroughPut:(NSMutableDictionary *)aThroughPutDictionary
{
	NSMutableArray *timingArray = [NSMutableArray new];
	NSString *fileName = [aFilePath lastPathComponent];
	int byteSize = [[[NSFileManager defaultManager] fileAttributesAtPath:aFilePath traverseLink:YES] fileSize];
	
	int testMode=0;
	for (testMode=0; testMode<4; testMode++) {
		[timingArray removeAllObjects];
		if ((testMode == 0 && !self.testNSTextStorage) ||
			(testMode == 1 && !self.testFoldableTextStorage) ||
			(testMode == 2 && !self.testFoldableTextStorageOneFolding) ||
			(testMode == 3 && !self.testFoldableTextStorageEveryOtherLineFolding)) {
			continue;
		}
		NSString *textStorageType = @"NSTextStorage";
		switch (testMode) {
			case 1: textStorageType = @"Foldable"; break;
			case 2: textStorageType = @"Foldable1Fold"; break;
			case 3: textStorageType = @"FoldableManyFold"; break;
		}
		[SEPLogger logWithFormat:
			[[NSString stringWithFormat:@"-> %@ (%d kb)", fileName, byteSize / 1024]
				stringByPaddingToLength:40 withString:@" " startingAtIndex:0]];
		[SEPLogger logWithFormat:
			[[NSString stringWithFormat:@"%@ ",textStorageType]
				stringByPaddingToLength:17 withString:@" " startingAtIndex:0]];
		[ibResultsTextView display];
	
		int i = 0;
		NSString *modeIdentifier = nil;
		for (;i<self.numberOfRepeats;i++) {
			SEPDocument *document = [[SEPDocument alloc] initWithURL:[NSURL fileURLWithPath:aFilePath]];
			if (document) {
				if (testMode > 0) {
					[document changeToFoldableTextStorage];
					if (testMode == 2) {
						[document addOneFolding];
					} else if (testMode == 3) {
						[document foldEveryOtherLine];
					}
				}
				modeIdentifier = [[document documentMode] documentModeIdentifier];
				NSTimeInterval time = [document timedHighlightAll];
				[timingArray addObject:[NSNumber numberWithFloat:time]];
				[document release];
			}
		}
		double throughPut = [self reportTimingArray:timingArray forByteLength:byteSize];
		if (![aThroughPutDictionary objectForKey:modeIdentifier]) {
			[aThroughPutDictionary setObject:[NSMutableArray array] forKey:modeIdentifier];
		}
		[[aThroughPutDictionary objectForKey:modeIdentifier] addObject:[NSNumber numberWithDouble:throughPut]];
		[SEPLogger logWithFormat:@"\n"];
		[ibResultsTextView display];
	}
	
	[timingArray release];
}

- (void)testFiles:(NSArray *)aFilePathArray
{
	NSMutableDictionary *throughputDictionary = [NSMutableDictionary dictionary];
	for (NSString *filePath in aFilePathArray) {
		[self testFileAtPath:filePath recordThroughPut:throughputDictionary];
	}
	[SEPLogger logWithFormat:@"--- Breakdown by Mode ---\n"];
	NSMutableArray *totalArray = [NSMutableArray array];
	for (NSString *key in [[throughputDictionary allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]) {
		DocumentMode *mode = [[DocumentModeManager sharedInstance] documentModeForIdentifier:key];
		[SEPLogger logWithFormat:
			[[NSString stringWithFormat:@"- %@ (%@ v%@)", [mode displayName], [mode documentModeIdentifier], [[[mode bundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]]
				stringByPaddingToLength:45 withString:@" " startingAtIndex:0]];
		double average = [self reportModeTimingArray:[throughputDictionary objectForKey:key]];
		[totalArray addObject:[NSNumber numberWithDouble:average]];
		[SEPLogger logWithFormat:@"\n"];
	}
	[self reportTotal:totalArray];
}

- (void)testFilesAtPath:(NSString *)aFilePath {
	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableArray *filePathArray = [NSMutableArray array];
	for (NSString *fileName in [[fm directoryContentsAtPath:aFilePath] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]) {
		[filePathArray addObject:[aFilePath stringByAppendingPathComponent:fileName]];
	}
	[self testFiles:filePathArray];	
}

- (void)application:(NSApplication *)anApplication openFiles:(NSArray *)aFilePathArray {
	[SEPLogger logWithFormat:@"------ opening testfiles (%d times per document) -----\n", self.numberOfRepeats];
	[anApplication replyToOpenOrPrint:NSApplicationDelegateReplySuccess]; // so finder isn't worried anymore
	[self testFiles:[aFilePathArray sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
}

- (IBAction)runTests:(id)aSender {
	[ibProgressIndicator startAnimation:self];
	[SEPLogger logWithFormat:@"------ runTests (%d times per document) -----\n", self.numberOfRepeats];
	// load up all files in TestFiles
	NSString *testfilePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"TestFiles"];
	[self testFilesAtPath:testfilePath];
	[ibProgressIndicator stopAnimation:self];
}


- (void)logString:(NSString *)aString
{
	[[[ibResultsTextView textStorage] mutableString] appendString:aString];
	NSLog(@"%@",aString);
	[logFileHandle writeData:[aString dataUsingEncoding:NSUTF8StringEncoding]];
}
@end
