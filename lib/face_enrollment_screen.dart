import 'dart:io';
import 'dart:math';
import 'package:face_idd/welcome_page.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

//import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceEnrollmentScreen extends StatefulWidget {
  @override
  _FaceEnrollmentScreenState createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  Interpreter? _interpreter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadModel());
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/mobilefacenet.tflite');
    } catch (e) {
      _showMessage("Erreur lors du chargement du modèle : $e");
    }
  }

  Future<void> _pickImageForEnrollment() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
      await _processImageForEnrollment(_image!);
    }
  }

  Future<void> _pickImageForRecognition() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
      await _processImageForRecognition(_image!);
    }
  }

  Future<void> _processImageForEnrollment(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(enableContours: true, enableLandmarks: true),
    );

    final faces = await faceDetector.processImage(inputImage);
    await faceDetector.close();

    if (faces.isEmpty) {
      _showMessage("Aucun visage détecté. Essayez encore.");
      return;
    }

    final faceImage = await _extractFaceImage(imageFile, faces.first);
    final embedding = await _getFaceEmbedding(faceImage);
    await _sendToBackend(embedding);
  }

  Future<void> _processImageForRecognition(File imageFile) async {
  final inputImage = InputImage.fromFile(imageFile);
  final faceDetector = FaceDetector(
    options: FaceDetectorOptions(enableContours: true, enableLandmarks: true),
  );

  final faces = await faceDetector.processImage(inputImage);
  await faceDetector.close();

  if (faces.isEmpty) {
    _showMessage("Aucun visage détecté. Essayez encore.");
    return;
  }

  final faceImage = await _extractFaceImage(imageFile, faces.first);
  final embedding = await _getFaceEmbedding(faceImage);

  // Récupérer les embeddings depuis la base de données
 final usersData = await _fetchUsersFromDatabase();

// Extraire uniquement les embeddings (profilePicture)
final usersEmbeddings = Map<String, List<double>>.fromEntries(
  usersData.entries.map((entry) => MapEntry(
        entry.key,
        List<double>.from(entry.value["profilePicture"]),
      )),
);

// Comparer l'embedding avec ceux de la base de données
String? recognizedUser = _compareEmbeddings(embedding, usersEmbeddings);;

if (recognizedUser != null) {
  // Vérifier que recognizedUser existe dans usersData
  final userData = usersData[recognizedUser];
  if (userData != null) {
    final score = userData["score"] ?? 0; // Valeur par défaut si null
    final progresLevel = userData["progresLevel"] ?? 0.0; // Valeur par défaut si null

    // Naviguer vers la nouvelle page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WelcomePage(
          username: recognizedUser!,
          score: score,
         
        ),
      ),
    );
  } else {
    _showMessage("Erreur : Données utilisateur manquantes.");
  }
} else {
  _showMessage("Visage non reconnu.");
}
  }

  Future<img.Image> _extractFaceImage(File imageFile, Face face) async {
    final originalImage = img.decodeImage(await imageFile.readAsBytes())!;
    final rect = face.boundingBox;
    return img.copyCrop(
      originalImage,
      rect.left.toInt(), rect.top.toInt(),
      rect.width.toInt(), rect.height.toInt(),
    );
  }

  Future<List<double>> _getFaceEmbedding(img.Image faceImage) async {
    if (_interpreter == null) throw Exception("Modèle non chargé");

    final resizedImage = img.copyResize(faceImage, width: 112, height: 112);
    final inputTensor = List.generate(112, (y) => List.generate(112, (x) {
      final pixel = resizedImage.getPixel(x, y);
      return [
        ((pixel >> 16) & 0xFF) / 255.0, // Rouge
        ((pixel >> 8) & 0xFF) / 255.0,  // Vert
        (pixel & 0xFF) / 255.0          // Bleu
      ];
    }));

    final input = [inputTensor];
    final output = List.filled(192, 0.0).reshape([1, 192]);

    try {
      _interpreter!.run(input, output);
      return List<double>.from(output[0]);
    } catch (e) {
      throw Exception("Erreur lors de l'inférence : $e");
    }
  }

  Future<void> _sendToBackend(List<double> embedding) async {
    final response = await http.post(
      Uri.parse("https://6342-196-229-153-144.ngrok-free.app/auth/signup"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": "kiramee",
        "birthday": "2002-12-25",
        "poids": 50,
        "taille": 170,
        "password": "zied",
        "profilePicture": embedding,
      }),
    );

    _showMessage(response.statusCode == 201
        ? "Inscription réussie avec reconnaissance faciale !"
        : "Échec de l'inscription. Réessayez.");
  }

 Future<Map<String, Map<String, dynamic>>> _fetchUsersFromDatabase() async {
  final response = await http.get(
    Uri.parse("https://6342-196-229-153-144.ngrok-free.app/auth/getAll"),
    headers: {"Content-Type": "application/json"},
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return Map<String, Map<String, dynamic>>.from({
      for (var user in data)
        user["username"]: {
          "profilePicture": List<double>.from(user["profilePicture"]),
          "score": user["score"] ?? 0, // Valeur par défaut si null
          "progresLevel": user["progresLevel"] ?? 0.0, // Valeur par défaut si null
        }
    });
  } else {
    throw Exception("Erreur lors de la récupération des utilisateurs.");
  }
}

 String? _compareEmbeddings(List<double> embedding, Map<String, List<double>> users) {
  double threshold = 1.0; // Seuil pour la distance euclidienne

  for (var entry in users.entries) {
    final username = entry.key;
    final storedEmbedding = entry.value;

    // Vérifier que l'embedding stocké n'est pas vide et a la même longueur
    if (storedEmbedding.isEmpty || storedEmbedding.length != embedding.length) {
      print("Erreur : Embedding invalide pour l'utilisateur $username");
      continue;
    }

    // Calculer la distance euclidienne
    final distance = _euclideanDistance(embedding, storedEmbedding);

    // Comparer avec le seuil
    if (distance < threshold) {
      return username;
    }
  }

  return null;
}

 double _euclideanDistance(List<double> a, List<double> b) {
  if (a.isEmpty || b.isEmpty) {
    throw Exception("Erreur : Les embeddings ne doivent pas être vides.");
  }
  if (a.length != b.length) {
    throw Exception("Erreur : Les embeddings doivent avoir la même longueur.");
  }

  double sum = 0.0;
  for (int i = 0; i < a.length; i++) {
    sum += (a[i] - b[i]) * (a[i] - b[i]);
  }
  return sqrt(sum);
}

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Reconnaissance faciale")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _image != null ? Image.file(_image!) : Text("Prenez une photo"),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickImageForEnrollment,
              child: Text("sign up"),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _pickImageForRecognition,
              child: Text("face idd"),
            ),
          ],
        ),
      ),
    );
  }
}