import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Reusable barcode scanner bottom sheet.
///
/// Shows a live camera viewfinder and pops with the scanned barcode string
/// once a code is detected.  Used by both the billing screen and the purchase
/// product-picker so the logic stays in one place.
///
/// Usage:
/// ```dart
/// final barcode = await showModalBottomSheet<String>(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (_) => const BarcodeScannerSheet(),
/// );
/// if (barcode != null && barcode.isNotEmpty) { /* use barcode */ }
/// ```
class BarcodeScannerSheet extends StatefulWidget {
  const BarcodeScannerSheet({super.key});

  @override
  State<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<BarcodeScannerSheet> {
  late final MobileScannerController _controller;

  // Guard flag — prevents the sheet from popping twice if multiple barcodes
  // are decoded in the same frame (MobileScanner can fire onDetect quickly).
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320.h,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(12.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Scan Barcode',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                if (_hasScanned) return;
                final barcode = capture.barcodes.firstOrNull?.rawValue;
                if (barcode != null && barcode.isNotEmpty) {
                  _hasScanned = true;
                  // Pop and return the raw barcode value to the caller.
                  Navigator.pop(context, barcode);
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Point camera at a barcode',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
