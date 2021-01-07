package com.smooch.rnsmooch;

import android.content.Intent;
import android.content.SharedPreferences;
import android.preference.PreferenceManager;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.ReadableMapKeySetIterator;
import com.facebook.react.bridge.ReadableType;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableNativeMap;
import com.facebook.react.bridge.WritableNativeArray;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.HashMap;
import java.util.Map;
import java.util.List;

import io.smooch.core.CardSummary;
import io.smooch.core.ConversationDelegate;
import io.smooch.core.ConversationEvent;
import io.smooch.core.InitializationStatus;
import io.smooch.core.MessageAction;
import io.smooch.core.MessageUploadStatus;
import io.smooch.core.PaymentStatus;
import io.smooch.core.Smooch;
import io.smooch.core.SmoochCallback;
import io.smooch.core.SmoochConnectionStatus;
import io.smooch.core.User;
import io.smooch.ui.ConversationActivity;
import io.smooch.core.MessageModifierDelegate;
import io.smooch.core.Message;
import io.smooch.core.Conversation;
import io.smooch.core.ConversationDelegateAdapter;
import io.smooch.core.ConversationDetails;
import io.smooch.core.LogoutResult;
import io.smooch.core.LoginResult;
import io.smooch.core.Participant;

public class ReactNativeSmooch extends ReactContextBaseJavaModule {

    private ReactApplicationContext mreactContext;
    private ReadableMap globalMetadata = null;
	private Boolean sendHideEvent = false;
	private String activeConversationId;

    @Override
    public String getName() {
        return "SmoochManager";
    }

    public ReactNativeSmooch(ReactApplicationContext reactContext) {
        super(reactContext);
        mreactContext = reactContext;
    }

    private void sendEvent(ReactContext reactContext,
                           String eventName,
                           @Nullable WritableMap params) {
        reactContext
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(eventName, params);
    }

    @ReactMethod
    public void setActiveConversationId(String conversationId, final Promise promise) {
        Smooch.loadConversation(conversationId, new SmoochCallback<Conversation>() {
            @Override
            public void run(Response<Conversation> response) {
                activeConversationId = conversationId;
                promise.resolve(null);
            }
        });
    }

    @ReactMethod
    public void login(String userId, String jwt, final Promise promise) {
        Smooch.login(userId, jwt, new SmoochCallback<LoginResult>() {
            @Override
            public void run(Response<LoginResult> response) {
              if (promise != null) {
                if (response.getError() != null) {
                    promise.reject("" + response.getStatus(), response.getError());
                    return;
                }
                setMessageDelegate();
                setConversationDelegate();

                promise.resolve(null);
              }
            }
        });
    }

    @ReactMethod
    public void markConversationAsRead(String conversationId, final Promise promise) {
        Smooch.getConversationById(conversationId, new SmoochCallback<Conversation>() {
            @Override
            public void run(Response<Conversation> response) {
              if (promise != null) {
                if (response.getError() != null) {
                    promise.reject("" + response.getStatus(), response.getError());
                    return;
                }
                response.getData().markAllAsRead();
                promise.resolve(null);
              }
            }
        });
    }

    private WritableMap convertMapToReactNativeMap(Map<String, Object> map) {
        WritableMap result = new WritableNativeMap();
        if (map == null) {
            return result;
        }
        for (String s : map.keySet()) {
            if (map.get(s) instanceof String) {
                result.putString(s, (String) map.get(s));
            } else if (map.get(s) instanceof Boolean) {
                result.putBoolean(s, (Boolean) map.get(s));
            } else if (map.get(s) instanceof Double) {
                result.putDouble(s, (Double) map.get(s));
            } else if (map.get(s) instanceof Integer) {
                result.putInt(s, (Integer) map.get(s));
            }
        }
        return result;
    }

