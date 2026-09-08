import 'dart:async';
import 'package:noticeboard/bloc/list_notices_bloc.dart';
import 'package:noticeboard/bloc/notice_detail_bloc.dart';
import 'package:noticeboard/enum/current_widget_enum.dart';
import 'package:noticeboard/enum/notice_content_enum.dart';
import 'package:noticeboard/routes/routing_constants.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import '../global/global_constants.dart';
import '../models/notice_intro.dart';
import 'package:flutter/material.dart';
import '../bloc/notice_content_bloc.dart';
import '../global/global_functions.dart';
import '../styles/notice_detail_consts.dart';

// ignore: must_be_immutable
class NoticeDetail extends StatefulWidget {
  final NoticeIntro? noticeIntro;
  List<NoticeIntro?>? listOfNotices;
  ListNoticesBloc listNoticesBloc;
  NoticeDetail(
      {required this.noticeIntro,
      required this.listOfNotices,
      required this.listNoticesBloc});

  @override
  _NoticeDetailState createState() => _NoticeDetailState();
}

class _NoticeDetailState extends State<NoticeDetail> {
  final NoticeIntro? noticeIntro;
  // ignore: unused_element
  _NoticeDetailState({this.noticeIntro});
  NoticeContentBloc _noticeContentBloc = NoticeContentBloc();
  PlatformWebViewController _webViewController = PlatformWebViewController(
    const PlatformWebViewControllerCreationParams()
  );
  NoticeDetailBloc _noticeDetailBloc = NoticeDetailBloc();
  bool pdfAlreadyOpened = false;
  bool snackBarShown = false;
  late StreamSubscription _streamSubscription;
  int currentIndex = 0;

  @override
  void initState() {
    _noticeContentBloc.context = context;
    _noticeContentBloc.noticeIntro = widget.noticeIntro;
    _noticeContentBloc.starred = widget.noticeIntro!.starred;
    _noticeContentBloc.eventSink.add(NoticeContentEvents.fetchContent);
    _streamSubscription = _noticeDetailBloc.eventStream.listen((event) {
      if (event == CurrentWidget.noticeDetail) {
        _noticeContentBloc.eventSink.add(NoticeContentEvents.fetchContent);
        _webViewController.reload();
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _noticeContentBloc.disposeStreams();
    // Canceling the stream subscription so it does not leaves a dangling listener to the stream preventing race condition
    _streamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double _width = MediaQuery.of(context).size.width;
    double _height = MediaQuery.of(context).size.height;
    return Scaffold(
        appBar: AppBar(
          elevation: 0.0,
          leadingWidth: 30.0,
          leading: IconButton(
            icon: screenPopIcon(Colors.white),
            onPressed: () {
              if (previousRoute == launchingRoute) {
                navigatorKey.currentState!
                    .pushReplacementNamed(bottomNavigationRoute);
              } else {
                navigatorKey.currentState!.pop();
              }
            },
          ),
          backgroundColor: globalBlueColor,
          centerTitle: false,
          title: Text(
            widget.noticeIntro!.department!,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w700),
          ),
        ),
        body: PopScope(
              canPop: false,
              onPopInvoked: (didPop) async {
                if (didPop) {
                  return;
                }
                if (previousRoute == launchingRoute) {
                  navigatorKey.currentState!
                      .pushReplacementNamed(bottomNavigationRoute);
                } else {
                  navigatorKey.currentState!.pop();
                }
              },
              child: Container(
                width: _width,
                height: _height * 0.88,
                child: Column(
                  children: [
                    buildNoticeIntro(_width),
                    buildNoticeContent(_width),
                  ],
                ),
              ),
            ),
          );
  }

  Expanded buildNoticeContent(double width) {
    return Expanded(
      child: Container(
        color: Colors.white,
        width: width,
        child: Center(
          child: StreamBuilder(
            stream: _noticeContentBloc.contentStream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return buildContent(snapshot);
              } else if (snapshot.hasError) {
                return buildErrorWidget(snapshot);
              }
              return buildLoadingWidget();
            },
          ),
        ),
      ),
    );
  }

  String wrapHtmlHeaders(String originalHtml) {
    return """
      <!DOCTYPE html>
      <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, minimum-scale=1.0, maximum-scale=5.0, user-scalable=yes">
          <style>
            body {
              font-family: sans-serif;
              font-size: 0.75em;
            }
            img { 
              height: auto; 
              max-width: 100%;
            }
          </style>
        </head>
        <body>
          $originalHtml
        </body>
      </html>
    """;
  }

Container buildContent(AsyncSnapshot snapshot) {
    String modifiedHtml = wrapHtmlHeaders(snapshot.data.content);
    final delegate = PlatformNavigationDelegate(
      const PlatformNavigationDelegateCreationParams(),
    );
    delegate.setOnNavigationRequest((navigation) async {
      final url = navigation.url;
      if (url.endsWith(".pdf") && !pdfAlreadyOpened) {
        pdfAlreadyOpened = true;
        if (await canLaunchUrlString(url)) {
          final newUrl =
              "https://docs.google.com/gview?embedded=true&url=$url";
          await launchUrlString(newUrl);
        }
        return NavigationDecision.prevent;
      } else {
        if (await canLaunchUrlString(url)) {
          await launchUrlString(
            url,
            mode: LaunchMode.externalApplication,
          );
          return NavigationDecision.prevent;
        }
      }
      return NavigationDecision.navigate;
    });
    _webViewController
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setPlatformNavigationDelegate(delegate)
      ..enableZoom(true)
      ..loadHtmlString(modifiedHtml);

    return Container(
        child: webviewFromCreationParams(_webViewController));
  }

  Container buildNoticeIntro(double _width) {
    return Container(
      color: globalLightBlueColor,
      width: _width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.noticeIntro!.title!,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                )
              ],
            ),
            sizedBox(5.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.noticeIntro!.dateCreated!),
                Row(
                  children: [
                    StreamBuilder<bool?>(
                      stream: _noticeContentBloc.starStream,
                      initialData: widget.noticeIntro!.starred,
                      builder: (context, snapshot) {
                        return GestureDetector(
                            onTap: () {
                              widget.listNoticesBloc.toggleBookMarkSink
                                  .add(widget.noticeIntro!);
                              _noticeContentBloc.eventSink
                                  .add(NoticeContentEvents.toggleStar);
                            },
                            child: bookMarkIconDecider(snapshot.data!));
                      },
                    ),
                    SizedBox(
                      width: 10.0,
                    ),
                    GestureDetector(
                      onTap: () {
                        _noticeContentBloc.eventSink
                            .add(NoticeContentEvents.shareNotice);
                      },
                      child: shareIcon,
                    )
                  ],
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
