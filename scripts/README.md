# GCE Startup and Shutdown Scripts

## Setup

1. Upload the scripts to a GCS bucket
2. Ensure that the scripts have access from the default Compute Engine service account or an alternate service account used

## Upload scripts to a GCS bucket

```
gsutil cp startup.sh shutdown.sh gs://<bucket-name-here>/<optional-folders-if-applicable>/
```

## Provide read access to the scripts to the service account

```
gsutil acl ch -u <service-account>:R gs://<bucket-name-here>/optional-folders-if-applicable>/startup.sh
gsutil acl ch -u <service-account>:R gs://<bucket-name-here>/optional-folders-if-applicable>/shudown.sh
```

## Add the following metadata keys as part of GCE instance
`startup-script-url=gs://<bucket-name-here>/optional-folders-if-applicable>/startup.sh`

and 

`shutdown-script-url=gs://<bucket-name-here>/optional-folders-if-applicable>/shutdown.sh`

## Additional instance metadata leveraged by the startup script is as follows
1. `uri-scheme=<http|https> (Optional. Default value: https)`
2. `uri-path=<URI path of the webservice running on this instance> (Optional. Default value: nil)`
3. `pubsub-topic=<pubsub topic name> (Required and must exist within the current project)`
4. `cloudfn_endpoint=<URI of Cloud Function to be used for push> (Required and must only contain the URI scheme and host only. No URI path or query parameters or fragments allowed)`

