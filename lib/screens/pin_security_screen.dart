import 'package:flutter/material.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import 'cleanup_screen.dart';

class PinSecurityScreen extends StatefulWidget {
  const PinSecurityScreen({super.key});

  @override
  State<PinSecurityScreen> createState() => _PinSecurityScreenState();
}

class _PinSecurityScreenState extends State<PinSecurityScreen> {
  String _enteredPin = '';
  static const String _correctPin = '5428'; // Change this to your preferred PIN
  bool _isWrongPin = false;

  void _onNumberPressed(String number) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += number;
        _isWrongPin = false;
      });

      // Check PIN when 4 digits entered
      if (_enteredPin.length == 4) {
        _checkPin();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _isWrongPin = false;
      });
    }
  }

  void _checkPin() {
    if (_enteredPin == _correctPin) {
      // Correct PIN - navigate to cleanup screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CleanupScreen()),
      );
    } else {
      // Wrong PIN - show error and reset
      setState(() {
        _isWrongPin = true;
      });

      // Clear PIN after a delay
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() {
            _enteredPin = '';
            _isWrongPin = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        backgroundColor: AppColors.darkGray,
        foregroundColor: AppColors.white,
        title: Text(
          'ADMIN ACCESS',
          style: AppTextStyles.screenTitle,
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lock Icon
            Icon(
              Icons.lock,
              size: 80,
              color: _isWrongPin ? Colors.red : AppColors.primaryOrange,
            ),
            const SizedBox(height: 30),

            // Title
            Text(
              'Enter Admin PIN',
              style: AppTextStyles.sectionHeader.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 10),

            // Subtitle
            Text(
              'Access to database cleanup tools',
              style: AppTextStyles.bodyText.copyWith(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // PIN Display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _enteredPin.length
                        ? (_isWrongPin ? Colors.red : AppColors.primaryOrange)
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),

            // Error Message
            if (_isWrongPin)
              Text(
                'Wrong PIN. Try again.',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 10),

            // Number Pad
            Expanded(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  if (index == 9) {
                    // Empty space
                    return const SizedBox.shrink();
                  } else if (index == 10) {
                    // Zero button
                    return _buildNumberButton('0');
                  } else if (index == 11) {
                    // Backspace button
                    return _buildBackspaceButton();
                  } else {
                    // Number buttons 1-9
                    return _buildNumberButton((index + 1).toString());
                  }
                },
              ),
            ),

            // Hint (remove this in production)
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'DEV HINT: PIN is 63(****)17',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                  fontFamily: 'AlfaSlabOne',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onNumberPressed(number),
        borderRadius: BorderRadius.circular(50),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.1),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          child: Center(
            child: Text(
              number,
              style: AppTextStyles.sectionHeader.copyWith(fontSize: 28),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _onBackspace,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withValues(alpha: 0.1),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.3),
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.backspace_outlined,
              color: Colors.red,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}