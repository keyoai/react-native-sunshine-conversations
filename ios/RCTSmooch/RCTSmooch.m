#import "RCTSmooch.h"
#import <Smooch/Smooch.h>
#import <UserNotifications/UserNotifications.h>
#import <Smooch/SKTMessage.h>
#import <Smooch/SKTConversation.h>

@interface MyConversationDelegate()
@end

@interface SmoochManager() {
    NSString *activeConversationId;
    NSDictionary *attributes;
}
- (void)sendEvent;
@end

@implementation MyConversationDelegate
@synthesize someProperty;

- (void)conversation:(SKTConversation *)conversation unreadCountDidChange:(NSUInteger)unreadCount {
    NSLog(@"New unreads in %@", conversation.conversationId);
}

- (void)conversationListDidRefresh:(NSArray<SKTConversation*> *)conversationList {
    NSLog(@"Smooch conversation list refresh");
    for (SKTConversation *conversation in conversationList) {
        NSMutableArray *participants = [NSMutableArray arrayWithCapacity:1];
        for (SKTParticipant *participant in conversation.participants) {
            NSDictionary *object = @{
                @"userId": participant.userId,
                @"participantId": participant.participantId,
            };
            [participants addObject:object];
        }
        NSArray *participantValues = [NSArray arrayWithArray:participants];
        NSDictionary *metadata = @{};
        if (conversation.metadata) {
            metadata = conversation.metadata;
        }
        SKTMessage *lastMessage = [[conversation messages] lastObject];
        NSMutableDictionary *newMessage = [[NSMutableDictionary alloc] init];
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
        newMessage[@"id"] = [lastMessage messageId]; // displayName
        newMessage[@"text"] = [lastMessage text];
        newMessage[@"date"] = [formatter stringFromDate:[lastMessage date]];
        newMessage[@"author"] = [lastMessage metadata][@"author"];
        newMessage[@"conversationId"] = [conversation conversationId];
        newMessage[@"metadata"] = [lastMessage metadata];
        NSDictionary *object = @{
            @"id": conversation.conversationId,
            @"displayName": conversation.displayName,
            @"lastUpdatedAt": conversation.lastUpdatedAt,
            @"metadata": metadata,
            @"participants": participantValues,
            @"messageCount": [NSNumber numberWithInteger:conversation.messageCount],
            @"lastMessage": newMessage,
            @"unreadCount": [NSNumber numberWithInteger:conversation.messageCount],
        };
        [hideId sendEventWithName:@"channel:joined" body:object];
        NSInteger unreadCount = conversation.unreadCount;
//        [hideId sendEventWithName:@"unreadCount" body:unreadCount];
        if (unreadCount > 0) {
            for (SKTMessage* message in conversation.messages) {
                if (message != nil && [message metadata] != nil && [message metadata][@"author"] != nil) {
                    NSMutableDictionary *newMessage = [[NSMutableDictionary alloc] init];
                    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
                    newMessage[@"id"] = [message messageId]; // displayName
                    newMessage[@"text"] = [message text];
                    newMessage[@"date"] = [formatter stringFromDate:[message date]];
                    newMessage[@"author"] = [message metadata][@"author"];
                    newMessage[@"conversationId"] = [conversation conversationId];
                    newMessage[@"metadata"] = [message metadata];
                    [hideId sendEventWithName:@"message" body:newMessage];
                } else {
                    NSLog(@"There was a problem parsing the message");
                    NSLog(@"Message %@", message);
                    NSLog(@"Message metadata %@", message.metadata);
                }
            }
        }
    }
}

- (void)conversation:(SKTConversation *)conversation didReceiveMessages:(nonnull NSArray *)messages {
    NSLog(@"Received Messages");
    for (SKTMessage *message in messages) {
        NSLog(@"Processing a message");
        if (message != nil && [message metadata] != nil && [message metadata][@"author"] != nil) {
            NSMutableDictionary *newMessage = [[NSMutableDictionary alloc] init];
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
            newMessage[@"id"] = [message messageId]; // displayName
            newMessage[@"text"] = [message text];
            newMessage[@"date"] = [formatter stringFromDate:[message date]];
            newMessage[@"author"] = [message metadata][@"author"];
            newMessage[@"conversationId"] = [conversation conversationId];
            newMessage[@"metadata"] = [message metadata];
            [hideId sendEventWithName:@"message" body:newMessage];
        } else {
            NSLog(@"There was a problem parsing the message");
            NSLog(@"Message %@", message);
            NSLog(@"Message metadata %@", message.metadata);
        }
    }
}

