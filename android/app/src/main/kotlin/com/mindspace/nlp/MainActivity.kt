package com.mindspace.nlp

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Enable modern edge-to-edge display before calling super
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}
