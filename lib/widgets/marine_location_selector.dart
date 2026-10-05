import 'package:flutter/material.dart';
import '../data/marine_weather_points.dart';
import '../l10n/app_localizations.dart';
import '../services/marine_location_controller.dart';

class MarineLocationSelector extends StatelessWidget {
  final MarineLocationController controller;
  const MarineLocationSelector({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final point = controller.weatherPoint;
          final mode = controller.lastKnown
              ? 'lastKnown'
              : controller.automatic
                  ? 'automatic'
                  : 'manual';
          final status = controller.issue?.name;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('marine-choose-location'),
                    onPressed: () => _choose(context),
                    icon: const Icon(Icons.place_outlined),
                    label: Text(
                        point?.name ?? context.tr('marineLocation.choose'),
                        textAlign: TextAlign.center),
                  ),
                  Text(context.tr('marineLocation.$mode'),
                      textAlign: TextAlign.center),
                  if (point != null &&
                      controller.automatic &&
                      controller.coordinates != null)
                    Text(
                        context.trArgs('marineLocation.distance', args: {
                          'distance': point
                              .distanceKm(controller.coordinates!.latitude,
                                  controller.coordinates!.longitude)
                              .toStringAsFixed(1),
                        }),
                        textAlign: TextAlign.center),
                  if (status != null)
                    Text(context.tr('marineLocation.$status'),
                        textAlign: TextAlign.center),
                  if (controller.locating)
                    const LinearProgressIndicator()
                  else
                    TextButton.icon(
                      key: const ValueKey('marine-use-position'),
                      onPressed: controller.useMyPosition,
                      icon: const Icon(Icons.my_location),
                      label: Text(context.tr('marineLocation.usePosition')),
                    ),
                ]),
          );
        },
      );

  Future<void> _choose(BuildContext context) async {
    final point = await showModalBottomSheet<MarineWeatherPoint>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _PointPicker(),
    );
    if (point != null) await controller.selectManual(point);
  }
}

class _PointPicker extends StatefulWidget {
  const _PointPicker();
  @override
  State<_PointPicker> createState() => _PointPickerState();
}

class _PointPickerState extends State<_PointPicker> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final points = marineWeatherPoints
        .where((p) =>
            p.name.toLowerCase().contains(_query.toLowerCase()) ||
            p.id.contains(_query.toLowerCase()))
        .toList();
    return SafeArea(
        child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                    labelText: context.tr('marineLocation.search'),
                    prefixIcon: const Icon(Icons.search)),
                onChanged: (value) => setState(() => _query = value),
              )),
          Expanded(
              child: ListView.builder(
            itemCount: points.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(points[index].name),
              onTap: () => Navigator.pop(context, points[index]),
            ),
          )),
        ]),
      ),
    ));
  }
}
