import 'package:flutter/material.dart';

class ParticipantCard extends StatelessWidget {
  final TextEditingController fullNameController;
  final TextEditingController staffIdController;
  final TextEditingController trainerNameController;
  final TextEditingController registrationDateController;

  const ParticipantCard({
    super.key,
    required this.fullNameController,
    required this.staffIdController,
    required this.trainerNameController,
    required this.registrationDateController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Participant Details",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF162B56),
            ),
          ),

          const SizedBox(height: 20),

          TextField(
            controller: fullNameController,
            decoration: InputDecoration(
              labelText: "Full Name",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: staffIdController,
            decoration: InputDecoration(
              labelText: "Staff ID",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: trainerNameController,
            decoration: InputDecoration(
              labelText: "Trainer Name",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: registrationDateController,
            decoration: InputDecoration(
              labelText: "Registration Date",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
