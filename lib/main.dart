import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this import for TextInputFormatter
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Enable offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shopping List',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey.shade800,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const ShoppingListPage(),
    );
  }
}

class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key});

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final CollectionReference _shoppingList =
      FirebaseFirestore.instance.collection('shopping_list');
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _setupConnectivityListener();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = connectivityResult != ConnectivityResult.none;
    });

    // Check Firestore availability on startup
    if (_isOnline) {
      _checkFirestoreAccess();
    }
  }

  Future<void> _checkFirestoreAccess() async {
    try {
      await _shoppingList.limit(1).get();
    } catch (e) {
      final errorMessage = _getFirestoreErrorMessage(e);
      _showSnackBar(errorMessage);
    }
  }

  String _getFirestoreErrorMessage(dynamic error) {
    // Extract error code from Firestore exceptions
    String errorCode = error.toString();

    if (errorCode.contains('permission-denied')) {
      return 'You don\'t have permission to access the shopping list. Please check your account.';
    } else if (errorCode.contains('unavailable')) {
      return 'Database service is currently unavailable. Please try again later.';
    } else if (errorCode.contains('unauthenticated')) {
      return 'Authentication required. Please sign in to access the shopping list.';
    } else {
      return 'Error connecting to the database: ${error.toString()}';
    }
  }

  void _setupConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((result) {
      final isOnline = result != ConnectivityResult.none;
      if (isOnline != _isOnline) {
        setState(() => _isOnline = isOnline);
        if (isOnline) {
          _showSnackBar('Back online. Changes will be synced.');
        } else {
          _showSnackBar(
              'You\'re offline. Changes will be synced when you reconnect.');
        }
      }
    });
  }

  @override
  void dispose() {
    _itemController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About This App'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data Consistency & User Experience',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'This app uses Firestore transactions to ensure data consistency when multiple users add or update the same item simultaneously, preventing conflicting updates. It provides seamless offline support, allowing you to add items even without an internet connection, with automatic synchronization when connectivity is restored. The real-time updates feature ensures all connected devices instantly see changes, while comprehensive error handling provides clear feedback about what went wrong and suggests appropriate action.',
              style: TextStyle(height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _addItem() async {
    final itemName = _itemController.text.trim();
    if (itemName.isEmpty) return;

    // Check network status before attempting to add
    if (!_isOnline) {
      _showSnackBar(
          'Adding item in offline mode. It will sync when you\'re back online.');
    }

    // Ensure quantity is an integer
    int quantityInt;
    try {
      quantityInt = int.parse(_quantityController.text.trim().isEmpty
          ? '1'
          : _quantityController.text.trim());
      if (quantityInt <= 0) {
        _showSnackBar('Quantity must be a positive number');
        return;
      }
    } catch (e) {
      _showSnackBar('Please enter a valid integer for quantity');
      return;
    }

    try {
      // Case insensitive search query
      final itemNameLower = itemName.toLowerCase();

      // Start a transaction for data consistency
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Check if item already exists (case-insensitive)
        final querySnapshot = await _shoppingList
            .where('nameLower', isEqualTo: itemNameLower)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          // Item exists, update quantity
          final docRef = querySnapshot.docs.first.reference;
          final snapshot = await transaction.get(docRef);

          if (snapshot.exists) {
            final currentQuantity = int.parse(snapshot['quantity'].toString());
            final newQuantity = currentQuantity + quantityInt;

            transaction.update(docRef, {'quantity': newQuantity});
            _showSnackBar('Updated quantity for ${snapshot['name']}');
          }
        } else {
          // Create new item
          final docRef = _shoppingList.doc();
          transaction.set(docRef, {
            'name': itemName,
            'nameLower': itemNameLower,
            'quantity': quantityInt,
            'createdAt': FieldValue.serverTimestamp(),
          });
          _showSnackBar('Added $itemName to the shopping list');
        }
      });

      // Clear input fields after successful operation
      _itemController.clear();
      _quantityController.clear();
    } catch (e) {
      print('Error adding/updating item: $e');
      _showSnackBar(_getFirestoreErrorMessage(e));
    }
  }

  Future<void> _deleteItem(String documentId) async {
    try {
      await _shoppingList.doc(documentId).delete();
      _showSnackBar('Item removed from the shopping list');
    } catch (e) {
      print('Error deleting item: $e');
      _showSnackBar(_getFirestoreErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping List'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
        actions: [
          // Network status indicator
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(
              _isOnline ? Icons.cloud_done : Icons.cloud_off,
              color: _isOnline ? Colors.green : Colors.red,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Input area
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _itemController,
                      decoration: const InputDecoration(
                        labelText: 'Item Name',
                        hintText: 'What do you need?',
                        prefixIcon: Icon(Icons.shopping_bag_outlined),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        hintText: 'Enter a number',
                        prefixIcon: Icon(Icons.numbers),
                        helperText: 'Must be a positive number',
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addItem(),
                      // Only allow digits
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Add Item'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Shopping list with StreamBuilder for real-time updates
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _shoppingList.orderBy('name').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    print('Firestore Error: ${snapshot.error}');
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 60,
                            color: Colors.red[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading shopping list',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32.0),
                            child: Text(
                              _getFirestoreErrorMessage(snapshot.error),
                              style: TextStyle(color: Colors.red[700]),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => setState(() {}),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final documents = snapshot.data?.docs ?? [];

                  if (documents.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 80,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Your shopping list is empty',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: documents.length,
                    itemBuilder: (context, index) {
                      final document = documents[index];
                      final itemData = document.data() as Map<String, dynamic>;

                      // Convert quantity to string for display
                      final quantity = itemData['quantity']?.toString() ?? '1';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: AnimatedSlide(
                          offset: const Offset(0, 0),
                          duration: const Duration(milliseconds: 300),
                          child: Card(
                            child: ListTile(
                              leading: Icon(
                                Icons.check_circle_outline,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              title: Text(
                                itemData['name'] ?? 'Unnamed Item',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text('Quantity: $quantity'),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteItem(document.id),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
