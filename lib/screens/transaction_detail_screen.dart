import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../models/user_data.dart';
import '../core/theme/app_colors.dart';

class TransactionDetailScreen extends StatefulWidget {
  final Transaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;
  bool _isDownloading = false;

  Future<void> _handleShare() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    await _captureAndProcess(isShare: true);
    if (mounted) setState(() => _isSharing = false);
  }

  Future<void> _handleDownload() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    await _captureAndProcess(isShare: false);
    if (mounted) setState(() => _isDownloading = false);
  }

  Future<void> _captureAndProcess({required bool isShare}) async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      final Uint8List? imageBytes = await _screenshotController.capture(pixelRatio: 2.0);
      
      if (imageBytes != null) {
        final directory = await getTemporaryDirectory();
        final fileName = 'ZD_Receipt_${widget.transaction.reference}.png';
        final imageFile = File('${directory.path}/$fileName');
        await imageFile.writeAsBytes(imageBytes);

        if (isShare) {
          await Share.shareXFiles(
            [XFile(imageFile.path)],
            text: 'ZeeData Receipt - ${widget.transaction.description}',
          );
        } else {
          // Since we don't have gallery plugin, we "share" to files or just notify
          // For now, let's use share sheet as a way to "save" to files
          await Share.shareXFiles(
            [XFile(imageFile.path)],
            text: 'Save ZeeData Receipt',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Use the menu to save to your files'), backgroundColor: Colors.green),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Transaction Details', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    color: const Color(0xFFF8FAFC),
                    child: Column(
                      children: [
                        _buildAmountHeader(currencyFormat),
                        const SizedBox(height: 12),
                        _buildInfoSection(dateFormat),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _buildActionButtons(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountHeader(NumberFormat format) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (widget.transaction.isCredit ? Colors.green : Colors.red).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.transaction.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: widget.transaction.isCredit ? Colors.green : Colors.red,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.transaction.serviceType.toUpperCase(),
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.transaction.isCredit ? "+" : "-"}${format.format(widget.transaction.amount)}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: widget.transaction.isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(height: 16),
          _buildStatusBadge(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final status = widget.transaction.status.toUpperCase();
    Color color;
    switch (status) {
      case 'SUCCESS': color = const Color(0xFF10B981); break;
      case 'PENDING': color = Colors.orange; break;
      case 'FAILED': color = const Color(0xFFEF4444); break;
      default: color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status == 'SUCCESS' ? Icons.check_circle : (status == 'FAILED' ? Icons.error : Icons.access_time), size: 14, color: color),
          const SizedBox(width: 6),
          Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildInfoSection(DateFormat format) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TRANSACTION DETAILS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.5)),
          const SizedBox(height: 24),
          _buildDetailRow('Reference', widget.transaction.reference),
          if (widget.transaction.provider != null)
            _buildDetailRow('Service Provider', widget.transaction.provider!),
          _buildDetailRow('Date & Time', format.format(widget.transaction.createdAt)),
          _buildDetailRow('Description', widget.transaction.description),
          
          if (widget.transaction.metadata != null && widget.transaction.metadata!.isNotEmpty) ...[
            const Divider(height: 40),
            const Text('ADDITIONAL INFO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.5)),
            const SizedBox(height: 24),
            
            // Specifically look for Token in Electricity Transactions
            if (widget.transaction.serviceType.toUpperCase().contains('ELECTRICITY')) 
              _buildTokenRow(),

            // Specifically look for PINs in Recharge Pin Transactions
            if (widget.transaction.serviceType.toUpperCase().contains('RECHARGE_PIN')) 
              _buildPinListRow(),

            ...widget.transaction.metadata!.entries.where((e) {
              final k = e.key.toLowerCase();
              return !['source', 'amount_received', 'provider_response', 'status', 'token', 'maintoken', 'purchased_code'].contains(k);
            }).map((e) => _buildDetailRow(e.key.replaceAll('_', ' ').toUpperCase(), e.value.toString())),
          ],
        ],
      ),
    );
  }

  Widget _buildPinListRow() {
    final metadata = widget.transaction.metadata;
    if (metadata == null) return const SizedBox.shrink();

    final List? pins = metadata['pins'] as List?;
    final List? serials = metadata['serials'] as List?;

    if (pins == null || pins.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RECHARGE PINS',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0369A1), letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        ...List.generate(pins.length, (index) {
          final pin = pins[index].toString();
          final serial = (serials != null && serials.length > index) ? serials[index].toString() : null;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pin,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: 1),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 20, color: AppColors.primary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: pin));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN copied!')));
                      },
                    ),
                  ],
                ),
                if (serial != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Serial: $serial',
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey[600], fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          );
        }),
        const Divider(height: 40),
      ],
    );
  }

  Widget _buildTokenRow() {
    String? token;
    final metadata = widget.transaction.metadata;
    if (metadata == null) return const SizedBox.shrink();

    // 1. Check top level
    token = metadata['token']?.toString() ?? 
            metadata['purchased_code']?.toString() ?? 
            metadata['mainToken']?.toString();

    // 2. Check inside provider_response
    if (token == null && metadata['provider_response'] != null) {
      final pr = metadata['provider_response'];
      token = pr['token']?.toString() ?? 
              pr['purchased_code']?.toString() ?? 
              pr['mainToken']?.toString();
      
      // Some providers nest it deeper
      if (token == null && pr['content'] != null) {
        final content = pr['content'];
        token = content['token']?.toString() ?? 
                content['purchased_code']?.toString() ?? 
                content['mainToken']?.toString();
      }
    }

    if (token == null || token.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ELECTRICITY TOKEN',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0369A1), letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  token,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0C4A6E), letterSpacing: 2),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: Color(0xFF0369A1)),
                onPressed: () {
                   Clipboard.setData(ClipboardData(text: token!));
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token copied to clipboard')));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _buildActionButton(
            label: 'Share Receipt',
            icon: Icons.share_rounded,
            onPressed: _handleShare,
            isLoading: _isSharing,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            label: 'Download Receipt',
            icon: Icons.file_download_rounded,
            onPressed: _handleDownload,
            isLoading: _isDownloading,
            color: const Color(0xFF64748B),
            isOutlined: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isLoading,
    required Color color,
    bool isOutlined = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: isOutlined
          ? OutlinedButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon: isLoading ? _loader(color) : Icon(icon, size: 20),
              label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            )
          : ElevatedButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon: isLoading ? _loader(Colors.white) : Icon(icon, size: 20),
              label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
    );
  }

  Widget _loader(Color color) => SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: color));

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600))),
          Expanded(flex: 7, child: Text(value, textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}