- (SKTMessage *)conversation:(SKTConversation *)conversation willSendMessage:(SKTMessage *)message {
    NSLog(@"Smooch willSendMessage with %@", message);
    NSDictionary *metadata = message.metadata;
    if (metadata == nil) {
        metadata = @{};
    }
    NSLog(@"Metadata %@", metadata);
    NSString *userId = [SKTUser currentUser].userId;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
    NSDictionary *messageData = @{
        @"id": message.text,
        @"date": [formatter stringFromDate:[message date]],
        @"text": message.text,
        @"conversationId": conversation.conversationId,
        @"metadata": metadata,
        @"author": userId,
    };
    [hideId sendEventWithName:@"message" body:messageData];
    NSLog(@"Smooch willSendMessage success");
    return message;
}

- (nullable SKTMessage *)conversation:(SKTConversation *)conversation willDisplayMessage:(SKTMessage *)message {
    NSLog(@"Smooch willDisplay with %@", message);
    NSLog(@"Metadata", metadata);
    NSUserDefaults *db = [NSUserDefaults standardUserDefaults];
    if (message != nil) {
      NSDictionary *options = message.metadata;
      if ([options[@"short_property_code"] isEqualToString:metadata[@"short_property_code"]]) {
        NSString *msgId = [message messageId];
        if (msgId != nil) {
            BOOL isRead = [db boolForKey:msgId]; // return NO if not exists
            if (!isRead) {
              [db setBool:@(YES) forKey:msgId];
              [db synchronize];
            }
        }

        return message;
      }
    }
    return nil;
}

- (BOOL)conversation:(SKTConversation *)conversation shouldShowInAppNotificationForMessage:(SKTMessage *)message {
    NSDictionary *options = message.metadata;
    NSLog(@"Smooch shouldShowInAppNotificationForMessage with %@", options);
    conversationTitle = @"Conversation";
    conversationDescription = options[@"location_display_name"];
    metadata = options;

    return false;
}

- (void)conversation:(SKTConversation *)conversation willShowViewController:(UIViewController *)viewController {
    if (viewController != nil && conversationTitle != nil && conversationDescription != nil) {
        UINavigationItem *navigationItem = viewController.navigationItem;
        NSString *fullTitle = [NSString stringWithFormat:@"%@ (%@)", conversationTitle, conversationDescription];
        UIStackView *titleView = [[UIStackView alloc] init];
        titleView.axis = UILayoutConstraintAxisVertical;

        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.textAlignment = UITextAlignmentCenter;
        titleLabel.font = [UIFont systemFontOfSize:20];
        titleLabel.textColor = UIColor.darkGrayColor;
        titleLabel.text = conversationTitle;

        UILabel *subtitleLabel = [[UILabel alloc] init];
        subtitleLabel.textAlignment = UITextAlignmentCenter;
        subtitleLabel.font = [UIFont systemFontOfSize:13];
        subtitleLabel.textColor = UIColor.darkGrayColor;
        subtitleLabel.text = conversationDescription;

        [titleView addArrangedSubview:titleLabel];
        [titleView addArrangedSubview:subtitleLabel];
        [titleView sizeToFit];

        // [navigationItem setTitle:fullTitle];
        [navigationItem setTitleView:titleView];
    }
}

-(void)conversation:(SKTConversation *)conversation willDismissViewController:(UIViewController*)viewController {
    if (sendHideEvent) {
        [hideId sendEvent];
    }
    hideConversation = YES;
}

+ (id)sharedManager {
    NSLog(@"Smooch setting up shared manager");
    static MyConversationDelegate *sharedMyManager = nil;
    @synchronized(self) {
        if (sharedMyManager == nil) {
            sharedMyManager = [[self alloc] init];
        }
    }
    return sharedMyManager;
}

- (void)setMetadata:(NSDictionary *)options {
    NSLog(@"Smooch setMetadata");
    metadata = options;
}
- (NSDictionary *)getMetadata {
    NSLog(@"Smooch getMetadata");
    return metadata;
}

- (void)setSendHideEvent:(BOOL)hideEvent {
    NSLog(@"Smooch setSendHideEvent");
    sendHideEvent = hideEvent;
}

- (BOOL)getSendHideEvent {
    NSLog(@"Smooch getSendHideEvent");
    return sendHideEvent;
}

