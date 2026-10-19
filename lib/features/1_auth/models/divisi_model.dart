class Divisi {
  final int id;
  final String nama;

  Divisi({required this.id, required this.nama});

  factory Divisi.fromJson(Map<String, dynamic> json) {
    return Divisi(
      id: json['id_divisi'],
      nama: json['nama_divisi'],
    );
  }


  @override
  String toString() {
    return nama;
  }
}