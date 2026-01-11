// main.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const FinanceApp());
}

/* ============================================================
   ROOT APP WITH THEME MODE
============================================================ */

class FinanceApp extends StatefulWidget {
  const FinanceApp({super.key});

  @override
  State<FinanceApp> createState() => _FinanceAppState();
}

class _FinanceAppState extends State<FinanceApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('theme_mode') ?? 0;
    setState(() {
      _themeMode = _indexToThemeMode(index);
    });
  }

  Future<void> _updateThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', _themeModeToIndex(mode));
    setState(() {
      _themeMode = mode;
    });
  }

  int _themeModeToIndex(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 1;
      case ThemeMode.dark:
        return 2;
      case ThemeMode.system:
      default:
        return 0;
    }
  }

  ThemeMode _indexToThemeMode(int index) {
    switch (index) {
      case 1:
        return ThemeMode.light;
      case 2:
        return ThemeMode.dark;
      case 0:
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      home: DashboardPage(
        currentThemeMode: _themeMode,
        onThemeChanged: _updateThemeMode,
      ),
    );
  }
}

/* ============================================================
   CATEGORY MODEL + DATA
============================================================ */

class CategoryModel {
  final String name;
  final IconData icon;
  final Color color;

  CategoryModel({
    required this.name,
    required this.icon,
    required this.color,
  });

  Map<String, dynamic> toJson() => {
        "name": name,
        "icon": icon.codePoint,
        "color": color.value,
      };

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      name: json["name"],
      icon: IconData(json["icon"], fontFamily: 'MaterialIcons'),
      color: Color(json["color"]),
    );
  }
}

final List<CategoryModel> categories = [
  CategoryModel(name: "Food", icon: Icons.fastfood, color: Colors.orange),
  CategoryModel(
      name: "Transport", icon: Icons.directions_bus, color: Colors.blue),
  CategoryModel(name: "Shopping", icon: Icons.shopping_bag, color: Colors.pink),
  CategoryModel(name: "Bills", icon: Icons.receipt_long, color: Colors.indigo),
  CategoryModel(name: "Salary", icon: Icons.attach_money, color: Colors.green),
  CategoryModel(name: "Others", icon: Icons.category, color: Colors.grey),
];

/* ============================================================
   CARD MODEL + DATA (Glassmorphism Cards)
============================================================ */

class CardModel {
  final String name;
  final String number;
  final String expiry;
  final String brand; // e.g. "Visa", "Mastercard"
  final Color color;

  CardModel({
    required this.name,
    required this.number,
    required this.expiry,
    required this.brand,
    required this.color,
  });

  Map<String, dynamic> toJson() => {
        "name": name,
        "number": number,
        "expiry": expiry,
        "brand": brand,
        "color": color.value,
      };

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      name: json["name"],
      number: json["number"],
      expiry: json["expiry"],
      brand: json["brand"],
      color: Color(json["color"]),
    );
  }
}

class CardColorOption {
  final String name;
  final Color color;

  CardColorOption(this.name, this.color);
}

final List<CardColorOption> cardColorOptions = [
  CardColorOption("Teal", Colors.teal),
  CardColorOption("Purple", Colors.deepPurple),
  CardColorOption("Orange", Colors.deepOrange),
  CardColorOption("Blue", Colors.indigo),
];

List<CardModel> savedCards = [];

/* ============================================================
   TRANSACTION MODEL + DATA
============================================================ */

class TransactionModel {
  final String title;
  final String subtitle;
  final double amount;
  final bool isIncome;
  final CategoryModel category;
  final DateTime date;

  TransactionModel({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isIncome,
    required this.category,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        "title": title,
        "subtitle": subtitle,
        "amount": amount,
        "isIncome": isIncome,
        "category": category.toJson(),
        "date": date.toIso8601String(),
      };

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      title: json["title"],
      subtitle: json["subtitle"],
      amount: (json["amount"] as num).toDouble(),
      isIncome: json["isIncome"],
      category: CategoryModel.fromJson(json["category"]),
      date:
          json["date"] != null ? DateTime.parse(json["date"]) : DateTime.now(),
    );
  }
}

