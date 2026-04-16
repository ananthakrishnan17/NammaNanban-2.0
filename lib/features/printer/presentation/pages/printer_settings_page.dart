import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../services/printer_service.dart';

class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isPrinting = false;
  String _statusMsg = '';

  @override
  void initState() {
    super.initState();
    _scanDevices();
  }

  Future<void> _scanDevices() async {
    setState(() { _isScanning = true; _statusMsg = 'Scanning for devices...'; });
    final devices = await PrinterService.instance.scanDevices();
    setState(() {
      _devices = devices;
      _isScanning = false;
      _statusMsg = devices.isEmpty ? 'No paired printers found. Pair your printer in Bluetooth settings first.' : '';
    });
  }

Future<void> _connect(BluetoothDevice device) async {
  // 🔥 ADD THIS BLOCK
  await [
    Permission.bluetooth,
    Permission.bluetoothConnect,
    Permission.bluetoothScan,
    Permission.location
  ].request();

  setState(() { 
    _isConnecting = true; 
    _statusMsg = 'Connecting to ${device.name}...'; 
  });

  final success = await PrinterService.instance.connectDevice(device);

  setState(() {
    _isConnecting = false;
    _selectedDevice = success ? device : null;
    _statusMsg = success 
        ? 'Connected to ${device.name}!' 
        : 'Failed to connect. Try again.';
  });
}
  Future<void> _testPrint() async {
    setState(() { _isPrinting = true; _statusMsg = 'Printing test page...'; });
    final success = await PrinterService.instance.testPrint();
    setState(() {
      _isPrinting = false;
      _statusMsg = success ? 'Test print sent!' : 'Print failed. Check connection.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Settings'),
        actions: [
          IconButton(
            onPressed: _isScanning ? null : _scanDevices,
            icon: _isScanning
                ? SizedBox(width: 20.w, height: 20.h, child: const CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status
            if (_statusMsg.isNotEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                margin: EdgeInsets.only(bottom: 16.h),
                decoration: BoxDecoration(
                  color: PrinterService.instance.isConnected
                      ? AppTheme.accent.withOpacity(0.1)
                      : AppTheme.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: PrinterService.instance.isConnected
                        ? AppTheme.accent.withOpacity(0.3)
                        : AppTheme.warning.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      PrinterService.instance.isConnected ? Icons.check_circle : Icons.info,
                      color: PrinterService.instance.isConnected ? AppTheme.accent : AppTheme.warning,
                      size: 18.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(child: Text(_statusMsg, style: AppTheme.body)),
                  ],
                ),
              ),

            // Connection Status Card
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48.w,
                    height: 48.w,
                    decoration: BoxDecoration(
                      color: PrinterService.instance.isConnected
                          ? AppTheme.accent.withOpacity(0.1)
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      Icons.print,
                      color: PrinterService.instance.isConnected
                          ? AppTheme.accent
                          : AppTheme.textSecondary,
                      size: 24.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          PrinterService.instance.isConnected
                              ? (_selectedDevice?.name ?? 'Printer')
                              : 'No Printer Connected',
                          style: AppTheme.heading3,
                        ),
                        Text(
                          PrinterService.instance.isConnected ? 'Connected' : 'Tap a device to connect',
                          style: AppTheme.caption.copyWith(
                            color: PrinterService.instance.isConnected
                                ? AppTheme.accent
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (PrinterService.instance.isConnected)
                    TextButton(
                      onPressed: () async {
                        await PrinterService.instance.disconnect();
                        setState(() {
                          _selectedDevice = null;
                          _statusMsg = 'Disconnected';
                        });
                      },
                      child: const Text('Disconnect'),
                    ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            Text('Paired Devices', style: AppTheme.heading3),
            SizedBox(height: 8.h),
            Text('Make sure your printer is turned on and paired with this phone.', style: AppTheme.caption),
            SizedBox(height: 12.h),

            if (_isScanning)
              const Center(child: CircularProgressIndicator())
            else if (_devices.isEmpty)
              Center(
                child: Column(
                  children: [
                    SizedBox(height: 20.h),
                    Text('📡', style: TextStyle(fontSize: 40.sp)),
                    SizedBox(height: 8.h),
                    Text('No Bluetooth printers found', style: AppTheme.body),
                    SizedBox(height: 4.h),
                    Text('Go to phone Settings > Bluetooth to pair your printer first', style: AppTheme.caption, textAlign: TextAlign.center),
                    SizedBox(height: 16.h),
                    ElevatedButton.icon(
                      onPressed: _scanDevices,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Scan Again'),
                    ),
                  ],
                ),
              )
            else
              ...(_devices.map((device) => _buildDeviceTile(device))),

            SizedBox(height: 24.h),

            // Test Print
            if (PrinterService.instance.isConnected) ...[
              Text('Printer Test', style: AppTheme.heading3),
              SizedBox(height: 12.h),
              OutlinedButton.icon(
                onPressed: _isPrinting ? null : _testPrint,
                icon: _isPrinting
                    ? SizedBox(width: 16.w, height: 16.h, child: const CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.print),
                label: Text(_isPrinting ? 'Printing...' : 'Print Test Page'),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(double.infinity, 48.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
              ),
            ],

            SizedBox(height: 20.h),

            // Paper size note
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Supported Printers', style: AppTheme.heading3),
                  SizedBox(height: 8.h),
                  Text('• 58mm thermal printers (most common)\n• 80mm thermal printers\n• Any ESC/POS compatible Bluetooth printer', style: AppTheme.body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTile(BluetoothDevice device) {
    final isSelected = _selectedDevice?.address == device.address;
    final isConnected = PrinterService.instance.isConnected && isSelected;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: isConnected ? AppTheme.accent.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isConnected ? AppTheme.accent : AppTheme.divider,
        ),
      ),
      child: ListTile(
        leading: Icon(
          Icons.bluetooth,
          color: isConnected ? AppTheme.accent : AppTheme.textSecondary,
        ),
        title: Text(device.name ?? 'Unknown Device', style: AppTheme.body),
        subtitle: Text(device.address ?? '', style: AppTheme.caption),
        trailing: _isConnecting && isSelected
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : isConnected
            ? Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Text('Connected', style: AppTheme.caption.copyWith(color: AppTheme.accent)),
        )
            : TextButton(
          onPressed: () => _connect(device),
          child: const Text('Connect'),
        ),
        onTap: isConnected ? null : () => _connect(device),
      ),
    );
  }
}