- (void)setTitle:(NSString *)title description:(NSString *)description {
    NSLog(@"Smooch setTitle");
    conversationTitle = title;
    conversationDescription = description;
}

- (void)setControllerState:(id)callEvent {
    hideConversation = NO;
    hideId = callEvent;
}

- (BOOL)getControllerState {
    return hideConversation;
}
@end


@interface NotificationManager : NSObject
@end

@implementation NotificationManager

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    if (notification.request.content.userInfo[SKTPushNotificationIdentifier] != nil) { [[Smooch userNotificationCenterDelegate] userNotificationCenter:center willPresentNotification:notification withCompletionHandler:completionHandler];
        return;

    }
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)())completionHandler {
    if (response.notification.request.content.userInfo[SKTPushNotificationIdentifier] != nil) {
        [[Smooch userNotificationCenterDelegate] userNotificationCenter:center didReceiveNotificationResponse:response withCompletionHandler:completionHandler];
        return;

    }
}

@end

@implementation SmoochManager

RCT_EXPORT_MODULE();

- (NSArray<NSString *> *)supportedEvents
{
  return @[@"unreadCount", @"message", @"participant:added", @"participant:removed", @"channel:joined"];
}

- (BOOL)isInteger:(NSString *)toCheck {
  if([toCheck intValue] != 0) {
    return true;
  } else if([toCheck isEqualToString:@"0"]) {
    return true;
  } else {
    return false;
  }
}

- (void)sendEvent {
    NSLog(@"sendEvent");
    MyConversationDelegate *myconversation = [MyConversationDelegate sharedManager];
    NSDictionary *options = [myconversation getMetadata];
    if (options != nil && options[@"short_property_code"] != nil) {
        NSString *name = options[@"short_property_code"];
        [self sendEventWithName:@"unreadCountUpdate" body:@{@"name":name}];
    } else {
        [self sendEventWithName:@"unreadCountUpdate" body:@{@"name":@""}];
    }
}

RCT_EXPORT_METHOD(show) {
  NSLog(@"Smooch Show");

  dispatch_async(dispatch_get_main_queue(), ^{
    [Smooch show];
  });
};

RCT_EXPORT_METHOD(close) {
  NSLog(@"Smooch Close");

  dispatch_async(dispatch_get_main_queue(), ^{
      [Smooch close];
    });
};

RCT_EXPORT_METHOD(login:(NSString*)externalId jwt:(NSString*)jwt resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  NSLog(@"Smooch Login");

  dispatch_async(dispatch_get_main_queue(), ^{
      [Smooch login:externalId jwt:jwt completionHandler:^(NSError * _Nullable error, NSDictionary * _Nullable userInfo) {
          if (error) {
              NSLog(@"Error Login");
              reject(
                 userInfo[SKTErrorCodeIdentifier],
                 userInfo[SKTErrorDescriptionIdentifier],
                 error);
          }
          else {
              MyConversationDelegate *myconversation = [MyConversationDelegate sharedManager];
              [Smooch updateConversationDelegate:myconversation];
              resolve(userInfo);
          }
      }];
  });
};

RCT_EXPORT_METHOD(setAttributes:(NSDictionary*)attributes) {
    NSLog(@"Setting attributes %@", attributes);
    self->attributes = attributes;
};

RCT_EXPORT_METHOD(setActiveConversationId:(NSString*)conversationId resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  NSLog(@"Smooch active cid");

  dispatch_async(dispatch_get_main_queue(), ^{
      [Smooch loadConversation:conversationId completionHandler:^(NSError * _Nullable error, NSDictionary * _Nullable userInfo) {
          self->activeConversationId = conversationId;
          MyConversationDelegate *myconversation = [MyConversationDelegate sharedManager];
          [myconversation setControllerState:self];

          resolve(nil);
      }];
  });
};

RCT_EXPORT_METHOD(markConversationAsRead:(NSString*)conversationId resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  NSLog(@"Smooch Mark Conversation Read");
  dispatch_async(dispatch_get_main_queue(), ^{
      [Smooch conversationById:conversationId completionHandler:^(NSError * _Nullable error, SKTConversation * _Nullable conversation) {
          if (error) {
              NSLog(@"Error marking conversation as read");
              reject(@"Error", @"Cannot mark conversation as read", error);
          }
          else {
              [conversation markAllAsRead];
              resolve(NULL);
          }
      }];
  });
};

