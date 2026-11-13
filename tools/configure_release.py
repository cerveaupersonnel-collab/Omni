#!/usr/bin/env python3
"""Configures android/app for release: SDK levels, R8 minify + resource shrinking,
upload-key signing (key.properties), network security, no cloud backup."""
import os
import re
import shutil
import sys

TARGET = os.environ.get("ANDROID_TARGET_SDK", "36")
GROOVY = "android/app/build.gradle"
KTS = "android/app/build.gradle.kts"
kts = os.path.exists(KTS)
path = KTS if kts else GROOVY
if not os.path.exists(path):
    sys.exit("android/app/build.gradle(.kts) not found. Run flutter create first.")
s = open(path, encoding="utf-8").read()

if kts:
    s = re.sub(r"compileSdk\s*=\s*flutter\.compileSdkVersion", f"compileSdk = {TARGET}", s)
    s = re.sub(r"targetSdk\s*=\s*flutter\.targetSdkVersion", f"targetSdk = {TARGET}", s)
    s = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 23", s)
else:
    s = re.sub(r"compileSdk(?:Version)?\s+flutter\.compileSdkVersion", f"compileSdk {TARGET}", s)
    s = re.sub(r"targetSdkVersion\s+flutter\.targetSdkVersion", f"targetSdkVersion {TARGET}", s)
    s = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 23", s)

if "proguard-rules.pro" not in s:
    if kts:
        rel = re.compile(r"(buildTypes\s*\{\s*(?:getByName\(\"release\"\)|release)\s*\{)")
        add = ('\n            isMinifyEnabled = true\n            isShrinkResources = true\n'
               '            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")')
    else:
        rel = re.compile(r"(buildTypes\s*\{\s*release\s*\{)")
        add = ("\n            minifyEnabled true\n            shrinkResources true\n"
               "            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'")
    if not rel.search(s):
        sys.exit("Could not find the release build type in " + path)
    s = rel.sub(lambda m: m.group(1) + add, s, count=1)

# Only add signing config if we're doing a release build (check environment)
if os.environ.get("ADD_SIGNING_CONFIG", "false") == "true" and "keystoreProperties" not in s:
    if kts:
        defs = ('val keystoreProperties = java.util.Properties()\n'
                'val keystorePropertiesFile = rootProject.file("key.properties")\n'
                'if (keystorePropertiesFile.exists()) {\n'
                '    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))\n}\n\n')
        signing = ('    signingConfigs {\n        create("release") {\n'
                   '            if (keystorePropertiesFile.exists()) {\n'
                   '                keyAlias = keystoreProperties["keyAlias"] as String\n'
                   '                keyPassword = keystoreProperties["keyPassword"] as String\n'
                   '                storeFile = file(keystoreProperties["storeFile"] as String)\n'
                   '                storePassword = keystoreProperties["storePassword"] as String\n'
                   '            }\n        }\n    }\n\n')
        s = re.sub(r"signingConfig\s*=\s*signingConfigs\.getByName\(\"debug\"\)",
                   'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")', s)
    else:
        defs = ("def keystoreProperties = new Properties()\n"
                "def keystorePropertiesFile = rootProject.file('key.properties')\n"
                "if (keystorePropertiesFile.exists()) {\n"
                "    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n}\n\n")
        signing = ("    signingConfigs {\n        release {\n"
                   "            if (keystorePropertiesFile.exists()) {\n"
                   "                keyAlias keystoreProperties['keyAlias']\n"
                   "                keyPassword keystoreProperties['keyPassword']\n"
                   "                storeFile file(keystoreProperties['storeFile'])\n"
                   "                storePassword keystoreProperties['storePassword']\n"
                   "            }\n        }\n    }\n\n")
        s = re.sub(r"signingConfig\s+signingConfigs\.debug",
                   "signingConfig keystorePropertiesFile.exists() ? signingConfigs.release : signingConfigs.debug", s)
    s = s.replace("\nandroid {", "\n" + defs + "android {", 1)
    s = re.sub(r"(\n\s*)buildTypes\s*\{", lambda m: "\n" + signing + m.group(1).lstrip("\n") + "buildTypes {", s, count=1)
open(path, "w", encoding="utf-8").write(s)


# google-services plugin (needed by Google Sign-In's default_web_client_id and google-services.json)
def add_google_services():
    for settings in ("android/settings.gradle.kts", "android/settings.gradle"):
        if not os.path.exists(settings):
            continue
        t = open(settings, encoding="utf-8").read()
        if "com.google.gms.google-services" in t:
            return
        if settings.endswith(".kts"):
            pat = re.compile(r'(\n(\s*)id\("com\.android\.application"\)[^\n]*apply false)')
            line = 'id("com.google.gms.google-services") version "4.4.2" apply false'
        else:
            pat = re.compile(r'(\n(\s*)id "com\.android\.application"[^\n]*apply false)')
            line = 'id "com.google.gms.google-services" version "4.4.2" apply false'
        if pat.search(t):
            t = pat.sub(lambda m: m.group(1) + "\n" + m.group(2) + line, t, count=1)
            open(settings, "w", encoding="utf-8").write(t)
            app = open(path, encoding="utf-8").read()
            plug = 'id("com.google.gms.google-services")' if kts else 'id "com.google.gms.google-services"'
            app = re.sub(r'(\n(\s*)id\(?\s*"com\.android\.application"\s*\)?)', lambda m: m.group(1) + "\n" + m.group(2) + plug, app, count=1)
            open(path, "w", encoding="utf-8").write(app)
        return

add_google_services()

# proguard + network security config (always add for both debug and release)
shutil.copy("android_patch/proguard-rules.pro", "android/app/proguard-rules.pro")
os.makedirs("android/app/src/main/res/xml", exist_ok=True)
shutil.copy("android_patch/res_xml/network_security_config.xml", "android/app/src/main/res/xml/network_security_config.xml")

# manifest: app label, no backup, network security config
mp = "android/app/src/main/AndroidManifest.xml"
m = open(mp, encoding="utf-8").read()
def add_attr(text, attr, value):
    if attr in text:
        return text
    return re.sub(r"<application", f'<application\n        {attr}="{value}"', text, count=1)
m = add_attr(m, "android:allowBackup", "false")
m = add_attr(m, "android:networkSecurityConfig", "@xml/network_security_config")
m = re.sub(r'android:label="omni"', 'android:label="OMNI"', m)
open(mp, "w", encoding="utf-8").write(m)

if os.environ.get("ADD_SIGNING_CONFIG", "false") == "true":
    print(f"Release configuration applied (targetSdk/compileSdk {TARGET}, R8 + shrinkResources on, signing config added).")
else:
    print(f"Release configuration applied (targetSdk/compileSdk {TARGET}, R8 + shrinkResources on, debug signing).")
