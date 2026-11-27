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

3 ステップで使えるようになります。管理者権限は不要です。

### 1. インストールする

お使いの環境に合わせて、どれか 1 つを実行してください。

**Linux / macOS / WSL / Git Bash**

```sh
curl -fsSL https://raw.githubusercontent.com/araaki12345/killsuru/main/install.sh | sh
```

**Windows（PowerShell）**

```powershell
irm https://raw.githubusercontent.com/araaki12345/killsuru/main/install.ps1 | iex
```

### 2. ターミナルを開き直す

新しいターミナル（タブやウィンドウ）を開いてください。開き直すまでは有効になりません。

### 3. 試してみる

適当なプロセスを起動して `kill` します。アスキーアートが表示されれば成功です。

**bash / zsh**

```sh
sleep 100 &
kill $!
```

**PowerShell（Windows）**

```powershell
$p = Start-Process notepad -PassThru
kill $p.Id
```

### うまくいかないとき

- **Windows で何も表示されない**: 実行ポリシーが `Restricted` だと設定が読み込まれません。次を実行してから、ターミナルを開き直してください。

  ```powershell
  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
  ```

- **Windows PowerShell 5.1 と PowerShell 7 の両方で使いたい**: 設定ファイルが別々のため、それぞれで手順 1 を実行してください。
- **スクリプトの中では表示されない**: 仕様です。対話的に `kill` と入力したときだけ表示します。

### Debian / Ubuntu で全ユーザーに入れる場合（.deb）

上の方法の代わりに、[Releases](https://github.com/araaki12345/killsuru/releases/latest) の `.deb` もお使いいただけます。

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
