import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:convert';

void main() => runApp(const DrinkApp());

class DrinkApp extends StatelessWidget {
  const DrinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const MainContainer(),
    );
  }
}

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _selectedIndex = 0; // 目前選中的分頁索引

  // 定義分頁清單
  final List<Widget> _pages = [
    const DrinkHistoryPage(),
    const AllHistoryPage(),
    const DrinkInputPage(),      
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex], // 根據索引顯示分頁
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFF9181F4), // 選中時的紫色
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "日曆"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "總覽"),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: "新增"),
        ],
      ),
    );
  }
}


class AllHistoryPage extends StatefulWidget {
  const AllHistoryPage({super.key});

  @override
  State<AllHistoryPage> createState() => _AllHistoryPageState();
}

class _AllHistoryPageState extends State<AllHistoryPage> {
  List<String> allHistory = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAllHistory();
  }

  void _loadAllHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      allHistory = prefs.getStringList('drink_history') ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    // 取得全部資料的統計
    var stats = getStats(allHistory);

    return Scaffold(
      appBar: AppBar(title: const Text("全部紀錄", style: TextStyle(fontWeight: FontWeight.bold))),
      body: Column(
        children: [
          // 總體統計方塊
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Row(
              children: [
                buildStatCard("累計杯數", stats['count']!, const Color(0xFF9181F4)),
                buildStatCard("總支出", stats['total']!, const Color(0xFFF56A9C)),
                buildStatCard("平均單價", stats['avg']!, const Color(0xFF4CAF50)),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: allHistory.isEmpty
                ? const Center(child: Text("目前還沒有任何紀錄喔"))
                : ListView.builder(
                    itemCount: allHistory.length,
                    itemBuilder: (context, index) {
                      // 這裡也要支援側滑刪除
                      final String itemString = allHistory[allHistory.length - 1 - index];
                      return Dismissible(
                        key: Key('all_$itemString$index'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) async {
                          final prefs = await SharedPreferences.getInstance();
                          setState(() {
                            allHistory.remove(itemString);
                          });
                          await prefs.setStringList('drink_history', allHistory);
                        },
                        child: buildHistoryCard(itemString),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class DrinkHistoryPage extends StatefulWidget {
  const DrinkHistoryPage({super.key});

  @override
  State<DrinkHistoryPage> createState() => _DrinkHistoryPageState();
}

class _DrinkHistoryPageState extends State<DrinkHistoryPage> {
  List<String> history = [];
  DateTime _focusedDay = DateTime.now();  
  DateTime _selectedDay = DateTime.now();

@override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      history = prefs.getStringList('drink_history') ?? [];
    });
  }

  // --- ★ 這裡放主要的 build 函數 ★ ---
@override
  Widget build(BuildContext context) {
    // 1. 過濾出選中日期的資料
    List<String> dayDrinks = history.where((jsonStr) {
      try {
        var data = jsonDecode(jsonStr);
        DateTime recordDate = DateTime.parse(data['date']);
        return isSameDay(recordDate, _selectedDay);
      } catch (e) {
        return false;
      }
    }).toList();

    // 2. 計算這「選定日期」的統計數字
    var stats = getStats(dayDrinks); // 使用我們之前的計算函數

    return Scaffold(
      appBar: AppBar(title: const Text("喝飲料（花錢）紀錄", style: TextStyle(fontWeight: FontWeight.bold))),
      body: Column(
        children: [
          // --- 第一層：日曆 ---
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: (day) {
              return history.where((jsonStr) {
                try {
                  var data = jsonDecode(jsonStr);
                  DateTime recordDate = DateTime.parse(data['date']);
                  return isSameDay(recordDate, day);
                } catch (e) {
                  return false;
                }
              }).toList();
            },
            calendarBuilders: CalendarBuilders(
                // ★ 關鍵：自訂每一格日期的外觀 ★
                prioritizedBuilder: (context, day, focusedDay) {
                  // 檢查這天有沒有紀錄
                  bool hasDrink = history.any((jsonStr) {
                    try {
                      var data = jsonDecode(jsonStr);
                      return isSameDay(DateTime.parse(data['date']), day);
                    } catch (e) {
                      return false;
                    }
                  });

                  // 如果有紀錄，且不是「目前選中的日期」，就顯示淡淡的背景色
                  if (hasDrink && !isSameDay(day, _selectedDay)) {
                    return Container(
                      margin: const EdgeInsets.all(6.0), // 讓背景稍微縮小一點，看起來像圓形或圓角矩形
                      decoration: BoxDecoration(
                        color: const Color(0xFF9181F4).withOpacity(0.2), // 淡淡的紫色背景
                        shape: BoxShape.circle, // 也可以改用 BoxShape.rectangle 並加上 borderRadius
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(color: Color(0xFF9181F4), fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }
                  return null; // 其他日子（沒紀錄的）使用預設樣式
                },
              ),

            // ★ 自訂小點點或標記的顏色
            calendarStyle: CalendarStyle(
              selectedDecoration: const BoxDecoration(color: Color.fromARGB(255, 199, 184, 197), shape: BoxShape.circle),
              todayDecoration: const BoxDecoration(color: Color.fromARGB(255, 238, 58, 124), shape: BoxShape.circle),
              markersMaxCount: 0,
            ),
            
            headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
          ),

          const Divider(),

          // --- 第二層：統計小方塊 ---
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                buildStatCard("本日杯數", stats['count']!, const Color(0xFF9181F4)),
                buildStatCard("本日支出", stats['total']!, const Color(0xFFF56A9C)),
                buildStatCard("平均單價", stats['avg']!, const Color(0xFF4CAF50)),
              ],
            ),
          ),

          // --- 第三層：紀錄清單 ---
          Expanded(
            child: dayDrinks.isEmpty
                ? Center(child: Text("${_selectedDay.month}/${_selectedDay.day} 沒喝飲料 健康人我的超人", style: const TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: dayDrinks.length,
                    itemBuilder: (context, index) {
                      final String itemString = dayDrinks[dayDrinks.length - 1 - index];

                      return Dismissible(
                            key: Key(itemString + index.toString()), // 給予每筆資料唯一的 Key
                            direction: DismissDirection.endToStart,  // 設定只能由右往左滑
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (direction) async {
                              // --- 這裡處理真正的刪除邏輯 ---
                              final prefs = await SharedPreferences.getInstance();
                              setState(() {
                                // 從原始的 history 清單中找到並移除這一筆
                                history.remove(itemString); 
                              });
                              // 同步存回手機記憶體
                              await prefs.setStringList('drink_history', history);
                              
                              // 提示使用者已刪除
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("紀錄已刪除"), duration: Duration(seconds: 1)),
                              );
                            },
                            // 3. 顯示你原本的漂亮卡片
                            child: buildHistoryCard(itemString),
                          );
                        },
                      )
          ),
        ],
      ),
    );
  }
}

class DrinkInputPage extends StatefulWidget {
  const DrinkInputPage({super.key});

  @override
  State<DrinkInputPage> createState() => _DrinkInputPageState();
}

class _DrinkInputPageState extends State<DrinkInputPage> {
  List<String> drinkHistory = [];
  DateTime selectedDate = DateTime.now();
  String selectedIce = "去冰";
  String selectedSugar = "一分糖";
  String selectedSize = "大杯";
  int currentPrice = 0;

  final TextEditingController storeController = TextEditingController();
  final TextEditingController menuController = TextEditingController();

  final List<String> sizeOptions = ["特大杯", "大杯", "中杯", "小杯"];
  final List<String> iceOptions = ["正常", "少冰", "微冰", "去冰", "溫", "熱"];
  final List<String> sugarOptions = ["全糖", "少糖", "半糖", "微糖", "一分糖", "無糖"];

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  void _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      drinkHistory = prefs.getStringList('drink_history') ?? [];
      print("[system] log recorded, ${drinkHistory.length} items loaded.");
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024), // 最早可以選到去年
      lastDate: DateTime(2101),
      // 可以自訂日曆顏色
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF9181F4), // 標題背景色
              onPrimary: Colors.white,   // 標題文字色
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          "多喝飲料會長胖的計劃",
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildDrinkCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildDrinkCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 頂部標籤與價格
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFFFEBF2), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  "這是今年喝的第 ${(drinkHistory.length + 1).toString().padLeft(2, '0')} 杯！", 
                  style: const TextStyle(color: Color(0xFFF56A9C), fontWeight: FontWeight.bold, fontSize: 14)
                ),
                
              ),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Color(0xFF9181F4)),
                      const SizedBox(width: 8),
                      Text(
                        "${selectedDate.year}/${selectedDate.month}/${selectedDate.day}",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
              const Text("\$ ", style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 24)),
              SizedBox(
                width: 60,
                child: TextField(
                  keyboardType: TextInputType.number, // 讓手機彈出數字鍵盤
                  onChanged: (val) {
                    setState(() {
                      currentPrice = int.tryParse(val) ?? 0;
                    });
                  },
                  decoration: const InputDecoration(hintText: "0", border: InputBorder.none, isDense: true),
                  style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 24),
                ),
              )
            ],
          ),
          const SizedBox(height: 25),

          
          // 店家與品項輸入
          Row(
            children: [
              _buildSimpleInput("STORE", "店家名稱", storeController),
              const SizedBox(width: 15),
              _buildSimpleInput("MENU", "品項名稱", menuController),
            ],
          ),
          const SizedBox(height: 25),

          // 杯型選擇器
          _buildSelectionGrid("SIZE", sizeOptions, selectedSize, (val) => setState(() => selectedSize = val), const Color(0xFF81F4C5)),

          const SizedBox(height: 25),
          // 冰塊選擇器
          _buildSelectionGrid("ICE", iceOptions, selectedIce, (val) => setState(() => selectedIce = val), const Color(0xFF6A9CFD)),
          
          const SizedBox(height: 25),

          // 甜度選擇器
          _buildSelectionGrid("SUGAR", sugarOptions, selectedSugar, (val) => setState(() => selectedSugar = val), const Color(0xFFF56A9C)),

          const SizedBox(height: 30), 
          _buildSaveButton(),

          const SizedBox(height: 30),
          const Text("最近的紀錄：", style: TextStyle(fontWeight: FontWeight.bold)),
          const Divider(),
          ...drinkHistory.reversed.take(3).map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(item, style: const TextStyle(color: Colors.grey)),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildSimpleInput(String label, String hint, TextEditingController controller) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          TextField(
            controller: controller,
            decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.black26)),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionGrid(String title, List<String> options, String current, Function(String) onSelect, Color activeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          childAspectRatio: 2.2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: options.map((opt) {
            bool isSelected = opt == current;
            return GestureDetector(
              onTap: () => onSelect(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : const Color(0xFFF5F7FB),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: isSelected ? [BoxShadow(color: activeColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))] : [],
                ),
                alignment: Alignment.center,
                child: Text(opt, style: TextStyle(color: isSelected ? Colors.white : Colors.black45, fontWeight: FontWeight.bold)),
              ),
            );
          }).toList(),
        ),
      ],
    );
    
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity, // 讓按鈕跟卡片一樣寬
      height: 55,
      child: ElevatedButton(
        onPressed: () async {
          final prefs = await SharedPreferences.getInstance();

          String store = storeController.text;
          String menu = menuController.text;
          if (store.isEmpty || menu.isEmpty || currentPrice <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("請填寫店名/品項/價格喔！")));
            return;
          }

          Map<String, dynamic> drinkData = {
              "store": store,
              "menu": menu,
              "size": selectedSize,
              "ice": selectedIce,
              "sugar": selectedSugar,
              "price": currentPrice,
              "date": selectedDate.toString(),
            };

            // 3. 將 Map 轉成 JSON 字串
            String jsonString = jsonEncode(drinkData);
          setState(() {
            drinkHistory.add(jsonString); // 加進記憶體
          });
          await prefs.setStringList('drink_history', drinkHistory);
          print("【系統】已儲存，目前共有 ${drinkHistory.length} 筆紀錄。");

          storeController.clear();
          menuController.clear();
          setState(() { currentPrice = 0; });

          if (!mounted) return;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("已紀錄：）"),
              content: Text("目前累計 ${drinkHistory.length} 杯。"),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("確定"))],
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9181F4), // 夢幻紫色
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: const Text("儲存這杯熱量"),
      ),
    );
  }
  

  
}

Map<String, String> getStats(List<String> currentList) {
  double total = 0;
  int count = currentList.length;
  for (var jsonStr in currentList) {
    try {
      var data = jsonDecode(jsonStr);
      total += (data['price'] ?? 0);
    } catch (e) {}
  }
  double avg = count > 0 ? total / count : 0;
  return {
    "count": count.toString().padLeft(2, '0'),
    "total": "\$${total.toInt()}",
    "avg": "\$${avg.toStringAsFixed(1)}"
  };
}

// --- 全域工具函數：建立統計小方塊 UI ---
Widget buildStatCard(String label, String value, Color color) {
  return Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(fontSize: 18, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );
}

// --- 全域工具函數：建立歷史紀錄卡片 UI ---
Widget buildHistoryCard(String jsonStr) {
  try {
    Map<String, dynamic> data = jsonDecode(jsonStr);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: const Icon(Icons.local_drink, color: Color(0xFF9181F4)),
        title: Text("${data['store']} - ${data['menu']}"),
        subtitle: Text("${data['date'].toString().substring(0, 10)} | ${data['ice']}/${data['sugar']}"),
        trailing: Text("\$${data['price']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
    );
  } catch (e) {
    return const Card(child: ListTile(title: Text("格式錯誤資料")));
  }
}