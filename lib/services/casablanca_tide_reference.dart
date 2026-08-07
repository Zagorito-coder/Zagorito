import 'dart:math' as math;

/// Prédiction harmonique locale de la hauteur de marée à Casablanca.
///
/// Les 69 constituants proviennent du marégraphe Casablanca (33.610001,
/// -7.61) publié par le Joint Research Centre de la Commission européenne :
/// https://webcritech.jrc.ec.europa.eu/SeaLevelsDb/Device/2052
/// Contenu UE réutilisable sous CC BY 4.0. La légère transformation affine
/// convertit le zéro du marégraphe vers la présentation BMI utilisée par les
/// tables locales. Elle a été validée contre les quatre extrema du 07/08/2026.
class CasablancaTideReference {
  const CasablancaTideReference._();

  // Alignement stationnel du zéro et de l'amplitude sur la référence BMI.
  // Il ne modifie ni la phase ni l'heure des extrema harmoniques.
  static const double _bmiScale = 0.961;
  static const double _bmiOffsetMeters = -0.075;

  /// Hauteur en mètres au-dessus de la référence locale BMI.
  static double heightAtUtc(DateTime instant) {
    final utc = instant.toUtc();
    final oleAutomationDays =
        utc.millisecondsSinceEpoch / Duration.millisecondsPerDay + 25569.0;

    var rawHeight = _meanLevelMeters;
    for (final constituent in _constituents) {
      final angle = oleAutomationDays * 2 * math.pi / constituent.periodDays;
      rawHeight += constituent.cosFactorMeters * math.cos(angle) +
          constituent.sinFactorMeters * math.sin(angle);
    }
    return rawHeight * _bmiScale + _bmiOffsetMeters;
  }

  static const double _meanLevelMeters = 2.26953266573745;

