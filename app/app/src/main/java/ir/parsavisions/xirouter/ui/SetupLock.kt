package ir.parsavisions.xirouter.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ir.parsavisions.xirouter.XirouterViewModel
import zed.rainxch.rikkaui.components.ui.button.Button
import zed.rainxch.rikkaui.components.ui.icon.Icon
import zed.rainxch.rikkaui.components.ui.input.Input
import zed.rainxch.rikkaui.components.ui.text.Text
import zed.rainxch.rikkaui.components.ui.text.TextVariant
import zed.rainxch.rikkaui.foundation.RikkaTheme

/** First-run gate: router URL + token. */
@Composable
fun SetupScreen(vm: XirouterViewModel, onConnected: () -> Unit) {
    var url by rememberSaveable { mutableStateOf(vm.store.baseUrl) }
    var token by rememberSaveable { mutableStateOf(vm.store.token) }
    var busy by remember { mutableStateOf(false) }
    var refreshStarted by remember { mutableStateOf(false) }
    LaunchedEffect(vm.loading.value, vm.lastUpdate.value, vm.error.value, refreshStarted) {
        if (!refreshStarted || vm.loading.value) return@LaunchedEffect
        busy = false
        refreshStarted = false
        if (vm.lastUpdate.value > 0L && vm.error.value == null) onConnected()
    }

    Column(
        Modifier
            .fillMaxSize()
            .imePadding()
            .verticalScroll(rememberScrollState())
            .padding(vertical = 24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        AdaptiveContent {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(Icons.Filled.Wifi, contentDescription = null, tint = RikkaTheme.colors.primary)
                Text("اتصال به روتر", variant = TextVariant.H2, modifier = Modifier.padding(vertical = 8.dp))
                Text(
                    "آدرس و توکن روتر را وارد کنید؛ توکن در /etc/routerapp.conf روی روتر است.",
                    variant = TextVariant.Muted,
                    modifier = Modifier.padding(bottom = 20.dp),
                )
                Input(value = url, onValueChange = { url = it }, placeholder = "http://192.168.1.1/cgi-bin/routerapi.sh", label = "آدرس روتر")
                Input(
                    value = token, onValueChange = { token = it }, label = "توکن دسترسی",
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                    modifier = Modifier.padding(top = 8.dp),
                )
                Spacer(Modifier.height(20.dp))
                Button(
                    onClick = {
                        busy = true
                        vm.store.baseUrl = url.trim()
                        vm.store.token = token.trim()
                        refreshStarted = true
                        vm.refreshAll()
                    },
                    enabled = url.isNotBlank() && token.isNotBlank() && !busy && !vm.loading.value,
                    modifier = Modifier.fillMaxWidth(),
                    loading = busy,
                ) {
                    Text(if (busy) "در حال اتصال…" else "اتصال")
                }
                vm.error.value?.let { Text(it, color = RikkaTheme.colors.destructive, modifier = Modifier.padding(top = 12.dp)) }
            }
        }
    }
}

/** PIN gate shown while the app lock is on. */
@Composable
fun LockScreen(pin: String, onUnlock: () -> Unit) {
    var input by rememberSaveable { mutableStateOf("") }
    Column(
        Modifier.fillMaxSize().padding(28.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(Icons.Filled.Lock, contentDescription = null, tint = RikkaTheme.colors.primary)
        Text("برنامه قفل است", variant = TextVariant.H3, modifier = Modifier.padding(vertical = 12.dp))
        Input(
            value = input, onValueChange = { if (it.length <= 8) input = it },
            placeholder = "پین", label = "پین",
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
            visualTransformation = PasswordVisualTransformation(),
        )
        Button(onClick = { if (input == pin) onUnlock() }, modifier = Modifier.padding(top = 16.dp)) {
            Text("ورود")
        }
        if (input.isNotEmpty() && input != pin) {
            Text("پین اشتباه است", color = RikkaTheme.colors.destructive, modifier = Modifier.padding(top = 8.dp))
        }
    }
}