    private WritableMap convertConversationToMap(Conversation c) {
        WritableMap map = new WritableNativeMap();

        WritableArray participantsArr = new WritableNativeArray();
        java.util.List<Participant> participants = c.getParticipants();

        for (Participant p : participants) {
            WritableMap participant = new WritableNativeMap();
            participant.putString("participantId", p.getId());
            participant.putString("userId", p.getUserId());
            participantsArr.pushMap(participant);
        }

        map.putString("id", c.getId());
        map.putString("displayName", c.getDisplayName());
        map.putString("lastUpdatedAt", c.getLastUpdatedAt().toString());
        map.putMap("metadata", convertMapToReactNativeMap(c.getMetadata()));
        map.putArray("participants", participantsArr);
        return map;
    }

    @ReactMethod
    public void getConversations(final Promise promise) {
        Smooch.getConversationsList(new SmoochCallback<java.util.List<Conversation>>() {
            @Override
            public void run(Response<java.util.List<Conversation>> response) {
              if (promise != null) {
                if (response.getError() != null) {
                    promise.reject("" + response.getStatus(), response.getError());
                    return;
                }
                WritableArray conversations = new WritableNativeArray();
                for (Conversation c : response.getData()) {
                    conversations.pushMap(convertConversationToMap(c));
                }
                promise.resolve(conversations);
              }
            }
        });
    }

    @ReactMethod
    public void sendMessage(final String conversationId, final String message, final Promise promise) {
        Smooch.getConversationById(conversationId, new SmoochCallback<Conversation>() {
            @Override
            public void run(Response<Conversation> response) {
              if (promise != null) {
                if (response.getError() != null) {
                    promise.reject("" + response.getStatus(), response.getError());
                    return;
                }
                HashMap metadata = new java.util.HashMap<java.lang.String,java.lang.Object>();
                User user = User.getCurrentUser();
                metadata.put("author", user.getUserId());
                response.getData().sendMessage(new Message(message, message, metadata));
                promise.resolve(null);
              }
            }
        });
    }

	@ReactMethod
	public void setSendHideEvent(Boolean hideEvent) {
	    sendHideEvent = hideEvent;
	}

    @ReactMethod
    public void logout(final Promise promise) {
        Smooch.logout(new SmoochCallback<LogoutResult>() {
            @Override
            public void run(Response<LogoutResult> response) {
                if (response.getError() != null) {
                    promise.reject("" + response.getStatus(), response.getError());
                    return;
                }
                promise.resolve(null);
            }
        });
    }

    @ReactMethod
    public void show() {
        ConversationActivity.builder().withFlags(Intent.FLAG_ACTIVITY_NEW_TASK).show(getReactApplicationContext());
        // v8 ConversationActivity.show(getReactApplicationContext(), Intent.FLAG_ACTIVITY_NEW_TASK);
    }

    @ReactMethod
    public void close() {
        ConversationActivity.close();
    }

    @ReactMethod
    public void getUnreadCount(Promise promise) {
        int unreadCount = Smooch.getConversation().getUnreadCount();
        promise.resolve(unreadCount);
    }

    @ReactMethod
    public void getGroupCounts(final Promise promise) {
        SharedPreferences sharedPreferences = PreferenceManager.getDefaultSharedPreferences(getReactApplicationContext());
        Integer totalUnreadCount = 0;
        List<Message> messages = Smooch.getConversation().getMessages();
        Map<String, Integer> map = new HashMap();
        for (Message message : messages) {
            if (message.getMetadata() != null) {
                String name = (String) message.getMetadata().get("short_property_code");
                String msgId = message.getId();
                if (msgId != null) {
                    if (map.get(name) == null) {
                        map.put(name, 0);
                    }
                    Boolean isRead = sharedPreferences.getBoolean(msgId, false);
                    if (!isRead) {
                        totalUnreadCount += 1;
                        Integer count = map.get(name);
                        map.put(name, count + 1);
                    }
                }
            }
        }

        WritableArray promiseArray = Arguments.createArray();
        WritableMap totalMap = Arguments.createMap();
        totalMap.putInt("totalUnReadCount", totalUnreadCount);
        promiseArray.pushMap(totalMap);

        for (Map.Entry<String, Integer> entry : map.entrySet()) {
            String name = entry.getKey();
            Integer value = entry.getValue();
            WritableMap nMap = Arguments.createMap();
            nMap.putString("short_property_code", name);
            nMap.putInt("unReadCount", value);
            promiseArray.pushMap(nMap);
        }
        promise.resolve(promiseArray);
    }

