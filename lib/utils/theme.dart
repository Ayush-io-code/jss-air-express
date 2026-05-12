// lib/utils/theme.dart
import 'package:flutter/material.dart';

const kNavy = Color(0xFF1A3A5C);
const kNavyLight = Color(0xFFEEF2F8);
const kBg = Color(0xFFF0F2F5);
const kGreen = Color(0xFF1A7A3A);
const kRed = Color(0xFFCC3333);
const kPurple = Color(0xFF7C3AED);
const kCardBorder = Color(0xFFE0E4EC);
const kInputBorder = Color(0xFFDDE1EB);
const kInputBg = Color(0xFFF8F9FC);
const kLabel = Color(0xFF666666);
const kMeta = Color(0xFF888888);

const kCompanyName = 'JSS AIR EXPRESS';
const kCompanyAddress =
    'Franchise- JSS Air Express, Shop no.-8, Opp to Powerlink Complex, Thanisandra main road Bangalore-560077';
const kCompanyPhone = '7975609737, 8884261970, 8431988489';
const kCompanyEmail = 'jssairexpress@gmail.com';
const kCompanyGST = '29CTCPD9755Q1ZS';
const kBankName = 'JSS AIR EXPRESS';
const kBankAcc = '1048111010000065';
const kBankIFSC = 'KSCB0001048';
const kBankBranch = 'THANISANDRA';

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kNavy,
      primary: kNavy,
      surface: kBg,
    ),
    scaffoldBackgroundColor: kBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: kNavy,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kInputBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kInputBorder, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kInputBorder, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kNavy, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      labelStyle: const TextStyle(fontSize: 12, color: kLabel),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: kCardBorder, width: 1.5),
      ),
      margin: EdgeInsets.zero,
    ),
    fontFamily: 'Roboto',
  );
}
