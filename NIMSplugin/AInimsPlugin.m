// Prepend numbers to outgoing IMs 
// and squawk if incoming IMs, if numbered, are not consecutive.

#import "AInimsPlugin.h"

@implementation AInimsPlugin

-(void)installPlugin
{
  //Register us as a filter
  [[adium contentController] registerContentFilter:self ofType:AIFilterContent 
                                         direction:AIFilterIncoming];
  [[adium contentController] registerContentFilter:self ofType:AIFilterContent 
                                         direction:AIFilterOutgoing];
  outNums = [[NSMutableDictionary alloc] init];
  lastMsgs = [[NSMutableDictionary alloc] init];
  enabledFlags = [[NSMutableDictionary alloc] init];
  hStacks = [[NSMutableDictionary alloc] init];
  
  nimsDefault = FALSE;
  DEBUG = FALSE;
  VERBOSE = TRUE;
  
  srand( (unsigned int)time(NULL) );
  
}


-(void)uninstallPlugin
{
  [[adium contentController] unregisterContentFilter:self];
}


-(void)dealloc {
  [outNums release];
  [lastMsgs release];
  [enabledFlags release];
  [hStacks release];
  [super dealloc];
}

/*******************************************************************************
 * filterAttributedString:  takes an IM and returns a modified one.
 ******************************************************************************/
-(NSAttributedString*)filterAttributedString:(NSAttributedString*)inStr 
                                     context:(id)context
{
  if (!inStr || ![inStr length]) return inStr;
  if (![context isKindOfClass:[AIContentObject class]]) return inStr;

  AIContentObject *contentObj = (AIContentObject*)context;
  
  
  AIChat* chatObj = [contentObj chat];
  NSDate* chatOpened = [chatObj dateOpened];
  
  // don't mess with messages if they come from ourself
  //if ([contentObj source] == [contentObj destination]) return inStr;

  // don't mess with messages unless they are real messages
  if (![[contentObj type] isEqualToString:CONTENT_MESSAGE_TYPE] ||
      (abs([contentObj.date timeIntervalSinceNow]) > 1))
    return inStr;
  
  if ([contentObj isOutgoing]) return [self procOut:inStr:contentObj];
  return [self procIn:inStr:contentObj];
}


/*******************************************************************************
 * procIn:  
 * takes an incoming IM and returns it, also warning about nonconsecutive nums.
 ******************************************************************************/
- (NSAttributedString*)procIn:(NSAttributedString*)inStr 
                             :(AIContentObject*)contentObj
{
  NSString* who = [[contentObj source] UID];
  int last = parseNum([lastMsgs valueForKey:who]);
  int parsed = parseNum([inStr string]);
  if (last != -1 && parsed != -1 && parsed > last+1)
    sendSystemMsg([NSString stringWithFormat:
                   @"WARNING! Message %i followed by %i.", last, parsed], 
                  contentObj);
  else if (VERBOSE && parsed != last+1 && !(last == -1 && parsed == -1))
    sendSystemMsg([NSString stringWithFormat:
                   @"Likely extraneous warning: Message %@ followed by %@.", 
                   tagify([lastMsgs valueForKey:who]), 
                   tagify([inStr string])], contentObj);
  [lastMsgs setObject:[NSString stringWithString:[inStr string]] forKey:who];
  
  if (DEBUG) return appendString(inStr, debugMsg(contentObj));    
  else return inStr;
}


// Takes message as a string and returns prepended number, or -1 if none.
int parseNum(NSString* s)
{
  if(s==nil) return -1;
  NSString* tmps = [NSString stringWithString:s];
  if ([tmps hasPrefix:@"("] || [tmps hasPrefix:@"["] || [tmps hasPrefix:@"<"]) 
    tmps = [tmps substringFromIndex:1];
    
  //int parsedNum = [[inStr string] intValue];
  int x = [tmps intValue];
  if (x == 0 && ![tmps hasPrefix:@"0"]) x = -1;
  return x;
}


// Takes a message, returns its number (as string) or a short abbrv of the msg.
NSString* tagify(NSString* in)
{
  int x = parseNum(in);
  if(x!=-1) return [NSString stringWithFormat:@"%i", x];  
  if(in==nil) return [NSString stringWithString:@"[NONE]"];
  if([in length] < 4) return [NSString stringWithFormat:@"'%@'", in];
  return [NSString stringWithFormat:@"'%@..'", [in substringToIndex:4]];
}


