import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yack/data/repositories/isar_adapter.dart';
import 'package:yack/logic/services/contract/contract_sync_service.dart';
import 'package:yack/logic/services/notification/contract_notification_handler.dart';

class NotificationRouterService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final ContractSyncService _contractSyncService = ContractSyncService();
  static ContractNotificationEvent? _pendingTap;

  static Future<void> _handleNotificationNavigation(
    ContractNotificationEvent event,
  ) async {
    switch (event.type) {
      case ContractNotificationType.contractJoin:
      case ContractNotificationType.contractSign:
        // A temporary invitation cannot be reconstructed safely from an ID
        // alone. Once the backend supplies the final contract ID, use the same
        // local-resolution path as every other contract notification.
        if (event.contractId != null) {
          await navigateToContract(event.contractId!);
        }
      case ContractNotificationType.contractAccept:
      case ContractNotificationType.contractDispute:
      case ContractNotificationType.contractMessage:
      case ContractNotificationType.contractMedia:
        if (event.contractId != null) {
          await navigateToContract(event.contractId!);
        }
    }
  }

  static Future<void> _navigateToRoute(
    String routeName, {
    Map<String, dynamic>? arguments,
  }) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    await navigator.pushNamed(routeName, arguments: arguments);
  }

  /// Resolves the backend Mongo ID to the local Isar ID expected by the
  /// agreement screen. A one-shot sync covers notifications that arrive before
  /// the local contract list has caught up.
  static Future<bool> navigateToContract(String externalContractId) async {
    var contract = await getContractByExternalId(externalContractId);
    if (contract == null) {
      await _contractSyncService.syncSingleContract(externalContractId);
      contract = await getContractByExternalId(externalContractId);
    }
    final navigator = navigatorKey.currentState;
    if (navigator == null || contract == null) return false;
    await navigator.pushNamed('/contract/view', arguments: contract.id);
    return true;
  }

  static Future<void> handleNotificationTap(Map<String, dynamic> data) async {
    if (data.isEmpty) return;
    final event = ContractNotificationEvent.fromFcmData(data);
    if (navigatorKey.currentState == null) {
      _pendingTap = event;
      return;
    }
    await _handleNotificationNavigation(event);
  }

  static Future<void> flushPendingNavigation() async {
    final event = _pendingTap;
    if (event == null || navigatorKey.currentState == null) return;
    _pendingTap = null;
    await _handleNotificationNavigation(event);
  }

  static void navigateTo(String routeName, {Map<String, dynamic>? arguments}) {
    unawaited(_navigateToRoute(routeName, arguments: arguments));
  }
}
