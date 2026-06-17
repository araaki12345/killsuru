# killsuru

`kill` でプロセスの終了に成功したとき、ターミナルに SUSURUTV のアスキーアートを表示する。Ubuntu などの Debian 系 Linux 向け

```
$ kill 12345
  ( SUSURUTV のアスキーアートが表示される )
```

## インストール

[Releases](https://github.com/araaki12345/killsuru/releases/latest) から `.deb` を入れる。

```sh
curl -LO https://github.com/araaki12345/killsuru/releases/tag/v0.1.0
sudo apt install ./killsuru_0.1.0_all.deb
exec bash        # 新しいシェルで読み込む（zsh なら exec zsh）
```

削除:

```sh
sudo apt remove killsuru
```

## 仕組み

`kill()` というシェル関数を定義し、内部では `builtin kill`（dash では `command kill`）を呼ぶ。終了コードが 0 のとき `killsuru` コマンドでアートを表示する。`/bin/kill` 自体は変更しない。

関数は対話シェルでのみ定義される（`case "$-"` で判定）。シェルスクリプト内の `kill` は素のまま動く。対応シェルは bash と zsh。POSIX sh のログインシェルからも読み込まれる。

### 読み込み経路

| ファイル | 対象 |
|---|---|
| `/etc/profile.d/killsuru.sh` | ログインシェル（SSH / TTY の bash・sh） |
| `/etc/bash.bashrc` | 非ログインの対話 bash |
| `/etc/zsh/zshrc` | 対話 zsh |

`/etc/bash.bashrc` と `/etc/zsh/zshrc` へはマーカー付きのブロックを追記し、パッケージ削除時（`postrm`）に同じブロックを削除する。

## アスキーアートの差し替え

アートは実行ファイルと別ファイルにしてある。

- システム全体: `/usr/share/killsuru/art.txt`
- ユーザー個別（優先）: `~/.config/killsuru/art.txt`

配布物を変更するときは `src/usr/share/killsuru/art.txt` を編集して再ビルドする。

### 環境変数

| 変数 | 効果 |
|---|---|
| `KILLSURU_DISABLE=1` | 表示しない |
| `KILLSURU_COLOR=N` | カラー端末での `tput` 色番号（既定 `1` = 赤） |

## ビルド（.deb）

Debian / Ubuntu 上で:

```sh
sudo apt install build-essential debhelper devscripts dpkg-dev
make deb           # = dpkg-buildpackage -us -uc -b
sudo apt install ../killsuru_0.1.0_all.deb
```

## ビルドせずに試す

```sh
sudo make install      # ファイル配置と rc への追記
sudo make uninstall    # 取り消し
```

## 構文チェック

```sh
make check             # sh -n / bash -n
```

## ディレクトリ構成

```
killsuru/
├── debian/                       # パッケージ定義（native, debhelper-compat 13）
│   ├── control  changelog  rules  install  copyright
│   ├── postinst  postrm           # rc ファイルへの追記 / 削除
│   └── source/format
├── src/
│   ├── usr/bin/killsuru           # アート表示コマンド（POSIX sh）
│   ├── usr/share/killsuru/
│   │   ├── killsuru.sh            # kill() 関数（bash & zsh）
│   │   └── art.txt               # SUSURUTV アスキーアート
│   └── etc/profile.d/killsuru.sh  # ログインシェル用
├── Makefile  README.md  LICENSE
```

## ライセンス

MIT
