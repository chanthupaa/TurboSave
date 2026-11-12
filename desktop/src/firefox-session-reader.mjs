// SPDX-License-Identifier: GPL-3.0-only
import {DatabaseSync} from 'node:sqlite';

// Executed by the verified Node engine. Never select other sites or Firefox passwords.
export function readFirefoxSession(file,now=Math.floor(Date.now()/1000)){
  const db=new DatabaseSync(file,{readOnly:true,allowExtension:false});
  try{
    db.exec('PRAGMA query_only=ON; PRAGMA trusted_schema=OFF;');
    return db.prepare(`SELECT host AS domain, path, isSecure AS secure, isHttpOnly AS httpOnly, expiry AS expires, name, value
      FROM moz_cookies WHERE (host='youtube.com' OR host='.youtube.com' OR host LIKE '%.youtube.com')
      AND originAttributes='' AND (expiry=0 OR expiry>?) LIMIT 401`).all(now);
  }finally{db.close();}
}
