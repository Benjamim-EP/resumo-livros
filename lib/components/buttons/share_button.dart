import 'package:flutter/material.dart';

class ShareButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFFCDE7BE),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      onPressed: () {},
      icon: Container(
        width: 20,
        height: 20,
        color: Color(0xFF2D3047),
      ),
      label: Text(
        'Share',
        style: TextStyle(
          color: Color(0xFF2D3047),
          fontSize: 14,
          fontFamily: 'Abel',
        ),
      ),
    );
  }
}
