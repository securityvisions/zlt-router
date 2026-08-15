package ir.parsavisions.xirouter.ui

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.automirrored.filled.ReceiptLong
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Speed
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import zed.rainxch.rikkaui.components.ui.icon.Icon
import zed.rainxch.rikkaui.components.ui.text.Text
import zed.rainxch.rikkaui.components.ui.text.TextVariant
import zed.rainxch.rikkaui.foundation.RikkaTheme

/**
 * Floating-island bottom navigation, rebuilt on RikkaUi primitives — the signature
 * 28dp-radius bar with an animated indicator dot, icons instead of emoji.
 */
@Composable
fun XirouterTabBar(
    selected: XRoute,
    routes: List<XRoute>,
    onSelect: (XRoute) -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = RikkaTheme.colors
    Box(
        modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 8.dp),
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .shadow(12.dp, RoundedCornerShape(28.dp))
                .clip(RoundedCornerShape(28.dp))
                .background(colors.surface)
                .height(64.dp)
                .padding(horizontal = 4.dp)
                .selectableGroup(),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            routes.forEach { route ->
                val isSelected = route == selected
                val label = tabLabel(route)
                val dot by animateDpAsState(targetValue = if (isSelected) 5.dp else 0.dp, label = "dot")
                Column(
                    Modifier
                        .weight(1f)
                        .height(56.dp)
                        .clip(RikkaTheme.shapes.full)
                        .selectable(
                            selected = isSelected,
                            role = Role.Tab,
                            onClick = { onSelect(route) },
                        ).semantics {
                            contentDescription = label
                            this.selected = isSelected
                        },
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(
                            imageVector = iconOf(route),
                            contentDescription = null,
                            tint = if (isSelected) colors.onBackground else colors.onMuted,
                        )
                        if (isSelected) {
                            Box(
                                Modifier
                                    .align(Alignment.BottomCenter)
                                    .size(dot)
                                    .clip(RikkaTheme.shapes.full)
                                    .background(StatusColors.up),
                            )
                        }
                    }
                    Text(
                        label,
                        variant = TextVariant.Small,
                        color = if (isSelected) colors.onBackground else colors.onMuted,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
    }
}

private fun iconOf(route: XRoute): ImageVector = when (route) {
    XRoute.Home -> Icons.Filled.Home
    XRoute.Ledger -> Icons.AutoMirrored.Filled.ReceiptLong
    XRoute.Data -> Icons.Filled.Speed
    XRoute.Live -> Icons.Filled.Bolt
    XRoute.Settings -> Icons.Filled.Settings
    else -> Icons.Filled.Home
}

fun tabLabel(route: XRoute): String = when (route) {
    XRoute.Home -> "خانه"
    XRoute.Ledger -> "حساب‌ها"
    XRoute.Data -> "بسته"
    XRoute.Live -> "زنده"
    XRoute.Settings -> "تنظیمات"
    else -> ""
}