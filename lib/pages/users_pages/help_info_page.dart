import 'package:flutter/material.dart';

class HelpInfoPage extends StatelessWidget {
  const HelpInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: true,
        elevation: 0,
        toolbarHeight: 70,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[700]!, Colors.blue[400]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        title: const Text(
          "Help & Information",
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: Colors.white, // This makes the back button white
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Help Section
            _buildQuickHelpSection(),
            const SizedBox(height: 20),

            // FAQ Section
            _buildFAQSection(),
            const SizedBox(height: 20),

            // App Information
            _buildAppInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickHelpSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick Help",
            style: TextStyle(
              fontSize: 18,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildHelpItem(
            Icons.gavel,
            "Understanding Fines",
            "Learn about traffic violations and fine amounts",
          ),
          const SizedBox(height: 12),
          _buildHelpItem(
            Icons.credit_card,
            "Payment Process",
            "How to pay your fines securely",
          ),
          const SizedBox(height: 12),
          _buildHelpItem(
            Icons.badge,
            "License Information",
            "Check your license status and validity",
          ),
          const SizedBox(height: 12),
          _buildHelpItem(
            Icons.history,
            "Violation History",
            "View your past violations and payments",
          ),
          const SizedBox(height: 12),
          _buildHelpItem(
            Icons.question_answer,
            "FAQ",
            "Frequently asked questions and answers",
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'Poppins',
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: Colors.blue[700], size: 16),
        ],
      ),
    );
  }

  Widget _buildFAQSection() {
    final List<Map<String, String>> faqs = [
      {
        'question': 'How do I pay my traffic fines?',
        'answer':
            'You can pay fines through the app using credit/debit cards or mobile payment options in the Payment section.',
      },
      {
        'question': 'What should I do if I receive a wrong fine?',
        'answer':
            'Contact support immediately with your fine ID and evidence. You can appeal within 14 days of issuance.',
      },
      {
        'question': 'How can I check my license status?',
        'answer':
            'Your license status is displayed on the dashboard. Green indicates active, red indicates deactivated.',
      },
      {
        'question': 'How long do I have to pay a fine?',
        'answer':
            'Typically, fines should be paid within 30 days. Late payments may incur additional penalties.',
      },
      {
        'question': 'Where can I view my payment history?',
        'answer':
            'Go to the History section to view all your past payments and transaction details.',
      },
      {
        'question': 'What payment methods are accepted?',
        'answer':
            'We accept credit cards, debit cards, and popular mobile payment platforms.',
      },
      {
        'question': 'How do I update my personal information?',
        'answer':
            'Visit your Profile page to update your personal details and contact information.',
      },
      {
        'question': 'Is my payment information secure?',
        'answer':
            'Yes, all payments are processed through secure encrypted channels to protect your information.',
      },
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Frequently Asked Questions",
            style: TextStyle(
              fontSize: 18,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...faqs.map((faq) => _buildFAQItem(faq['question']!, faq['answer']!)),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 14,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              answer,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'Poppins',
                color: Colors.grey,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "App Information",
            style: TextStyle(
              fontSize: 18,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoItem("App Version", "1.0.0"),
          _buildInfoItem("Last Updated", "December 2023"),
          _buildInfoItem("Developer", "SafeRoad Team"),
          _buildInfoItem("License", "Government Use Only"),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
