# Keep kotlinx-serialization's generated serializers (they're referenced reflectively).
-keepclassmembers class ir.parsavisions.xirouter.** {
    *** Companion;
}
-keepclasseswithmembers class ir.parsavisions.xirouter.** {
    kotlinx.serialization.KSerializer serializer(...);
}