RCT_EXPORT_METHOD(getUnreadCount:(NSString*) conversationId resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [Smooch conversationById:conversationId completionHandler:^(NSError * _Nullable error, SKTConversation * _Nullable conversation) {
            if (error) {
                NSLog(@"Error getting conversation");
                reject(@"Error", @"Error getting conversation", error);
            }
            else {
                resolve([NSNumber numberWithInteger:conversation.unreadCount]);
            }
        }];
    });
}

RCT_EXPORT_METHOD(sendMessage:(NSString*)conversationId message:(NSString*)message resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  NSLog(@"Smooch send message");
  dispatch_async(dispatch_get_main_queue(), ^{
      [Smooch conversationById:conversationId completionHandler:^(NSError * _Nullable error, SKTConversation * _Nullable conversation) {
          if (error) {
              NSLog(@"Error sending message");
              reject(@"Error", @"Error sending message", error);
          }
          else {
              NSMutableDictionary *metadata = [[NSMutableDictionary alloc] init];
              [metadata addEntriesFromDictionary:@{
                  @"author": [SKTUser currentUser].externalId,
              }];
              if (self->attributes) {
                  [metadata addEntriesFromDictionary:self->attributes];
              }
              SKTMessage *newMessage = [[SKTMessage alloc] initWithText:message payload:message metadata:metadata];
              [conversation sendMessage:newMessage];
              NSLog(@"Smooch message sent");
              resolve(NULL);
          }
      }];
  });
};

RCT_EXPORT_METHOD(getConversations:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  NSLog(@"Smooch get conversations");
  dispatch_async(dispatch_get_main_queue(), ^{
      [Smooch getConversations:^(NSError * _Nullable error, NSArray * _Nullable conversations) {
          if (error) {
              NSLog(@"Error getting conversations");
              reject(@"Error", @"Error getting conversations", error);
          }
          else {
            NSMutableArray *values = [NSMutableArray arrayWithCapacity:1];
            for (SKTConversation *element in conversations) {
                NSMutableArray *participants = [NSMutableArray arrayWithCapacity:1];
                for (SKTParticipant *participant in element.participants) {
                    NSDictionary *object = @{
                        @"userId": participant.userId,
                        @"participantId": participant.participantId,
                    };
                    [participants addObject:object];
                }
                NSArray *participantValues = [NSArray arrayWithArray:participants];
                NSDictionary *metadata = @{};
                if (element.metadata) {
                    metadata = element.metadata;
                }
                SKTMessage *lastMessage = [[element messages] lastObject];
                NSMutableDictionary *newMessage = [[NSMutableDictionary alloc] init];
                if (![lastMessage metadata][@"isInternalNote"]) {
                    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZ-ZZ"];
                    newMessage[@"id"] = [lastMessage messageId]; // displayName
                    newMessage[@"text"] = [lastMessage text];
                    newMessage[@"date"] = [formatter stringFromDate:[lastMessage date]];
                    newMessage[@"author"] = [lastMessage metadata][@"author"];
                    newMessage[@"conversationId"] = [element conversationId];
                    newMessage[@"metadata"] = [lastMessage metadata];
                }
                NSLog(@"last message %@", lastMessage);
                NSDictionary *object = @{
                    @"id": element.conversationId,
                    @"displayName": element.displayName,
                    @"lastUpdatedAt": element.lastUpdatedAt,
                    @"metadata": metadata,
                    @"participants": participantValues,
                    @"messageCount": [NSNumber numberWithInteger:element.messageCount],
                    @"lastMessage": newMessage,
                    @"unreadCount": element.unreadCount,
                };
                [values addObject:object];
            }
            NSArray *returnVal = [NSArray arrayWithArray:values];
            resolve(returnVal);
          }
      }];
  });
};

RCT_EXPORT_METHOD(logout:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  NSLog(@"Smooch Logout");

  dispatch_async(dispatch_get_main_queue(), ^{
      [Smooch logoutWithCompletionHandler:^(NSError * _Nullable error, NSDictionary * _Nullable userInfo) {
          if (error) {
              reject(
                     userInfo[SKTErrorCodeIdentifier],
                     userInfo[SKTErrorDescriptionIdentifier],
                     error);
          }
          else {
              resolve(userInfo);
          }
      }];
  });
};

RCT_EXPORT_METHOD(getUserId:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  NSLog(@"Smooch getUserId");

  resolve([SKTUser currentUser].userId);
};

