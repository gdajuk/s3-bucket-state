# S3 BUCKET STATE

In this repository, you'll find a script which configures the AWS S3 backend to store terraform state files. Script do not take any arguments, so there 3 variables to set before usage:
```
bucket_name = Bucket name
profile     = AWS profile
region      = AWS region
```
Please note, that bucket name can be between 3 and 63 characters long, and can contain only lower-case characters, numbers, periods, and dashes. Each label in the bucket name must start with a lowercase letter or number. You need to use a unique bucket name when creating S3 bucket. All those 3 variables can be customized. Otherwise default one will be used.  

To execute the script, simply run it:
```
./create_bucket.sh
```