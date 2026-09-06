"""Создаёт проверочные CSV и графики для портфолио из исходного датасета.

Основная обработка проекта выполняется SQL-скриптами в PostgreSQL. Этот файл
нужен только для воспроизводимой генерации статических изображений для README.
Логика очистки повторяет sql/03_prepare_data.sql, а итоговые суммы сверены с
sql/06_full_audit.sql.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import matplotlib
import pandas as pd

matplotlib.use("Agg")
import matplotlib.pyplot as plt


ROOT = Path(__file__).resolve().parents[1]
RESULTS_DIR = ROOT / "docs" / "results"
IMAGES_DIR = ROOT / "images"
PRIMARY = "#1F4E79"
SECONDARY = "#A9C6DF"
INK = "#17212B"
GRID = "#DCE3EA"


def load_and_prepare(csv_path: Path) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Загружает raw-данные и воспроизводит очистку PostgreSQL-проекта."""
    raw = pd.read_csv(csv_path, dtype=str, keep_default_na=False)
    raw = raw.rename(
        columns={
            "TransactionNo": "transaction_no",
            "Date": "transaction_date",
            "ProductNo": "product_no",
            "ProductName": "product_name",
            "Price": "price",
            "Quantity": "quantity",
            "CustomerNo": "customer_no",
            "Country": "country",
        }
    )

    typed = raw.copy()
    typed["transaction_date"] = pd.to_datetime(
        typed["transaction_date"], format="%m/%d/%Y"
    )
    typed["price"] = pd.to_numeric(typed["price"])
    typed["quantity"] = pd.to_numeric(typed["quantity"]).astype("int64")
    customer = typed["customer_no"].str.strip().replace({"": "-1", "NA": "-1"})
    typed["customer_no"] = pd.to_numeric(customer).astype("int64")

    deduplicated = typed.drop_duplicates()
    group_columns = [
        "transaction_no",
        "transaction_date",
        "product_no",
        "product_name",
        "price",
        "customer_no",
        "country",
    ]
    clean = (
        deduplicated.groupby(group_columns, as_index=False, sort=False)["quantity"]
        .sum()
        .reset_index(drop=True)
    )
    clean["total_amount"] = clean["price"] * clean["quantity"]
    return raw, clean


def build_results(raw: pd.DataFrame, clean: pd.DataFrame) -> dict[str, pd.DataFrame]:
    """Рассчитывает те же итоговые срезы, что и аналитические SQL-запросы."""
    sales = clean.loc[clean["quantity"] > 0].copy()
    returns = clean.loc[clean["quantity"] < 0].copy()
    returns["return_amount"] = -returns["total_amount"]

    orders = (
        sales.groupby("transaction_no", as_index=False)
        .agg(
            order_amount=("total_amount", "sum"),
            total_quantity=("quantity", "sum"),
            product_lines=("product_no", "size"),
        )
    )

    country_sales = (
        sales.groupby("country", as_index=False)
        .agg(
            orders_count=("transaction_no", "nunique"),
            units_sold=("quantity", "sum"),
            gross_revenue=("total_amount", "sum"),
        )
        .sort_values(["gross_revenue", "country"], ascending=[False, True])
    )

    top_products = (
        sales.groupby(["product_no", "product_name"], as_index=False)
        .agg(
            units_sold=("quantity", "sum"),
            gross_revenue=("total_amount", "sum"),
        )
        .sort_values(
            ["gross_revenue", "product_no", "product_name"],
            ascending=[False, True, True],
        )
        .head(10)
    )

    sales["month"] = sales["transaction_date"].dt.to_period("M").dt.to_timestamp()
    last_month = sales["month"].max()
    monthly_sales = (
        sales.loc[sales["month"] < last_month]
        .groupby("month", as_index=False)
        .agg(
            orders_count=("transaction_no", "nunique"),
            gross_revenue=("total_amount", "sum"),
        )
        .sort_values("month")
    )

    top_returns = (
        returns.groupby(["product_no", "product_name"], as_index=False)
        .agg(
            returned_units=("quantity", lambda values: values.abs().sum()),
            return_amount=("return_amount", "sum"),
        )
        .sort_values(
            ["return_amount", "product_no", "product_name"],
            ascending=[False, True, True],
        )
        .head(10)
    )

    summary = pd.DataFrame(
        [
            ("raw_rows", len(raw)),
            ("clean_rows", len(clean)),
            ("sales_rows", len(sales)),
            ("return_rows", len(returns)),
            ("orders", len(orders)),
            ("gross_revenue", round(sales["total_amount"].sum(), 2)),
            ("return_amount", round(returns["return_amount"].sum(), 2)),
            ("net_amount", round(clean["total_amount"].sum(), 2)),
            ("average_order_value", round(orders["order_amount"].mean(), 2)),
        ],
        columns=["metric", "value"],
    )

    return {
        "summary_metrics": summary,
        "country_sales": country_sales,
        "top_products": top_products,
        "monthly_sales": monthly_sales,
        "top_returns": top_returns,
    }


