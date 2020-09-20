# Deploy Cloud Function used by GCE Pusher solution

The Cloud Function is a simple HTTP trigger based function that simply invokes the endpoint on the GCE instance as specified in the URL.

## Requirements for building locally

1. You need to install `nodejs >= 10.0.0` to test the function locally. 

## Build steps (for local testing)

1. `npm install`

## Testing locally

1. `npm start` (This will start the function on `http://localhost:8080`)

## Deploying to Google Cloud Functions

To deploy th function to GCF, run the following command from this folder:

```
gcloud functions deploy <name-of-the-function> \
    --region <region> \
    --vpc-connector <vpc-connector> \
    --memory 128MB \
    --runtime nodejs10 \
    --trigger-http \
    --timeout 10s \
    --ingress-settings internal-only \
    --allow-unauthenticated
```

### Note:
 1. Since the invocation is allowed only from the resources within the project (using the `ingress-settings` parameter), unauthenticated invocations are allowed. You may chose to specify an alternative authentication method.
 2. It is important to ensure that the GCF is in the same region as the Serverless VPC Access Connector deployed.
 3. To better control the scaling, optionally provide `--max-instances` parameter as well.
 4. Ensure that the Cloud Pub/Sub service account is provided access to invoke the Cloud Function via the `Cloud Functions Invoker` IAM role.

## Note:
The function is written is support on HTTP `POST` method as that is the default method used by Cloud Pub/Sub when it invokes the push endpoints.