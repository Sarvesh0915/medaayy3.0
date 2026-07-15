import 'package:flutter/material.dart';
import '../services/billing_service.dart';
import 'profile_info_screen.dart';

class PlanSelectScreen extends StatefulWidget {
  final String owner; // 'me' or 'parent'
  const PlanSelectScreen({super.key, required this.owner});

  @override
  State<PlanSelectScreen> createState() => _PlanSelectScreenState();
}

class _PlanSelectScreenState extends State<PlanSelectScreen> {
  String _billing = 'monthly';
  bool _buying = false;

  // Fallback display prices — used only if the real Play Console prices
  // haven't loaded yet (e.g. products still pending approval).
  static const _fallbackPrices = {
    'alarm': {'monthly': '₹49', 'yearly': '₹499'},
    'call': {'monthly': '₹129', 'yearly': '₹1,499'},
  };
  static const addOnPricePerMedicine = '₹49/month';

  String _priceLabel(String type) {
    final productId = type == 'alarm' ? BillingProductIds.alarm : BillingProductIds.call;
    final storePrice = BillingService.instance.priceFor(productId);
    return storePrice ?? _fallbackPrices[type]![_billing]!;
  }

  Future<void> _choose(String type) async {
    setState(() => _buying = true);

    final productId = type == 'alarm' ? BillingProductIds.alarm : BillingProductIds.call;
    final result = await BillingService.instance.buy(productId, _billing);

    if (!mounted) return;
    setState(() => _buying = false);

    if (!result.success) {
      if (result.error != 'Cancelled') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Purchase could not be completed.')),
        );
      }
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileInfoScreen(owner: widget.owner, planType: type, billingCycle: _billing),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a reminder plan')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: ToggleButtons(
                    borderRadius: BorderRadius.circular(999),
                    isSelected: [_billing == 'monthly', _billing == 'yearly'],
                    onPressed: _buying ? null : (i) => setState(() => _billing = i == 0 ? 'monthly' : 'yearly'),
                    children: const [
                      Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: Text('Monthly')),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: Text('Yearly')),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _PlanCard(
                  icon: Icons.alarm,
                  title: 'Alarm reminders',
                  description: 'A loud in-app alarm goes off at each dose time — rings through silent mode, like a real alarm clock.',
                  features: const [
                    'Unlimited medicines',
                    'Works even with the phone on silent',
                    'SOS button (calls you + sends a backup SMS)',
                    'Fall detection, while the app is open',
                  ],
                  priceLabel: _priceLabel('alarm'),
                  billing: _billing,
                  onTap: _buying ? null : () => _choose('alarm'),
                ),
                const SizedBox(height: 12),
                _PlanCard(
                  icon: Icons.phone_in_talk,
                  title: 'Call reminders',
                  description: 'A real phone call comes in at each dose time, spoken in the language they choose.',
                  features: const [
                    'Everything in Alarm reminders',
                    'A phone call at each dose time, not just a sound',
                    'Spoken in their preferred language (10 supported)',
                    'Same-time medicines share one call, not several',
                    'AI-generated care tips based on their exact medicines',
                    'First 2 medicines included, +$addOnPricePerMedicine each after',
                  ],
                  priceLabel: _priceLabel('call'),
                  billing: _billing,
                  badge: 'Best for parents',
                  onTap: _buying ? null : () => _choose('call'),
                ),
              ],
            ),
          ),
          if (_buying)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<String> features;
  final String priceLabel;
  final String billing;
  final String? badge;
  final VoidCallback? onTap;

  const _PlanCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.features,
    required this.priceLabel,
    required this.billing,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (badge != null)
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              Row(children: [
                Icon(icon, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ]),
              const SizedBox(height: 6),
              Text(description),
              const SizedBox(height: 12),
              ...features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Expanded(child: Text(f, style: const TextStyle(fontSize: 12.5))),
                      ],
                    ),
                  )),
              const SizedBox(height: 6),
              Text(
                '$priceLabel / ${billing == 'monthly' ? 'month' : 'year'}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

