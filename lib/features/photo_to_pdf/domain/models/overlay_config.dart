enum OverlayGridPosition {
  topLeft('Top Left'),
  topCenter('Top Center'),
  topRight('Top Right'),
  middleLeft('Middle Left'),
  middleCenter('Center'),
  middleRight('Middle Right'),
  bottomLeft('Bottom Left'),
  bottomCenter('Bottom Center'),
  bottomRight('Bottom Right');

  final String label;
  const OverlayGridPosition(this.label);
}

enum PageNumberFormatPreset {
  numberOnly('1'),
  pageNumber('Page 1'),
  pageNOfTotal('Page 1 of N'),
  nOfTotal('1/N');

  final String label;
  const PageNumberFormatPreset(this.label);

  String format(int current, int total) {
    switch (this) {
      case PageNumberFormatPreset.numberOnly:
        return '$current';
      case PageNumberFormatPreset.pageNumber:
        return 'Page $current';
      case PageNumberFormatPreset.pageNOfTotal:
        return 'Page $current of $total';
      case PageNumberFormatPreset.nOfTotal:
        return '$current/$total';
    }
  }
}

enum DateStampFormatPreset {
  ddMmYyyy('DD/MM/YYYY'),
  mmDdHyyy('MM/DD/YYYY'),
  yyyyMmDd('YYYY-MM-DD');

  final String label;
  const DateStampFormatPreset(this.label);

  String format(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');

    switch (this) {
      case DateStampFormatPreset.ddMmYyyy:
        return '$d/$m/$y';
      case DateStampFormatPreset.mmDdHyyy:
        return '$m/$d/$y';
      case DateStampFormatPreset.yyyyMmDd:
        return '$y-$m-$d';
    }
  }
}

enum DateStampSource {
  auto('Auto (Device Clock at Export)'),
  custom('Custom (Selected Date)');

  final String label;
  const DateStampSource(this.label);
}
