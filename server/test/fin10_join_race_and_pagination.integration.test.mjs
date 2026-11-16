import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { Fin08Store } from '../src/store.mjs';

const dbUrl=process.env.FIN08_TEST_DATABASE_URL;
test('FIN-10: concurrent phone verification never loses invites and microsecond page cursors never skip claims',
  {skip:!dbUrl},async()=>{
    const {Pool}=await import('pg');
    const pool=new Pool({connectionString:dbUrl});
    const store=new Fin08Store(pool,{cursorSecret:'fin10-concurrency-test-only-secret-strong-hmac-key'});
    const suffix=randomUUID().slice(0,8);
    const m1={id:'m1-'+suffix,role:'merchant'};
    const m2={id:'m2-'+suffix,role:'merchant'};
    const customer={id:'customer-'+suffix,role:'customer'};
    const stranger={id:'stranger-'+suffix,role:'customer'};
    const identity={id:'identity-integration',role:'identity_service'};
    const phone='+96771'+String(Math.floor(Math.random()*10000000)).padStart(7,'0');
    try{
      await store.onboardMerchant(identity,{merchant_id:m1.id,verified_display_name:'M One'});
      await store.onboardMerchant(identity,{merchant_id:m2.id,verified_display_name:'M Two'});
      // The same-phone writes begin concurrently. The per-phone advisory lock
      // ensures whichever transaction commits last reconciles both states.
      const [c1,c2]=await Promise.all([
        store.createContact(m1,{name:'Historic Contact One',phone}),
        store.createContact(m2,{name:'Historic Contact Two',phone}),
        store.verifyPhone(identity,{customer_id:customer.id,phone,
          proof_reference:'race-proof-'+suffix}),
      ]).then(results=>[results[0],results[1]]);
      const links=await store.listCustomerRelationships(customer,{limit:1});
      assert.equal(links.items.length,1);
      assert.ok(links.next_cursor);
      const following=await store.listCustomerRelationships(customer,{limit:1,cursor:links.next_cursor});
      assert.equal(following.items.length,1);
      assert.deepEqual(
        new Set([...links.items,...following.items].map(x=>x.merchant_id)),
        new Set([m1.id,m2.id]));
      assert.ok([...links.items,...following.items].every(x=>x.status==='pending'));
      const rec=await store.requestRelationship(m1,{contact_id:c1.id});
      assert.equal(rec.status,'pending');
      // Two separate claims with the exact same PostgreSQL microsecond timestamp.
      const a=await store.createClaim(m1,{contact_id:c1.id,amount:'10.0000',currency:'YER'},
        'race-claim-a-'+suffix);
      const b=await store.createClaim(m1,{contact_id:c1.id,amount:'20.2500',currency:'USD'},
        'race-claim-b-'+suffix);
      await pool.query('UPDATE merchant_claims SET created_at=now() WHERE id IN($1,$2)',
        [a.claim.id,b.claim.id]);
      const inbox=await store.claimsInbox(customer,{limit:1});
      assert.ok(inbox.next_cursor);
      const next=await store.claimsInbox(customer,{limit:1,cursor:inbox.next_cursor});
      assert.deepEqual(
        new Set([...inbox.items,...next.items].map(x=>x.claim_id)),
        new Set([a.claim.id,b.claim.id]));
      assert.equal(next.next_cursor,null);
      await assert.rejects(
        ()=>store.claimsInbox(stranger,{limit:1,cursor:inbox.next_cursor}),{status:422});
      const merchantFirst=await store.listContactClaims(m1,c1.id,{limit:1});
      assert.ok(merchantFirst.next_cursor);
      const merchantNext=await store.listContactClaims(m1,c1.id,{
        limit:1,cursor:merchantFirst.next_cursor,
      });
      assert.deepEqual(
        new Set([...merchantFirst.items,...merchantNext.items].map(x=>x.claim_id)),
        new Set([a.claim.id,b.claim.id]));
      // Also validate microsecond ties in the merchant contact list.
      const secondPhone='+96777'+String(Math.floor(Math.random()*10000000)).padStart(7,'0');
      const secondContact=await store.createContact(m1,{name:'Other Contact',phone:secondPhone});
      await pool.query('UPDATE merchant_contacts SET created_at=now() WHERE id IN($1,$2)',
        [c1.id,secondContact.id]);
      const contactsFirst=await store.listContacts(m1,{limit:1});
      const contactsSecond=await store.listContacts(m1,{
        limit:1,cursor:contactsFirst.next_cursor,
      });
      assert.deepEqual(
        new Set([...contactsFirst.items,...contactsSecond.items].map(x=>x.contact_id)),
        new Set([c1.id,secondContact.id]));
      const unrelated=await store.listCustomerRelationships(stranger,{});
      assert.equal(unrelated.items.length,0);
      assert.equal(c2.id.length>0,true);
    }finally{await pool.end();}
  });
