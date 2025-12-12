/// Central repository for all app constants including quotes, messages, and static data
library;

import 'dart:math' as math;

class AppConstants {
  AppConstants._(); // Private constructor to prevent instantiation

  /// Cloud and DevOps themed quotes
  static const List<String> cloudQuotes = [
    "The cloud is just someone else's computer... but way cooler!",
    "In the cloud, we trust. On-premise, we backup.",
    "There's no place like 127.0.0.1, but the cloud comes close.",
    "Keep calm and scale horizontally.",
    "Infrastructure as code: Because clicking is for mortals.",
    "May your deployments be smooth and your rollbacks unnecessary.",
    "Cloud computing: Where virtual becomes reality.",
    "Automate everything, question nothing... except your bills.",
    "In the cloud, every day is a deployment day.",
    "The best time to migrate to cloud was yesterday. The second best time is now.",
    "Cloud: Because managing your own servers is so 2010.",
    "Your infrastructure should be cattle, not pets.",
    "May your uptime be high and your latency low.",
    "In AWS we trust, all others must bring IAM policies.",
    "The cloud never sleeps, and neither do DevOps engineers.",
    "Serverless: Because managing servers is now someone else's problem.",
    "There are 10 types of clouds: public, private, and hybrid.",
    "With great scalability comes great responsibility... and bills.",
    "The cloud giveth, and the cloud taketh away. Mostly your money.",
    "Auto-scaling: When your infrastructure knows it needs therapy.",
  ];

  /// Funny loading messages for user info
  static const List<String> userLoadingMessages = [
    'Fetching your cloud identity...',
    'Diving into the AWS matrix...',
    'Asking the cloud gods for your name...',
    'Decrypting your digital DNA...',
    'Scanning the cloud for your existence...',
    'Retrieving your cosmic credentials...',
    'Consulting the IAM oracle...',
    'Summoning your user profile from the void...',
  ];

  /// Loading messages for specific AWS services
  static const Map<String, List<String>> serviceLoadingMessages = {
    'iam': [
      'Summoning IAM wizards...',
      'Gathering user permissions...',
      'Consulting the access control matrix...',
      'Decoding identity policies...',
    ],
    's3': [
      'Diving into your secret buckets...',
      'Fishing for your files...',
      'Scanning the object storage ocean...',
      'Retrieving your cloud treasures...',
    ],
    'ec2': [
      'Booting up virtual machines...',
      'Counting your instances...',
      'Checking server heartbeats...',
      'Waking up sleeping instances...',
    ],
    'lambda': [
      'Waking up Lambda functions...',
      'Invoking serverless magic...',
      'Warming up cold starts...',
      'Triggering cloud functions...',
    ],
    'cloudwatch': [
      'Reading the tea leaves...',
      'Analyzing metrics...',
      'Gathering cloud insights...',
      'Monitoring the monitors...',
    ],
    'rds': [
      'Querying the database gods...',
      'Connecting to data realms...',
      'Fetching relational wisdom...',
    ],
  };

  /// Get a random cloud quote
  static String getRandomQuote() {
    final random = math.Random();
    return cloudQuotes[random.nextInt(cloudQuotes.length)];
  }

  /// Get a random user loading message
  static String getRandomUserLoadingMessage() {
    final random = math.Random();
    return userLoadingMessages[random.nextInt(userLoadingMessages.length)];
  }

  /// Get a random loading message for a specific service
  static String getRandomServiceLoadingMessage(String service) {
    final serviceLower = service.toLowerCase();
    final messages = serviceLoadingMessages[serviceLower];

    if (messages == null || messages.isEmpty) {
      return 'Loading...';
    }

    final random = math.Random();
    return messages[random.nextInt(messages.length)];
  }

  /// Get a loading message based on context (auto-detects from message text)
  static String getContextualLoadingMessage(String? context) {
    if (context == null || context.isEmpty) {
      return getRandomQuote();
    }

    final contextLower = context.toLowerCase();

    if (contextLower.contains('user') || contextLower.contains('iam')) {
      return getRandomServiceLoadingMessage('iam');
    } else if (contextLower.contains('bucket') ||
        contextLower.contains('s3') ||
        contextLower.contains('object')) {
      return getRandomServiceLoadingMessage('s3');
    } else if (contextLower.contains('instance') ||
        contextLower.contains('ec2') ||
        contextLower.contains('server')) {
      return getRandomServiceLoadingMessage('ec2');
    } else if (contextLower.contains('function') ||
        contextLower.contains('lambda')) {
      return getRandomServiceLoadingMessage('lambda');
    } else if (contextLower.contains('log') ||
        contextLower.contains('cloudwatch') ||
        contextLower.contains('metric')) {
      return getRandomServiceLoadingMessage('cloudwatch');
    } else if (contextLower.contains('database') ||
        contextLower.contains('rds')) {
      return getRandomServiceLoadingMessage('rds');
    } else {
      return getRandomQuote();
    }
  }
}
