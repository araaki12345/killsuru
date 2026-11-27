# killsuru

`kill` でプロセスの終了に成功すると、ターミナルに SUSURUTV のアスキーアートを表示します。

```
$ kill 12345
  ( SUSURUTV のアスキーアートが表示されます )
```

## 対応環境

| OS | シェル | 状態 |
|---|---|---|
| Linux / WSL | bash、zsh、PowerShell | CI でテスト済み |
| macOS | bash、zsh、PowerShell | CI でテスト済み |
| Windows | PowerShell 5.1 / 7 以降 | CI でテスト済み |
| Windows | Git Bash / MSYS2 | 未テスト |
| FreeBSD などの BSD | bash、zsh | 未テスト |

Windows の cmd と fish には対応していません。外部への依存はありません。

## インストール

いずれもユーザー単位で入り、管理者権限は不要です。インストール後に新しいシェルを開くと有効になります。

### Linux / macOS / WSL / Git Bash

```sh
curl -fsSL https://raw.githubusercontent.com/araaki12345/killsuru/main/install.sh | sh
```

### Windows（PowerShell）

```powershell
irm https://raw.githubusercontent.com/araaki12345/killsuru/main/install.ps1 | iex
```

- Windows PowerShell 5.1 と PowerShell 7 の両方でお使いの場合は、それぞれで実行してください。
- 実行ポリシーが `Restricted` の場合はプロファイルが読み込まれません。インストーラが警告を表示しますので、次を実行してください。

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

### Debian / Ubuntu（全ユーザー向け、.deb）

[Releases](https://github.com/araaki12345/killsuru/releases/latest) の `.deb` をお使いください。

```sh
VER=0.2.0
curl -LO "https://github.com/araaki12345/killsuru/releases/download/v${VER}/killsuru_${VER}_all.deb"
sudo apt install "./killsuru_${VER}_all.deb"
```

## アンインストール

| インストール方法 | コマンド |
|---|---|
| install.sh | `curl -fsSL https://raw.githubusercontent.com/araaki12345/killsuru/main/install.sh \| sh -s uninstall` |
| install.ps1 | `$env:KILLSURU_UNINSTALL = '1'; irm https://raw.githubusercontent.com/araaki12345/killsuru/main/install.ps1 \| iex` |
| .deb | `sudo apt remove killsuru` |

リポジトリを clone 済みの場合は、`make install` / `make uninstall`、または `.\install.ps1` / `.\install.ps1 -Uninstall` もお使いいただけます。

## カスタマイズ

### アスキーアートの差し替え

`~/.config/killsuru/art.txt` を置くと、そちらが優先して表示されます。

### 環境変数

| 変数 | 効果 |
|---|---|
| `KILLSURU_DISABLE=1` | アートを表示しません |
| `KILLSURU_COLOR=N` | ANSI 色番号を指定します（既定は `1` = 赤、0〜255） |
| `NO_COLOR` | 設定されていると色を付けません |

### インストーラの設定

| 変数 | 対象 | 効果 |
|---|---|---|
| `KILLSURU_NO_RC=1` | 共通 | 設定ファイルを編集しません（読み込み行はご自身で追加してください） |
| `KILLSURU_REF` | 共通 | 取得するブランチ / タグ（既定は `main`） |
| `PREFIX` | install.sh | インストール先（既定は `$HOME/.local`） |
| `KILLSURU_HOME` | install.ps1 | インストール先（既定は `%LOCALAPPDATA%\killsuru`） |

設定ファイルをご自身で管理される場合は、次の 1 行を追加してください。

```sh
eval "$(killsuru init)"                            # bash / zsh / sh
```

```powershell
. "$env:LOCALAPPDATA\killsuru\killsuru.ps1"        # PowerShell
```

## 仕組み

本物の `kill` には手を加えず、シェル側で薄く包んでいます。

- **bash / zsh / sh**: `kill()` というシェル関数を定義し、内部でシェル組み込みの `kill` を呼びます。終了コードが 0 のときだけアートを表示します。
- **PowerShell**: Windows の `kill` は `Stop-Process` のエイリアスです。これをラッパー関数に向け直し、引数とパイプライン入力をそのまま `Stop-Process` に渡します。Linux / macOS ではネイティブの `kill` を呼びます。

どちらも対話シェルでのみ有効になり、スクリプト内の `kill` には影響しません。

インストーラは、次のファイルにマーカー付きのブロックを 1 つ追記します。アンインストール時には同じブロックを削除します。

| インストール方法 | 追記先 |
|---|---|
| install.sh | `~/.zshrc`、`~/.bashrc`（macOS と Git Bash では `~/.bash_profile` なども） |
| install.ps1 | `$PROFILE.CurrentUserAllHosts` |
| .deb | `/etc/bash.bashrc`、`/etc/zsh/zshrc`（加えて `/etc/profile.d/killsuru.sh` を配置） |

### Windows での注意

PowerShell の `kill` は Unix の `kill` と構文が異なります。

- シグナル指定（`kill -9 1234`）はできません。
- 複数の PID はカンマで区切ります（`kill 1234, 5678`）。
- 名前で指定する場合は `kill -Name notepad` と書きます。
- `taskkill` や、`Stop-Process` を直接呼んだ場合はアートを表示しません。

## 開発

```sh
make check                              # 構文チェック（sh / bash / zsh）
make test                               # bash / zsh / dash の E2E テスト
pwsh -NoProfile -File tests/test.ps1    # PowerShell の E2E テスト
make deb                                # .deb のビルド（Debian / Ubuntu）
```

```
killsuru/
├── bin/killsuru              # アート表示コマンド（POSIX sh）
├── share/killsuru/
│   ├── killsuru.sh           # kill() 関数（bash / zsh / sh）
│   ├── killsuru.ps1          # kill ラッパー（PowerShell）
│   └── art.txt               # アスキーアート
├── install.sh  install.ps1   # インストーラ
├── tests/                    # E2E テスト
└── debian/                   # .deb パッケージ定義
```

## ライセンス

MIT
