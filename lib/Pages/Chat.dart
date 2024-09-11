import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:register/Pages/ProductsChats.dart';

import '../Auth/Auth.dart';
import '../Controllers/ChatController.dart';
import '../Models/ProductInfo.dart';
import 'Home.dart';

class Chat extends StatefulWidget {
  final String receiverId;
  final ProductInfo product;

  const Chat({super.key, required this.receiverId, required this.product});

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> with WidgetsBindingObserver {
  final TextEditingController textController = TextEditingController();
  final ChatController chatController = ChatController();
  final Auth auth = Auth();
  FocusNode focusNode = FocusNode();
  File? image;
  String? status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        Future.delayed(
            const Duration(milliseconds: 100),
                () => scrollDown(duration: const Duration(milliseconds: 400)));
      }
    });
    getChatStatus();

    Future.delayed(
        const Duration(milliseconds: 200),
            () => scrollDown(duration: const Duration(milliseconds: 400)));
  }
  Future<void> getChatStatus() async {
    List<String> buildId = [widget.product.productID, auth.currentUser!.uid, widget.receiverId]..sort();
    String chatId = buildId.join("-");
    DocumentSnapshot chat = await FirebaseFirestore.instance.collection('Chats').doc(chatId).get();
    setState(() {
      status = chat['status'];
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    focusNode.dispose();
    textController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    scrollDown(duration: Duration.zero);
  }

  final ScrollController scrollController = ScrollController();

  void scrollDown({required Duration duration}) {
    if (duration == Duration.zero) {
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
    } else {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: duration,
        curve: Curves.easeOut,
      );
    }
  }

  void sendMessage() async {
    await chatController.sendMessage(
        widget.product.productID, widget.receiverId, textController.text, image);
    textController.clear();
    image = null;

    scrollDown(duration: const Duration(milliseconds: 400));
  }

  Future<void> sendLocation() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    String locationMessage =
        'Location: ${position.latitude}, ${position.longitude}';
    await chatController.sendMessage(
        widget.product.productID, widget.receiverId, locationMessage, null);
    scrollDown(duration: const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.network(
              widget.product.imageURL,
              width: 80,
              height: 100,
              fit: BoxFit.cover,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product.productName,
                  style: Theme.of(context).appBarTheme.titleTextStyle,
                ),
                Opacity(
                  opacity: 0.7,
                  child: Text(
                    widget.product.category,
                    style: const TextStyle(fontSize: 16.0),
                  ),
                ),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => ProductsChats()),
              );
            }
        ),
        actions: status != 'finished' ? [
          IconButton(
            icon: const Icon(Icons.check_box),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Confirm Transaction'),
                    content: const Text('Are you sure you want to confirm this transaction?'),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('Yes'),
                        onPressed: () async {
                          List<String> buildId = [widget.product.productID, auth.currentUser!.uid, widget.receiverId]..sort();
                          String chatId = buildId.join("-");
                          try {
                            await chatController.verifyTransaction(chatId);
                            getChatStatus();
                          } catch (e) {
                            print('Error verifying transaction: $e');
                          }
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: const Text('No'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ] : [],
      ),
      body: Column(children: [
        const SizedBox(height: 8),
        Expanded(
          child: buildAllMessages(),
        ),
        writeMessage(context),
      ]),
    );
  }

  Widget buildAllMessages() {
    String senderId = auth.currentUser!.uid;
    return StreamBuilder(
        stream: ChatController()
            .getMessages(widget.product.productID, widget.receiverId, senderId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text("Error: ${snapshot.error}");
          } else if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else {
            return ListView(
                controller: scrollController,
                children: snapshot.data!.docs
                    .map((doc) => buildSingleMessage(context, doc))
                    .toList());
          }
        });
  }

  Widget buildSingleMessage(BuildContext context, DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    List<Widget> messageWidgets = [];

    if (data["imageURL"] != null) {
      messageWidgets.add(Image.network(data["imageURL"]));
    }

    if (data["message"] != null && data["message"].isNotEmpty) {
      if (data["message"].startsWith("Location:")) {
        List<String> parts = data["message"].split(":")[1].split(",");
        double lat = double.parse(parts[0]);
        double lon = double.parse(parts[1]);
        messageWidgets.add(GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MapScreen(latitude: lat, longitude: lon),
              ),
            );
          },
          child: Text(
            "Shared Location",
            style: TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
                fontSize: 16),
          ),
        ));
      } else {
        messageWidgets.add(Text(data["message"]));
      }
    }

    bool isReceiver = data["receiverID"] == widget.receiverId;
    return Align(
      alignment: isReceiver ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: 1,
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: ChatBubble(
          isReceiver: isReceiver,
          content: Column(
            crossAxisAlignment:
            isReceiver ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: messageWidgets,
          ),
        ),
      ),
    );
  }

  Widget writeMessage(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(30.0),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.image),
            onPressed: () async {
              final picked =
              await ImagePicker().pickImage(source: ImageSource.gallery);

              if (picked != null) {
                setState(() {
                  image = File(picked.path);
                });
              } else {
                print('No image selected.');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: sendLocation,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TextField(
                controller: textController,
                decoration: InputDecoration(
                  hintText: "Type a message",
                  hintStyle: TextStyle(color: Theme.of(context).hintColor),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: sendMessage,
          ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final Widget content;
  final bool isReceiver;

  const ChatBubble({super.key, required this.content, required this.isReceiver});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
      margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: isReceiver ? Colors.indigo : Theme.of(context).primaryColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(15.0),
          topRight: const Radius.circular(15.0),
          bottomLeft:
          isReceiver ? const Radius.circular(15.0) : const Radius.circular(0),
          bottomRight:
          isReceiver ? const Radius.circular(0) : const Radius.circular(15.0),
        ),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontSize: 16.0),
        child: content,
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;

  const MapScreen({Key? key, required this.latitude, required this.longitude}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  double _currentZoom = 14.0;

  void _zoomIn() {
    setState(() {
      _currentZoom += 1;
      _mapController.move(_mapController.center, _currentZoom);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentZoom -= 1;
      _mapController.move(_mapController.center, _currentZoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Map"),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: LatLng(widget.latitude, widget.longitude),
              zoom: _currentZoom,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    width: 80.0,
                    height: 80.0,
                    point: LatLng(widget.latitude, widget.longitude),
                    builder: (ctx) => const Icon(Icons.location_on, color: Colors.red, size: 40),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Column(
              children: [
                FloatingActionButton(
                  onPressed: _zoomIn,
                  mini: true,
                  child: const Icon(Icons.zoom_in),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  onPressed: _zoomOut,
                  mini: true,
                  child: const Icon(Icons.zoom_out),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
