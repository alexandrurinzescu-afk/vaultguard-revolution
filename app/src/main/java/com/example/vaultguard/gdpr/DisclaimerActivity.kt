package com.example.vaultguard.gdpr

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.vaultguard.MainActivity
import com.example.vaultguard.R

/**
 * 2.5.1 Legal disclaimer gate.
 *
 * "First-to-claim" integration: user cannot reach the app until they accept this disclaimer once.
 */
class DisclaimerActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Fast path: if accepted, never show this screen again.
        if (GdprPrefs.isLegalDisclaimerAccepted(this)) {
            startActivity(Intent(this, MainActivity::class.java))
            finish()
            return
        }

        setContent {
            Surface(color = MaterialTheme.colorScheme.background) {
                DisclaimerScreen(
                    onAccept = {
                        GdprPrefs.setLegalDisclaimerAccepted(this, true)
                        startActivity(Intent(this, MainActivity::class.java))
                        finish()
                    },
                    onDecline = {
                        // Hard stop: user chose not to accept the legal disclaimer.
                        finishAffinity()
                    }
                )
            }
        }
    }
}

@Composable
private fun DisclaimerScreen(
    onAccept: () -> Unit,
    onDecline: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        verticalArrangement = Arrangement.Top,
    ) {
        Text(
            text = stringResource(id = R.string.legal_disclaimer_title),
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.SemiBold,
        )
        Spacer(modifier = Modifier.height(12.dp))

        Text(
            modifier = Modifier
                .weight(1f, fill = true)
                .verticalScroll(rememberScrollState()),
            text = stringResource(id = R.string.legal_disclaimer_body),
            style = MaterialTheme.typography.bodyMedium,
        )

        Spacer(modifier = Modifier.height(16.dp))

        Button(
            onClick = onAccept,
            modifier = Modifier.fillMaxWidth().height(48.dp),
            contentPadding = PaddingValues(horizontal = 16.dp),
        ) {
            Text(text = stringResource(id = R.string.legal_disclaimer_accept))
        }
        Spacer(modifier = Modifier.height(10.dp))
        OutlinedButton(
            onClick = onDecline,
            modifier = Modifier.fillMaxWidth().height(48.dp),
            contentPadding = PaddingValues(horizontal = 16.dp),
        ) {
            Text(text = stringResource(id = R.string.legal_disclaimer_decline))
        }
    }
}