/*******************************************************************************
 * procOut:
 * takes an outgoing IM and prepends a number; also process it if a slash cmd.
 ******************************************************************************/
- (NSAttributedString*)procOut:(NSAttributedString*)inStr 
                              :(AIContentObject*)contentObj
{
  // TODO: this check should be extraneous (see filterAttributedMessage)
  // first of all, don't prepend to old messages
  if (abs([contentObj.date timeIntervalSinceNow]) > 1) return inStr;
  
  NSString* who = [[contentObj destination] UID];
  NSNumber* enab = [enabledFlags valueForKey:who];
  // set enab flag to nimsDefault if it doesn't already exist in enabledFlags
  if (enab == nil) {
    enab = [NSNumber numberWithBool:nimsDefault];
    [enabledFlags setObject:enab forKey:who];
  }
   
  if (DEBUG)
    return appendString([self preNum:[self procSlash:inStr:contentObj]:who],
                        debugMsg(contentObj));    
  else
    return [self preNum:[self procSlash:inStr:contentObj]:who];
}


/*******************************************************************************
 * procSlash:
 * process slash command (do nothing if inStr doesn't start with a slash)
 ******************************************************************************/
-(NSAttributedString*)procSlash:(NSAttributedString*)inStr 
                               :(AIContentObject*)contentObj
{ 
  if(![[[inStr string] stringByTrimmingCharactersInSet:[NSCharacterSet 
                                                        whitespaceCharacterSet]] 
        hasPrefix:@"/"]) return inStr;
  NSString* from = [[contentObj destination] UID];
  NSString* to = [[contentObj source] UID];
  
  NSString *cmd;
  NSScanner *scanner = [NSScanner scannerWithString:[inStr string]];
  [scanner scanUpToCharactersFromSet:[NSCharacterSet
                                      whitespaceAndNewlineCharacterSet] 
                          intoString:&cmd];
  NSString *args = [[[scanner string] substringFromIndex:[scanner scanLocation]]
                    stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  
  
  
  //sendSystemMsg([NSString stringWithFormat:@"[%@|%@]", cmd,args], contentObj);

  if ([cmd isEqualToString:@"/version"]) {
    return [[[NSAttributedString alloc]
             initWithString:[NSString stringWithFormat:
                             @"%@\n [NIMS version %@]",
                             [inStr string],VERSION]] 
            autorelease];
  }
  if ([cmd isEqualToString:@"/help"]) {
    return [[[NSAttributedString alloc]
             initWithString:[NSString stringWithFormat:
             @"%@\n [Type /nims to toggle numbered IMs with the person " 
              "you're chatting with.]",
             [inStr string]]] autorelease];
  }
  if ([cmd isEqualToString:@"/nims"]) {
    BOOL nims;
    if ([args isEqualToString:@"on"]) {
      nims = TRUE;
    } else if ([args isEqualToString:@"off"]) {
      nims = FALSE;
    } else {
      nims = ![[enabledFlags valueForKey:from] boolValue];
    }
    [enabledFlags setObject:[NSNumber numberWithBool:nims] forKey:from];
    // TODO Send the parenthetical as a system message (w/ delay so comes after)
    sendSystemMsg(@"(Use /nimsdef to toggle the default for new chats.)",
                  contentObj);
    
    NSString* alert = nims ? 
    @"Numbered IMs (NIMS) for this chat is now ON.": 
    @"Numbered IMs (NIMS) for this chat is now OFF.";

    return [[[NSAttributedString alloc]
             initWithString:[NSString stringWithFormat:
                             @"%@\n [%@]",
                             [inStr string], alert]]
            autorelease];
  } 
  if ([cmd isEqualToString:@"/nimsdef"] || 
      [cmd isEqualToString:@"/nimsdefault"]) {
    nimsDefault = !nimsDefault;
    NSString* alert = nimsDefault ? @"NIMS default (for new chats) is ON." : 
                                    @"NIMS default (for new chats) is OFF.";
    sendSystemMsg(alert, contentObj);
    return nil;
  } 
  if ([cmd isEqualToString:@"/rand"] || [cmd isEqualToString:@"/skyootle"]) {
    int max = [args intValue];
    if (max == 0) max = 10;
    return [[[NSAttributedString alloc] // was NSMutableAttributedString
             initWithString:[NSString stringWithFormat:
                             @"%@\n [%@ rolled %i out of 1-%i]", 
                             [inStr string], to, rand()%max+1, max]] 
            autorelease];
  }
  if ([cmd isEqualToString:@"/show"]) {
    NSMutableString* toShow = [hStacks valueForKey:from];
    if (toShow == nil) 
      toShow = [NSString stringWithString:@"[Nothing to show.]"];
    [hStacks removeObjectForKey:from];
    NSAttributedString* ret = [[[NSAttributedString alloc]
                                initWithString:[NSString stringWithFormat:
                                            @"%@\n%@", [inStr string], toShow]] 
                               autorelease];
    [toShow release];
    return ret;
  }
  if ([cmd isEqualToString:@"/hide"]) {
    NSMutableString* hid = [hStacks valueForKey:from];
    if (hid == nil) {
      hid = [[NSMutableString alloc] initWithString:
             [NSString stringWithFormat:@" %@",args]];
    } else {
      [hid appendFormat:@"\n %@",args];
    }
    [hStacks setObject:hid forKey:from];
    
    sendSystemMsg([NSString stringWithFormat:
                   @"Your stack:\n%@", hid], contentObj);
    
    return [[[NSAttributedString alloc] initWithString:
             @"/hide [***HIDDEN***]\n"
              " [Use /show to reveal all your hidden messages]"]
            autorelease];
  }
  
  return inStr;
}

/******************************************************************************
 * preNum:
 * prepend number to inStr (an IM), if numbering enabled.
 ******************************************************************************/
-(NSAttributedString*)preNum:(NSAttributedString*)inStr :(NSString*)who
{
  if (![[enabledFlags valueForKey:who] boolValue]) return inStr;
  if (inStr == nil) return nil;
  
  NSNumber* tmp = [outNums valueForKey:who];
  int outn = tmp == nil ? 1 : [tmp intValue];  // start counting at 1.
  // TODO: adjustable wrap threshold (ie, what to mod by)
  //       also means pad left with 0's to be length log_10 of mod_amt
  [outNums setObject:[NSNumber numberWithInt: (outn+1)%100] forKey:who];
  
  NSMutableAttributedString* newStr =  
  [[[NSMutableAttributedString alloc]
    initWithString:[NSString stringWithFormat:@"(%@%i) %@", 
                    (outn<10 ? @"0" : @""), outn, [inStr string]]]
   autorelease];

  //Make the prepended number distinctive (small/gray/bold):
  NSColor *txtColor = [NSColor grayColor];
  //NSFont *txtFont = [NSFont boldSystemFontOfSize:6];
  NSDictionary *txtDict = [NSDictionary dictionaryWithObjectsAndKeys:
                           //txtFont, NSFontAttributeName, 
                           txtColor, NSForegroundColorAttributeName, nil];
  [newStr addAttributes:txtDict range:NSMakeRange(0,4)];
  
  return newStr;
}


/******************************************************************************
 * toggleEnabled:
 * toggle whether number is on for given user; return new value (a boolean). 
 ******************************************************************************/
-(BOOL)toggleEnabled:(NSString*)who
{
  BOOL enab = ![[enabledFlags valueForKey:who] boolValue];
  [enabledFlags setObject:[NSNumber numberWithBool:enab] forKey:who];
  return enab;
}


/******************************************************************************
 * sendSystemMsg:
 ******************************************************************************/
// TODO: can I send withSource nil? or is there some other convention
// for sending messages to myself?
void sendSystemMsg(NSString* m, AIContentObject* co)
{
  NSAttributedString* tmp = [[[NSAttributedString alloc] initWithString:m] 
                             autorelease];
  //Create our content object
  AIContentEvent* sysmsg = [AIContentEvent statusInChat:[co chat]
                                          withSource:[[co chat] account]
                                         destination:[[co chat] account]
                                                date:[NSDate date]
                                             message:tmp
                                            withType:CONTENT_EVENT_TYPE];
  //Add the object
  [[adium contentController] receiveContentObject:sysmsg];
  
  //An alternate way that seems to do the same thing, and may be preferable?
  /*
  [[adium contentController] displayEvent:m
                                   ofType:CONTENT_EVENT_TYPE
                                   inChat:[contentObj chat]];
   */
}


// NOTE: this is a non delaying attempt at delayed sysmessages. As yet does no 
// such thing.
//- (void)displayContentObject:(AIContentObject *)inObject usingContentFilters:(BOOL)useContentFilters immediately:(BOOL)immediately;
//- (void)displayEvent:(NSString *)message ofType:(NSString *)type inChat:(AIChat *)inChat;
/*
-(void)sendSystemMsgDelayed:(NSString*)m :(AIContentObject*)contentObj;
//void sendSystemMsgDelayed(NSString *m, AIContentObject *contentObj)
{
  [super performSelector:@selector(sendSystemMsg:object:)
             withObject:m
             withObject:contentObj
             afterDelay:0];
  
  NSAttributedString* tmp = [[[NSAttributedString alloc] initWithString:m] 
                             autorelease];
  //Create our content object
  AIContentEvent* sysmsg = [AIContentEvent statusInChat:[contentObj chat]
                                             withSource:[[contentObj chat] account]
                                            destination:[[contentObj chat] account]
                         // date:[NSDate dateWithTimeIntervalSinceNow:1.] 
                                                   date:[NSDate date]
                                                message:tmp
                                               withType:CONTENT_EVENT_TYPE];
  
  [sysmsg setDisplayContentImmediately:NO];
  //Add the object
  [[adium contentController] sendContentObject:sysmsg];
  [[adium contentController] displayEvent:m
                                   ofType:CONTENT_EVENT_TYPE
                                   inChat:[contentObj chat]];
   
}
*/


NSString* debugMsg(AIContentObject* co)
{

  //AIChat* chatObj = [co chat];
  return [NSString stringWithFormat:@"\n--------------------\nDEBUG:"
                                    @"\n  type = %@"
                                    @"\n  source = %@\n  dest = %@"
                                    @"\n  msgDate = %@",
                                    //@"\n  chatOpened = %@\n  hasSentRcv = %@",
          [co type], 
          [co source], 
          [co destination], 
          [[co date] description] 
          //[chatObj dateOpened] description], 
          //[chatObj hasSentOrReceivedContent]
          ];

 }
NSAttributedString* appendString(NSAttributedString* inStr, NSString* add) {
  return [[[NSAttributedString alloc]
           initWithString:[NSString stringWithFormat:
                           @"%@%@",
                           [inStr string],
                           add]
           ] 
          autorelease];
}


/*!
 * @brief When should this filter run?
 */
- (CGFloat)filterPriority { return DEFAULT_FILTER_PRIORITY; }

- (NSString *)pluginAuthor {
	return @"Daniel Reeves & Bethany Soule";
}

- (NSString *)pluginURL {
	return @"http://yootles.com/nims";
}

- (NSString *)pluginVersion {
	return VERSION;
}

- (NSString *)pluginDescription {
	return @"Prepend consecutive numbers to outgoing messages and check that "
  "incoming messages (if numbered) are consecutive, sending an alert if not.";
}


@end

/* contentEvent examples:

 **************************************
 if ([contentType isEqualToString:CONTENT_EVENT_TYPE] 
                               || CONTENT_NOTIFICATION_TYPE
 
 **************************************
 AIContentEvent	*content;
 
 //Create our content object
 content = [AIContentEvent statusInChat:chat
 withSource:contact
 destination:[chat account]
 date:[NSDate date]
 message:attributedMessage
 withType:type];
 
 //Add the object
 [[adium contentController] receiveContentObject:content];
 
 */

/******************************************************************************
 * SCRATCH (scheduled for deletion)
 ******************************************************************************/

//NSArray *args = [[inStr string] componentsSeparatedByString:@" "];

 
//else {  // append stuff anyway, for debugging
//modstr = [[NSMutableAttributedString alloc]
//          initWithString:[NSString stringWithFormat:
//           @"%@\n[DEBUG:\n%i -> %i\n%@ -> %@]",
//                          [inAttributedString string], lastn, parsedNum, 
//                               [[contentObj source] UID], @"me"]];
//}