/* Stored transactions */
List<TransactionModel> mockTransactions = [];

/* For monthly chart labels */
const List<String> _monthShortNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

class _MonthlyData {
  final String label;
  final double income;
  final double expense;

  _MonthlyData({
    required this.label,
    required this.income,
    required this.expense,
  });
}
/* ============================================================
   DASHBOARD PAGE
============================================================ */

class DashboardPage extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const DashboardPage({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _navIndex = 0;
  String _cardHolderName = "Card Holder";

  // Budget & alerts
  double _monthlyBudget = 1500;
  bool _alertsEnabled = true;
  bool _budgetLoaded = false;
  bool _alertShownThisSession = false;

  // Filters & search
  CategoryModel? _filterCategory;
  String _filterType = 'All'; // All / Income / Expense
  String? _filterMonthKey; // "YYYY-MM"
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadTransactions();
    loadCards();
    _loadProfileName();
    _loadProfileSettings();
  }

  /* ---- CALCULATIONS ---- */
  double get income =>
      mockTransactions.where((t) => t.isIncome).fold(0, (s, t) => s + t.amount);

  double get expense => mockTransactions
      .where((t) => !t.isIncome)
      .fold(0, (s, t) => s + t.amount);

  double _currentMonthExpense() {
    final now = DateTime.now();
    return mockTransactions
        .where((t) =>
            !t.isIncome && t.date.year == now.year && t.date.month == now.month)
        .fold(0.0, (s, t) => s + t.amount);
  }

  /* ---- SAVE / LOAD TRANSACTIONS ---- */
  Future<void> saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = mockTransactions.map((t) => t.toJson()).toList();
    await prefs.setString("transactions", jsonEncode(jsonList));
    _maybeShowBudgetSnackbar();
  }

  Future<void> loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("transactions");
    if (raw != null) {
      final List decoded = jsonDecode(raw);
      setState(() {
        mockTransactions =
            decoded.map((item) => TransactionModel.fromJson(item)).toList();
      });
    }
    _maybeShowBudgetSnackbar();
  }

  /* ---- SAVE / LOAD CARDS ---- */
  Future<void> saveCards() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = savedCards.map((c) => c.toJson()).toList();
    await prefs.setString("cards", jsonEncode(jsonList));
  }

  Future<void> loadCards() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("cards");

    if (raw == null) {
      // default demo card
      setState(() {
        savedCards = [
          CardModel(
            name: "Main Card",
            number: "4356 7812 9012 3456",
            expiry: "12/27",
            brand: "Visa",
            color: Colors.teal,
          ),
        ];
      });
      await saveCards();
      return;
    }

    final List decoded = jsonDecode(raw);
    setState(() {
      savedCards = decoded.map((item) => CardModel.fromJson(item)).toList();
    });
  }

  /* ---- LOAD PROFILE SETTINGS ---- */

  Future<void> _loadProfileName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString("profile_name") ?? "User";
    setState(() {
      _cardHolderName = name;
    });
  }

  Future<void> _loadProfileSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final budget = prefs.getDouble("profile_budget") ?? 1500;
    final alerts = prefs.getBool("profile_alerts") ?? true;
    setState(() {
      _monthlyBudget = budget;
      _alertsEnabled = alerts;
      _budgetLoaded = true;
    });
    _maybeShowBudgetSnackbar();
  }

  void _maybeShowBudgetSnackbar() {
    if (!_alertsEnabled || !_budgetLoaded || _alertShownThisSession) return;
    if (!mounted) return;
    if (_monthlyBudget <= 0) return;

    final spent = _currentMonthExpense();
    final ratio = spent / _monthlyBudget;

    if (ratio >= 1.0) {
      _alertShownThisSession = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You’ve exceeded your monthly budget!"),
          ),
        );
      });
    } else if (ratio >= 0.8) {
      _alertShownThisSession = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You’re close to reaching your monthly budget."),
          ),
        );
      });
    }
  }

  /* ---- HELPERS (CARDS) ---- */

  String _generateCardNumber() {
    final rnd = Random();
    final groups = List.generate(4, (_) {
      final n = rnd.nextInt(9000) + 1000; // 1000–9999
      return n.toString();
    });
    return groups.join(' ');
  }

  String _formatCardNumber(String number) {
    final cleaned = number.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < cleaned.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      if (i < cleaned.length - 4) {
        buffer.write('•');
      } else {
        buffer.write(cleaned[i]);
      }
    }
    return buffer.toString();
  }

  Widget _buildCardBrandChip(String brand) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        brand.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildGlassCard(CardModel card) {
    final formattedNumber = _formatCardNumber(card.number);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    card.color.withOpacity(0.9),
                    card.color.withOpacity(0.4),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          card.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        _buildCardBrandChip(card.brand),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      formattedNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "CARD HOLDER",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _cardHolderName.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "EXPIRES",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              card.expiry,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ---- ADD / EDIT TRANSACTION SHEET ---- */
  void _openTransactionSheet({TransactionModel? tx, int? index}) {
    final title = TextEditingController(text: tx?.title ?? "");
    final subtitle = TextEditingController(text: tx?.subtitle ?? "");
    final amount = TextEditingController(
      text: tx != null ? tx.amount.toString() : "",
    );

    bool isIncome = tx?.isIncome ?? true;
    CategoryModel selectedCategory = tx?.category ?? categories.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, modalSetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tx == null ? "New Transaction" : "Edit Transaction",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: "Title",
                      prefixIcon: Icon(Icons.text_fields),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subtitle,
                    decoration: const InputDecoration(
                      labelText: "Subtitle",
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Amount",
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<CategoryModel>(
                    value: selectedCategory,
                    items: categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Row(
                              children: [
                                Icon(c.icon, color: c.color),
                                const SizedBox(width: 10),
                                Text(c.name),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    decoration: const InputDecoration(
                      labelText: "Category",
                      prefixIcon: Icon(Icons.category),
                    ),
                    onChanged: (c) {
                      if (c == null) return;
                      modalSetState(() => selectedCategory = c);
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: isIncome,
                    onChanged: (v) => modalSetState(() => isIncome = v),
                    title: const Text("Is Income?"),
                    secondary: Icon(
                      isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isIncome ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final parsedAmount =
                            double.tryParse(amount.text.trim());
                        if (parsedAmount == null || title.text.trim().isEmpty) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Fill all fields correctly"),
                            ),
                          );
                          return;
                        }

                        final newTx = TransactionModel(
                          title: title.text.trim(),
                          subtitle: subtitle.text.trim(),
                          amount: parsedAmount,
                          isIncome: isIncome,
                          category: selectedCategory,
                          date: tx?.date ?? DateTime.now(),
                        );

                        setState(() {
                          if (index != null) {
                            mockTransactions[index] = newTx;
                          } else {
                            mockTransactions.insert(0, newTx);
                          }
                        });

                        saveTransactions();
                        Navigator.pop(context);
                      },
                      child: Text(
                        tx == null ? "Add Transaction" : "Save Changes",
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /* ---- ADD / EDIT CARD SHEET ---- */
  void _openCardSheet({CardModel? card, int? index}) {
    final nameController = TextEditingController(text: card?.name ?? "");
    final numberController =
        TextEditingController(text: card?.number ?? _generateCardNumber());
    final expiryController =
        TextEditingController(text: card?.expiry ?? "12/27");
    String brand = card?.brand ?? "Visa";

    CardColorOption selectedColorOption = cardColorOptions.firstWhere(
      (c) => c.color == (card?.color ?? cardColorOptions.first.color),
      orElse: () => cardColorOptions.first,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, modalSetState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      card == null ? "New Card" : "Edit Card",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: "Card Name",
                        prefixIcon: Icon(Icons.credit_card),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: numberController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: "Card Number",
                        prefixIcon: const Icon(Icons.numbers),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () {
                            modalSetState(() {
                              numberController.text = _generateCardNumber();
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: expiryController,
                            decoration: const InputDecoration(
                              labelText: "Expiry (MM/YY)",
                              prefixIcon: Icon(Icons.date_range),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: brand,
                            items: const [
                              DropdownMenuItem(
                                value: "Visa",
                                child: Text("Visa"),
                              ),
                              DropdownMenuItem(
                                value: "Mastercard",
                                child: Text("Mastercard"),
                              ),
                            ],
                            decoration: const InputDecoration(
                              labelText: "Brand",
                              prefixIcon: Icon(Icons.credit_card_rounded),
                            ),
                            onChanged: (value) {
                              if (value == null) return;
                              modalSetState(() => brand = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Card Color",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: cardColorOptions.map((option) {
                        final selected = option == selectedColorOption;
                        return ChoiceChip(
                          label: Text(option.name),
                          selected: selected,
                          avatar: CircleAvatar(
                            backgroundColor: option.color,
                            radius: 4,
                          ),
                          onSelected: (_) {
                            modalSetState(() {
                              selectedColorOption = option;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          if (nameController.text.trim().isEmpty) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please enter a card name"),
                              ),
                            );
                            return;
                          }

                          final newCard = CardModel(
                            name: nameController.text.trim(),
                            number: numberController.text.trim(),
                            expiry: expiryController.text.trim(),
                            brand: brand,
                            color: selectedColorOption.color,
                          );

                          setState(() {
                            if (index != null) {
                              savedCards[index] = newCard;
                            } else {
                              savedCards.insert(0, newCard);
                            }
                          });

                          saveCards();
                          Navigator.pop(context);
                        },
                        child: Text(
                          card == null ? "Add Card" : "Save Changes",
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  /* ============================================================
     CHART HELPERS
  ============================================================ */

  Map<CategoryModel, double> _categoryExpenseTotals() {
    final Map<CategoryModel, double> totals = {};
    for (final tx in mockTransactions.where((t) => !t.isIncome)) {
      totals[tx.category] = (totals[tx.category] ?? 0) + tx.amount;
    }
    return totals;
  }

  List<_MonthlyData> _buildMonthlyData({int months = 6}) {
    final now = DateTime.now();
    final List<_MonthlyData> result = [];

    for (int i = months - 1; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final monthLabel = _monthShortNames[monthDate.month - 1];

      double monthIncome = 0;
      double monthExpense = 0;

      for (final tx in mockTransactions) {
        if (tx.date.year == monthDate.year &&
            tx.date.month == monthDate.month) {
          if (tx.isIncome) {
            monthIncome += tx.amount;
          } else {
            monthExpense += tx.amount;
          }
        }
      }

      result.add(_MonthlyData(
        label: monthLabel,
        income: monthIncome,
        expense: monthExpense,
      ));
    }

    return result;
  }

  Widget _buildCategoryPieChartCard(BuildContext context) {
    final totals = _categoryExpenseTotals();
    if (totals.isEmpty) {
      return Card(
        child: SizedBox(
          height: 200,
          child: Center(
            child: Text(
              "No expense data yet",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    final totalAmount =
        totals.values.fold<double>(0, (sum, value) => sum + value);

    final sections = totals.entries.map((entry) {
      final category = entry.key;
      final amount = entry.value;
      final percentage = totalAmount == 0 ? 0 : (amount / totalAmount * 100);
      return PieChartSectionData(
        value: amount,
        color: category.color,
        title: "${percentage.toStringAsFixed(0)}%",
        radius: 60,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Spending by Category",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 1,
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: totals.entries.map((entry) {
                final category = entry.key;
                final amount = entry.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: category.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${category.name} (${amount.toStringAsFixed(0)})",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyBarChartCard(BuildContext context) {
    final data = _buildMonthlyData(months: 6);
    final bool hasAnyData = data.any((m) => m.income > 0 || m.expense > 0);

    if (!hasAnyData) {
      return Card(
        child: SizedBox(
          height: 200,
          child: Center(
            child: Text(
              "No monthly data yet",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Income vs Expense (Last 6 months)",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= data.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              data[index].label,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: data.asMap().entries.map((entry) {
                    final index = entry.key;
                    final m = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barsSpace: 4,
                      barRods: [
                        BarChartRodData(
                          toY: m.income,
                          width: 7,
                          color: Colors.green,
                        ),
                        BarChartRodData(
                          toY: m.expense,
                          width: 7,
                          color: Colors.red,
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendDot(Colors.green, "Income", context),
                const SizedBox(width: 16),
                _legendDot(Colors.red, "Expense", context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label, BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  /* ============================================================
     FILTERS & SEARCH
  ============================================================ */

  List<String> _availableMonthKeys() {
    final set = <String>{};
    for (final tx in mockTransactions) {
      final key = "${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}";
      set.add(key);
    }
    final list = set.toList()..sort();
    if (list.isEmpty) {
      final now = DateTime.now();
      list.add("${now.year}-${now.month.toString().padLeft(2, '0')}");
    }
    return list;
  }

  String _labelForMonthKey(String key) {
    final parts = key.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    return "${_monthShortNames[month - 1]} $year";
  }

  void _openFilterSheet() {
    CategoryModel? selectedCategory = _filterCategory;
    String selectedType = _filterType;
    String? selectedMonthKey = _filterMonthKey;
    final monthKeys = _availableMonthKeys();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, modalSetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Filter Transactions",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<CategoryModel?>(
                    value: selectedCategory,
                    items: [
                      const DropdownMenuItem<CategoryModel?>(
                        value: null,
                        child: Text("All categories"),
                      ),
                      ...categories.map(
                        (c) => DropdownMenuItem<CategoryModel?>(
                          value: c,
                          child: Row(
                            children: [
                              Icon(c.icon, color: c.color),
                              const SizedBox(width: 8),
                              Text(c.name),
                            ],
                          ),
                        ),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: "Category",
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    onChanged: (value) {
                      modalSetState(() => selectedCategory = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    items: const [
                      DropdownMenuItem(
                        value: "All",
                        child: Text("All types"),
                      ),
                      DropdownMenuItem(
                        value: "Income",
                        child: Text("Income"),
                      ),
                      DropdownMenuItem(
                        value: "Expense",
                        child: Text("Expense"),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: "Type",
                      prefixIcon: Icon(Icons.swap_vert),
                    ),
                    onChanged: (value) {
                      if (value == null) return;
                      modalSetState(() => selectedType = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: selectedMonthKey,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text("All months"),
                      ),
                      ...monthKeys.map(
                        (key) => DropdownMenuItem<String?>(
                          value: key,
                          child: Text(_labelForMonthKey(key)),
                        ),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: "Month",
                      prefixIcon: Icon(Icons.calendar_month),
                    ),
                    onChanged: (value) {
                      modalSetState(() => selectedMonthKey = value);
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          modalSetState(() {
                            selectedCategory = null;
                            selectedType = "All";
                            selectedMonthKey = null;
                          });
                        },
                        child: const Text("Clear filters"),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _filterCategory = selectedCategory;
                            _filterType = selectedType;
                            _filterMonthKey = selectedMonthKey;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text("Apply"),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  List<TransactionModel> _filteredTransactions() {
    List<TransactionModel> list = mockTransactions;

    if (_filterCategory != null ||
        _filterType != 'All' ||
        _filterMonthKey != null) {
      list = list.where((t) {
        if (_filterCategory != null &&
            t.category.name != _filterCategory!.name) {
          return false;
        }
        if (_filterType == 'Income' && !t.isIncome) return false;
        if (_filterType == 'Expense' && t.isIncome) return false;
        if (_filterMonthKey != null) {
          final key =
              "${t.date.year}-${t.date.month.toString().padLeft(2, '0')}";
          if (key != _filterMonthKey) return false;
        }
        return true;
      }).toList();
    }

    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((t) {
        return t.title.toLowerCase().contains(q) ||
            t.subtitle.toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  Widget _buildSearchAndFilterRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: "Search transactions",
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: _openFilterSheet,
        ),
      ],
    );
  }

  /* ============================================================
     BUDGET WIDGETS
  ============================================================ */

  Widget _buildBudgetAlertBanner(BuildContext context) {
    if (!_alertsEnabled || !_budgetLoaded || _monthlyBudget <= 0) {
      return const SizedBox.shrink();
    }
    final spent = _currentMonthExpense();
    final ratio = spent / _monthlyBudget;
    if (ratio < 0.8) return const SizedBox.shrink();

    final over = ratio >= 1.0;
    final color = over ? Colors.red : Colors.orange;
    final text = over
        ? "You’ve exceeded your budget this month."
        : "You’re close to reaching your monthly budget.";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard(BuildContext context) {
    if (!_budgetLoaded || _monthlyBudget <= 0) {
      return const SizedBox.shrink();
    }

    final spent = _currentMonthExpense();
    final ratio = (spent / _monthlyBudget).clamp(0.0, 1.0);
    Color barColor;
    if (ratio >= 0.9) {
      barColor = Colors.red;
    } else if (ratio >= 0.7) {
      barColor = Colors.orange;
    } else {
      barColor = Colors.green;
    }

    final remaining = (_monthlyBudget - spent).clamp(0, _monthlyBudget);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Monthly Budget",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              "Budget: ${_monthlyBudget.toStringAsFixed(0)}",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                color: barColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${spent.toStringAsFixed(0)} spent • ${remaining.toStringAsFixed(0)} left this month",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /* ============================================================
     CSV EXPORT
  ============================================================ */

  Future<void> _exportTransactions() async {
    if (mockTransactions.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No transactions to export")),
      );
      return;
    }

    try {
      final buffer = StringBuffer();
      buffer.writeln("Title,Subtitle,Amount,Type,Category,Date");

      String esc(String input) => '"${input.replaceAll('"', '""')}"';

      for (final t in mockTransactions) {
        final type = t.isIncome ? "Income" : "Expense";
        final dateStr = t.date.toIso8601String();
        buffer.writeln(
          "${esc(t.title)},${esc(t.subtitle)},${t.amount.toStringAsFixed(2)},$type,${esc(t.category.name)},$dateStr",
        );
      }

      final dir = await getApplicationDocumentsDirectory();
      final safeTimestamp =
          DateTime.now().toIso8601String().replaceAll(":", "-");
      final filePath = "${dir.path}/transactions_$safeTimestamp.csv";
      final file = File(filePath);
      await file.writeAsString(buffer.toString());

      await Share.shareXFiles(
        [XFile(filePath)],
        text: "Here is my transactions export.",
        subject: "Finance app transactions",
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Exported: transactions_$safeTimestamp.csv",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to export transactions")),
      );
    }
  }

  /* ============================================================
     BUILD UI
  ============================================================ */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_navIndex == 0) {
            _openTransactionSheet();
          } else {
            _openCardSheet();
          }
        },
        child: Icon(_navIndex == 0 ? Icons.add : Icons.credit_card),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) {
          if (i == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfilePage(
                  currentThemeMode: widget.currentThemeMode,
                  onThemeChanged: widget.onThemeChanged,
                ),
              ),
            ).then((_) {
              _loadProfileName();
              _loadProfileSettings();
            });
            return;
          }
          setState(() => _navIndex = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: "Dashboard",
          ),
          NavigationDestination(
            icon: Icon(Icons.credit_card_outlined),
            label: "Cards",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: "Profile",
          ),
        ],
      ),
      appBar: AppBar(
        title: Text(
          _navIndex == 0 ? "Finance Dashboard" : "My Cards",
        ),
        backgroundColor: Colors.transparent,
        actions: [
          if (_navIndex == 0)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'export') {
                  _exportTransactions();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'export',
                  child: Text("Export CSV"),
                ),
              ],
            ),
        ],
      ),
      body:
          _navIndex == 0 ? _buildDashboard(context) : _buildCardsPage(context),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final transactionsToShow = _filteredTransactions();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildBudgetAlertBanner(context),

            /* BALANCE CARD */
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.teal,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Text(
                    "Current Balance",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "\$${(income - expense).toStringAsFixed(2)}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _balanceItem("Income", income, Colors.greenAccent),
                      _balanceItem("Expense", expense, Colors.redAccent),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildBudgetCard(context),
            const SizedBox(height: 16),
            _buildCategoryPieChartCard(context),
            const SizedBox(height: 16),
            _buildMonthlyBarChartCard(context),
            const SizedBox(height: 24),
            _buildSearchAndFilterRow(context),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Recent Transactions",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            if (transactionsToShow.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  "No transactions match your filters/search.",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              ...transactionsToShow.map((t) {
                final originalIndex = mockTransactions.indexOf(t);
                return Card(
                  child: ListTile(
                    onTap: () =>
                        _openTransactionSheet(tx: t, index: originalIndex),
                    onLongPress: () {
                      setState(() => mockTransactions.removeAt(originalIndex));
                      saveTransactions();
                    },
                    leading: CircleAvatar(
                      backgroundColor: t.category.color.withOpacity(0.2),
                      child: Icon(
                        t.category.icon,
                        color: t.category.color,
                      ),
                    ),
                    title: Text(t.title),
                    subtitle: Text("${t.subtitle} • ${t.category.name}"),
                    trailing: Text(
                      (t.isIncome ? "+" : "-") + "\$${t.amount}",
                      style: TextStyle(
                        color: t.isIncome ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCardsPage(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Your Cards",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              "Manage virtual cards for different goals.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (savedCards.isEmpty)
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Icon(
                      Icons.credit_card_off_outlined,
                      size: 48,
                      color: Colors.teal.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    const Text("No cards yet. Tap + to create one."),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: savedCards.length,
                itemBuilder: (context, index) {
                  final card = savedCards[index];
                  return Dismissible(
                    key: ValueKey(card.number + index.toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      setState(() {
                        savedCards.removeAt(index);
                      });
                      saveCards();
                    },
                    child: GestureDetector(
                      onTap: () => _openCardSheet(card: card, index: index),
                      child: _buildGlassCard(card),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _balanceItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        Text(
          "\$${amount.toStringAsFixed(2)}",
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
/* ============================================================
   PROFILE PAGE (THEME + PROFILE SETTINGS)
============================================================ */

class ProfilePage extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const ProfilePage({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _currency = TextEditingController(text: "USD");
  final _budget = TextEditingController();

  bool _alerts = true;
  bool _loading = true;
  late ThemeMode _selectedThemeMode;

  @override
  void initState() {
    super.initState();
    _selectedThemeMode = widget.currentThemeMode;
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _name.text = prefs.getString("profile_name") ?? "User";
      _email.text = prefs.getString("profile_email") ?? "you@example.com";
      _currency.text = prefs.getString("profile_currency") ?? "USD";
      _budget.text =
          (prefs.getDouble("profile_budget") ?? 1500).toStringAsFixed(0);
      _alerts = prefs.getBool("profile_alerts") ?? true;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString("profile_name", _name.text.trim());
    await prefs.setString("profile_email", _email.text.trim());
    await prefs.setString("profile_currency", _currency.text.trim());
    await prefs.setDouble(
      "profile_budget",
      double.tryParse(_budget.text) ?? 0,
    );
    await prefs.setBool("profile_alerts", _alerts);

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Profile saved")));
  }

  Widget _themeChip(String label, ThemeMode mode) {
    final selected = _selectedThemeMode == mode;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _selectedThemeMode = mode);
        widget.onThemeChanged(mode);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.teal.withOpacity(0.20),
                  child: Text(
                    _name.text.isEmpty ? "U" : _name.text[0],
                    style: const TextStyle(
                      color: Colors.teal,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  _name.text.isEmpty ? "Your Name" : _name.text,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: "Name",
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              decoration: const InputDecoration(
                labelText: "Email",
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _currency,
                    decoration: const InputDecoration(
                      labelText: "Currency",
                      prefixIcon: Icon(Icons.currency_exchange),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _budget,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Monthly Budget",
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _alerts,
              onChanged: (v) => setState(() => _alerts = v),
              title: const Text("Spending alerts"),
              subtitle: const Text("Get notified when spending is high"),
              secondary: const Icon(Icons.notifications_active_outlined),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Appearance",
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _themeChip("System", ThemeMode.system),
                _themeChip("Light", ThemeMode.light),
                _themeChip("Dark", ThemeMode.dark),
              ],
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text("Save Changes"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
