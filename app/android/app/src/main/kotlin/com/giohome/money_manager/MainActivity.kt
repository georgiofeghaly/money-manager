package com.giohome.money_manager

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth's Android biometric prompt needs a FragmentActivity to attach
// to; the default FlutterActivity (a plain Activity) can't host it.
class MainActivity : FlutterFragmentActivity() {
    // Blocks screenshots and hides financial data from the recent-apps
    // preview thumbnail, since this app holds sensitive account/transaction data.
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }
}
