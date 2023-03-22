<p align="center">
  <img alt="Akamai logo" width="320" height="320" src="https://www.eiseverywhere.com/file_uploads/8fca94ae15da82d17d76787b3e6a987a_logo_akamai-developer-experience-2-OL-RGB.png"/>
  <h3 align="center">GitHub Action to deploy Akamai EdgeWorkers</h3>
  <p align="center">
    <img alt="GitHub license" src="https://badgen.net/github/license/jdmevo123/akamai-purge-action?cache=300&color=green"/>
  </p>
</p>

# Deploy Akamai EdgeWorkers   

This action calls the Akamai Api's to deploy <a href="https://developer.akamai.com/akamai-edgeworkers-overview" target="_blank">EdgeWorkers</a> to the Akamai platform. There are two pipelines in place for your repository, create an EdgeWorker (register) or upload a new version to an existing EdgeWorker. In both cases your EdgeWorker bundle will be uploaded and activated to the network you have selected. The action will execute the necessary pipeline when it executes.
<p align="center">
    <img alt="Edgeworkers" width="793" src="https://developer.akamai.com/sites/default/files/inline-images/image1_20.png"/>
</p>

## Usage

Setup your repository with the following files:
```
<repository name>
            - bundle.json
            - main.js
            - utils/somejs.js
```

EdgeWorker pipeline flow:
<p align="center">
    <img alt="Pipeline flow" src="https://github.com/jdmevo123/akamai-edgeworker-action/blob/master/images/Blank%20Diagram.png"/>
</p>

All sensitive variables should be [set as encrypted secrets](https://help.github.com/en/articles/virtual-environments-for-github-actions#creating-and-using-secrets-encrypted-variables) in the action's configuration.

## Authentication

You need to declare a `AKAMAI_EDGERC` secret in your repository containing the following structure :
```
[edgeworkers]
client_secret = your_client_secret
host = your_host
access_token = your_access_token
client_token = your_client_token
```
You can retrieve these from Akamai Control Center >> Identity Management >> API User.

## Inputs

### `edgeworkersName`
**Required**
Edgeworker name: Currently set to use repository name

### `network`
**Required**
Network:
- staging
- production
Defaults to staging

### `groupid`
**Required** 
Akamai groupid to assign new registrations to

## `workflow.yml` Example

Place in a `.yml` file such as this one in your `.github/workflows` folder. [Refer to the documentation on workflow YAML syntax here.](https://help.github.com/en/articles/workflow-syntax-for-github-actions)

```yaml
steps:
    - uses: actions/checkout@v1
    - name: Deploy Edgeworkers
      uses: anne2gao/akamai-edgeworker-action@1.1
      env:
        EDGERC: ${{ secrets.AKAMAI_EDGERC }}
        EDGEKV_TOKENS: ${{ inputs.EDGEKV_TOKENS }}
        WORKER_DIR: workerdirname # Optional directory for worker code (relative)
      with:
        - ${{ inputs.edgeworkersName}}
        - ${{ inputs.network }}
        - ${{ inputs.groupid }}
        - ${{ inputs.resourceTierId }}
        - ${{ inputs.hasUploaded }}
        - ${{ inputs.bundleversion }}
```

## input variables in yml files
## `edgeworkersName`
**Required**
Edgeworker name

## `network`
**Required**
Network:
- staging
- production
- staging production

## `resourceTierId`
**Required** 
Resource Tier ID for a edgeworker id. The availabl value is 200 or 100

## `EDGERC`
**Required** 
Akamai edgeworkers api secret. Set it into app Github environment variable or in a file like my.secrets

## `EDGEKV_TOKENS`
**Required** 
Akamai edgekv_tokens.js file put into app secret. Set it into Github environment variable or in a file like my.secrets

## `WORKER_DIR`
**Required** 
Source code directory in the repository

## `hasUploaded`
**Required** 
The value is yes or no. You set it to yes if you have uploaded bundle code to Akamai with current edgeworker-version in bundle.json; Otherwise You set it to no if your new version in the repo has not be uploaded yet, and the action will upload it for you and activating it to akamai network defined in network var.

## `bundleversion`
**Not Required** 
The bundle version you want to active. If hasUploaded is yes, and the bundle code with edgeworker-version is existing but not in active status in Akamai, you can set the bundleversion such as 1.0.10 whcih you want to active. You can use it to activate a uploaded version only with setting hasUploaded=yes, in case you need to rollback to old version.
