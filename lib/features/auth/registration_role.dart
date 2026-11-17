import 'package:flutter/material.dart';

/// Account-type choice on the signup UI. Not an authorization claim.
///
/// Server-side roles and permissions must be verified by the future backend;
/// choosing a label in the form grants no financial or supplier privileges.
enum RegistrationRole { customer, merchant, supplier }

/// Optional profile data. It never grants an app role or financial consent.
enum ProfileGender { male, female, unspecified }

extension ProfileGenderUi on ProfileGender {
  String get title => switch (this) {
        ProfileGender.male => 'ذكر',
        ProfileGender.female => 'أنثى',
        ProfileGender.unspecified => 'أفضل عدم التحديد',
      };
}

extension RegistrationRoleUi on RegistrationRole {
  String get title => switch (this) {
        RegistrationRole.customer => 'عميل',
        RegistrationRole.merchant => 'تاجر',
        RegistrationRole.supplier => 'مورد',
      };

  String get subtitle => switch (this) {
        RegistrationRole.customer => 'أتابع حساباتي وأراجع طلبات التجار',
        RegistrationRole.merchant => 'أدير مبيعاتي وعملائي وحساباتي',
        RegistrationRole.supplier => 'أتواصل مع التجار وأنظم التوريدات',
      };

  IconData get icon => switch (this) {
        RegistrationRole.customer => Icons.person_outline_rounded,
        RegistrationRole.merchant => Icons.storefront_outlined,
        RegistrationRole.supplier => Icons.inventory_2_outlined,
      };
}
