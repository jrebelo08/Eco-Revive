import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:register/Auth/Auth.dart';
import 'package:register/Controllers/ChatController.dart';
import 'package:register/Models/ProductInfo.dart';
import 'package:register/Controllers/CloudStorageController.dart';
import 'package:register/Controllers/FireStoreController.dart';
import 'package:register/Pages/theme_provider.dart';

import 'Chat.dart';
import 'Review.dart';

class ProductPage extends StatelessWidget {
  final ProductInfo product;

  ProductPage({required this.product});

  Color _ratingColor(double rating) {
    if (rating < 2.0) {
      return Colors.red;
    } else if (rating < 3.0) {
      return Colors.orange;
    } else if (rating < 4.0) {
      return Colors.yellow;
    } else {
      return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final _fireStoreController = FireStoreController();

    return Scaffold(
      appBar: AppBar(
        title: Text(product.productName),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    product.imageURL,
                    width: MediaQuery.of(context).size.width - 32,
                    height: 200,
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Description:',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    product.description,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Owned By:',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<String>(
                    future: CloudStorageController().getDownloadURL('PFPImages/${product.UserID}'),
                    builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      } else if (snapshot.hasError) {
                        return Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[300],
                              ),
                              child: Center(
                                child: snapshot.hasError || !snapshot.hasData
                                    ? Icon(Icons.no_photography_outlined)
                                    : Image.network(snapshot.data!),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FutureBuilder<String?>(
                                future: _fireStoreController.getUsernameByUid(product.UserID),
                                builder: (BuildContext context, AsyncSnapshot<String?> nameSnapshot) {
                                  if (nameSnapshot.connectionState == ConnectionState.waiting) {
                                    return CircularProgressIndicator();
                                  } else if (nameSnapshot.hasError || !nameSnapshot.hasData) {
                                    return Text(
                                      'Error loading name',
                                      style: TextStyle(fontSize: 20),
                                    );
                                  } else {
                                    final ownerName = nameSnapshot.data ?? 'Unknown';
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ownerName,
                                          style: const TextStyle(
                                            fontSize: 20,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        FutureBuilder<double>(
                                          future: FireStoreController().getUserOverallRating(product.UserID),
                                          builder: (BuildContext context, AsyncSnapshot<double> ratingSnapshot) {
                                            if (ratingSnapshot.connectionState == ConnectionState.waiting) {
                                              return CircularProgressIndicator();
                                            } else if (ratingSnapshot.hasError) {
                                              return Text("Error: ${ratingSnapshot.error}");
                                            } else {
                                              final userRating = ratingSnapshot.data;
                                              if (userRating == null || userRating == 0.0) {
                                                return const Text(
                                                  'Rating: No rating yet',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                );
                                              } else {
                                                return Text(
                                                  'Rating: ${userRating.toStringAsFixed(1)}',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: _ratingColor(userRating),
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                      ],
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        );
                      } else {
                        return const SizedBox(); // Return an empty SizedBox for now
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 125),
            Container(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.5,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    String sender = Auth().currentUser!.uid;
                    bool flag = await ChatController().chatExists(product.productID, sender, product.UserID);
                    if (!flag) ChatController().initiateChat(product.productID, sender, product.UserID);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => Chat(receiverId: product.UserID, product: product)));
                  },
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                          (Set<MaterialState> states) {
                        return themeProvider.getTheme().appBarTheme.backgroundColor;
                      },
                    ),
                    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.0),
                      ),
                    ),
                  ),
                  icon: Icon(Icons.chat, color: themeProvider.getTheme().appBarTheme.iconTheme!.color),
                  label: Text('Chat', style: TextStyle(color: themeProvider.getTheme().appBarTheme.iconTheme!.color)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.5,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReviewPage(productId: product.productID, revieweeId: product.UserID),
                      ),
                    );
                  },
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                          (Set<MaterialState> states) {
                        return themeProvider.getTheme().primaryColor;
                      },
                    ),
                    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.0),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.rate_review, color: Colors.white),
                  label: const Text('Leave a Review', style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