RCT_EXPORT_METHOD(getGroupCounts:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  NSLog(@"Smooch getGroupCounts");
  NSUserDefaults *db = [NSUserDefaults standardUserDefaults];
  NSInteger totalUnreadCount = 0;

  NSArray *messages = [Smooch conversation].messages;
  NSMutableDictionary *newMessage = [[NSMutableDictionary alloc] init];

  for (id message in messages) {
      if (message != nil) {
          NSDictionary *options = [message metadata];
          if (options != nil) {
              NSString *name = options[@"short_property_code"];
              NSString *msgId = [message messageId];
              if (msgId != nil) {
                  if (newMessage[name] == nil) {
                      newMessage[name] = @(0);
                  }
                  BOOL isRead = [db boolForKey:msgId];
                  if (!isRead) {
                      totalUnreadCount += 1;
                      NSNumber *count = newMessage[name];
                      newMessage[name] = [NSNumber numberWithInt:[count intValue] + 1];
                  }
              }
          }
      }
  }

  NSMutableArray *groups = [[NSMutableArray alloc] init];

  NSMutableDictionary *totalMessage = [[NSMutableDictionary alloc] init];
  totalMessage[@"totalUnReadCount"] = @(totalUnreadCount);
  [groups addObject: totalMessage];

  for (NSString *key in newMessage) {
      NSInteger value = [newMessage[key] longValue];
      NSMutableDictionary *tMsg = [[NSMutableDictionary alloc] init];
      tMsg[@"short_property_code"] = key;
      tMsg[@"unReadCount"] = @(value);
      [groups addObject: tMsg];
  }

  resolve(groups);
};

RCT_EXPORT_METHOD(getMessages:(NSString*)conversationId resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  NSLog(@"Smooch getMessages");
    [Smooch conversationById:conversationId completionHandler:^(NSError * _Nullable error, SKTConversation * _Nullable conversation) {
        if (error) {
            NSLog(@"Error marking conversation as read");
            reject(@"Error", @"Cannot mark conversation as read", error);
        }
        else {
            NSMutableArray *newMessages = [[NSMutableArray alloc] init];
            NSArray *messages = conversation.messages;
            for (id message in messages) {
                if (message != nil && [message metadata] != nil && [message metadata][@"author"] != nil) {
                    NSMutableDictionary *newMessage = [[NSMutableDictionary alloc] init];
                    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
                    newMessage[@"id"] = [message messageId]; // displayName
                    newMessage[@"text"] = [message text];
                    newMessage[@"date"] = [formatter stringFromDate:[message date]];
                    newMessage[@"author"] = [message metadata][@"author"];
                    newMessage[@"conversationId"] = [conversation conversationId];
                    newMessage[@"metadata"] = [message metadata];
                    [newMessages addObject: newMessage];
                }
            }
            resolve(newMessages);
        }
    }];
};

RCT_EXPORT_METHOD(getIncomeMessages:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  NSLog(@"Smooch getIncomeMessages");
  NSUserDefaults *db = [NSUserDefaults standardUserDefaults];

  NSMutableArray *newMessages = [[NSMutableArray alloc] init];
  NSArray *messages = [Smooch conversation].messages;
  for (id message in messages) {
      if (message != nil && ![message isFromCurrentUser]) {
          NSMutableDictionary *newMessage = [[NSMutableDictionary alloc] init];
          NSDate *msgDate = [message date];
          NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
          [formatter setDateFormat: @"yyyy-MM-dd'T'HH:mm:ss"];
          newMessage[@"date"] = [formatter stringFromDate:msgDate];
          NSString *msgId = [message messageId];
          if (msgId != nil) {
            newMessage[@"id"] = msgId; // example: 5fbdc1a608b132000c691500
            BOOL isRead = [db boolForKey:msgId];
            newMessage[@"is_read"] = @(isRead);
          } else {
            newMessage[@"id"] = @"0";
            newMessage[@"is_read"] = @(NO);
          }
          NSDictionary *options = [message metadata];
          if (options != nil) {
            if (options[@"short_property_code"] != nil) {
              newMessage[@"chat_type"] = @"property";
              newMessage[@"short_property_code"] = options[@"short_property_code"];
              if (options[@"location_display_name"] != nil) {
                newMessage[@"location_display_name"] = options[@"location_display_name"];
              } else {
                newMessage[@"location_display_name"] = [message name];
              }
            } // chat_type of employee and employee_name is not real anymore
          }
          [newMessages addObject: newMessage];
      }
  }
  resolve(newMessages);
};

