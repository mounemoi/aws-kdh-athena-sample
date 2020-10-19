# aws-kdh-athena-sample

このサンプルでは、Lambda (Python 3.8) から分析用ログ(JSON)を [Kinesis Data Firehose](https://aws.amazon.com/jp/kinesis/data-firehose/) に送信し S3 に保存を行った後、そのログに対して [Athena](https://aws.amazon.com/jp/athena/) で分析を行うという一連の操作を行います。

## 手順1. S3 バケットを作成

分析用ログファイルを格納する S3 バケットを作成します。

## 手順2. Kineiss Data Firehose を作成

AWSコンソールより、以下の手順で Kinesis Data Fireose を作成します。

1. AWSコンソールより **[サービス]** → **[Kinesis]** を選択
2. 今すぐ始めるから **[Kinsis Data Firehose]** を選択し **[配信ストリームを作成]** を選択
3. Step1: Name and source にて **[Delivery stream name]** に任意の Stream 名を入力し **[Next]** を選択
4. Step2: Process records にて **[Next]** を選択
5. Step3: Choose a destination にて Destination に Amazon S3 が選択されていることを確認し、**[S3 destination]** の **[S3 bucket]** に、**手順1** で作成した S3 バケットを選択
6. **[S3 prefix]** に、任意の Prefix を入力します ( Prefix の末尾には必ず `/` を入れること ex. `test-table/` )
7. Step4: Configure settings にて、**[S3 buffer conditions]** にて **[Buffer interval]** を `60` seconds に変更 (※1)
8. **[S3 compression and encryption]** にて、**[S3 compression]** を `GZIP` に (※2)
9. **[Next]** を選択
10. Step:5 Review で入力を確認し **[Create delivery stream]** を選択

※1 **[Buffer interval]** では S3 にファイルを出力する Interval を設定します。ここでは動作確認がしやすいように `60 seconds` を選択しています

※2 S3, Athena の利用料金削減のために `GSIP` を選択し、ファイルを圧縮しています

これで、手順1 で作成した S3 にログを書き込む Kinsis Data Firehose の準備ができました。

## 手順3. Lambda の作成

Kineis Data Firehose 分析用ログを送信するための Lambda を作成します。

この手順ではサンプルコードを用いて Lambda を作成し、**手順2** で作成を行った Kineis Data Firehose への書き込み権限を Lambda に付与しています。

用意されているサンプルコードでは、分析用ログを1秒おきに600回(合計10分間)出力し、ログは以下のフォーマットとしています。

```
{ create_time: [TIMESTAMP], user_name: [文字列], point: [0-100までの数値] }
```

1. AWSコンソールより **[サービス]** → **[Lambda]** を選択
2. **[関数の作成]** を選択
3. **[関数名]** に任意の名前を入力、**[ランタイム]** を `Python 3.8` を選択した後 **[関数の作成]** を選択
4. 次に表示される関数の詳細画面で **[関数コード]** に [こちら](sample.py) のコードをコピペします。この時、コードの中の変数 `KDH_STREAM_NAME` を **手順2** で作成したストリーム名に変更します
5. **[Deploy]** を選択します
6. **[基本設定]** の **[編集]** をクリック、**[タイムアウト]** を `11分` とします
7. 関数の **[アクセス権限]** タブを選択、実行ロールの `関数名-role-xxxx` を選択
8. 選択したロールの IAM 設定画面に遷移するので、**[ポリシーをアタッチします]** を選択
9.  **[AmazonKinesisFirehoseFullAccess]** を選択し、**[ポリシーのアタッチ]** を選択します

これで Lambda の準備ができました。次の手順で動作確認とログ出力を行います。

1. 作成を行った関数の詳細画面で **[テスト]** を選択
2. ポップアップ画面で **[イベント名]** に任意の名前を入力し **[作成]** を選択します
3. **[テスト]** の左のプルダウンに 2 で入力したイベント名になっていることを確認し、**[テスト]** を選択します
4. これで、**手順1** の S3 に対して `60秒` おきにログファイルが出力されているはずです。念の為にファイルが出力されていることを確認します

## 手順4. Athena の実行

これまでの手順で **手順1** で作成した S3 にログが記録されるようになりました。このログに対して Athena を用いて SQL で分析します。

まず、S3 上のログをソースとしてテーブルの作成を行います。

1. AWSコンソールより **[サービス]** → **[Athena]** を選択
2. **[今すぐ始める]** を選択
3. **クエリエディタ** において [こちら](DDL.sql) の SQL をコピペします。この SQL の `L12`, `L21` にて **手順1** で作成を行った S3 Bucket 名(サンプルでは `example-kdh-athena-20201013` )、**手順2** で指定を行った Prefix (サンプルでは `test-table/` )を指定しているので、適宜書き換えます。
4. **[クエリの実行]** を選択し、直下の **結果** 欄にクエリは成功した旨のメッセージが表示されれば、テーブル作成は完了です。

このテーブルに対してクエリを実行してみます。

**<< Point >>**

- テーブルは `datahour` (`YYYY/MM/DD/HH`) でパーティショニングされているので、このカラムを活用することで分析対象データを効率的に絞り込むことができます
- `datahour` は JST ではなく UTC であることに注意してください

**<< クエリ例 >>**

user_name 毎にログ行数の COUNT と point の合計値(SUM)を集計 (2020年10月分(JST))
```
SELECT
  user_name, COUNT(user_name), SUM(point)
FROM
  test
WHERE datehour >=  '2020/10/01/09' AND datehour <= '2020/11/01/08'
GROUP BY user_name
ORDER BY user_name
```