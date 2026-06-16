# killsuru

`kill` コマンドを実行してプロセスの終了に成功したとき、ターミナルに **SUSURUTV のアスキーアート** を表示するパッケージです。Ubuntu などの Debian 系 Linux 向け。名前は `kill` + すする → **killsuru**。

```
$ kill 12345
  ( SUSURUTV のアスキーアートが表示される )
```

## 仕組み（安全設計）

- 実体の `/bin/kill` は **一切書き換えません**。`kill()` という **シェル関数** を定義して上書きし、内部では `builtin kill`（dash では `command kill`）で本物を呼びます。アンインストールすれば完全に元通り。
- **対話シェルのみ** で有効化されるため、シェルスクリプト内の `kill` には影響しません（`case "$-"` で対話判定）。
- 対応シェル: **bash / zsh**（POSIX sh ログインシェルでも安全に読み込まれます）。

### 有効化の経路

| ファイル | 対象 |
|---|---|
| `/etc/profile.d/killsuru.sh` | ログインシェル（SSH / TTY の bash・sh） |
| `/etc/bash.bashrc`（管理ブロックを追記） | デスクトップ端末などの非ログイン対話 bash |
| `/etc/zsh/zshrc`（管理ブロックを追記） | 対話 zsh |

`/etc/bash.bashrc` と `/etc/zsh/zshrc` への追記は、明示マーカー付きの「管理ブロック」として行い、パッケージ削除時（`postrm`）にきれいに取り除きます。

## アスキーアートの差し替え

アートは実行ファイルから分離してあります。

- システム全体: `/usr/share/killsuru/art.txt`
- ユーザー個別（優先）: `~/.config/killsuru/art.txt`

配布物を変更する場合は `src/usr/share/killsuru/art.txt` を編集して再ビルドしてください。

### 環境変数

| 変数 | 効果 |
|---|---|
| `KILLSURU_DISABLE=1` | 表示を抑止 |
| `KILLSURU_COLOR=N` | カラー端末での `tput` 色番号（既定 `1` = 赤） |

## ビルド（.deb）

Debian / Ubuntu 上で:

```sh
sudo apt install build-essential debhelper devscripts
make deb           # = dpkg-buildpackage -us -uc -b
sudo apt install ../killsuru_0.1.0_all.deb
```

新しいシェルを開けば有効になります（または `source /usr/share/killsuru/killsuru.sh`）。

## ビルドせずに試す

```sh
sudo make install      # ファイル配置 + rc 配線
# ... 動作確認 ...
sudo make uninstall    # 元に戻す
```

## 構文チェック

```sh
make check             # sh -n / bash -n で全スクリプトを検査
```

## アンインストール

```sh
sudo apt remove killsuru
```

`/etc/bash.bashrc` と `/etc/zsh/zshrc` の管理ブロックも自動で除去されます。

## ディレクトリ構成

```
killsuru/
├── debian/                       # パッケージ定義（native, debhelper-compat 13）
│   ├── control  changelog  rules  install  copyright
│   ├── postinst  postrm           # rc ファイルへの配線 / 撤去
│   └── source/format
├── src/
│   ├── usr/bin/killsuru           # アート表示ヘルパー（POSIX sh）
│   ├── usr/share/killsuru/
│   │   ├── killsuru.sh            # 共有 kill() 関数（bash & zsh）
│   │   └── art.txt               # SUSURUTV アスキーアート（差し替え対象）
│   └── etc/profile.d/killsuru.sh  # ログインシェル用フック
├── Makefile  README.md  LICENSE
```

## ライセンス

MIT
