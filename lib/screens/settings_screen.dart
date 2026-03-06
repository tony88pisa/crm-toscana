import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/storage_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isObscured = true;

  @override
  void initState() {
    super.initState();
    _apiKeyController.text = StorageService.getGeminiApiKey() ?? '';
  }

  Future<void> _saveKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci una chiave valida.')),
      );
      return;
    }

    await StorageService.setGeminiApiKey(key);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API Key salvata correttamente!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _logout() async {
    await StorageService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = StorageService.getUserName() ?? 'Utente';
    final userEmail = StorageService.getUserEmail() ?? '';
    final userAvatar = StorageService.getUserAvatar();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni Profilo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Profilo
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: userAvatar != null ? NetworkImage(userAvatar) : null,
                  child: userAvatar == null ? const Icon(Icons.person, size: 30) : null,
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      userEmail,
                      style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6)),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  onPressed: _logout,
                  tooltip: 'Logout',
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 20),
            
            // Sezione API Key
            const Text(
              'Configurazione AI Gemini',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 10),
            const Text(
              'Inserisci la tua API Key personale per abilitare l\'analisi dei lead. Ogni utente deve usare la propria chiave gratuita.',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _apiKeyController,
              obscureText: _isObscured,
              decoration: InputDecoration(
                labelText: 'Gemini API Key',
                hintText: 'Incolla qui la tua chiave...',
                suffixIcon: IconButton(
                  icon: Icon(_isObscured ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _isObscured = !_isObscured),
                ),
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: _saveKey,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Salva API Key'),
            ),
            
            const SizedBox(height: 30),
            _buildUsageCard(),
            const SizedBox(height: 30),
            
            // GUIDA API KEY
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.help_outline, color: Colors.blue),
                      SizedBox(width: 10),
                      Text(
                        'Come ottenere la tua API Key?',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildStep(1, 'Vai su Google AI Studio cliccando il link sotto.'),
                  _buildStep(2, 'Accedi con il tuo account Google.'),
                  _buildStep(3, 'Clicca su "Get API Key" nel menu a sinistra.'),
                  _buildStep(4, 'Crea una nuova chiave API per un nuovo progetto.'),
                  _buildStep(5, 'Copia la chiave e incollala nel box sopra.'),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _launchUrl('https://aistudio.google.com/app/apikey'),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Apri Google AI Studio (Gratis)'),
                      style: TextButton.styleFrom(foregroundColor: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 9,
            backgroundColor: Colors.blue,
            child: Text(
              number.toString(),
              style: const TextStyle(fontSize: 10, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageCard() {
    final stats = StorageService.getQuotaStats();
    final tokens = stats['tokens'] ?? 0;
    final requests = stats['requests'] ?? 0;
    final tokenLimit = 500000;
    final tokenPercent = (tokens / tokenLimit).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_outlined, color: Colors.amber),
              SizedBox(width: 10),
              Text(
                'Monitoraggio Quota (Oggi)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _usageRow('Token consumati:', '$tokens', tokenPercent),
          const SizedBox(height: 15),
          _usageRow('Richieste effettuate:', '$requests / 15 RPM', (requests / 15).clamp(0.0, 1.0)),
        ],
      ),
    );
  }

  Widget _usageRow(String label, String value, double percent) {
    final color = percent > 0.8 ? Colors.redAccent : (percent > 0.5 ? Colors.orangeAccent : Colors.green);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: Colors.white70)),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: Colors.white.withOpacity(0.1),
            color: color,
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