    @ReactMethod
    public void getUserId(final Promise promise) {
        User user = User.getCurrentUser();
        Log.d("__SMOOCH__ External ID", user.getExternalId());
        Log.d("__SMOOCH__ Actual ID", user.getUserId());
        promise.resolve(user.getUserId());
    }

    @ReactMethod
    public void getMessages(final String conversationId, final Promise promise) {
        Smooch.getConversationById(conversationId, new SmoochCallback<Conversation>() {
            @Override
            public void run(Response<Conversation> response) {
              if (promise != null) {
                if (response.getError() != null) {
                    promise.reject("" + response.getStatus(), response.getError());
                    return;
                }

                Conversation conversation = response.getData();
                List<Message> messages = conversation.getMessages();
                WritableArray promiseArray = Arguments.createArray();

                for (Message message : messages) {
                    Map metadata = message.getMetadata();
                    if (message != null && metadata != null && metadata.get("author") != null) {
                        WritableMap map = Arguments.createMap();
                        map.putString("id", message.getId());
                        map.putString("date", message.getDate().toString());
                        map.putString("text", message.getText());
                        map.putString("author", (String) metadata.get("author"));
                        map.putString("conversationId", conversationId);
                        map.putMap("metadata", convertMapToReactNativeMap(message.getMetadata()));
                        promiseArray.pushMap(map);
                    }
                }

                promise.resolve(promiseArray);
              }
            }
        });
    }

    @ReactMethod
    public void getIncomeMessages(final Promise promise) {
        SharedPreferences sharedPreferences = PreferenceManager.getDefaultSharedPreferences(getReactApplicationContext());

        List<Message> messages = Smooch.getConversation().getMessages();

        WritableArray promiseArray = Arguments.createArray();
        for (Message message : messages) {
            if (message != null && !message.isFromCurrentUser()) {
                WritableMap map = Arguments.createMap();
                DateFormat df2 = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss");
                map.putString("date", df2.format(message.getDate()));
                String msgId = message.getId();
                if (msgId != null) {
                    map.putString("id", msgId); // example: 5fbdc1a608b132000c691500
                    Boolean isRead = sharedPreferences.getBoolean(msgId, false);
                    map.putBoolean("is_read", isRead);
                } else {
                    map.putString("id", "0" );
                    map.putBoolean("is_read", false);
                }
                if (message.getMetadata() != null) {
                    if (message.getMetadata().get("short_property_code") != null) {
                        map.putString("chat_type", "property");
                        map.putString("short_property_code", (String) message.getMetadata().get("short_property_code"));
                        if (message.getMetadata().get("location_display_name") != null) {
                            map.putString("location_display_name", (String) message.getMetadata().get("location_display_name"));
                        } else {
                            map.putString("location_display_name", (String) message.getName());
                        }
                    } // chat_type of employee and employee_name is not real anymore
                }
                promiseArray.pushMap(map);
            }
        }
        promise.resolve(promiseArray);
    }

