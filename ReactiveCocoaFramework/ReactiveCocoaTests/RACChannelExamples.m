//
//  RACChannelExamples.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 30/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACChannelExamples.h"

#import "NSObject+RACDeallocating.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACChannel.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACSignal+Operations.h"

NSString * const RACChannelExamples = @"RACChannelExamples";
NSString * const RACChannelExampleCreateBlock = @"RACChannelExampleCreateBlock";

NSString * const RACViewChannelExamples = @"RACViewChannelExamples";
NSString * const RACViewChannelExampleCreateViewBlock = @"RACViewChannelExampleCreateViewBlock";
NSString * const RACViewChannelExampleCreateTerminalBlock = @"RACViewChannelExampleCreateTerminalBlock";
NSString * const RACViewChannelExampleKeyPath = @"RACViewChannelExampleKeyPath";
NSString * const RACViewChannelExampleSetViewTextBlock = @"RACViewChannelExampleSetViewTextBlock";

SharedExampleGroupsBegin(RACChannelExamples)

sharedExamplesFor(RACChannelExamples, ^(NSDictionary *data) {
	__block RACChannel * (^getChannel)(void);
	__block RACChannel *channel;

	id value1 = @"test value 1";
	id value2 = @"test value 2";
	id value3 = @"test value 3";
	NSArray *values = @[ value1, value2, value3 ];
	
	before(^{
		getChannel = data[RACChannelExampleCreateBlock];
		channel = getChannel();
	});
	
	it(@"should not send any leadingTerminal value on subscription", ^{
		__block id receivedValue = nil;

		[channel.followingTerminal sendNext:value1];
		[channel.leadingTerminal subscribeNext:^(id x) {
			receivedValue = x;
		}];

		expect(receivedValue).to.beNil();
		
		[channel.followingTerminal sendNext:value2];
		expect(receivedValue).to.equal(value2);
	});
	
	it(@"should send the latest followingTerminal value on subscription", ^{
		__block id receivedValue = nil;

		[channel.leadingTerminal sendNext:value1];
		[[channel.followingTerminal take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];

		expect(receivedValue).to.equal(value1);
		
		[channel.leadingTerminal sendNext:value2];
		[[channel.followingTerminal take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];

		expect(receivedValue).to.equal(value2);
	});
	
	it(@"should send leadingTerminal values as they change", ^{
		NSMutableArray *receivedValues = [NSMutableArray array];
		[channel.leadingTerminal subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];

		[channel.followingTerminal sendNext:value1];
		[channel.followingTerminal sendNext:value2];
		[channel.followingTerminal sendNext:value3];
		expect(receivedValues).to.equal(values);
	});
	
	it(@"should send followingTerminal values as they change", ^{
		[channel.leadingTerminal sendNext:value1];

		NSMutableArray *receivedValues = [NSMutableArray array];
		[channel.followingTerminal subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];

		[channel.leadingTerminal sendNext:value2];
		[channel.leadingTerminal sendNext:value3];
		expect(receivedValues).to.equal(values);
	});

	it(@"should complete both signals when the leadingTerminal is completed", ^{
		__block BOOL completedLeft = NO;
		[channel.leadingTerminal subscribeCompleted:^{
			completedLeft = YES;
		}];

		__block BOOL completedRight = NO;
		[channel.followingTerminal subscribeCompleted:^{
			completedRight = YES;
		}];

		[channel.leadingTerminal sendCompleted];
		expect(completedLeft).to.beTruthy();
		expect(completedRight).to.beTruthy();
	});

	it(@"should complete both signals when the followingTerminal is completed", ^{
		__block BOOL completedLeft = NO;
		[channel.leadingTerminal subscribeCompleted:^{
			completedLeft = YES;
		}];

		__block BOOL completedRight = NO;
		[channel.followingTerminal subscribeCompleted:^{
			completedRight = YES;
		}];

		[channel.followingTerminal sendCompleted];
		expect(completedLeft).to.beTruthy();
		expect(completedRight).to.beTruthy();
	});

	it(@"should replay completion to new subscribers", ^{
		[channel.leadingTerminal sendCompleted];

		__block BOOL completedLeft = NO;
		[channel.leadingTerminal subscribeCompleted:^{
			completedLeft = YES;
		}];

		__block BOOL completedRight = NO;
		[channel.followingTerminal subscribeCompleted:^{
			completedRight = YES;
		}];

		expect(completedLeft).to.beTruthy();
		expect(completedRight).to.beTruthy();
	});
});

SharedExampleGroupsEnd

SharedExampleGroupsBegin(RACViewChannelExamples)

sharedExamplesFor(RACViewChannelExamples, ^(NSDictionary *data) {
	__block NSString *keyPath;
	__block NSObject * (^getView)(void);
	__block RACChannelTerminal * (^getTerminal)(NSObject *);
	__block void (^setViewText)(NSObject *view, NSString *text);

	__block NSObject *testView;
	__block RACChannelTerminal *endpoint;

	beforeEach(^{
		keyPath = data[RACViewChannelExampleKeyPath];
		getTerminal = data[RACViewChannelExampleCreateTerminalBlock];
		getView = data[RACViewChannelExampleCreateViewBlock];
		setViewText = data[RACViewChannelExampleSetViewTextBlock];

		testView = getView();
		endpoint = getTerminal(testView);
	});

	it(@"should not send changes made by the channel itself", ^{
		__block BOOL receivedNext = NO;
		[endpoint subscribeNext:^(id x) {
			receivedNext = YES;
		}];

		expect(receivedNext).to.beFalsy();

		[endpoint sendNext:@"foo"];
		expect(receivedNext).to.beFalsy();

		[endpoint sendNext:@"bar"];
		expect(receivedNext).to.beFalsy();

		[endpoint sendCompleted];
		expect(receivedNext).to.beFalsy();
	});

	it(@"should not send progammatic changes made to the view", ^{
		__block BOOL receivedNext = NO;
		[endpoint subscribeNext:^(id x) {
			receivedNext = YES;
		}];

		expect(receivedNext).to.beFalsy();

		[testView setValue:@"foo" forKeyPath:keyPath];
		expect(receivedNext).to.beFalsy();

		[testView setValue:@"bar" forKeyPath:keyPath];
		expect(receivedNext).to.beFalsy();
	});

	it(@"should not have a starting value", ^{
		__block BOOL receivedNext = NO;
		[endpoint subscribeNext:^(id x) {
			receivedNext = YES;
		}];

		expect(receivedNext).to.beFalsy();
	});

	it(@"should send view changes", ^{
		__block NSString *received;
		[endpoint subscribeNext:^(id x) {
			received = x;
		}];

		setViewText(testView, @"fuzz");
		expect(received).to.equal(@"fuzz");

		setViewText(testView, @"buzz");
		expect(received).to.equal(@"buzz");
	});

	it(@"should set values on the view", ^{
		[endpoint sendNext:@"fuzz"];
		expect([testView valueForKeyPath:keyPath]).to.equal(@"fuzz");

		[endpoint sendNext:@"buzz"];
		expect([testView valueForKeyPath:keyPath]).to.equal(@"buzz");
	});

	it(@"should not echo changes back to the channel", ^{
		__block NSUInteger receivedCount = 0;
		[endpoint subscribeNext:^(id _) {
			receivedCount++;
		}];

		expect(receivedCount).to.equal(0);

		[endpoint sendNext:@"fuzz"];
		expect(receivedCount).to.equal(0);

		setViewText(testView, @"buzz");
		expect(receivedCount).to.equal(1);
	});

	it(@"should complete when the view deallocates", ^{
		__block BOOL deallocated = NO;
		__block BOOL completed = NO;

		@autoreleasepool {
			NSObject *view __attribute__((objc_precise_lifetime)) = getView();
			[view.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				deallocated = YES;
			}]];

			RACChannelTerminal *terminal = getTerminal(view);
			[terminal subscribeCompleted:^{
				completed = YES;
			}];

			expect(deallocated).to.beFalsy();
			expect(completed).to.beFalsy();
		}

		expect(deallocated).to.beTruthy();
		expect(completed).to.beTruthy();
	});

	it(@"should deallocate after the view deallocates", ^{
		__block BOOL viewDeallocated = NO;
		__block BOOL terminalDeallocated = NO;

		@autoreleasepool {
			NSObject *view __attribute__((objc_precise_lifetime)) = getView();
			[view.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				viewDeallocated = YES;
			}]];

			RACChannelTerminal *terminal = getTerminal(view);
			[terminal.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				terminalDeallocated = YES;
			}]];

			expect(viewDeallocated).to.beFalsy();
			expect(terminalDeallocated).to.beFalsy();
		}

		expect(viewDeallocated).to.beTruthy();
		expect(terminalDeallocated).will.beTruthy();
	});
});

SharedExampleGroupsEnd
