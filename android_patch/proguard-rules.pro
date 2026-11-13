# OMNI release rules (R8). Most libraries ship their own consumer rules.

# PdfBox (Android port) loads some filters/fonts reflectively and references optional classes.
-keep class com.tom_roush.pdfbox.** { *; }
-dontwarn com.tom_roush.pdfbox.**
-dontwarn com.gemalto.jp2.**
-dontwarn org.bouncycastle.**
-dontwarn javax.annotation.**
-dontwarn java.awt.**
-dontwarn javax.imageio.**

# Keep line numbers for readable crash reports in Play Console (upload mapping.txt automatically via AAB).
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
