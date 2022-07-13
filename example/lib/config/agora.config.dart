/// Get your own App ID at https://dashboard.agora.io/
String get appId {
  // Allow pass an `appId` as an environment variable with name `TEST_APP_ID` by using --dart-define
  return '05ca794042c44f7f94645bfabdfa3a7b';
}

/// Please refer to https://docs.agora.io/en/Agora%20Platform/token
String get token {
  // Allow pass a `token` as an environment variable with name `TEST_TOKEN` by using --dart-define
  return '00605ca794042c44f7f94645bfabdfa3a7bIABS4lMhW6lyHV7B3F+tn336UMoQI50YRC85DAnxg+9Caha9THkAAAAACgDqLwAAFBDQYgAA';
}

/// Your channel ID
String get channelId {
  // Allow pass a `channelId` as an environment variable with name `TEST_CHANNEL_ID` by using --dart-define
  return 'dev_13173';
}

/// Your int user ID
const int uid = 1;

/// Your user ID for the screen sharing
const int screenSharingUid = 101;

/// Your string user ID
const String stringUid = '10';
