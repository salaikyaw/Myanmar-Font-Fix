import pathlib, shutil, tempfile, yaml
base=pathlib.Path('/home/sk-dell-1/.docker/mcp/catalogs')
backup=pathlib.Path(tempfile.mkdtemp(prefix='mcp-http-20260914-',dir='/var/backups'))
names={'fetch','gemini-api-docs','memory','openapi','sequentialthinking','mcp-code-interpreter','playwright','github-official','n8n','mcp-api-gateway','notion','SQLite','aws-api','cloudflare-docs','filesystem','localserver_trading','localserver_searxng'}
for filename in ['docker-official-20260914.yaml','localserver.yaml']:
    p=base/filename
    shutil.copy2(p,backup/filename)
    doc=yaml.safe_load(p.read_text())
    for name,item in doc['registry'].items():
        if name not in names or not item.get('image'): continue
        entries=item.setdefault('env',[])
        if not isinstance(entries,list): raise RuntimeError('Unexpected catalog env schema')
        additions={'HTTP_PROXY':'http://172.17.0.1:1083','HTTPS_PROXY':'http://172.17.0.1:1083','http_proxy':'http://172.17.0.1:1083','https_proxy':'http://172.17.0.1:1083','NO_PROXY':'localhost,127.0.0.1,172.17.0.1,192.168.1.4,192.168.1.5,host.docker.internal'}
        entries[:]=[e for e in entries if e.get('name') not in additions]
        entries.extend({'name':k,'value':v} for k,v in additions.items())
    p.write_text(yaml.safe_dump(doc,sort_keys=False))
for p in pathlib.Path('/etc/systemd/system').glob('mcp-gateway-*.service.d/91-mcp-egress.conf'):
    shutil.copy2(p,backup/(p.parent.name+'.conf'))
    text=p.read_text().replace('socks5://127.0.0.1:1082','http://127.0.0.1:1083')
    text=text.replace('Wants=mcp-egress-skhp.service','Wants=mcp-egress-skhp.service mcp-http-egress.service')
    text=text.replace('After=mcp-egress-skhp.service','After=mcp-egress-skhp.service mcp-http-egress.service')
    p.write_text(text)
print('BACKUP='+str(backup))
