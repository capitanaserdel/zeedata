import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../models/user_data.dart';

class TransactionSuccessScreen extends StatefulWidget {
  final Transaction transaction;

  const TransactionSuccessScreen({super.key, required this.transaction});

  @override
  State<TransactionSuccessScreen> createState() => _TransactionSuccessScreenState();
}

class _TransactionSuccessScreenState extends State<TransactionSuccessScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;

  Future<void> _shareReceipt() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    
    try {
      // Small delay to ensure rendering is complete
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Capturing receipt
      final Uint8List? imageBytes = await _screenshotController.capture(
        pixelRatio: 2.0,
      );
      
      if (imageBytes != null) {
        // Captured
        final directory = await getTemporaryDirectory();
        final fileName = 'ZD_Receipt_${widget.transaction.reference}.png';
        final imageFile = File('${directory.path}/$fileName');
        await imageFile.writeAsBytes(imageBytes);
        // Sharing
        await Share.shareXFiles(
          [XFile(imageFile.path)],
          text: 'ZeeData Receipt - ${widget.transaction.serviceType} purchase of ${widget.transaction.amount}',
          subject: 'Transaction Receipt',
        );
      } else {
        throw 'Failed to generate receipt image';
      }
    } catch (e, stack) {
      // Share error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(),
                  
                  Screenshot(
                    controller: _screenshotController,
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Success Animation / Icon
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8F5E9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF4CAF50),
                              size: 60,
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          const Text(
                            'Transaction Successful',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          Text(
                            'Your ${widget.transaction.serviceType.toLowerCase()} purchase was completed successfully.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Summary Box
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: const Color(0xFFF1F5F9)),
                            ),
                            child: Column(
                              children: [
                                _buildSummaryRow('Amount', currencyFormat.format(widget.transaction.amount), isAmount: true),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Divider(color: Color(0xFFE2E8F0)),
                                ),
                                
                                // Token for Electricity or Education
                                if (widget.transaction.serviceType == 'ELECTRICITY' || widget.transaction.serviceType == 'UTILITY' || widget.transaction.serviceType == 'EDUCATION')
                                  (() {
                                    final metadata = widget.transaction.metadata;
                                    final providerResp = metadata?['provider_response'];
                                    
                                    // Extract token/PIN based on service type
                                    String? label = 'TOKEN';
                                    String? token;
                                    String? subText = 'Copy and enter this on your meter';
    
                                    if (widget.transaction.serviceType == 'EDUCATION') {
                                      label = 'EXAMINATION PIN / SERIAL';
                                      subText = 'Keep this PIN safe for your result checking or registration';
                                      
                                      token = metadata?['pin'] ?? metadata?['token'] ?? providerResp?['purchased_code'] ?? providerResp?['Pin'];
                                      
                                      if (token == null) {
                                        final tokens = providerResp?['tokens'];
                                        if (tokens is List && tokens.isNotEmpty) {
                                          token = tokens[0].toString();
                                        }
                                      }
                                      
                                      if (token == null) {
                                        final cards = providerResp?['cards'];
                                        if (cards is List && cards.isNotEmpty) {
                                          final card = cards[0];
                                          token = "${card['Serial']} / ${card['Pin']}";
                                        }
                                      }
                                    } else {
                                      token = metadata?['token'] ?? 
                                              metadata?['purchased_code'] ??
                                              metadata?['mainToken'] ??
                                              providerResp?['mainToken'] ?? 
                                              providerResp?['purchased_code'] ?? 
                                              providerResp?['token'] ?? 
                                              providerResp?['cards']?[0]?['pin'];
                                    }
                                    
                                    if (token != null) {
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 20),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF7ED),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: const Color(0xFFFED7AA)),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              label!,
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFC2410C), letterSpacing: 1.2),
                                            ),
                                            const SizedBox(height: 8),
                                            SelectableText(
                                              token.toString(),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF9A3412), letterSpacing: 1),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              subText!,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 11, color: Color(0xFFC2410C)),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  })(),
    
                                _buildSummaryRow('Service', widget.transaction.serviceType),
                                const SizedBox(height: 12),
                                _buildSummaryRow('Reference', widget.transaction.reference),
                                const SizedBox(height: 12),
                                _buildSummaryRow('Date', dateFormat.format(widget.transaction.createdAt)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Action Buttons
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF011B60),
                          minimumSize: const Size(double.infinity, 64),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _isSharing ? null : _shareReceipt,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isSharing)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF011B60)),
                              )
                            else
                              const Icon(Icons.share_rounded, size: 20, color: Color(0xFF011B60)),
                            const SizedBox(width: 8),
                            Text(
                              _isSharing ? 'Preparing Receipt...' : 'Share Receipt',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF011B60),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isAmount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isAmount ? 20 : 14,
            fontWeight: isAmount ? FontWeight.w900 : FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}
