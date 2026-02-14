
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCfzWZEAq7rjpnXfjznTOJ25skrStZ4FHY",
      authDomain: "shop-management-1.firebaseapp.com",
      projectId: "shop-management-1",
      storageBucket: "shop-management-1.firebasestorage.app",
      messagingSenderId: "154721959797",
      appId: "1:154721959797:web:e9c79c83f28d70c68fdd3c",
      measurementId: "G-VEHXPEPWQM",
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shop Creator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: Colors.black,
          secondary: const Color(0xFF23e5db),
        ),
        scaffoldBackgroundColor: const Color(0xFFf2f4f5),
      ),
      home: const ShopPage(),
    );
  }
}

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _products = [];
  Map<String, dynamic>? _shopData;
  DocumentSnapshot? _lastVisible;
  bool _hasMoreProducts = true;
  bool _isLoading = false;
  bool _isInitialLoading = true;
  String? _shopId;
  String _userId = '';
  String _sessionId = '';
  final int _productsPerPage = 6;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _getShopIdFromUrl();
    _scrollController.addListener(_onScroll);
  }

  void _initializeUser() {
  final random = Random();
  _userId = 'user_${DateTime.now().millisecondsSinceEpoch}_${random.nextDouble().toString().substring(2, 11)}';
  _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
}
void _getShopIdFromUrl() {
    try {
      // Get the current URI
      final uri = Uri.base;
      
      // Extract the 'id' parameter from the query string
      final String? id = uri.queryParameters['id'];
      
      if (id != null && id.isNotEmpty) {
        setState(() {
          _shopId = id;
        });
        _loadShopBanner();
        _loadInitialProducts();
      } else {
        // If no ID is provided, try to get it from the path (for cases like /shop/123)
        final pathSegments = uri.pathSegments;
        if (pathSegments.isNotEmpty) {
          // You might want to handle different URL patterns here
          // For now, we'll just show the not found state
          setState(() {
            _shopId = null;
            _isInitialLoading = false;
          });
        } else {
          setState(() {
            _shopId = null;
            _isInitialLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error parsing URL: $e');
      setState(() {
        _shopId = null;
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _loadShopBanner() async {
    try {
      final doc = await _firestore.collection('shops').doc(_shopId).get();
      if (doc.exists) {
        setState(() {
          _shopData = doc.data();
        });
      }
    } catch (e) {
      debugPrint('Error loading banner: $e');
    }
  }

  Future<void> _loadInitialProducts() async {
    if (_shopId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      Query query = _firestore
          .collection('products')
          .where('shopId', isEqualTo: _shopId)
          .where('active', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(_productsPerPage);

      final snapshot = await query.get();
      _processProductSnapshot(snapshot);
    } catch (e) {
      debugPrint('Error loading products: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isInitialLoading = false;
      });
    }
  }

  void _processProductSnapshot(QuerySnapshot snapshot) {
    final List<Map<String, dynamic>> newProducts = [];
    
    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      // Parse price if it's string
      if (data['price'] is String) {
        data['price'] = double.tryParse(data['price']) ?? 0;
      }
      if (data['oldPrice'] is String) {
        data['oldPrice'] = double.tryParse(data['oldPrice']) ?? 0;
      }
      newProducts.add({'id': doc.id, ...data});
    }

    setState(() {
      _products = newProducts;
      _lastVisible = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      _hasMoreProducts = snapshot.docs.length == _productsPerPage;
    });
  }

  Future<void> _loadMoreProducts() async {
    if (!_hasMoreProducts || _isLoading || _shopId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      Query query = _firestore
          .collection('products')
          .where('shopId', isEqualTo: _shopId)
          .where('active', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastVisible!)
          .limit(_productsPerPage);

      final snapshot = await query.get();
      
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (data['price'] is String) {
          data['price'] = double.tryParse(data['price']) ?? 0;
        }
        if (data['oldPrice'] is String) {
          data['oldPrice'] = double.tryParse(data['oldPrice']) ?? 0;
        }
        _products.add({'id': doc.id, ...data});
      }

      setState(() {
        _lastVisible = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMoreProducts = snapshot.docs.length == _productsPerPage;
      });
    } catch (e) {
      debugPrint('Error loading more products: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreProducts();
    }
  }

  Future<void> _searchProducts(String query) async {
    if (query.isEmpty) {
      _loadInitialProducts();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await _firestore
          .collection('products')
          .where('shopId', isEqualTo: _shopId)
          .where('active', isEqualTo: true)
          .get();

      final List<Map<String, dynamic>> allProducts = [];
      for (var doc in snapshot.docs) {
        var data = doc.data();
        if (data['price'] is String) {
          data['price'] = double.tryParse(data['price']) ?? 0;
        }
        if (data['oldPrice'] is String) {
          data['oldPrice'] = double.tryParse(data['oldPrice']) ?? 0;
        }
        allProducts.add({'id': doc.id, ...data});
      }

      final filtered = allProducts.where((p) {
        final name = p['name']?.toString().toLowerCase() ?? '';
        final description = p['description']?.toString().toLowerCase() ?? '';
        final searchTerm = query.toLowerCase();
        return name.contains(searchTerm) || description.contains(searchTerm);
      }).toList();

      setState(() {
        _products = filtered;
        _hasMoreProducts = false;
      });
    } catch (e) {
      debugPrint('Error searching: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _loadInitialProducts();
  }

  Future<void> _trackPageView() async {
    try {
      await _firestore.collection('visitor_stats').add({
        'userId': _userId,
        'sessionId': _sessionId,
        'type': 'page_view',
        'page': 'shop_view',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error tracking: $e');
    }
  }

  void _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch URL')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isInitialLoading
          ? const _LoadingScreen()
          : _shopId == null
              ? const _ShopNotFound()
              : CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    // Banner
                    if (_shopData != null && 
                        _shopData!['bannerUrl'] != null && 
                        _shopData!['bannerUrl'].toString().isNotEmpty)
                      SliverToBoxAdapter(
                        child: _BannerWidget(
                          imageUrl: _shopData!['bannerUrl'],
                          title: _shopData!['name'] ?? 'Shop',
                          subtitle: _shopData!['subtitle'] ?? 'Best deals',
                        ),
                      ),
                    
                    // Search Bar
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverToBoxAdapter(
                        child: _SearchBar(
                          controller: _searchController,
                          onSearch: _searchProducts,
                          onClear: _clearSearch,
                        ),
                      ),
                    ),

                    // Products Grid
                    _products.isEmpty && !_isLoading
                        ? SliverToBoxAdapter(
                            child: _EmptyState(
                              message: _searchController.text.isEmpty
                                  ? 'No products found'
                                  : 'No results for "${_searchController.text}"',
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.7,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final product = _products[index];
                                  return _ProductCard(
                                    product: product,
                                    onTap: () => _showProductDetails(product),
                                    onBuyTap: () {
                                      if (product['affiliateLink'] != null) {
                                        _launchUrl(product['affiliateLink']);
                                      }
                                    },
                                  );
                                },
                                childCount: _products.length,
                              ),
                            ),
                          ),

                    // Loading indicator
                    if (_isLoading)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                  ],
                ),
      bottomNavigationBar: _BottomNavBar(
        onHomeTap: () {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
          _clearSearch();
        },
        onSearchTap: () {
          FocusScope.of(context).requestFocus(FocusNode());
          _searchController.clear();
        },
      ),
    );
  }

  void _showProductDetails(Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProductDetailsModal(
        product: product,
        onBuyTap: () {
          if (product['affiliateLink'] != null) {
            _launchUrl(product['affiliateLink']);
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// Loading Screen Widget
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFf2f4f5),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        ),
      ),
    );
  }
}

// Shop Not Found Widget
class _ShopNotFound extends StatelessWidget {
  const _ShopNotFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Shop not found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Invalid shop ID',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

// Banner Widget
class _BannerWidget extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;

  const _BannerWidget({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[300],
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[400],
              child: const Icon(Icons.error, color: Colors.white),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Search Bar Widget
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSearch;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.onSearch,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onSearch,
        decoration: InputDecoration(
          hintText: 'Search products...',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: onClear,
                  color: Colors.grey,
                ),
              Container(
                width: 50,
                height: 45,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: const Icon(
                  Icons.search,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Product Card Widget
class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;
  final VoidCallback onBuyTap;

  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onBuyTap,
  });

  @override
  Widget build(BuildContext context) {
    final price = (product['price'] ?? 0).toDouble();
    final oldPrice = (product['oldPrice'] ?? 0).toDouble();
    final discount = oldPrice > 0
        ? ((oldPrice - price) / oldPrice * 100).round()
        : 0;

    String imageUrl = 'https://via.placeholder.com/300';
    if (product['imageUrls'] != null && product['imageUrls'].isNotEmpty) {
      imageUrl = product['imageUrls'][0];
    } else if (product['imageUrl'] != null) {
      imageUrl = product['imageUrl'];
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image container
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 150,
                      color: Colors.grey[200],
                    ),
                  ),
                ),
                if (discount > 0)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFffce32),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '-$discount%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            
            // Product info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] ?? 'Unnamed',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (price > 0) ...[
                    Row(
                      children: [
                        Text(
                          NumberFormat.currency(symbol: '\$').format(price),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (oldPrice > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            NumberFormat.currency(symbol: '\$').format(oldPrice),
                            style: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onBuyTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.open_in_new, size: 16),
                          SizedBox(width: 4),
                          Text('View Product', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Product Details Modal
class _ProductDetailsModal extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onBuyTap;

  const _ProductDetailsModal({
    required this.product,
    required this.onBuyTap,
  });

  @override
  State<_ProductDetailsModal> createState() => _ProductDetailsModalState();
}

class _ProductDetailsModalState extends State<_ProductDetailsModal> {
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final price = (widget.product['price'] ?? 0).toDouble();
    final oldPrice = (widget.product['oldPrice'] ?? 0).toDouble();
    final discount = oldPrice > 0
        ? ((oldPrice - price) / oldPrice * 100).round()
        : 0;

    List<String> imageUrls = [];
    if (widget.product['imageUrls'] != null && 
        widget.product['imageUrls'].isNotEmpty) {
      imageUrls = List<String>.from(widget.product['imageUrls']);
    } else if (widget.product['imageUrl'] != null) {
      imageUrls = [widget.product['imageUrl']];
    } else {
      imageUrls = ['https://via.placeholder.com/300'];
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.product['name'] ?? 'Product Name',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Image carousel
                  Stack(
                    children: [
                      CarouselSlider(
                        options: CarouselOptions(
                          height: 300,
                          viewportFraction: 1,
                          onPageChanged: (index, reason) {
                            setState(() {
                              _currentImageIndex = index;
                            });
                          },
                        ),
                        items: imageUrls.map((url) {
                          return CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                            ),
                          );
                        }).toList(),
                      ),
                      if (imageUrls.length > 1) ...[
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: imageUrls.asMap().entries.map((entry) {
                              return Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentImageIndex == entry.key
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.5),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Product info
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product['name'] ?? 'Product Name',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              NumberFormat.currency(symbol: '\$').format(price),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (oldPrice > 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                NumberFormat.currency(symbol: '\$').format(oldPrice),
                                style: TextStyle(
                                  fontSize: 18,
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '-$discount%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.product['description'] ?? 'No description',
                          style: const TextStyle(height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onBuyTap();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.open_in_new),
                    SizedBox(width: 8),
                    Text('View Product'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Empty State Widget
class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Bottom Navigation Bar
class _BottomNavBar extends StatelessWidget {
  final VoidCallback onHomeTap;
  final VoidCallback onSearchTap;

  const _BottomNavBar({
    required this.onHomeTap,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavItem(
                icon: Icons.home,
                label: 'Home',
                onTap: onHomeTap,
              ),
              _NavItem(
                icon: Icons.search,
                label: 'Search',
                onTap: onSearchTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Navigation Item
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.black),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}