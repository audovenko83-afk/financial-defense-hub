class StrategyStock {
  final String ticker;
  final String name;
  final String sector;
  final double defaultPrice;
  final String description;

  const StrategyStock({
    required this.ticker,
    required this.name,
    required this.sector,
    required this.defaultPrice,
    required this.description,
  });

  Map<String, dynamic> toJson({double? customPrice}) => {
        'ticker': ticker,
        'name': name,
        'asset_class': 'Stock',
        'price': customPrice ?? defaultPrice,
      };
}

class MillionDollarPortfolio {
  static const double monthlyBudget = 160.0;
  static const double weeklyBudget = 40.0;
  static const double allocationPerStock = 1.0;

  static const List<StrategyStock> stocks = [
    StrategyStock(
      ticker: 'AAPL',
      name: 'Apple Inc.',
      sector: 'Технології',
      defaultPrice: 228.0,
      description: 'Світовий технологічний гігант, екосистема iPhone, Mac та ШІ.',
    ),
    StrategyStock(
      ticker: 'ADBE',
      name: 'Adobe Inc.',
      sector: 'Технології',
      defaultPrice: 535.0,
      description: 'Лідер цифрових медіа, Photoshop та генеративного ШІ Firefly.',
    ),
    StrategyStock(
      ticker: 'ADP',
      name: 'Automatic Data Processing',
      sector: 'Фінтех',
      defaultPrice: 275.0,
      description: 'Найбільший у світі провайдер виплат заробітної плати та HR.',
    ),
    StrategyStock(
      ticker: 'AMAT',
      name: 'Applied Materials, Inc.',
      sector: 'Напівпровідники',
      defaultPrice: 205.0,
      description: 'Обладнання для виробництва мікрочіпів у світовому масштабі.',
    ),
    StrategyStock(
      ticker: 'AMGN',
      name: 'Amgen Inc.',
      sector: 'Медицина',
      defaultPrice: 320.0,
      description: 'Один із піонерів світових біотехнологій та інноваційних ліків.',
    ),
    StrategyStock(
      ticker: 'AMZN',
      name: 'Amazon.com, Inc.',
      sector: 'Технології',
      defaultPrice: 178.0,
      description: 'Лідер світового e-commerce та хмарної інфраструктури AWS.',
    ),
    StrategyStock(
      ticker: 'APH',
      name: 'Amphenol Corporation',
      sector: 'Електроніка',
      defaultPrice: 66.0,
      description: 'Виробник сенсорів і розʼємів для 5G, автопрому й дата-центрів.',
    ),
    StrategyStock(
      ticker: 'AXON',
      name: 'Axon Enterprise, Inc.',
      sector: 'Безпека',
      defaultPrice: 380.0,
      description: 'Технології безпеки, електрошокери TASER та натільні камери.',
    ),
    StrategyStock(
      ticker: 'BKNG',
      name: 'Booking Holdings Inc.',
      sector: 'Сервіси',
      defaultPrice: 4050.0,
      description: 'Провідна світова платформа онлайн-бронювання подорожей.',
    ),
    StrategyStock(
      ticker: 'BRO',
      name: 'Brown & Brown, Inc.',
      sector: 'Фінанси',
      defaultPrice: 104.0,
      description: 'Високоприбутковий страховий брокер зі стабільним зростанням.',
    ),
    StrategyStock(
      ticker: 'CHD',
      name: 'Church & Dwight Co., Inc.',
      sector: 'Споживчі товари',
      defaultPrice: 102.0,
      description: 'Захисний бізнес товарів для дому (бренд Arm & Hammer).',
    ),
    StrategyStock(
      ticker: 'CPRT',
      name: 'Copart, Inc.',
      sector: 'Сервіси',
      defaultPrice: 53.0,
      description: 'Глобальний лідер онлайн-аукціонів та ремаркетингу автомобілів.',
    ),
    StrategyStock(
      ticker: 'CTAS',
      name: 'Cintas Corporation',
      sector: 'Промисловість',
      defaultPrice: 200.0,
      description: 'Корпоративна уніформа та засоби безпеки для 1+ млн бізнесів.',
    ),
    StrategyStock(
      ticker: 'EXPD',
      name: 'Expeditors International',
      sector: 'Логістика',
      defaultPrice: 124.0,
      description: 'Глобальна логістична мережа авіаційних і морських вантажів.',
    ),
    StrategyStock(
      ticker: 'FAST',
      name: 'Fastenal Company',
      sector: 'Промисловість',
      defaultPrice: 70.0,
      description: 'Промислове постачання, кріплення та вендинг на заводах США.',
    ),
    StrategyStock(
      ticker: 'FICO',
      name: 'Fair Isaac Corporation',
      sector: 'Фінтех',
      defaultPrice: 1950.0,
      description: 'Творець стандартного кредитного рейтингу банків FICO Score.',
    ),
    StrategyStock(
      ticker: 'HD',
      name: 'The Home Depot, Inc.',
      sector: 'Рітейл',
      defaultPrice: 375.0,
      description: 'Найбільша в світі мережа товарів для будівництва та дому.',
    ),
    StrategyStock(
      ticker: 'IBKR',
      name: 'Interactive Brokers Group',
      sector: 'Фінанси',
      defaultPrice: 128.0,
      description: 'Передовий міжнародний брокер з доступом до 150+ ринків.',
    ),
    StrategyStock(
      ticker: 'IDXX',
      name: 'IDEXX Laboratories, Inc.',
      sector: 'Медицина',
      defaultPrice: 485.0,
      description: 'Світовий лідер лабораторної ветеринарної діагностики.',
    ),
    StrategyStock(
      ticker: 'ISRG',
      name: 'Intuitive Surgical, Inc.',
      sector: 'Медицина',
      defaultPrice: 470.0,
      description: 'Творець роботизованої хірургічної платформи da Vinci.',
    ),
    StrategyStock(
      ticker: 'J',
      name: 'Jacobs Solutions Inc.',
      sector: 'Інженерія',
      defaultPrice: 145.0,
      description: 'Глобальний інжиніринг, програми NASA та інфраструктура.',
    ),
    StrategyStock(
      ticker: 'LRCX',
      name: 'Lam Research Corporation',
      sector: 'Напівпровідники',
      defaultPrice: 82.0,
      description: 'Обладнання для нано-травлення та осадження тонких плівок.',
    ),
    StrategyStock(
      ticker: 'MSFT',
      name: 'Microsoft Corporation',
      sector: 'Технології',
      defaultPrice: 425.0,
      description: 'Windows, Azure, Office 365, партнерство з OpenAI та ШІ.',
    ),
    StrategyStock(
      ticker: 'NFLX',
      name: 'Netflix, Inc.',
      sector: 'Медіа',
      defaultPrice: 690.0,
      description: 'Найпопулярніший стримінговий відеосервіс у світі.',
    ),
    StrategyStock(
      ticker: 'NVDA',
      name: 'NVIDIA Corporation',
      sector: 'Напівпровідники',
      defaultPrice: 115.0,
      description: 'Абсолютний домінант графічних чіпів для ШІ.',
    ),
    StrategyStock(
      ticker: 'ODFL',
      name: 'Old Dominion Freight Line',
      sector: 'Логістика',
      defaultPrice: 195.0,
      description: 'Преміальний американський вантажоперевізник.',
    ),
    StrategyStock(
      ticker: 'ORCL',
      name: 'Oracle Corporation',
      sector: 'Технології',
      defaultPrice: 140.0,
      description: 'Корпоративні СУБД, Oracle Cloud та інфраструктура для ШІ.',
    ),
    StrategyStock(
      ticker: 'ORLY',
      name: 'O\'Reilly Automotive, Inc.',
      sector: 'Рітейл',
      defaultPrice: 1140.0,
      description: 'Мережа магазинів автозапчастин із 30+ роками зростання.',
    ),
    StrategyStock(
      ticker: 'PHM',
      name: 'PulteGroup, Inc.',
      sector: 'Будівництво',
      defaultPrice: 135.0,
      description: 'Один із найбільших забудовників житла у США.',
    ),
    StrategyStock(
      ticker: 'POOL',
      name: 'Pool Corporation',
      sector: 'Сервіси',
      defaultPrice: 355.0,
      description: 'Найбільший дистрибʼютор обладнання для басейнів.',
    ),
    StrategyStock(
      ticker: 'RJF',
      name: 'Raymond James Financial',
      sector: 'Фінанси',
      defaultPrice: 122.0,
      description: 'Провідний інвестиційний банк та управління капіталом.',
    ),
    StrategyStock(
      ticker: 'ROST',
      name: 'Ross Stores, Inc.',
      sector: 'Рітейл',
      defaultPrice: 152.0,
      description: 'Гігант дисконтного рітейлу (Ross Dress for Less).',
    ),
    StrategyStock(
      ticker: 'SHW',
      name: 'The Sherwin-Williams Company',
      sector: 'Матеріали',
      defaultPrice: 360.0,
      description: 'Лідер лакофарбових матеріалів та покриттів.',
    ),
    StrategyStock(
      ticker: 'SPGI',
      name: 'S&P Global Inc.',
      sector: 'Фінанси',
      defaultPrice: 510.0,
      description: 'Творець S&P 500, глобальний лідер кредитних рейтингів.',
    ),
    StrategyStock(
      ticker: 'SYK',
      name: 'Stryker Corporation',
      sector: 'Медицина',
      defaultPrice: 355.0,
      description: 'Інноваційне хірургічне та ортопедичне медобладнання.',
    ),
    StrategyStock(
      ticker: 'TSCO',
      name: 'Tractor Supply Company',
      sector: 'Рітейл',
      defaultPrice: 280.0,
      description: 'Найбільша в США мережа товарів для фермерів і ранчо.',
    ),
    StrategyStock(
      ticker: 'TSLA',
      name: 'Tesla, Inc.',
      sector: 'Авто & Енергетика',
      defaultPrice: 220.0,
      description: 'Електромобілі, автопілот FSD, робототехніка та сонячна енергія.',
    ),
    StrategyStock(
      ticker: 'UNH',
      name: 'UnitedHealth Group',
      sector: 'Медицина',
      defaultPrice: 585.0,
      description: 'Найбільша страхова та медична корпорація світу.',
    ),
    StrategyStock(
      ticker: 'WMT',
      name: 'Walmart Inc.',
      sector: 'Рітейл',
      defaultPrice: 76.0,
      description: 'Найбільша роздрібна торговельна мережа планети.',
    ),
    StrategyStock(
      ticker: 'WST',
      name: 'West Pharmaceutical Services',
      sector: 'Медицина',
      defaultPrice: 305.0,
      description: 'Компоненти упаковки для інʼєкційних препаратів та вакцин.',
    ),
  ];
}
