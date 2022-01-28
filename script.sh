aws configure
## 2.1 Khởi tạo CMK
aws kms create-key
## alias
aws kms create-alias --alias-name alias/FirstCMK --target-key-id '6c91a371-9f46-403a-a5ee-1d98bbb1a9a5'
## 2.2 Khởi tạo CMK External
aws kms create-key --origin EXTERNAL
## make status=`Enabled`
aws kms get-parameters-for-import --key-id '9a4759db-03fc-44c0-a439-2fa2b77763d6'  --wrapping-algorithm RSAES_OAEP_SHA_1 --wrapping-key-spec RSA_2048
openssl enc -d -base64 -A -in pkey.b64 -out pkey.bin
openssl enc -d -base64 -A -in token.b64 -out token.bin
openssl rand -out genkey.bin 32
openssl rsautl -encrypt -in genkey.bin -oaep -inkey pkey.bin -keyform DER -pubin -out WrappedKeyMaterial.bin
aws kms import-key-material --key-id '9a4759db-03fc-44c0-a439-2fa2b77763d6' --encrypted-key-material fileb://WrappedKeyMaterial.bin --import-token fileb://token.bin --expiration-model KEY_MATERIAL_EXPIRES --valid-to 2022-09-01T12:00:00-08:00
## alias
aws kms create-alias --alias-name alias/ImportedCMK --target-key-id '9a4759db-03fc-44c0-a439-2fa2b77763d6'
aws kms list-aliases
## 2.3 Thực hiện Rotating AWS KMS CMK
aws kms enable-key-rotation --key-id '6c91a371-9f46-403a-a5ee-1d98bbb1a9a5'
## 2.4 Xóa bỏ AWS KMS CMKs
aws kms disable-key --key-id '6c91a371-9f46-403a-a5ee-1d98bbb1a9a5'
aws kms schedule-key-deletion --key-id '6c91a371-9f46-403a-a5ee-1d98bbb1a9a5' --pending-window-in-days 7
## 3.1 Cách hoạt động của Envelope Encryption trong thực tế
sudo echo "Sample Secret Text to Encrypt" > samplesecret.txt
aws kms generate-data-key --key-id alias/ImportedCMK --key-spec AES_256 --encryption-context project=workshop
->
{
    "Plaintext": "+rGaJQ/bTQ2L89U2RhNHEOMgqg3wew6CndkXX43/Xq4=", 
    "KeyId": "arn:aws:kms:us-east-1:<AWS_ACC_ID>:key/9a4759db-03fc-44c0-a439-2fa2b77763d6", 
    "CiphertextBlob": "AQIDAHh0ZG/y6qAJZH7jVnnj4zJnNlZZRkNeFThxM/UokNU5zQE3hOi8oUKTrN+iJ30UcCwyAAAAfjB8BgkqhkiG9w0BBwagbzBtAgEAMGgGCSqGSIb3DQEHATAeBglghkgBZQMEAS4wEQQMN8VlyXG78Cgg5/LDAgEQgDsZcD6KkRl4+wd1tRPTXVhdEdnG2AolsXH3N0o9LV1IoYdB2C1h5xRun/UD0ArWFjuW8Aq46UWB6LG7ag=="
}
echo '+rGaJQ/bTQ2L89U2RhNHEOMgqg3wew6CndkXX43/Xq4=' | base64 --decode > datakeyPlainText.txt
echo 'AQIDAHh0ZG/y6qAJZH7jVnnj4zJnNlZZRkNeFThxM/UokNU5zQE3hOi8oUKTrN+iJ30UcCwyAAAAfjB8BgkqhkiG9w0BBwagbzBtAgEAMGgGCSqGSIb3DQEHATAeBglghkgBZQMEAS4wEQQMN8VlyXG78Cgg5/LDAgEQgDsZcD6KkRl4+wd1tRPTXVhdEdnG2AolsXH3N0o9LV1IoYdB2C1h5xRun/UD0ArWFjuW8Aq46UWB6LG7ag==' | base64 --decode > datakeyEncrypted.txt
ls
->
WrappedKeyMaterial.bin  datakeyEncrypted.txt  datakeyPlainText.txt  genkey.bin  pkey.b64  pkey.bin  samplesecret.txt  token.b64  token.bin
## 3-mã-hóa-file-text-encryptedSecret
openssl enc -e -aes256 -in samplesecret.txt -out encryptedSecret.txt -k fileb://datakeyPlainText.txt
cat encryptedSecret.txt
-> "Sample Secret Text to Encrypt" is encrypted
## 4-giải-mã-file-text-encryptedSecret
aws kms  decrypt --encryption-context project=workshop --ciphertext-blob fileb://datakeyEncrypted.txt
->
{
    "Plaintext": "+rGaJQ/bTQ2L89U2RhNHEOMgqg3wew6CndkXX43/Xq4=", 
    "EncryptionAlgorithm": "SYMMETRIC_DEFAULT", 
    "KeyId": "arn:aws:kms:us-east-1:<AWS_ACC_ID>:key/9a4759db-03fc-44c0-a439-2fa2b77763d6"
}
echo '+rGaJQ/bTQ2L89U2RhNHEOMgqg3wew6CndkXX43/Xq4=' | base64 --decode > datakeyPlainText.txt
openssl enc -d -aes256 -in encryptedSecret.txt -k fileb://datakeyPlainText.txt
-> "Sample Secret Text to Encrypt"
## mã-hóa-với-aws-kms--không-sử-dụng-data-key
## encrypt
echo "New secret text" > NewSecretFile.txt
aws kms encrypt --key-id alias/ImportedCMK --plaintext fileb://NewSecretFile.txt --encryption-context project=kmsworkshop --output text  --query CiphertextBlob | base64 --decode > NewSecretsEncryptedFile.txt
cat NewSecretsEncryptedFile.txt
-> "New secret text" is encrypted
## decrypt
aws kms decrypt --ciphertext-blob fileb://NewSecretsEncryptedFile.txt --encryption-context project=kmsworkshop --output text --query Plaintext | base64 --decode
-> "New secret text"

## 4.1 CÀI ĐẶT WEB APP
pwd
-> /home/ec2-user
sudo easy_install pip
pip3 --version
-> pip 20.2.2 from /usr/lib/python3.7/site-packages/pip (python 3.7)
sudo pip3 install boto3
sudo mkdir SampleWebApp
cd SampleWebApp
sudo wget  https://raw.githubusercontent.com/aws-samples/aws-kms-workshop/master/WebApp.py
sudo curl http://169.254.169.254/latest/meta-data/public-ipv4/
-> 34.203.247.236 # same with IPv4 of `DTQEC2KMSDemo`
sudo python3 WebApp.py 80
-> Serving HTTP on 0.0.0.0 port 8000 (http://0.0.0.0:8000/) ...
