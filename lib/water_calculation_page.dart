
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para permitir apenas números no teclado
import 'package:task_list/perfil_page.dart';


class WaterCalculationPage extends StatefulWidget {
  const WaterCalculationPage({super.key});

  @override
  State<WaterCalculationPage> createState() => _WaterCalculationPageState();
}

class _WaterCalculationPageState extends State<WaterCalculationPage> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController(); // Incluído conforme a imagem, mas não usado no cálculo
  double _recommendedWater = 0.00;

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _calculateWaterIntake() {
    final double? weight = double.tryParse(_weightController.text);

    if (weight != null && weight > 0) {
      setState(() {
        _recommendedWater = (weight * 35) / 1000; // 35ml por kg, convertido para litros
      });
    } else {
      setState(() {
        _recommendedWater = 0.00;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, insira um peso válido.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Calcule seu consumo de água',
          style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const SizedBox(height: 20),
            const Icon(
              Icons.water_drop_outlined,
              color: Color(0xFF0D9488),
              size: 80,
            ),
            const SizedBox(height: 10),
            const Text(
              'Consumo recomendado',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            Text(
              '${_recommendedWater.toStringAsFixed(2)}L',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D9488),
              ),
            ),
            const Text(
              'por dia',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            _buildInputField('Peso (kg)', _weightController, TextInputType.number),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _calculateWaterIntake,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Calcular consumo ideal',
                  style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 40),
            _buildExplanationCard(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Dieta',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
        onTap: (index) {
          if (index == 0) {
            // Volta para a HomePage removendo todas as telas empilhadas
            Navigator.popUntil(context, (route) => route.isFirst);
          }
          else if (index == 1) {
            Navigator.push(context,MaterialPageRoute(builder: (_) => const PerfilPage()));
          }
        },
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, TextInputType keyboardType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly
          ], // Permite apenas dígitos
          decoration: InputDecoration(
            hintText: '0',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildExplanationCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Como calculamos?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                children: <TextSpan>[
                 
                  TextSpan(
                    text: '35ml \u00D7 peso corporal (kg)',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