    @ReactMethod
    public void getMessagesMetadata(final ReadableMap metadata, Promise promise) {
        SharedPreferences sharedPreferences = PreferenceManager.getDefaultSharedPreferences(getReactApplicationContext());

        List<Message> messages = Smooch.getConversation().getMessages();
        WritableArray promiseArray = Arguments.createArray();

        for (Message message : messages) {
            if (message != null && message.getMetadata() != null && message.getMetadata().get("short_property_code").equals(getProperties(metadata).get("short_property_code"))) {
                WritableMap map = Arguments.createMap();
                map.putString("name", message.getName());
                map.putString("text", message.getText());
                map.putBoolean("isFromCurrentUser", message.isFromCurrentUser());
                map.putString("messageId", message.getId());
                if (message.getMetadata() != null) {
                    map.putString("short_property_code", (String) message.getMetadata().get("short_property_code"));
                    map.putString("location_display_name", (String) message.getMetadata().get("location_display_name"));
                }
                String msgId = message.getId();
                if (message.isFromCurrentUser()) {
                    map.putBoolean("isRead", true);
                } else if (msgId != null) {
                    Boolean isRead = sharedPreferences.getBoolean(msgId, false);
                    map.putBoolean("isRead", isRead);
                } else {
                    map.putBoolean("isRead", false);
                }
                promiseArray.pushMap(map);
            }
        }
        promise.resolve(promiseArray);
    }

    @ReactMethod
    public void setFirstName(String firstName) {
        User.getCurrentUser().setFirstName(firstName);
    }

    @ReactMethod
    public void setLastName(String lastName) {
        User.getCurrentUser().setLastName(lastName);
    }

    @ReactMethod
    public void setEmail(String email) {
        User.getCurrentUser().setEmail(email);
    }

    @ReactMethod
    public void setRead(String msgId) {
        SharedPreferences sharedPreferences = PreferenceManager.getDefaultSharedPreferences(getReactApplicationContext());

        SharedPreferences.Editor editor = sharedPreferences.edit();
        editor.putBoolean(msgId, true);
        editor.apply();
    }

    @ReactMethod
    public void setMetadata(final ReadableMap metadata) {
        this.globalMetadata = metadata;
    }

    @ReactMethod
    public void updateConversation(String title, String description, final Promise promise) {
        String conversationId = Smooch.getConversation().getId();
        if (conversationId != null) {
            Smooch.updateConversationById(conversationId, title, description, null, null, new SmoochCallback<Conversation>() {
                @Override
                public void run(Response<Conversation> response) {
                    if (promise != null) {
                        if (response.getError() != null) {
                            Log.d("Update conversation", String.valueOf(response.getError()));
                            promise.reject("" + response.getStatus(), response.getError());
                            return;
                        }
                        promise.resolve(null);
                    }
                }
            });
        }
    }

