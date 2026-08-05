import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/participant.dart';
import '../../services/firebase_service.dart';
import '../ai/ai_assessment_screen.dart';
import '../register/register_screen.dart';

class ParticipantManagementScreen extends StatefulWidget {
  const ParticipantManagementScreen({super.key});

  @override
  State<ParticipantManagementScreen> createState() =>
      _ParticipantManagementScreenState();
}

class _ParticipantManagementScreenState
    extends State<ParticipantManagementScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  final TextEditingController _searchController = TextEditingController();

  String _keyword = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteParticipant(Participant participant) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Participant"),

          content: Text(
            "Are you sure you want to delete "
            "${participant.fullName} "
            "(${participant.staffId})?",
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("Cancel"),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    final success = await _firebaseService.deleteParticipant(
      participant.staffId,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? "Participant deleted successfully." : "Delete failed.",
        ),
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterParticipants(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (_keyword.trim().isEmpty) {
      return docs;
    }

    final search = _keyword.trim().toLowerCase();

    return docs.where((doc) {
      final data = doc.data();

      final staff = (data["staff"] ?? "").toString().toLowerCase();

      final name = (data["name"] ?? "").toString().toLowerCase();

      final trainer = (data["trainer"] ?? "").toString().toLowerCase();

      return staff.contains(search) ||
          name.contains(search) ||
          trainer.contains(search);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),

      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 90,

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Participant Dashboard",
              style: TextStyle(
                color: Color(0xFF1F3D73),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              "Manage registrations, assessments and participant records",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),

        actions: [
          Container(
            margin: const EdgeInsets.only(right: 20),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF1F3D73),
              child: const Icon(Icons.people_alt_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _searchController,

              decoration: InputDecoration(
                hintText: "Search Staff ID / Name / Trainer",

                prefixIcon: const Icon(Icons.search),

                filled: true,
                fillColor: Colors.white,

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),

                suffixIcon: _keyword.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();

                          setState(() {
                            _keyword = "";
                          });
                        },
                      ),
              ),

              onChanged: (value) {
                setState(() {
                  _keyword = value.trim();
                });
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firebaseService.streamParticipants(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];

                final total = docs.length;

                final assessed = docs.where((e) {
                  final score = (e.data()["latestScore"] ?? 0);
                  return score != 0;
                }).length;

                final pending = total - assessed;

                final today = docs.where((e) {
                  final date = (e.data()["registrationDate"] ?? "").toString();

                  return date.contains(DateTime.now().day.toString());
                }).length;

                Widget card(
                  String title,
                  String value,
                  IconData icon,
                  Color color,
                ) {
                  return Expanded(
                    child: Container(
                      height: 105,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, color: color, size: 26),

                          const Spacer(),

                          Text(
                            value,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 3),

                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Row(
                  children: [
                    card(
                      "Participants",
                      total.toString(),
                      Icons.people,
                      Colors.blue,
                    ),

                    card(
                      "Assessed",
                      assessed.toString(),
                      Icons.analytics,
                      Colors.green,
                    ),

                    card(
                      "Pending",
                      pending.toString(),
                      Icons.schedule,
                      Colors.orange,
                    ),

                    card("Today", today.toString(), Icons.today, Colors.purple),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firebaseService.streamParticipants(),

              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No participants found."));
                }

                final docs = _filterParticipants(snapshot.data!.docs);

                if (docs.isEmpty) {
                  return const Center(child: Text("No matching participant."));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),

                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final participant = Participant.fromJson({
                      ...docs[index].data(),
                      "id": docs[index].id,
                    });

                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Hero(
                                    tag: participant.staffId,
                                    child: CircleAvatar(
                                      radius: 34,
                                      backgroundImage:
                                          participant.photoUrl.isNotEmpty
                                          ? NetworkImage(participant.photoUrl)
                                          : null,
                                      child: participant.photoUrl.isEmpty
                                          ? const Icon(Icons.person)
                                          : null,
                                    ),
                                  ),

                                  const SizedBox(width: 16),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          participant.fullName,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),

                                        const SizedBox(height: 4),

                                        Text(
                                          "Staff ID : ${participant.staffId}",
                                        ),

                                        Text(
                                          "Trainer : ${participant.trainerName}",
                                        ),
                                      ],
                                    ),
                                  ),

                                  PopupMenuButton<String>(
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: "info",
                                        child: Text("Participant"),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              const Divider(),

                              const SizedBox(height: 20),

                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.visibility),
                                      label: const Text("View"),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) {
                                            return AlertDialog(
                                              title: const Text(
                                                "Participant Details",
                                              ),

                                              content: SingleChildScrollView(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Center(
                                                      child: CircleAvatar(
                                                        radius: 50,
                                                        backgroundImage:
                                                            participant
                                                                .photoUrl
                                                                .isNotEmpty
                                                            ? NetworkImage(
                                                                participant
                                                                    .photoUrl,
                                                              )
                                                            : null,
                                                        child:
                                                            participant
                                                                .photoUrl
                                                                .isEmpty
                                                            ? const Icon(
                                                                Icons.person,
                                                                size: 40,
                                                              )
                                                            : null,
                                                      ),
                                                    ),

                                                    const SizedBox(height: 20),

                                                    Text(
                                                      "Name : ${participant.fullName}",
                                                    ),
                                                    Text(
                                                      "Staff ID : ${participant.staffId}",
                                                    ),
                                                    Text(
                                                      "Trainer : ${participant.trainerName}",
                                                    ),
                                                    Text(
                                                      "Registration Date : ${participant.registrationDate}",
                                                    ),

                                                    const SizedBox(height: 16),

                                                    Text(
                                                      "Latest Score : ${participant.latestScore}",
                                                    ),

                                                    Text(
                                                      "Latest Result : ${participant.latestResult}",
                                                    ),

                                                    Text(
                                                      "Assessment Count : ${participant.assessmentCount}",
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              actions: [
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                  },
                                                  child: const Text("Close"),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),

                                  const SizedBox(width: 10),

                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.edit),
                                      label: const Text("Edit"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () {
                                        final nameController =
                                            TextEditingController(
                                              text: participant.fullName,
                                            );

                                        final trainerController =
                                            TextEditingController(
                                              text: participant.trainerName,
                                            );

                                        File? selectedImage;

                                        showDialog(
                                          context: context,
                                          builder: (_) {
                                            return StatefulBuilder(
                                              builder: (context, setDialogState) {
                                                return AlertDialog(
                                                  title: const Text(
                                                    "Edit Participant",
                                                  ),

                                                  content: SingleChildScrollView(
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        GestureDetector(
                                                          onTap: () async {
                                                            final picker =
                                                                ImagePicker();

                                                            final image = await picker
                                                                .pickImage(
                                                                  source:
                                                                      ImageSource
                                                                          .gallery,
                                                                  imageQuality:
                                                                      80,
                                                                );

                                                            if (image == null) {
                                                              return;
                                                            }

                                                            setDialogState(() {
                                                              selectedImage =
                                                                  File(
                                                                    image.path,
                                                                  );
                                                            });
                                                          },

                                                          child: CircleAvatar(
                                                            radius: 45,
                                                            backgroundImage:
                                                                selectedImage !=
                                                                    null
                                                                ? FileImage(
                                                                    selectedImage!,
                                                                  )
                                                                : participant
                                                                      .photoUrl
                                                                      .isNotEmpty
                                                                ? NetworkImage(
                                                                    participant
                                                                        .photoUrl,
                                                                  )
                                                                : null,
                                                            child:
                                                                selectedImage ==
                                                                        null &&
                                                                    participant
                                                                        .photoUrl
                                                                        .isEmpty
                                                                ? const Icon(
                                                                    Icons
                                                                        .camera_alt,
                                                                  )
                                                                : null,
                                                          ),
                                                        ),

                                                        const SizedBox(
                                                          height: 20,
                                                        ),

                                                        TextField(
                                                          controller:
                                                              nameController,
                                                          decoration:
                                                              const InputDecoration(
                                                                labelText:
                                                                    "Full Name",
                                                              ),
                                                        ),

                                                        const SizedBox(
                                                          height: 15,
                                                        ),

                                                        TextField(
                                                          controller:
                                                              trainerController,
                                                          decoration:
                                                              const InputDecoration(
                                                                labelText:
                                                                    "Trainer Name",
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                  actions: [
                                                    TextButton(
                                                      onPressed: () {
                                                        Navigator.pop(context);
                                                      },
                                                      child: const Text(
                                                        "Cancel",
                                                      ),
                                                    ),

                                                    ElevatedButton(
                                                      child: const Text("Save"),

                                                      onPressed: () async {
                                                        final navigator =
                                                            Navigator.of(
                                                              context,
                                                            );
                                                        final messenger =
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            );
                                                        String photoUrl =
                                                            participant
                                                                .photoUrl;

                                                        if (selectedImage !=
                                                            null) {
                                                          final uploadedUrl =
                                                              await _firebaseService
                                                                  .uploadPhoto(
                                                                    staff: participant
                                                                        .staffId,
                                                                    image:
                                                                        selectedImage!,
                                                                  );

                                                          if (uploadedUrl !=
                                                              null) {
                                                            photoUrl =
                                                                uploadedUrl;
                                                          }
                                                        }

                                                        final success = await _firebaseService
                                                            .updateParticipant(
                                                              staff: participant
                                                                  .staffId,
                                                              name:
                                                                  nameController
                                                                      .text
                                                                      .trim(),
                                                              trainer:
                                                                  trainerController
                                                                      .text
                                                                      .trim(),
                                                              registrationDate:
                                                                  participant
                                                                      .registrationDate,
                                                              photoUrl:
                                                                  photoUrl,
                                                            );

                                                        if (!mounted) return;

                                                        navigator.pop();

                                                        messenger.showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              success
                                                                  ? "Participant updated successfully."
                                                                  : "Update failed.",
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),

                                  const SizedBox(width: 10),

                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.assignment),
                                      label: const Text("Assess"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => AIAssessmentScreen(
                                              participantId:
                                                  participant.staffId,
                                              participantName:
                                                  participant.fullName,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),

                                  const SizedBox(width: 10),

                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.delete),
                                      label: const Text("Delete"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () {
                                        _deleteParticipant(participant);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1F3D73),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text("Register"),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegisterScreen()),
          );

          if (!mounted) return;

          setState(() {});
        },
      ),
    );
  }
}
