// lib/features/session/presentation/pages/session_summary_page.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/utils/extensions.dart';
import 'package:hermes/features/session/domain/entities/session.dart';
import 'package:hermes/features/translation/domain/entities/transcript.dart';
import 'package:hermes/routes.dart';

class SessionSummaryPage extends StatelessWidget {
  final Session session;
  final List<Transcript> transcripts;
  final int audienceCount;
  final Duration sessionDuration;

  const SessionSummaryPage({
    super.key,
    required this.session,
    required this.transcripts,
    required this.audienceCount,
    required this.sessionDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Summary'),
        automaticallyImplyLeading: false, // No back button
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Session success banner
                _buildSuccessBanner(context),

                const SizedBox(height: 24),

                // Session metrics cards
                _buildMetricsSection(context),

                const SizedBox(height: 24),

                // Transcript overview
                _buildTranscriptSection(context),

                const SizedBox(height: 32),

                // Action buttons
                _buildActionButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check, color: Colors.green.shade700),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Session Completed',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
                Text(
                  'Your speech has been successfully transcribed and translated.',
                  style: TextStyle(color: Colors.green.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Session Metrics', style: context.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Row(
          children: [
            // Session duration card
            Expanded(
              child: _buildMetricCard(
                context,
                Icons.timer,
                _formatDuration(sessionDuration),
                'Duration',
              ),
            ),
            const SizedBox(width: 12),
            // Audience count card
            Expanded(
              child: _buildMetricCard(
                context,
                Icons.people,
                audienceCount.toString(),
                'Audience',
              ),
            ),
            const SizedBox(width: 12),
            // Transcript count card
            Expanded(
              child: _buildMetricCard(
                context,
                Icons.text_fields,
                transcripts.length.toString(),
                'Transcripts',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: context.theme.primaryColor),
            const SizedBox(height: 8),
            Text(
              value,
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(label, style: context.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscriptSection(BuildContext context) {
    // Limit to 5 most recent transcripts
    final recentTranscripts =
        transcripts.length > 5
            ? transcripts.sublist(transcripts.length - 5)
            : transcripts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Transcripts', style: context.textTheme.headlineSmall),
            TextButton(
              onPressed: () {
                // Navigate to full transcript view (future feature)
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (recentTranscripts.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No transcripts were recorded in this session.'),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentTranscripts.length,
            itemBuilder: (context, index) {
              final transcript = recentTranscripts[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(transcript.text),
                  subtitle: Text(
                    _formatTimestamp(transcript.timestamp),
                    style: const TextStyle(fontSize: 12),
                  ),
                  leading: const Icon(Icons.text_format),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Export button (placeholder for future feature)
        OutlinedButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('Export Session Data'),
          onPressed: () {
            // Future feature: Export transcript data as text/CSV
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Export feature coming soon!')),
            );
          },
        ),

        const SizedBox(height: 16),

        // Return to home button
        ElevatedButton.icon(
          icon: const Icon(Icons.home),
          label: const Text('Return to Home'),
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.home,
              (route) => false,
            );
          },
        ),

        const SizedBox(height: 16),

        // New session button
        ElevatedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Start New Session'),
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.sessionStart,
              (route) => false,
            );
          },
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }
}
