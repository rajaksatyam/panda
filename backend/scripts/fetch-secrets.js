const { SecretsManagerClient, GetSecretValueCommand } = require("@aws-sdk/client-secrets-manager");
const fs = require("fs");
const path = require("path");

const secretName = "productify/prod/env";
const region = "eu-north-1"; // Matches user's aws configure

async function fetchSecrets() {
  console.log(`Fetching secrets from AWS Secrets Manager (${secretName})...`);
  const client = new SecretsManagerClient({ region });

  try {
    const response = await client.send(
      new GetSecretValueCommand({
        SecretId: secretName,
        VersionStage: "AWSCURRENT",
      })
    );

    const secrets = JSON.parse(response.SecretString);
    let envContent = "";

    for (const [key, value] of Object.entries(secrets)) {
      envContent += `${key}=${value}\n`;
    }

    fs.writeFileSync(path.join(__dirname, "../.env"), envContent);
    console.log("✅ .env file generated successfully from AWS Secrets!");
  } catch (error) {
    console.error("❌ Error fetching secrets:", error.message);
    process.exit(1);
  }
}

fetchSecrets();
