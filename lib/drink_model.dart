class DrinkRecord {
  String id;
  DateTime date;
  String storeName;
  String itemName;
  String ice;
  String sugar;
  int price;

  DrinkRecord({
    required this.id,
    required this.date,
    this.storeName = "",
    this.itemName = "",
    this.ice = "正常",
    this.sugar = "全糖",
    this.price = 0,
  });
}