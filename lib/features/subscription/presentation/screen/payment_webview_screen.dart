import 'package:flutter/material.dart';
import 'package:tutur_id_app/core/utils/app_logger.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _tag = 'PAYMENT_WEBVIEW';

class PaymentWebViewScreen extends StatefulWidget {
  final String snapToken;
  final VoidCallback onPaymentSuccess;

  const PaymentWebViewScreen({
    super.key,
    required this.snapToken,
    required this.onPaymentSuccess,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    final snapUrl = 'https://app.sandbox.midtrans.com/snap/v4/redirection/${widget.snapToken}';
    // Untuk production: https://app.midtrans.com/snap/v4/redirection/{snapToken}

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            AppLogger.i('Navigasi: ${request.url}', tag: _tag);

            // Midtrans akan redirect ke URL tertentu setelah pembayaran selesai
            // (finish_redirect_url) - kita deteksi dari URL untuk tau kapan selesai
            if (request.url.contains('transaction_status=settlement') ||
                request.url.contains('status_code=200')) {
              AppLogger.s('Pembayaran berhasil terdeteksi dari redirect URL', tag: _tag);
              widget.onPaymentSuccess();
              Navigator.of(context).pop();
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(snapUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
