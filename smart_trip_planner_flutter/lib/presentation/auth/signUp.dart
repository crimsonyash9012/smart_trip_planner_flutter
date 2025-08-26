import 'package:flutter/material.dart';


class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailController = TextEditingController(text: '');
  final _passController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Widget _buildHeader(double width) {
    return Column(
      children: [
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text("✈️", style: TextStyle(fontSize: 26)),
            SizedBox(width: 8),
            Text(
              'Itinera AI',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: Color(0xFF0E6A45),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const Text(
          'Create your Account',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF0B2340),
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Lets get started",
          style: TextStyle(
            color: Color(0xFF9AA0AA),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _googleButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E6EB)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: const Color(0xFFF5F5F5),
              ),
              child: const Center(child: Text('G', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
            ),
            const SizedBox(width: 12),
            const Text(
              'Sign up with Google',
              style: TextStyle(
                color: Color(0xFF222222),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _orDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18.0),
      child: Row(
        children: [
          const Expanded(
            child: Divider(
              thickness: 1,
              color: Color(0xFFE2E6EB),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'or Sign up with Email',
            style: TextStyle(color: Color(0xFF9AA0AA), fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Divider(
              thickness: 1,
              color: Color(0xFFE2E6EB),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({required Widget prefix}) {
    return InputDecoration(
      prefixIcon: prefix,
      prefixIconConstraints: const BoxConstraints(minWidth: 52),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFE6EAF0)),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFDDE4EA)),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _emailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Email address',
          style: TextStyle(color: Color(0xFF22292F), fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: _fieldDecoration(
            prefix: Padding(
              padding: const EdgeInsets.only(left: 14.0, right: 6.0),
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                child: const Icon(Icons.email_outlined, size: 20, color: Color(0xFF9AA0AA)),
              ),
            ),
          ).copyWith(hintText: 'john@example.com'),
        ),
      ],
    );
  }

  Widget _passwordField({required String label, required TextEditingController controller, required bool obscure, required VoidCallback toggle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF22292F), fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: _fieldDecoration(
            prefix: Padding(
              padding: const EdgeInsets.only(left: 14.0, right: 6.0),
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                child: const Icon(Icons.lock_outline, size: 20, color: Color(0xFF9AA0AA)),
              ),
            ),
          ).copyWith(
            hintText: '',
            suffixIcon: GestureDetector(
              onTap: toggle,
              child: Padding(
                padding: const EdgeInsets.only(right: 14.0),
                child: Icon(
                  obscure ? Icons.visibility : Icons.visibility_off,
                  color: const Color(0xFF9AA0AA),
                ),
              ),
            ),
            suffixIconConstraints: const BoxConstraints(minWidth: 52),
          ),
        ),
      ],
    );
  }

  Widget _signUpButton(BuildContext ctx) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            // boxShadow: [
            //   BoxShadow(
            //     color: const Color(0xFF0B2640).withOpacity(0.12),
            //     offset: const Offset(0, 6),
            //     blurRadius: 12,
            //   ),
            //   BoxShadow(
            //     color: const Color(0xFF7A6BFF).withOpacity(0.12),
            //     offset: const Offset(0, 10),
            //     blurRadius: 26,
            //   ),
            // ],
          ),
          child: Center(
            child: ElevatedButton(
              onPressed: () {
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F6A4E),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 6,
              ),
              child: const Text(
                'Sign UP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            )
            ,
          ),
        ),
      ),
    );
  }

  Widget _bottomHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 10),
      child: Center(
        child: Container(
          width: 80,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22.0),
            child: Column(
              children: [
                _buildHeader(w),
                _googleButton(context),
                _orDivider(),
                const SizedBox(height: 6),
                _emailField(),
                const SizedBox(height: 18),
                _passwordField(
                  label: 'Password',
                  controller: _passController,
                  obscure: _obscurePass,
                  toggle: () => setState(() => _obscurePass = !_obscurePass),
                ),
                const SizedBox(height: 18),
                _passwordField(
                  label: 'Confirm Password',
                  controller: _confirmController,
                  obscure: _obscureConfirm,
                  toggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                const SizedBox(height: 28),
                _signUpButton(context),
                const SizedBox(height: 18),
                _bottomHandle(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
