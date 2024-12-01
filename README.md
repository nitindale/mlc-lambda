# mlc-lambda

## Prerequisites

Before setting up the project, ensure the following tools are installed and configured:

- **npm**: [Install npm](https://www.npmjs.com/get-npm)
- **AWS CLI**: [Install AWS CLI](https://aws.amazon.com/cli/)
  - Configure AWS credentials by running:
    ```bash
    aws configure
    ```
- **Terraform**: [Install Terraform](https://www.terraform.io/downloads)

Additionally, register with [OpenWeatherMap](https://openweathermap.org/) and get your **API Key**. Once received, update it in the `main.tf` file at line 44:
`OPENWEATHER_API_KEY = "your-api-key-here"`

## Setup Instructions

### • Source code for the Lambda functions.

To set up the source code for the Lambda functions:

```unzip lambda.zip
   npm install
   tsc
```

### • Terraform scripts for provisioning AWS infrastructure.

To set up the source code for the Lambda functions:

`unzip terraform.zip`

### • A README file with setup and testing instructions.

    ``` terraform init
        terraform plan
        terraform apply
        terraform destroy (incase of removing provisioning)
    ```

### • Having an UI to trigger the API calls to fetch weather data.

    - Open index.html
    - replace API_BASE_URL with the deployed API GW url from terrform

### • Document the Terraform setup and commands needed to deploy the infrastructure.

    - Mentioned above
