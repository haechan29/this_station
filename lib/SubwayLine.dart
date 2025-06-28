import 'package:flutter/material.dart';

enum SubwayLine {
  line1('1호선', Color(0xFF0052A4)),
  line2('2호선', Color(0xFF00A84D)),
  line3('3호선', Color(0xFFEF7C1C)),
  line4('4호선', Color(0xFF00A5DE)),
  line5('5호선', Color(0xFF996CAC)),
  line6('6호선', Color(0xFFCD7C2F)),
  line7('7호선', Color(0xFF747F00)),
  line8('8호선', Color(0xFFE6186C)),
  line9('9호선', Color(0xFFBDB092)),
  lineGyenggang('경강선', Color(0xff003da5)),
  lineGyeongui('경의선', Color(0xff77c4a3)),
  lineGyeongchun('경춘선', Color(0xff0c8e72)),
  lineAirportRailloadExpress('공항철도', Color(0xff0065B3)),
  lineGimpoGold('김포골드라인', Color(0xffa17800)),
  lineSeohae('서해선', Color(0xff81a914)),
  lineSuinBundang('수인분당선', Color(0xffF5a200)),
  lineShinBundang('신분당선', Color(0xffd4003b)),
  lineLrtYongin('용인경전철', Color(0xff509f22)),
  lineLrtSinseol('우이신설경전철', Color(0xffb7c452)),
  lineLrtUijeongbu('의정부경전철', Color(0xfffca600)),
  lineIncheon('인천선', Color(0xff7ca8d5)),
  lineIncheonTwo('인천2호선', Color(0xffed8B00));

  const SubwayLine(this.lineNumber, this.color);

  final String lineNumber;
  final Color color;
}