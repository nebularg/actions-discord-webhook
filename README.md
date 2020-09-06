# GitHub Actions Discord Webhook

```yaml
    - name: Send status to Discord
      using: nebularg/actions-discord-webhook@master
      with:
        webhook_url: ${{ secrets.discord_webhook_url }} # required
        status: ${{ job.status }} # optional, this is default
      if: always() # or failure() or success()
```
