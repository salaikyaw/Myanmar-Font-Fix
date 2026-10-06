"""Replace only the two verified remote entries; preserve a rollback copy."""
import pathlib, shutil, tempfile, yaml
p=pathlib.Path('/home/sk-dell-1/.docker/mcp/catalogs/docker-official-20260914.yaml')
doc=yaml.safe_load(p.read_text())
backup=pathlib.Path(tempfile.mkdtemp(prefix='mcp-adapters-20260914-',dir='/var/backups'))
shutil.copy2(p,backup/p.name)
for name in ['context7','cloudflare-docs']:
    entry=doc['registry'][name]
    entry.pop('remote',None)
    entry['type']='server'
    entry['image']='mcp-remote-egress:local'
    entry['command']=[name]
    env=entry.setdefault('env',[])
    proxy={'HTTP_PROXY':'http://172.17.0.1:1083','HTTPS_PROXY':'http://172.17.0.1:1083',
           'NO_PROXY':'localhost,127.0.0.1,172.17.0.1'}
    env[:]=[e for e in env if e.get('name') not in proxy]
    env.extend({'name':k,'value':v} for k,v in proxy.items())
p.write_text(yaml.safe_dump(doc,sort_keys=False))
print('BACKUP='+str(backup))
