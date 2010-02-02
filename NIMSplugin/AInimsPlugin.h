#import <Cocoa/Cocoa.h>

// prepend numbers to outgoing IMs 
// and squawk if incoming IMs, if numbered, are not consecutive.
// Created by Bethany <3 Danny 2008.12.14

#import <Adium/AIPlugin.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AISharedAdium.h>
#import <Adium/AIContentObject.h>
#import <Adium/AIListObject.h>
#import <Adium/AIContentEvent.h>
#import <Adium/AIContentMessage.h>
#import <AIUtilities/AIAttributedStringAdditions.h>

#define VERSION @"1.5.1"

@protocol AIContentFilter;

@interface AInimsPlugin : AIPlugin <AIContentFilter> {
  NSMutableDictionary *outNums;  // last outgoing number sent on this chat
  NSMutableDictionary *lastMsgs; // last incoming message seen on this chat
  NSMutableDictionary *enabledFlags;  // nims on for this chat?
  NSMutableDictionary *hStacks;  // stack of messages hidden with /hide
  //NSMutableDictionary *helloFlags; // per/contact flag for whether 
  
  BOOL nimsDefault;  // whether nims is on by default for new chats
  BOOL DEBUG;
  BOOL VERBOSE; // give verbose/liberal warnings on incoming messages
}

-(NSAttributedString*)procIn:(NSAttributedString*)inStr
                            :(AIContentObject*)contentObj;
-(NSAttributedString*)procOut:(NSAttributedString*)inStr 
                             :(AIContentObject*)contentObj;
-(NSAttributedString*)procSlash:(NSAttributedString*)inStr 
                               :(AIContentObject*)contentObj;
-(NSAttributedString*)preNum:(NSAttributedString*)inStr :(NSString*)who;
//-(void)sendSystemMsgDelayed:(NSString*)m :(AIContentObject*)contentObj;
//-(void)sendSystemMsg:(NSString*)m :(AIContentObject*)contentObj;

-(BOOL)toggleEnabled:(NSString*)who;

int parseNum(NSString*);
NSString* tagify(NSString*);

void sendSystemMsg(NSString*, AIContentObject*);
//void sendSystemMsgDelayed(NSString*, AIContentObject*);

NSString* debugMsg(AIContentObject*);
NSAttributedString* appendString(NSAttributedString*, NSString*);

@end
