mkdir -p package
pip install -r lambda/requirements.txt --target package
cd package
cp ../lambda/lambda_handler.py .
zip -r ../lambda.zip .