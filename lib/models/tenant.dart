class Tenant{
  int id;
  String name;
  String phone;
  String email;
  String idNo;
  String unitNo;



  Tenant({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.idNo,
    required this.unitNo,
  });


  //map json to image model
  factory Tenant.fromJson(Map<String, dynamic> json){
    return Tenant(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      email: json['email'],
      idNo: json['id_number'],
      unitNo: json['unit_number'],
    
    );
  }
}
