import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../api/assessment_api.dart';
import '../../models/app_user.dart';
import '../../models/captured_image.dart';
import '../../models/participant.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';
import '../../services/image_service.dart';
import '../ai/ai_assessment_screen.dart';
import '../auth/login_screen.dart';
import '../auth/role_selection_screen.dart';
import '../register/register_screen.dart';
import 'participant_profile_screen.dart';

class ParticipantManagementScreen extends StatefulWidget {
  const ParticipantManagementScreen({super.key});

  @override
  State<ParticipantManagementScreen> createState() =>
      _ParticipantManagementScreenState();
}

class _ParticipantManagementScreenState
    extends State<ParticipantManagementScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();

  final TextEditingController _searchController = TextEditingController();

  String _keyword = "";

  bool _checkingAccess = true;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  /// This screen previously had no role check at all beyond being
  /// reachable only from DashboardScreen's buttons -- reachability
  /// through the UI is not an access control. Same guard pattern as
  /// DashboardScreen._checkAdminAccess: not-signed-in -> Login;
  /// signed-in but not Admin -> Role Selection; only a confirmed
  /// `role: admin` account loads participant data.
  Future<void> _checkAdminAccess() async {
    if (FirebaseAuth.instance.currentUser == null) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    AppUser? appUser;
    try {
      appUser = await _authService.getCurrentAppUser();
    } catch (_) {
      // Falls through to the role check below, which treats a failed
      // lookup the same as "not Admin" -- fail closed, not open.
    }

    if (!mounted) return;

    if (appUser == null || appUser.role != UserRole.admin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      );
      return;
    }

    setState(() {
      _checkingAccess = false;
    });
  }

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
    if (_checkingAccess) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

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

                // No fixed height (was `height: 105`, with a Spacer()
                // to push content to the bottom) -- same overflow cause
                // as DashboardScreen's _OverviewCard had: any title
                // long enough to wrap, or a larger device text-scale
                // setting, pushed past that fixed box. Sizing to
                // content (`mainAxisSize: MainAxisSize.min`, a plain
                // SizedBox gap instead of Spacer -- Spacer needs a
                // bounded height to expand into, which content-sized
                // Column no longer has) means it can't overflow itself.
                Widget card(
                  String title,
                  String value,
                  IconData icon,
                  Color color,
                ) {
                  return Expanded(
                    child: Container(
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
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, color: color, size: 26),

                          const SizedBox(height: 12),

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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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

                              Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 46,
                                          child: OutlinedButton.icon(
                                            icon: const Icon(
                                              Icons.visibility,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              "View",
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            onPressed: () async {
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      ParticipantProfileScreen(
                                                        staffId:
                                                            participant.staffId,
                                                      ),
                                                ),
                                              );

                                              if (!context.mounted) return;
                                              setState(() {});
                                            },
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 10),

                                      Expanded(
                                        child: SizedBox(
                                          height: 46,
                                          child: ElevatedButton.icon(
                                            icon: const Icon(
                                              Icons.edit,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              "Edit",
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            onPressed: () {
                                              final nameController =
                                                  TextEditingController(
                                                    text: participant.fullName,
                                                  );

                                              final trainerController =
                                                  TextEditingController(
                                                    text:
                                                        participant.trainerName,
                                                  );

                                              CapturedImage? selectedImage;
                                              bool validatingPhoto = false;

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
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              GestureDetector(
                                                                // STRICT COMPANY REQUIREMENT: the
                                                                // Reference Photo must be a
                                                                // full-body photo (head to feet),
                                                                // same as every other appearance
                                                                // photo entry point in this app --
                                                                // see RegisterScreen's class doc
                                                                // comment. Editing it from here
                                                                // must go through the exact same
                                                                // authoritative validator
                                                                // (AssessmentApi.detectPerson),
                                                                // never a separate, unvalidated
                                                                // path -- this dialog previously
                                                                // bypassed validation entirely.
                                                                onTap:
                                                                    validatingPhoto
                                                                    ? null
                                                                    : () async {
                                                                        final picked =
                                                                            await ImageService().pickFromGallery();

                                                                        if (picked ==
                                                                            null) {
                                                                          return;
                                                                        }

                                                                        setDialogState(() {
                                                                          validatingPhoto =
                                                                              true;
                                                                        });

                                                                        bool
                                                                        isFullBody;
                                                                        try {
                                                                          isFullBody = await AssessmentApi().detectPerson(
                                                                            image:
                                                                                picked,
                                                                          );
                                                                        } catch (
                                                                          e
                                                                        ) {
                                                                          debugPrint(
                                                                            "EditParticipant photo validation: $e",
                                                                          );
                                                                          isFullBody =
                                                                              false;
                                                                        }

                                                                        setDialogState(() {
                                                                          validatingPhoto =
                                                                              false;
                                                                          if (isFullBody) {
                                                                            selectedImage =
                                                                                picked;
                                                                          }
                                                                        });

                                                                        if (!isFullBody) {
                                                                          if (!context
                                                                              .mounted) {
                                                                            return;
                                                                          }
                                                                          ScaffoldMessenger.of(
                                                                            context,
                                                                          ).showSnackBar(
                                                                            const SnackBar(
                                                                              content: Text(
                                                                                kFullBodyPhotoErrorMessage,
                                                                              ),
                                                                              backgroundColor: Colors.red,
                                                                            ),
                                                                          );
                                                                        }
                                                                      },

                                                                child: Stack(
                                                                  alignment:
                                                                      Alignment
                                                                          .center,
                                                                  children: [
                                                                    CircleAvatar(
                                                                      radius:
                                                                          45,
                                                                      backgroundImage:
                                                                          selectedImage !=
                                                                              null
                                                                          ? (selectedImage!.file !=
                                                                                        null
                                                                                    ? FileImage(
                                                                                        selectedImage!.file!,
                                                                                      )
                                                                                    : MemoryImage(
                                                                                        selectedImage!.webBytes!,
                                                                                      ))
                                                                                as ImageProvider
                                                                          : participant.photoUrl.isNotEmpty
                                                                          ? NetworkImage(
                                                                              participant.photoUrl,
                                                                            )
                                                                          : null,
                                                                      child:
                                                                          selectedImage ==
                                                                                  null &&
                                                                              participant.photoUrl.isEmpty
                                                                          ? const Icon(
                                                                              Icons.camera_alt,
                                                                            )
                                                                          : null,
                                                                    ),
                                                                    if (validatingPhoto)
                                                                      const CircularProgressIndicator(),
                                                                  ],
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
                                                              Navigator.pop(
                                                                context,
                                                              );
                                                            },
                                                            child: const Text(
                                                              "Cancel",
                                                            ),
                                                          ),

                                                          ElevatedButton(
                                                            child: const Text(
                                                              "Save",
                                                            ),

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
                                                                final uploadResult =
                                                                    await _firebaseService.uploadPhoto(
                                                                      staff: participant
                                                                          .staffId,
                                                                      image:
                                                                          selectedImage!,
                                                                    );

                                                                if (uploadResult
                                                                    .success) {
                                                                  photoUrl =
                                                                      uploadResult
                                                                          .imageUrl!;
                                                                } else {
                                                                  if (!mounted) {
                                                                    return;
                                                                  }

                                                                  messenger.showSnackBar(
                                                                    SnackBar(
                                                                      content: Text(
                                                                        "Photo upload failed: ${uploadResult.errorMessage}",
                                                                      ),
                                                                      backgroundColor:
                                                                          Colors
                                                                              .red,
                                                                    ),
                                                                  );
                                                                  return;
                                                                }
                                                              }

                                                              final success = await _firebaseService.updateParticipant(
                                                                staff:
                                                                    participant
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

                                                              if (!mounted) {
                                                                return;
                                                              }

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
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 46,
                                          child: ElevatedButton.icon(
                                            icon: const Icon(
                                              Icons.assignment,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              "Assessment",
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      AIAssessmentScreen(
                                                        participantId:
                                                            participant.staffId,
                                                        participantName:
                                                            participant
                                                                .fullName,
                                                      ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: SizedBox(
                                          height: 46,
                                          child: ElevatedButton.icon(
                                            icon: const Icon(
                                              Icons.delete,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              "Delete",
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            onPressed: () {
                                              _deleteParticipant(participant);
                                            },
                                          ),
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
