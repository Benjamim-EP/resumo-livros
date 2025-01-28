import 'package:flutter/material.dart';

class EditProfileButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFFCDE7BE),
        padding: EdgeInsets.symmetric(horizontal: 23, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      onPressed: () {},
      child: Text(
        'Editar Perfil',
        style: TextStyle(
          color: Color(0xFF232538),
          fontSize: 15,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
