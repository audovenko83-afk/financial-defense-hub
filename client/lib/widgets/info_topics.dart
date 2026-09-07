import 'package:flutter/material.dart';

enum InfoTopic {
  millionGoal,
  freeCash,
  investedTotal,
  unrealizedPnL,
  strategy40,
  assetClass,
  avgPrice,
  analyticsEngine,
}

class InfoTopicData {
  final String title;
  final String shortTag;
  final String whatIsIt;
  final String whyImportant;
  final String tip;
  final IconData icon;
  final Color accentColor;

  const InfoTopicData({
    required this.title,
    required this.shortTag,
    required this.whatIsIt,
    required this.whyImportant,
    required this.tip,
    this.icon = Icons.lightbulb_outline_rounded,
    this.accentColor = const Color(0xFF00FF94),
  });
}

class InfoTopics {
  static const Map<InfoTopic, InfoTopicData> all = {
    InfoTopic.millionGoal: InfoTopicData(
      title: 'Ціль: \$1,000,000 (Million Dollar Way)',
      shortTag: 'СТРАТЕГІЯ КАПІТАЛУ',
      whatIsIt: 'План фінансової свободи через щотижневе інвестування \$40 (\$160/міс) у 40 топ-компаній.',
      whyImportant: 'Складний відсоток (~10.2% річних S&P 500) створює новий капітал на дистанції 25-30 років.',
      tip: 'Дисципліна перемагає все: купуйте щотижня незалежно від коливань біржі (DCA).',
      icon: Icons.emoji_events_rounded,
      accentColor: Color(0xFF00FF94),
    ),
    InfoTopic.freeCash: InfoTopicData(
      title: 'Вільний кеш (Cash Balance)',
      shortTag: 'ЛІКВІДНІСТЬ',
      whatIsIt: 'Гроші на балансі в USD, які ще не інвестовані в акції. Вони захищені від коливань біржі.',
      whyImportant: 'Потрібен для регулярного викупу плану «Стратегія 40» або купівлі активів під час просідань.',
      tip: 'Поповнюйте кеш на початку місяця (наприклад \$160), щоб щотижня легко купувати активи в один клік.',
      icon: Icons.account_balance_wallet_rounded,
      accentColor: Color(0xFF00FF94),
    ),
    InfoTopic.investedTotal: InfoTopicData(
      title: 'Вкладено (Invested Capital)',
      shortTag: 'АКТИВНІ ІНВЕСТИЦІЇ',
      whatIsIt: 'Сума грошей, яка працює в придбаних акціях та ETF фондах світових гігантів.',
      whyImportant: 'Ці кошти володіють реальними бізнесами і зростають разом із світовою економікою.',
      tip: 'Коливання біржі — це нормальний процес створення вартості на довгому горизонті.',
      icon: Icons.pie_chart_outline_rounded,
      accentColor: Color(0xFF00E5FF),
    ),
    InfoTopic.unrealizedPnL: InfoTopicData(
      title: 'Нереалізований PnL (Прибуток / Збиток)',
      shortTag: 'ПРИБУТКОВІСТЬ',
      whatIsIt: 'Різниця між поточною ціною ваших акцій та ціною їх купівлі.',
      whyImportant: '«Нереалізований» означає, що прибуток не зафіксовано. Поки акції у вас — це біржова оцінка.',
      tip: 'Зелений PnL — зростання. Червоний PnL — нагода докупити якісні активи дешевше!',
      icon: Icons.show_chart_rounded,
      accentColor: Color(0xFFFFC857),
    ),
    InfoTopic.strategy40: InfoTopicData(
      title: 'Стратегія 40: DCA та Диверсифікація',
      shortTag: 'АВТОМАТИЧНИЙ ПЛАН',
      whatIsIt: 'Розподіл \$40 порівну (по \$1) між 40 наднадійними компаніями різних секторів економіки.',
      whyImportant: 'Якщо якась галузь падає, інші зростають. Захищає від ризику невдачі окремої компанії.',
      tip: 'Купуючи щотижня, ви берете більше часток на спадах цін і менше на піках.',
      icon: Icons.track_changes_rounded,
      accentColor: Color(0xFF00FF94),
    ),
    InfoTopic.assetClass: InfoTopicData(
      title: 'Класи активів: Акції та ETF',
      shortTag: 'СТРУКТУРА',
      whatIsIt: 'Акція (Stock) — це частка компанії. ETF — кошик із сотень компаній під одним тікером.',
      whyImportant: 'Поєднання топ-акцій та широких фондів дає і швидкість росту, і надійний захист.',
      tip: 'Початківцям надійно тримати індексні фонди (VOO) разом із лідерами зі «Стратегії 40».',
      icon: Icons.layers_rounded,
      accentColor: Color(0xFF94A3B8),
    ),
    InfoTopic.avgPrice: InfoTopicData(
      title: 'Середня ціна купівлі (Average Price)',
      shortTag: 'МАТЕМАТИКА',
      whatIsIt: 'Середньозважена вартість часток акції, придбаних у різний час за різними цінами.',
      whyImportant: 'Згладжує ринкові стрибки. Якщо поточна ціна вища за середню — ви в чистому плюсі.',
      tip: 'Формула: Загальні витрати / Кількість придбаних часток.',
      icon: Icons.calculate_outlined,
      accentColor: Color(0xFF00E5FF),
    ),
    InfoTopic.analyticsEngine: InfoTopicData(
      title: 'Як працює аналітика та звідки цифри?',
      shortTag: 'МАТЕМАТИКА ТА ДЖЕРЕЛА',
      whatIsIt: 'Дані котирувань надходять напряму з Yahoo Finance / бірж NYSE та NASDAQ у реальному часі.',
      whyImportant: 'Симулятор моделює портфель за формулою складного відсотка на основі 50-річної статистики S&P 500 (~10.2% річних).',
      tip: 'Збільшення внеску навіть на \$50 скорочує шлях до \$1,000,000 на кілька років!',
      icon: Icons.analytics_rounded,
      accentColor: Color(0xFF00FF94),
    ),
  };
}
