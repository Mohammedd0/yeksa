// هەڵبژاردنی شوێنی ورد لەسەر نەخشە (TK.pickLocation): دەرزی لە ناوەڕاستدا، نەخشەکە دەجووڵێنیت، یان «شوێنی ئێستام»
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../core/cloud.dart';
import '../core/live.dart';
import '../ui/theme.dart';
import '../ui/trip_map.dart';
import '../ui/widgets.dart';
import '../ui/yk_icon.dart';

/// شوێنی ئێستای مۆبایل. هەڵە بە کوردی دەگەڕێنێتەوە
Future<(Geo?, String?)> currentLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return (null, 'شوێن (GPS) لە مۆبایلەکەت کوژاوەتەوە');
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
      return (null, 'ڕێگەت نەدا ئەپەکە شوێنەکەت بزانێت. لە ڕێکخستنەکانی مۆبایلەوە ڕێگە بدە');
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
    );
    return ((lat: pos.latitude, lng: pos.longitude), null);
  } catch (_) {
    return (null, 'نەتوانرا شوێنەکەت بدۆزرێتەوە، دووبارە هەوڵ بدەرەوە');
  }
}

/// پەڕەی هەڵبژاردنی شوێن. Geo دەگەڕێنێتەوە یان null
Future<Geo?> pickLocation(BuildContext context, {required String title, Geo? center, bool useHere = false}) {
  return Navigator.of(context).push<Geo>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => LocationPicker(title: title, center: center, useHere: useHere),
  ));
}

class LocationPicker extends StatefulWidget {
  const LocationPicker({super.key, required this.title, this.center, this.useHere = false});
  final String title;
  final Geo? center;
  final bool useHere;
  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  GoogleMapController? _ctrl;
  late Geo _pos;
  bool _locating = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _pos = widget.center ?? context.read<Cloud>().cityCenter;
    if (widget.useHere) WidgetsBinding.instance.addPostFrameCallback((_) => _here());
  }

  Future<void> _here() async {
    setState(() {
      _locating = true;
      _err = null;
    });
    final (g, err) = await currentLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _err = err;
    });
    if (g != null) {
      _pos = g;
      _ctrl?.animateCamera(CameraUpdate.newLatLngZoom(ll(g), 17));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: ll(_pos), zoom: widget.center != null ? 16 : 13),
            style: t.dark ? kMapStyleDark : kMapStyleLight,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            onMapCreated: (c) => _ctrl = c,
            onCameraMove: (p) => _pos = (lat: p.target.latitude, lng: p.target.longitude),
          ),
        ),
        // دەرزی لە ناوەڕاستی نەخشەکە (خاڵی خوارەوەی دەرزییەکە شوێنەکەیە)
        IgnorePointer(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 44),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3))],
                  ),
                  alignment: Alignment.center,
                  child: const YkIcon('pin', size: 22, color: kAmber, stroke: 2.4),
                ),
                Container(width: 3, height: 14, color: const Color(0xFF1C1C1E)),
                Container(width: 8, height: 4, decoration: BoxDecoration(color: Colors.black.withValues(alpha: .25), borderRadius: BorderRadius.circular(4))),
              ]),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              _RoundBtn(icon: 'x', tooltip: 'داخستن', onTap: () => Navigator.pop(context)),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), boxShadow: t.shadow),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(widget.title, style: Ts.bold(context).copyWith(height: 1.3)),
                    Text('نەخشەکە بجووڵێنە تا دەرزییەکە لەسەر شوێنەکە بێت', style: Ts.muted(context, size: 12.8)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16 + bottom,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_err != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: t.dangerBg, borderRadius: BorderRadius.circular(14)),
                child: Text(_err!, style: TextStyle(color: t.dangerText, fontSize: 14)),
              ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: _RoundBtn(icon: 'navigate', tooltip: 'شوێنی ئێستام', busy: _locating, onTap: _here),
            ),
            const SizedBox(height: 10),
            YkButton('ئەم شوێنە', icon: 'check', block: true, large: true, onPressed: () => Navigator.pop(context, _pos)),
          ]),
        ),
      ]),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.tooltip, required this.onTap, this.busy = false});
  final String icon, tooltip;
  final VoidCallback onTap;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: t.card,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: busy ? null : onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: busy ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: t.text)) : YkIcon(icon, size: 22, color: t.text),
            ),
          ),
        ),
      ),
    );
  }
}
