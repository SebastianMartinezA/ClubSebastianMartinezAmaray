import 'package:flutter/material.dart';

import '../models/api_error.dart';
import 'empty_view.dart';
import 'error_view.dart';
import 'loading_view.dart';

/// Loads a future and renders the four states every screen needs:
/// loading, error (with retry), empty and data.
///
/// Usage:
/// ```dart
/// final GlobalKey<FutureViewState<List<Venue>>> key = GlobalKey();
/// FutureView<List<Venue>>(
///   key: key,
///   load: () => catalog.venues(),
///   isEmpty: (List<Venue> venues) => venues.isEmpty,
///   emptyMessage: 'Todavía no hay sedes cargadas.',
///   builder: (context, venues, reload) => ListView(...),
/// )
/// ```
/// The [FutureViewState] type is public so a screen can keep a `GlobalKey` and
/// call `reload()` after a booking or a cancellation.
class FutureView<T> extends StatefulWidget {
  const FutureView({
    super.key,
    required this.load,
    required this.builder,
    this.isEmpty,
    this.emptyMessage = 'No hay nada para mostrar.',
    this.emptyIcon = Icons.inbox_outlined,
    this.loadingMessage,
  });

  /// Request to run on start and on every retry/refresh.
  final Future<T> Function() load;

  /// Builder of the success state. `reload` re-runs [load].
  final Widget Function(BuildContext context, T data, Future<void> Function() reload)
      builder;

  /// Tells whether the loaded data has to be shown as "empty".
  final bool Function(T data)? isEmpty;

  final String emptyMessage;
  final IconData emptyIcon;
  final String? loadingMessage;

  @override
  FutureViewState<T> createState() => FutureViewState<T>();
}

class FutureViewState<T> extends State<FutureView<T>> {
  T? _data;
  ApiException? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// Runs [FutureView.load] again, keeping the previous data visible while the
  /// new one arrives (used by pull to refresh).
  Future<void> reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final T data = await widget.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = ApiException.unexpected();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ApiException? error = _error;
    if (error != null) {
      return ErrorView(
        message: error.userMessage,
        onRetry: reload,
        isConnectivityProblem: error.isConnectivityProblem,
      );
    }

    final T? data = _data;
    if (data == null) {
      return LoadingView(message: widget.loadingMessage);
    }

    final bool empty = widget.isEmpty?.call(data) ?? false;
    if (empty && !_loading) {
      // The empty state is refreshable too: without this the only way out was leaving the
      // screen and coming back.
      return RefreshIndicator(
        onRefresh: reload,
        child: LayoutBuilder(
          builder: (BuildContext _, BoxConstraints constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: EmptyView(
                  message: widget.emptyMessage,
                  icon: widget.emptyIcon,
                ),
              ),
            );
          },
        ),
      );
    }

    return Stack(
      children: <Widget>[
        widget.builder(context, data, reload),
        if (_loading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }
}