def style_axes(ax: plt.Axes) -> None:
    """Применяет единый спокойный стиль ко всем графикам."""
    ax.spines[["top", "right"]].set_visible(False)
    ax.spines[["left", "bottom"]].set_color(GRID)
    ax.tick_params(colors=INK)
    ax.title.set_color(INK)


def add_subtitle(ax: plt.Axes, text: str) -> None:
    """Добавляет пояснение периода и правил расчёта под заголовком."""
    ax.text(
        0,
        1.01,
        text,
        transform=ax.transAxes,
        color="#52616B",
        fontsize=9,
        va="bottom",
    )


def save_charts(results: dict[str, pd.DataFrame]) -> None:
    """Сохраняет три статических графика для README."""
    IMAGES_DIR.mkdir(parents=True, exist_ok=True)

    monthly = results["monthly_sales"].copy()
    fig, ax = plt.subplots(figsize=(10, 5.4))
    ax.plot(
        monthly["month"],
        monthly["gross_revenue"] / 1_000_000,
        color=PRIMARY,
        marker="o",
        linewidth=2.4,
    )
    ax.set_title(
        "Динамика валовых продаж по месяцам", loc="left", weight="bold", pad=28
    )
    add_subtitle(
        ax,
        "Полные месяцы: декабрь 2018 — ноябрь 2019; возвраты исключены",
    )
    ax.set_ylabel("Валовые продажи, млн £")
    ax.set_xlabel("Месяц")
    ax.grid(axis="y", color=GRID, linewidth=0.8)
    style_axes(ax)
    fig.autofmt_xdate(rotation=35)
    fig.tight_layout()
    fig.savefig(IMAGES_DIR / "monthly_revenue.png", dpi=180, bbox_inches="tight")
    plt.close(fig)

    products = results["top_products"].sort_values("gross_revenue").copy()
    labels = products["product_name"].str.slice(0, 42)
    colors = [SECONDARY] * len(products)
    colors[-1] = PRIMARY
    fig, ax = plt.subplots(figsize=(10, 6.4))
    bars = ax.barh(
        labels,
        products["gross_revenue"] / 1_000,
        color=colors,
        edgecolor=PRIMARY,
    )
    ax.set_title(
        "Топ-10 товаров по валовым продажам", loc="left", weight="bold", pad=28
    )
    add_subtitle(ax, "Период: 01.12.2018–09.12.2019; возвраты исключены")
    ax.set_xlabel("Валовые продажи, тыс. £")
    ax.bar_label(bars, fmt="%.0f", padding=4, fontsize=8, color=INK)
    ax.margins(x=0.12)
    ax.grid(axis="x", color=GRID, linewidth=0.8)
    style_axes(ax)
    fig.tight_layout()
    fig.savefig(IMAGES_DIR / "top_products.png", dpi=180, bbox_inches="tight")
    plt.close(fig)

    countries = results["country_sales"].head(8).sort_values("gross_revenue").copy()
    colors = [SECONDARY] * len(countries)
    colors[-1] = PRIMARY
    fig, ax = plt.subplots(figsize=(10, 5.6))
    bars = ax.barh(
        countries["country"],
        countries["gross_revenue"] / 1_000_000,
        color=colors,
        edgecolor=PRIMARY,
    )
    ax.set_title(
        "Страны с наибольшими валовыми продажами",
        loc="left",
        weight="bold",
        pad=28,
    )
    add_subtitle(ax, "Период: 01.12.2018–09.12.2019; возвраты исключены")
    ax.set_xlabel("Валовые продажи, млн £")
    ax.bar_label(bars, fmt="%.2f", padding=4, fontsize=8, color=INK)
    ax.margins(x=0.11)
    ax.grid(axis="x", color=GRID, linewidth=0.8)
    style_axes(ax)
    fig.tight_layout()
    fig.savefig(IMAGES_DIR / "top_countries.png", dpi=180, bbox_inches="tight")
    plt.close(fig)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True, help="Путь к исходному CSV")
    args = parser.parse_args()

    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    raw, clean = load_and_prepare(args.csv)
    results = build_results(raw, clean)
    for name, frame in results.items():
        frame.to_csv(RESULTS_DIR / f"{name}.csv", index=False, encoding="utf-8")
    save_charts(results)

    print(results["summary_metrics"].to_string(index=False))
    print("\nTop countries:\n", results["country_sales"].head(5).to_string(index=False))
    print("\nTop products:\n", results["top_products"].head(5).to_string(index=False))
    print("\nTop returns:\n", results["top_returns"].head(5).to_string(index=False))


if __name__ == "__main__":
    main()
