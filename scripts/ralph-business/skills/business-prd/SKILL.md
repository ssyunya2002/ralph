---
name: business-prd
description: "ビジネスタスク用PRDを生成する。リサーチ、レポート作成、戦略立案などの非コーディングタスクに対応。Triggers on: ビジネスprd作成, business prd, タスク計画, 調査計画"
user-invocable: true
---

# Business PRD Generator

ビジネスタスク用のPRD（タスク定義）を生成する。

---

## The Job

1. ユーザーからプロジェクト概要を受け取る
2. 3-5個の明確化質問をする（選択肢付き）
3. 回答をもとに構造化されたprd.jsonを生成
4. `prd.json` として保存

**重要:** 実装は開始しない。PRD作成のみ。

---

## Step 1: 明確化質問

以下の観点で質問:

- **目的**: このプロジェクトで達成したいこと
- **アウトプット**: 最終成果物の形式
- **スコープ**: 含めること/含めないこと
- **期限・優先度**: 時間的制約

### 質問フォーマット例:

```
1. このプロジェクトの主な目的は？
   A. 市場調査・競合分析
   B. 戦略立案・計画作成
   C. レポート・ドキュメント作成
   D. 実行・アクション（SNS投稿等）
   E. その他: [具体的に]

2. 最終アウトプットの形式は？
   A. 調査レポート（.md）
   B. 提案書・企画書
   C. 実行計画書
   D. 複数の成果物（調査→分析→計画）
```

ユーザーは「1A, 2D」のように簡潔に回答可能。

---

## Step 2: タスク分解

プロジェクトを以下のタスクタイプに分解:

### taskType一覧

| taskType | 用途 | 典型的なアウトプット |
|----------|------|---------------------|
| research | Web調査・情報収集 | 調査レポート、競合分析 |
| document | ドキュメント作成 | 提案書、マニュアル |
| analysis | データ分析 | SWOT分析、数値分析 |
| planning | 戦略・計画立案 | 実行計画、ロードマップ |
| execution | 実行タスク | SNS投稿、メール送信 |

### タスクサイズのルール

**1タスク = 1イテレーションで完了可能なサイズ**

良いサイズ:
- 競合3社の価格調査
- SWOT分析の作成
- 月次レポートの作成

大きすぎる（分割が必要）:
- 「市場調査全般」→ 競合調査、顧客調査、トレンド調査に分割
- 「マーケ戦略策定」→ 調査、分析、戦略立案、実行計画に分割

---

## Step 3: prd.json生成

### スキーマ

```json
{
  "project": "プロジェクト名（日本語OK）",
  "projectName": "project-name-kebab",
  "description": "プロジェクト概要",
  "outputDir": "./outputs",
  "tasks": [
    {
      "id": "BT-001",
      "taskType": "research",
      "title": "タスクタイトル",
      "description": "詳細な説明",
      "acceptanceCriteria": [
        "検証可能な完了条件1",
        "検証可能な完了条件2",
        "outputs/{outputFileName} に保存"
      ],
      "outputDestination": "local",
      "outputFileName": "BT-001-ファイル名.md",
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

### acceptanceCriteriaのパターン

**research:**
- 「情報源を{N}つ以上引用」
- 「各項目に根拠データを記載」
- 「結論を{N}字以内で要約」

**document:**
- 「目次・要約・本文を含む」
- 「{N}ページ相当の分量」
- 「指定フォーマットに従う」

**analysis:**
- 「{前のタスクID}の成果物を参照」
- 「各項目に根拠を記載」
- 「表形式でまとめる」

**planning:**
- 「月別/週別のマイルストーンを定義」
- 「KPIを{N}つ以上設定（数値目標付き）」
- 「アクションアイテムを{N}個以上」

**execution:**
- 「実行結果をスクリーンショット」
- 「完了を確認」

### outputDestination

- `local` - ./outputs/ に保存（デフォルト）
- `obsidian` - Obsidian FleetingNoteに保存
- `notion` - Notion MCPで保存

---

## Example

**Input:**
> Q2の売上目標達成のために、競合分析して戦略を立てたい

**Output prd.json:**

```json
{
  "project": "Q2セールス強化",
  "projectName": "q2-sales-boost",
  "description": "Q2売上目標達成のための競合分析・戦略立案",
  "outputDir": "./outputs",
  "tasks": [
    {
      "id": "BT-001",
      "taskType": "research",
      "title": "競合価格調査",
      "description": "主要競合の価格帯・割引戦略を調査",
      "acceptanceCriteria": [
        "価格帯を表形式でまとめる",
        "情報源を5つ以上引用",
        "outputs/BT-001-競合価格.md に保存"
      ],
      "outputDestination": "local",
      "outputFileName": "BT-001-競合価格.md",
      "priority": 1,
      "passes": false,
      "notes": ""
    },
    {
      "id": "BT-002",
      "taskType": "analysis",
      "title": "SWOT分析",
      "description": "BT-001をもとにSWOT分析",
      "acceptanceCriteria": [
        "BT-001の成果物を参照",
        "各象限3項目以上",
        "outputs/BT-002-SWOT.md に保存"
      ],
      "outputDestination": "local",
      "outputFileName": "BT-002-SWOT.md",
      "priority": 2,
      "passes": false,
      "notes": ""
    },
    {
      "id": "BT-003",
      "taskType": "planning",
      "title": "Q2戦略立案",
      "description": "分析結果をもとに戦略策定",
      "acceptanceCriteria": [
        "BT-001, BT-002を踏まえる",
        "月別マイルストーン定義",
        "KPIを3つ以上設定",
        "outputs/BT-003-戦略.md に保存"
      ],
      "outputDestination": "local",
      "outputFileName": "BT-003-戦略.md",
      "priority": 3,
      "passes": false,
      "notes": ""
    }
  ]
}
```

---

## Checklist

prd.json保存前に確認:

- [ ] 各タスクが1イテレーションで完了可能なサイズ
- [ ] タスクが依存順に並んでいる（調査→分析→計画）
- [ ] acceptanceCriteriaが検証可能（曖昧でない）
- [ ] outputFileNameが各タスクに設定されている
- [ ] priorityが依存関係を反映している
