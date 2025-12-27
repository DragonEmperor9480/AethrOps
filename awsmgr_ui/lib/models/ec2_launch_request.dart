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
    };
  }
}

class AmiOption {
  final String name;
  final String imageId;
  final String description;
  final String architecture;

  const AmiOption({
    required this.name,
    required this.imageId,
    required this.description,
    required this.architecture,
  });
}
