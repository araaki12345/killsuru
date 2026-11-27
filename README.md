# killsuru

`kill` でプロセスの終了に成功したとき、ターミナルに SUSURUTV のアスキーアートを表示する。

```
$ kill 12345
  ( SUSURUTV のアスキーアートが表示される )
```

## 対応環境

POSIX sh だけで書いてあり、外部依存はない。

| OS | 状態 |
|---|---|
| Linux（ディストリ不問） / WSL | CI でテスト済み（Ubuntu） |
| macOS | CI でテスト済み |
| FreeBSD などの BSD | 動くはず（未テスト） |
| Windows の Git Bash / MSYS2 | 動くはず（未テスト） |
| Windows の PowerShell / cmd | 非対応 |

対応シェルは bash と zsh。dash などの POSIX sh でも `eval "$(killsuru init)"` で使える。fish は非対応。

## インストール

### どの OS でも（ユーザー単位、root 不要）

```sh
curl -fsSL https://raw.githubusercontent.com/araaki12345/killsuru/main/install.sh | sh
exec $SHELL        # 新しいシェルで読み込む
```

`~/.local` 以下にファイルを置き、`~/.zshrc` / `~/.bashrc`（macOS と Git Bash では `~/.bash_profile` なども）にマーカー付きのブロックを 1 つ追記する。

リポジトリを clone 済みなら:

```sh
make install       # = sh install.sh
```

削除:

```sh
make uninstall     # = sh install.sh uninstall
```

clone していない場合は:

```sh
curl -fsSL https://raw.githubusercontent.com/araaki12345/killsuru/main/install.sh | sh -s uninstall
```

| 環境変数 | 効果 |
|---|---|
| `PREFIX` | インストール先（既定 `$HOME/.local`） |
| `KILLSURU_NO_RC=1` | rc ファイルを編集しない（自分で 1 行足す） |
| `DESTDIR` | パッケージャ用のステージング先（rc は編集しない） |
| `KILLSURU_REF` | ダウンロードするブランチ / タグ（既定 `main`） |

rc ファイルを自分で管理したい場合は、次の 1 行を足せばよい。

```sh
eval "$(killsuru init)"
```

### Debian / Ubuntu（システム全体、.deb）

[Releases](https://github.com/araaki12345/killsuru/releases/latest) から `.deb` を入れる。全ユーザーの対話シェルで有効になる。

```sh
VER=0.2.0
curl -LO "https://github.com/araaki12345/killsuru/releases/download/v${VER}/killsuru_${VER}_all.deb"
sudo apt install "./killsuru_${VER}_all.deb"
exec bash        # 新しいシェルで読み込む（zsh なら exec zsh）
```

削除:

```sh
sudo apt remove killsuru
```

## 仕組み

`kill()` というシェル関数を定義し、内部では `builtin kill`（dash では `command kill`）を呼ぶ。終了コードが 0 のとき `killsuru` コマンドでアートを表示する。`/bin/kill` 自体は変更しない。

関数は対話シェルでのみ定義される（`case "$-"` で判定）。シェルスクリプト内の `kill` は素のまま動く。

`killsuru` コマンドは自分自身の場所から `../share/killsuru/` を探すので、どの prefix（`~/.local`、`/usr`、`/usr/local`、`/opt/homebrew` …）に置いても動く。`killsuru init` は自分の絶対パスを埋め込んだ読み込み用コードを出力するため、`PATH` に入っていなくてもフックは動く。

### 読み込み経路

install.sh（ユーザー単位）:

| ファイル | 対象 |
|---|---|
| `~/.zshrc`（`$ZDOTDIR` 対応） | 対話 zsh |
| `~/.bashrc` | 対話 bash |
| `~/.bash_profile` / `~/.bash_login` / `~/.profile` の最初にあるもの | macOS・Git Bash のログイン bash |

存在するファイル、またはログインシェル（`$SHELL`）のものだけを対象にする。

.deb（システム全体）:

| ファイル | 対象 |
|---|---|
| `/etc/profile.d/killsuru.sh` | ログインシェル（SSH / TTY の bash・sh） |
| `/etc/bash.bashrc` | 非ログインの対話 bash |
| `/etc/zsh/zshrc` | 対話 zsh |

どちらもマーカー付きのブロックを追記し、アンインストール時に同じブロックを削除する。

## アスキーアートの差し替え

アートは実行ファイルと別ファイルにしてある。

- 既定: `<prefix>/share/killsuru/art.txt`
- ユーザー個別（優先）: `~/.config/killsuru/art.txt`

`killsuru path` で実際に使われるファイルを確認できる。配布物を変更するときは `share/killsuru/art.txt` を編集する。

### 環境変数

| 変数 | 効果 |
|---|---|
| `KILLSURU_DISABLE=1` | 表示しない |
| `KILLSURU_COLOR=N` | 端末での ANSI 色番号（既定 `1` = 赤、0〜255） |
| `NO_COLOR` | 設定されていれば色を付けない |

## 開発

```sh
make check         # sh -n / bash -n / zsh -n
make test          # 使い捨ての HOME にインストールして bash / zsh / dash で実際に kill する
```

### .deb のビルド

Debian / Ubuntu 上で:

```sh
sudo apt install build-essential debhelper devscripts dpkg-dev
make deb           # = dpkg-buildpackage -us -uc -b
sudo apt install ../killsuru_0.2.0_all.deb
```

## ディレクトリ構成

```
killsuru/
├── bin/killsuru                   # アート表示コマンド（POSIX sh）
├── share/killsuru/
│   ├── killsuru.sh                # kill() 関数（bash / zsh / sh）
│   └── art.txt                    # SUSURUTV アスキーアート
├── install.sh                     # OS 共通のユーザー単位インストーラ
├── tests/test.sh                  # E2E テスト
├── debian/                        # .deb パッケージ定義（native, debhelper-compat 13）
│   ├── control  changelog  rules  install  copyright
│   ├── postinst  postrm           # システム rc ファイルへの追記 / 削除
│   └── profile.d/killsuru.sh      # ログインシェル用
├── Makefile  README.md  LICENSE
```

## ライセンス

MIT