    private Map<String, Object> getProperties(ReadableMap properties) {
        ReadableMapKeySetIterator iterator = properties.keySetIterator();
        Map<String, Object> props = new HashMap<>();

        while (iterator.hasNextKey()) {
            String key = iterator.nextKey();
            ReadableType type = properties.getType(key);
            if (type == ReadableType.Boolean) {
                props.put(key, properties.getBoolean(key));
            } else if (type == ReadableType.Number) {
                props.put(key, properties.getDouble(key));
            } else if (type == ReadableType.String) {
                props.put(key, properties.getString(key));
            }
        }

        return props;
    }
    private void setMessageDelegate() {
        Smooch.setMessageModifierDelegate(new MessageModifierDelegate() {
            @Override
            public Message beforeSend(ConversationDetails conversationDetails, Message message) {
                if (globalMetadata != null) {
                    Log.d("Smooch", String.valueOf(globalMetadata));
                    message.setMetadata(getProperties(globalMetadata));
                }
                return message;
            }

            @Override
            public Message beforeDisplay(ConversationDetails conversationDetails, Message message) {
                SharedPreferences sharedPreferences = PreferenceManager.getDefaultSharedPreferences(getReactApplicationContext());
                if (globalMetadata != null && message != null && message.getMetadata() != null && message.getMetadata().get("short_property_code").equals(getProperties(globalMetadata).get("short_property_code"))) {
                    String msgId = message.getId();
                    if (msgId != null) {
                        Boolean isRead = sharedPreferences.getBoolean(msgId, false);
                        if (!isRead) {
                            SharedPreferences.Editor editor = sharedPreferences.edit();
                            editor.putBoolean(msgId, true);
                            editor.apply();
                        }
                    }
                    return message;
                }
                return null;
            }

            @Override
            public Message beforeNotification(String s, Message message) {

                WritableMap params = Arguments.createMap();
                if (message.getMetadata() == null) {
                    return null;
                }
                String code = (String) message.getMetadata().get("short_property_code");
                params.putString("short_property_code", code);
                String name = (String) message.getMetadata().get("location_display_name");
                params.putString("location_display_name", name);

                setMetadata(params);
                updateConversation("Conversation", name, null);
                if (sendHideEvent) {
                    Log.d("onUnreadCountUpdate", "on beforeNotification");
                    sendEvent(mreactContext, "unreadCountUpdate", null);
                }

                return message;
            }
        });
    }
    private void setConversationDelegate() {
        Smooch.setConversationDelegate(new ConversationDelegate() {
            @Override
            public void onMessagesReceived(@NonNull Conversation conversation, @NonNull List<Message> list) {
                Log.d("__SMOOCH__", "Messages received");
                for (Message m : list) {
                    WritableMap message = new WritableNativeMap();
                    message.putString("id", m.getId());
                    message.putString("date", m.getDate().toString());
                    message.putString("text", m.getText());
                    message.putString("author", m.getUserId());
                    message.putString("conversationId", conversation.getId());
                    message.putMap("metadata", convertMapToReactNativeMap(m.getMetadata()));
                    sendEvent(mreactContext, "message", message);
                }
            }

            @Override
            public void onMessagesReset(@NonNull Conversation conversation, @NonNull List<Message> list) {

            }

            @Override
            public void onUnreadCountChanged(@NonNull Conversation conversation, int i) {

            }

            @Override
            public void onMessageSent(@NonNull Message message, @NonNull MessageUploadStatus messageUploadStatus) {
                Log.d("__SMOOCH__ sending", message.getId());
                Log.d("__SMOOCH__ message date", message.getDate().toString());
                User user = User.getCurrentUser();

                WritableMap result = new WritableNativeMap();
                result.putString("id", message.getId());
                result.putString("date", message.getDate().toString());
                result.putString("text", message.getText());
                result.putString("author", user.getUserId());
                result.putString("conversationId", activeConversationId);
                result.putMap("metadata", convertMapToReactNativeMap(message.getMetadata()));
                sendEvent(mreactContext, "message", result);
            }

            @Override
            public void onConversationEventReceived(@NonNull ConversationEvent conversationEvent) {

            }

            @Override
            public void onInitializationStatusChanged(@NonNull InitializationStatus initializationStatus) {

            }

            @Override
            public void onLoginComplete(@NonNull LoginResult loginResult) {

            }

            @Override
            public void onLogoutComplete(@NonNull LogoutResult logoutResult) {

            }

            @Override
            public void onPaymentProcessed(@NonNull MessageAction messageAction, @NonNull PaymentStatus paymentStatus) {

            }

            @Override
            public boolean shouldTriggerAction(@NonNull MessageAction messageAction) {
                return false;
            }

            @Override
            public void onCardSummaryLoaded(@NonNull CardSummary cardSummary) {

            }

            @Override
            public void onSmoochConnectionStatusChanged(@NonNull SmoochConnectionStatus smoochConnectionStatus) {

            }

            @Override
            public void onSmoochShown() {
            }

            @Override
            public void onSmoochHidden() {
                if (sendHideEvent) {
                    Log.d("onUnreadCountUpdate", "onSmoochHidden");
                    sendEvent(mreactContext, "unreadCountUpdate", null);
                }
            }

            @Override
            public void onConversationsListUpdated(@NonNull List<Conversation> list) {
                for (Conversation conversation : list) {
                    sendEvent(mreactContext, "channel:joined", convertConversationToMap(conversation));
                }
            }
        });
    }

}
