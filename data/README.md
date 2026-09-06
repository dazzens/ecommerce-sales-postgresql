# Исходные данные

CSV намеренно не хранится в репозитории.

1. Откройте [E-commerce Business Transaction на Kaggle](https://www.kaggle.com/datasets/gabrielramos87/an-online-shop-business).
2. Скачайте набор и распакуйте `Sales Transaction v.4a.csv`.
3. Импортируйте файл в `raw.transactions` по инструкции из корневого README.

Для версии 7, использованной в этом проекте:

```text
Файл: Sales Transaction v.4a.csv
Строк данных: 536350
SHA-256: cc2116c7f59378bde9616d6df8462bc7c8997aaec77474062be18d22e8f88d65
```

Контрольную сумму в PowerShell можно проверить командой:

```powershell
Get-FileHash -Algorithm SHA256 "C:\path\to\Sales Transaction v.4a.csv"
```

Страница Kaggle указывает лицензию набора: **CC0: Public Domain**.

