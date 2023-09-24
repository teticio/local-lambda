FROM public.ecr.aws/lambda/python:3.11
COPY lambda_function.py /var/task
CMD [ "lambda_function.lambda_handler" ]
