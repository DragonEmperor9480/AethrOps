class Ec2LaunchRequest {
  final String imageId;
  final String instanceType;
  final int minCount;
  final int maxCount;
  final String? keyName;
  final List<String>? securityGroupIds;
  final String? subnetId;
  final Map<String, String>? tags;
  final String? userData;
  final int? volumeSize;
  final String? volumeType;
  final String? region;

  Ec2LaunchRequest({
    required this.imageId,
    required this.instanceType,
    this.minCount = 1,
    this.maxCount = 1,
    this.keyName,
    this.securityGroupIds,
    this.subnetId,
    this.tags,
    this.userData,
    this.volumeSize,
    this.volumeType,
    this.region,
  });

  Map<String, dynamic> toJson() {
    return {
      'image_id': imageId,
      'instance_type': instanceType,
      'min_count': minCount,
      'max_count': maxCount,
      if (keyName != null) 'key_name': keyName,
      if (securityGroupIds != null) 'security_group_ids': securityGroupIds,
      if (subnetId != null) 'subnet_id': subnetId,
      if (tags != null) 'tags': tags,
      if (userData != null) 'user_data': userData,
      if (volumeSize != null) 'volume_size': volumeSize,
      if (volumeType != null) 'volume_type': volumeType,
      if (region != null) 'region': region,
    };
  }
}