  static const List<_HarmonicConstituent> _constituents = [
    _HarmonicConstituent(
        0.128766334283776, 5.15673525103079e-5, -1.62983609476035e-4),
    _HarmonicConstituent(
        0.128857194376164, -4.40828053581161e-4, 2.37292841056507e-4),
    _HarmonicConstituent(
        0.129381266016223, -2.65053468885167e-4, 4.33491313776686e-4),
    _HarmonicConstituent(
        0.147068369304709, 1.66388476390220e-4, 5.16929976978464e-5),
    _HarmonicConstituent(
        0.168413975812495, 1.96678751663214e-4, -2.65851914860876e-5),
    _HarmonicConstituent(
        0.168569435980517, -3.40567175026184e-4, -2.15248173834960e-4),
    _HarmonicConstituent(
        0.170357083547568, -3.39686798654321e-4, -1.57551267298362e-4),
    _HarmonicConstituent(
        0.170516143636361, 1.2691735864568e-3, 1.0522644685781e-3),
    _HarmonicConstituent(
        0.172508349331654, -1.38773354376061e-3, -1.697774369212e-3),
    _HarmonicConstituent(
        0.174695758496972, 2.57214431029385e-4, -6.64721077462819e-5),
    _HarmonicConstituent(
        0.199890544415426, -2.16725195318293e-4, -2.66800320280117e-4),
    _HarmonicConstituent(
        0.205453337753506, -1.05379674877908e-3, 1.38137549809805e-4),
    _HarmonicConstituent(
        0.249658233357344, -3.12282319328210e-4, 7.11710241314925e-6),
    _HarmonicConstituent(
        0.249999992, 1.56088483792259e-3, -4.12946433168412e-4),
    _HarmonicConstituent(
        0.253952177489379, 1.7442011979501e-3, -9.45613229873239e-4),
    _HarmonicConstituent(
        0.254305803118864, -8.5577393949284e-3, -1.57939649965794e-4),
    _HarmonicConstituent(
        0.25631444055176, -7.79870842178971e-4, -5.6590846767958e-4),
    _HarmonicConstituent(
        0.256674704014076, 2.7140515601423e-4, 8.22175557019791e-4),
    _HarmonicConstituent(
        0.258762532032447, 1.44688722190594e-2, 1.06680424375406e-2),
    _HarmonicConstituent(
        0.261215591287424, -1.31819372812505e-3, -7.50534329121771e-3),
    _HarmonicConstituent(
        0.333029389398687, 1.06829107577262e-3, -1.66084972504758e-3),
    _HarmonicConstituent(
        0.340714167095135, -8.81113746267471e-4, -3.22045014157091e-4),
    _HarmonicConstituent(
        0.341351021629882, -3.68523269600825e-4, -3.11323145692056e-4),
    _HarmonicConstituent(
        0.34501669723487, 3.88176050940186e-3, -1.79348492798977e-3),
    _HarmonicConstituent(
        0.349429284557433, -9.55494489876174e-5, -2.14842762746564e-4),
    _HarmonicConstituent(
        0.489771751709733, 3.35982932484325e-3, -2.55195260134663e-3),
    _HarmonicConstituent(
        0.491088802767104, 8.42429794920552e-4, -8.24974973807799e-4),
    _HarmonicConstituent(
        0.498634767923513, -5.64248327859649e-2, -6.16551591824129e-2),
    _HarmonicConstituent(
        0.499316511591742, -6.84086201427379e-6, -3.44645756068091e-3),
    _HarmonicConstituent(0.499999984, 6.60737270781194e-2, 3.57425515518007e-1),
    _HarmonicConstituent(
        0.507984165946608, 1.92551151197994e-3, -2.29039962101719e-2),
    _HarmonicConstituent(
        0.509240592196617, -3.93551202741424e-3, 2.46112092953507e-3),
    _HarmonicConstituent(
        0.51606260547855, -2.23846970029477e-3, 1.7670267780548e-3),
    _HarmonicConstituent(
        0.516792827371988, 5.25923089487346e-4, 4.11280874729966e-3),
    _HarmonicConstituent(
        0.517525060850908, 1.02865510184108, -7.18091549686275e-2),
    _HarmonicConstituent(
        0.518259333570738, -1.8308821616588e-3, -1.52651158983671e-4),
    _HarmonicConstituent(
        0.526083541864433, 3.99886148441509e-2, 7.5024852376282e-3),
    _HarmonicConstituent(
        0.527431160919067, -4.64660252337204e-2, -2.15287575282496e-1),
    _HarmonicConstituent(
        0.536323226339296, -6.76226215184554e-3, -4.00912695045823e-2),
    _HarmonicConstituent(
        0.537723941372983, -2.88073709631182e-2, 1.19153371830106e-2),
    _HarmonicConstituent(
        0.546969491030712, -8.63031416855703e-3, 3.93450166712005e-3),
    _HarmonicConstituent(
        0.548426385474333, 1.86435948359574e-3, 3.12854094591448e-3),
    _HarmonicConstituent(
        0.899093169594225, 3.22840672689151e-4, 7.29962618160559e-5),
    _HarmonicConstituent(
        0.92941980084125, 6.32832636839499e-4, -1.07054157238416e-4),
    _HarmonicConstituent(
        0.934174122926896, 7.85269311378168e-4, 3.79183597963561e-4),
    _HarmonicConstituent(
        0.962436511046921, -1.33076590256777e-3, 3.1116328503659e-4),
    _HarmonicConstituent(
        0.966956557148237, 5.10199876980974e-4, 2.81382307566426e-5),
    _HarmonicConstituent(
        0.991853148349387, -1.03455511438493e-3, -4.02076427342692e-4),
    _HarmonicConstituent(
        0.994554139787846, 8.84085783545684e-4, -1.47435723251609e-4),
    _HarmonicConstituent(
        0.997269547781583, 5.13861159835875e-2, 3.53734118628786e-2),
    _HarmonicConstituent(
        0.999999872000017, -3.8352115504056e-3, -2.7096709606584e-3),
    _HarmonicConstituent(
        1.00274540461034, 1.47247863601809e-2, 1.4869426195162e-2),
    _HarmonicConstituent(
        1.00550583624144, 1.52990357028493e-3, 5.0451035712897e-4),
    _HarmonicConstituent(
        1.02954467892393, 7.79859077392326e-4, -5.11833190867824e-4),
    _HarmonicConstituent(
        1.03471863450781, 4.04855593946953e-3, -3.29862089562844e-3),
    _HarmonicConstituent(
        1.04061468326798, -9.97500637737538e-4, 1.17192841117874e-3),
    _HarmonicConstituent(
        1.06950552105274, 1.28857809914202e-3, 1.4196293102087e-4),
    _HarmonicConstituent(
        1.07580588726596, -6.81158659115596e-5, -5.31345658311633e-2),
    _HarmonicConstituent(
        1.11346057230323, -1.18794406117328e-3, -2.44998230647051e-3),
    _HarmonicConstituent(
        1.11951481625018, -1.23877966338122e-2, 1.26008399003213e-2),
    _HarmonicConstituent(
        1.16034950581132, -2.41607337820851e-3, 2.89346264254652e-3),
    _HarmonicConstituent(
        1.16692589225208, 3.84086171477795e-3, 3.68062201555345e-4),
    _HarmonicConstituent(
        1.21136109404707, 9.32987355417148e-4, 4.28944430805623e-4),
    _HarmonicConstituent(
        13.6607901226149, -5.12686565819463e-5, -8.401548649068e-5),
    _HarmonicConstituent(
        14.7652926794033, -6.28828989770803e-3, -6.28976272449845e-3),
    _HarmonicConstituent(
        27.5545491899403, -2.01458275358503e-3, -4.85819898997688e-4),
    _HarmonicConstituent(
        31.8119339543532, -1.37523653981598e-3, 7.61522475169641e-3),
    _HarmonicConstituent(
        182.621183765123, -3.60956841776233e-2, -3.90094209211056e-2),
    _HarmonicConstituent(
        365.259977441544, -2.0054484512927e-2, -6.41113892959679e-2),
  ];
}

class _HarmonicConstituent {
  final double periodDays;
  final double cosFactorMeters;
  final double sinFactorMeters;

  const _HarmonicConstituent(
    this.periodDays,
    this.cosFactorMeters,
    this.sinFactorMeters,
  );
}