RCT_EXPORT_METHOD(getMessagesMetadata:(NSDictionary *)metadata resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  NSLog(@"Smooch getMessagesMetadata");
  NSUserDefaults *db = [NSUserDefaults standardUserDefaults];

  NSMutableArray *newMessages = [[NSMutableArray alloc] init];
  NSArray *messages = [Smooch conversation].messages;
  for (id message in messages) {
    if (message != nil) {
      NSDictionary *options = [message metadata];
      if ([options[@"short_property_code"] isEqualToString:metadata[@"short_property_code"]]) {
          NSMutableDictionary *newMessage = [[NSMutableDictionary alloc] init];
          newMessage[@"name"] = [message name]; // displayName
          newMessage[@"text"] = [message text];
          newMessage[@"isFromCurrentUser"] = @([message isFromCurrentUser]);
          newMessage[@"messageId"] = [message messageId];
          NSDictionary *options = [message metadata];
          if (options != nil) {
              newMessage[@"short_property_code"] = options[@"short_property_code"];
              newMessage[@"location_display_name"] = options[@"location_display_name"];
          }
          NSString *msgId = [message messageId];
          if ([message isFromCurrentUser]) {
              newMessage[@"isRead"] = @(YES);
          } else if (msgId != nil) {
              BOOL isRead = [db boolForKey:msgId];
              newMessage[@"isRead"] = @(isRead);
          } else {
              newMessage[@"isRead"] = @(NO);
          }
          [newMessages addObject: newMessage];
      }
    }
  }
  resolve(newMessages);
};

RCT_EXPORT_METHOD(setFirstName:(NSString*)firstName) {
  NSLog(@"Smooch setFirstName");

  [SKTUser currentUser].firstName = firstName;
};

RCT_EXPORT_METHOD(setLastName:(NSString*)lastName) {
  NSLog(@"Smooch setLastName");

  [SKTUser currentUser].lastName = lastName;
};

RCT_EXPORT_METHOD(setEmail:(NSString*)email) {
  NSLog(@"Smooch setEmail");

  [SKTUser currentUser].email = email;
};

RCT_EXPORT_METHOD(setSignedUpAt:(NSDate*)date) {
  NSLog(@"Smooch setSignedUpAt");

  [SKTUser currentUser].signedUpAt = date;
};

RCT_EXPORT_METHOD(setSendHideEvent:(BOOL)hideEvent) {
  NSLog(@"Smooch setSendHideEvent");
    MyConversationDelegate *myconversation = [MyConversationDelegate sharedManager];
  [myconversation setSendHideEvent:hideEvent];
};

RCT_EXPORT_METHOD(setRead:(NSString *)msgId) {
  NSLog(@"Smooch setRead with %@", msgId);
  NSUserDefaults *db = [NSUserDefaults standardUserDefaults];
  [db setBool:@(YES) forKey:msgId];
  [db synchronize];
};

RCT_EXPORT_METHOD(setMetadata:(NSDictionary *)options) {
  NSLog(@"Smooch setMetadata with %@", options);
    MyConversationDelegate *myconversation = [MyConversationDelegate sharedManager];
  [myconversation setMetadata:options];
  NSLog(@"Smooch getMetadata with %@", [myconversation getMetadata]);
};

RCT_EXPORT_METHOD(updateConversation:(NSString *)title description:(NSString *)description resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  NSLog(@"Smooch updateConversation with %@", description);
    MyConversationDelegate *myconversation = [MyConversationDelegate sharedManager];
  [myconversation setTitle:title description:description];
  resolve(@(YES));
};

// Version 9.0.0
//
//RCT_EXPORT_METHOD(updateConversation:(NSString*)title description:(NSString*)description  resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
//
//  NSLog(@"Smooch updateConversation with %@", description);
//
//  NSString *conversationId = [Smooch conversation].conversationId;
//  if (conversationId != nil) {
//    dispatch_async(dispatch_get_main_queue(), ^{
//        [Smooch updateConversationById:conversationId withName:title description:description iconUrl:nil metadata:nil completionHandler:^(NSError * _Nullable error, NSDictionary * _Nullable userInfo) {
//            if (error) {
//                reject(
//                   userInfo[SKTErrorCodeIdentifier],
//                   userInfo[SKTErrorDescriptionIdentifier],
//                   error);
//            }
//            else {
//                resolve(userInfo);
//            }
//        }];
//    });
//  }
//};


@end
