import concurrent.futures, hashlib, json, os, pathlib, urllib.request, xml.etree.ElementTree as ET, zipfile
root=pathlib.Path(os.environ['LOCALAPPDATA'])/'TurboSaveBuildTools'
root.mkdir(parents=True,exist_ok=True)
def fetch(url,dest,checksum=None,kind='sha256'):
    if dest.exists() and (not checksum or hashlib.new(kind,dest.read_bytes()).hexdigest()==checksum): return dest
    with urllib.request.urlopen(url,timeout=90) as r, open(str(dest)+'.part','wb') as out:
        while chunk:=r.read(1024*1024):out.write(chunk)
    staged=pathlib.Path(str(dest)+'.part')
    if checksum and hashlib.new(kind,staged.read_bytes()).hexdigest()!=checksum:raise RuntimeError('Published checksum did not match: '+dest.name)
    staged.replace(dest)
    return dest
repo=ET.fromstring(urllib.request.urlopen('https://dl.google.com/android/repository/repository2-3.xml',timeout=60).read())
packages=[]
for pkg in repo.findall('.//{*}remotePackage'):
    if not pkg.attrib.get('path','').startswith('cmdline-tools;'):continue
    if pkg.find('{*}obsolete') is not None:continue
    rev=pkg.find('{*}revision');version=tuple(int(rev.findtext('{*}'+key,'0')) for key in ['major','minor','micro'])
    for archive in pkg.findall('.//{*}archive'):
        if archive.findtext('{*}host-os')!='windows':continue
        complete=archive.find('{*}complete');ch=complete.find('{*}checksum')
        packages.append((version,complete.findtext('{*}url'),ch.text.strip(),ch.attrib.get('type','sha1')))
version,url,digest,kind=max(packages)
if not url.startswith('https://'):url='https://dl.google.com/android/repository/'+url
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    android=pool.submit(fetch,url,root/'android-commandline-tools.zip',digest,kind)
    python=pool.submit(fetch,'https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe',root/'python-3.11.9-amd64.exe')
    android_path=android.result();python_path=python.result()
sdk=root/'android-sdk';target=sdk/'cmdline-tools'/'latest'
if not (target/'bin'/'sdkmanager.bat').exists():
    with zipfile.ZipFile(android_path) as z:
        for item in z.infolist():
            if item.is_dir():continue
            name=pathlib.PurePosixPath(item.filename)
            if name.parts[0]!='cmdline-tools' or '..' in name.parts:raise RuntimeError('Unexpected SDK archive entry')
            dest=target.joinpath(*name.parts[1:]);dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(z.read(item))
(root/'downloads.json').write_text(json.dumps({'sdkVersion':version,'sdkArchive':url,'sdkPublishedChecksum':digest,'sdkChecksumType':kind,'pythonInstallerSHA256':hashlib.sha256(python_path.read_bytes()).hexdigest()},indent=2))
print(json.dumps({'sdk':str(sdk),'sdkVersion':version,'pythonInstaller':str(python_path)}))
