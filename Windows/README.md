# Cray's Windows Hardening Tools

Run at the beginning to allow execution of Powershell scripts
```powershell 
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Password: ```Ping@123456789!```

## TODO:
- [ ] - add where unknown services are stopped and disabled as they should work without them and enable known
- [ ] - add a function that flags if a service is logged in as a local user/administrator.
