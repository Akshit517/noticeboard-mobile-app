import 'dart:async';
import 'package:flutter/material.dart';
import 'package:noticeboard/bloc/notice_detail_bloc.dart';
import 'package:noticeboard/enum/connectivity_status_enum.dart';
import 'package:noticeboard/enum/current_widget_enum.dart';
import 'package:noticeboard/global/global_constants.dart';

class ConnectivityStatusBloc {
  late CurrentWidget currentWidget;
  final _eventController = StreamController<ConnectivityStatus>.broadcast();
  StreamSink<ConnectivityStatus> get eventSink => _eventController.sink;
  Stream<ConnectivityStatus> get _eventStream => _eventController.stream;
  ConnectivityStatus previousResult = ConnectivityStatus.connected;

  static final ConnectivityStatusBloc _connectivityStatusBloc =
      ConnectivityStatusBloc._();

  final networkSnackBar =
      const SnackBar(content: Text("Please check your internet connection!"));
  final backOnlineSnackbar = const SnackBar(content: Text("Back online!"));

  factory ConnectivityStatusBloc() => _connectivityStatusBloc;
  final NoticeDetailBloc _noticeDetailBloc = NoticeDetailBloc();

  ConnectivityStatusBloc._() {
    _eventStream.listen((connectivityEvent) {
      if (connectivityEvent == ConnectivityStatus.notConnected &&
          previousResult == ConnectivityStatus.connected) {
        snackKey.currentState!.showSnackBar(networkSnackBar);
      } else if (connectivityEvent == ConnectivityStatus.connected &&
          previousResult == ConnectivityStatus.notConnected) {
        snackKey.currentState!.showSnackBar(backOnlineSnackbar);
        if (currentWidget == CurrentWidget.noticeDetail) {
          // Add an event in the sink so that notice detail webview can be refetched
          _noticeDetailBloc.eventSink.add(CurrentWidget.noticeDetail);
        } else {
          // User is on list of notices , refetch them
          _noticeDetailBloc.eventSink.add(CurrentWidget.listNotices);
        }
      }
      previousResult = connectivityEvent;
    });
  }

  void disposeStream() {
    _eventController.close();
  }
}
