# SQLite-Simple

sqlite3 を簡単に利用するための簡易的なデータベース管理モジュール

## Memo

```zsh
h2xs -AX --skip-exporter -n SQLite::Simple

mv -n SQLite-Simple/* .
rm -r SQLite-Simple

echo 'local' >> .gitignore

echo '5.34.1' > .perl-version
echo "requires 'DBD::SQLite', '1.70';" >> cpanfile
echo "requires 'Text::CSV', '2.01';" >> cpanfile

curl -L https://cpanmin.us/ -o cpanm
chmod +x cpanm
./cpanm -l ./local --installdeps .

cp ~/github/zsearch-api/t/simple.t ~/github/SQLite-Simple/t
cp ~/github/zsearch-api/t/test.sql ~/github/SQLite-Simple/t
cp ~/github/zsearch-api/t/test.csv ~/github/SQLite-Simple/t

# 実装コードとテストコード調整してから

prove
```
