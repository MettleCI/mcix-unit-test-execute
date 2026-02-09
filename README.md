# MCIX DataStage Unit Test Execute GitHub Action

Run DataStage unit tests managed by MCIX as part of CI/CD.

> Namespace: `unit-test`  
> Action: `execute`  
> Usage: `DataMigrators/mcix/unit-test/execute@v1`

## 🚀 Usage

```yaml
- uses: DataMigrators/mcix/unit-test/execute@v1
  with:
    api-key: ${{ secrets.MCIX_API_KEY }}
    url: https://your-mcix-server/api
    user: dm-automation
    report: unit-tests
    project: GitHub_CP4D_DevOps
```

## 🔧 Inputs

| Name                   | Required | Description |
|------------------------|----------|-------------|
| api-key                | Yes      | MCIX API key |
| url                    | Yes      | MCIX URL |
| user                   | Yes      | Logical user |
| report                 | Yes      | Report/mode |
| project                | Conditional | Project name |
| project-id             | Conditional | Project ID |
| max-concurrency        | Optional | Concurrency level |
| included-tags          | Optional | Include tags |
| excluded-tags          | Optional | Exclude tags |
| test-suite             | Optional | Suite name |
| ignore-test-failures   | Optional | Bool |

## 📤 Outputs

| Name | Description |
|------|-------------|
| return-code | Exit code |

## 📚 More information

See https://nextgen.mettleci.io/mettleci-cli/unit-test-namespace/#unit-test-execute
