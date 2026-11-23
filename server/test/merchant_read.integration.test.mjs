import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { Fin08Store } from '../src/store.mjs';

const url = process.env.FIN08_TEST_DATABASE_URL;

test('FIN-09 merchant restores private contacts and every claim stage without cross-merchant disclosure',
  { skip: !url }, async () => {
    const { Pool } = await import('pg');
    const pool = new Pool({ connectionString: url });
    const store = new Fin08Store(pool, { cursorSecret: 'fin09-ci-only-secret-' + '9'.repeat(40) });
    const suffix = randomUUID().slice(0, 8);
    const merchant = { id: `restore-${suffix}-m`, role: 'merchant' };
    const other = { id: `restore-${suffix}-foreign`, role: 'merchant' };
    const customer = { id: `restore-${suffix}-customer`, role: 'customer' };
    const identity = { id: 'trusted-identity', role: 'identity_service' };
    const phone = '+96777' + String(Math.floor(Math.random() * 10000000)).padStart(7, '0');
    const otherPhone = '+96778' + String(Math.floor(Math.random() * 10000000)).padStart(7, '0');
    try {
      await store.onboardMerchant(identity,{ merchant_id: merchant.id,verified_display_name:'M One' });
      await store.onboardMerchant(identity,{ merchant_id: other.id,verified_display_name:'M Two' });
      const contact = await store.createContact(merchant,{ name:'Client Before App',phone });
      const another = await store.createContact(merchant,{ name:'Client No App',phone:otherPhone });
      const foreignContact = await store.createContact(other,{ name:'Foreign Client',phone });
      const a = (await store.createClaim(merchant,{ contact_id:contact.id,amount:'100.50',currency:'YER' },`fin09-${suffix}-a`)).claim;
      const b = (await store.createClaim(merchant,{ contact_id:contact.id,amount:'5.75',currency:'USD' },`fin09-${suffix}-b`)).claim;
      const c = (await store.createClaim(merchant,{ contact_id:another.id,amount:'300.00',currency:'SAR' },`fin09-${suffix}-c`)).claim;
      const first = await store.listContacts(merchant,{ limit:1 });
      assert.equal(first.items.length,1);
      assert.ok(first.next_cursor);
      const second = await store.listContacts(merchant,{ limit:1,cursor:first.next_cursor });
      assert.deepEqual(new Set([first.items[0].contact_id,second.items[0].contact_id]),new Set([contact.id,another.id]));
      assert.equal(second.next_cursor,null);
      const nameSearch=await store.listContacts(merchant,{ q:'before app' });
      assert.deepEqual(nameSearch.items.map(row=>row.contact_id),[contact.id]);
      const phoneSearch=await store.listContacts(merchant,{ q:phone.slice(-7) });
      assert.deepEqual(new Set(phoneSearch.items.map(row=>row.contact_id)),new Set([contact.id]));
      assert.equal((await store.listContacts(merchant,{ q:'no-such-client-'+suffix })).items.length,0);
      await assert.rejects(()=>store.listContacts(merchant,{ q:'x'.repeat(81) }),{status:422});
      await assert.rejects(()=>store.listContacts(merchant,{ q:'bad\u0000term' }),{status:422});
      await assert.rejects(()=>store.listContacts(other,{ limit:1,cursor:first.next_cursor }),{status:422});
      await assert.rejects(()=>store.listContactClaims(other,contact.id,{}),{status:404});
      const before = await store.listContactClaims(merchant,contact.id,{});
      assert.deepEqual(new Set(before.items.map(row=>row.claim_id)),new Set([a.id,b.id]));
      assert.ok(before.items.every(row=>row.stage==='outside_app'));
      assert.ok(before.items.every(row=>typeof row.amount==='string'));
      const amountSearch=await store.listContactClaims(merchant,contact.id,{ q:'100.50' });
      assert.deepEqual(amountSearch.items.map(row=>row.claim_id),[a.id]);
      assert.deepEqual(new Set((await store.listContactClaims(merchant,contact.id,{ type:'debt' })).items
        .map(row=>row.claim_id)),new Set([a.id,b.id]));
      assert.equal((await store.listContactClaims(merchant,contact.id,{ type:'payment' })).items.length,0);
      assert.deepEqual((await store.listContactClaims(merchant,contact.id,{ currency:'USD' })).items
        .map(row=>row.claim_id),[b.id]);
      assert.equal((await store.listContactClaims(merchant,contact.id,{ currency:'SAR' })).items.length,0);
      await assert.rejects(()=>store.listContactClaims(merchant,contact.id,{ type:'refund' }),{status:422});
      await assert.rejects(()=>store.listContactClaims(merchant,contact.id,{ currency:'EUR' }),{status:422});
      const day=new Date(a.created_at).toISOString().slice(0,10);
      assert.deepEqual(new Set((await store.listContactClaims(merchant,contact.id,{
        from:day,to:day })).items.map(row=>row.claim_id)),new Set([a.id,b.id]));
      assert.equal((await store.listContactClaims(merchant,contact.id,{
        from:'2999-01-01' })).items.length,0);
      assert.equal((await store.listContactClaims(merchant,contact.id,{
        to:'2000-01-01' })).items.length,0);
      await assert.rejects(()=>store.listContactClaims(merchant,contact.id,{
        from:'2026-13-01' }),{status:422});
      await assert.rejects(()=>store.listContactClaims(merchant,contact.id,{
        sort:'name' }),{status:422});
      const highest=await store.listContactClaims(merchant,contact.id,{
        sort:'amount_desc',limit:1 });
      assert.equal(highest.items[0].claim_id,a.id);
      assert.ok(highest.next_cursor);
      const secondHighest=await store.listContactClaims(merchant,contact.id,{
        sort:'amount_desc',limit:1,cursor:highest.next_cursor });
      assert.equal(secondHighest.items[0].claim_id,b.id);
      await assert.rejects(()=>store.listContactClaims(merchant,contact.id,{
        sort:'newest',limit:1,cursor:highest.next_cursor }),{status:422});
      assert.equal((await store.listContactClaims(merchant,contact.id,{
        sort:'amount_asc',limit:1 })).items[0].claim_id,b.id);
      await assert.rejects(()=>store.listContactClaims(merchant,contact.id,{ q:'x'.repeat(81) }),{status:422});
      const otherPage = await store.listContactClaims(merchant,another.id,{});
      assert.deepEqual(otherPage.items.map(row=>row.claim_id),[c.id]);
      assert.equal(otherPage.items[0].currency,'SAR');
      await assert.rejects(()=>store.listContactClaims(merchant,another.id,{cursor:first.next_cursor}),{status:422});
      const claimPage = await store.listContactClaims(merchant,contact.id,{limit:1});
      assert.ok(claimPage.next_cursor);
      const claimPage2 = await store.listContactClaims(merchant,contact.id,{limit:1,cursor:claimPage.next_cursor});
      assert.equal(claimPage2.items.length,1);
      await assert.rejects(()=>store.listContactClaims(merchant,another.id,{limit:1,cursor:claimPage.next_cursor}),{status:422});
      await store.verifyPhone(identity,{ customer_id:customer.id,phone,proof_reference:`proof-${suffix}` });
      const automatic=await store.listCustomerRelationships(customer,{});
      assert.deepEqual(new Set(automatic.items.map(x=>x.merchant_id)),new Set([merchant.id,other.id]));
      assert.ok(automatic.items.every(x=>x.status==='pending'));
      const joined = await store.listContactClaims(merchant,contact.id,{});
      assert.ok(joined.items.every(row=>row.stage==='awaiting_review'));
      await store.decideClaim(customer,b.id,{decision:'reject'});
      assert.equal((await store.listContactClaims(merchant,contact.id,{})).items.find(x=>x.claim_id===b.id).stage,'rejected');
      await store.decideClaim(customer,a.id,{decision:'accept'});
      assert.equal((await store.listContactClaims(merchant,contact.id,{})).items.find(x=>x.claim_id===a.id).stage,'accepted_awaiting_relationship');
      await store.requestRelationship(other,{contact_id:foreignContact.id});
      const relationship = await store.requestRelationship(merchant,{contact_id:contact.id});
      const requested=await store.listCustomerRelationships(customer,{limit:1});
      assert.equal(requested.items.length,1);
      assert.equal(requested.items[0].status,'pending');
      assert.equal((await store.listCustomerRelationships({id:'unrelated-customer',role:'customer'},{})).items.length,0);
      assert.ok(requested.next_cursor);
      const older=await store.listCustomerRelationships(customer,{limit:1,cursor:requested.next_cursor});
      assert.equal(older.items.length,1);
      const twoRows=[...requested.items,...older.items];
      assert.deepEqual(new Set(twoRows.map(row=>row.merchant_id)),new Set([merchant.id,other.id]));
      const merchantRelation=twoRows.find(row=>row.merchant_id===merchant.id);
      assert.equal(merchantRelation.relationship_id,relationship.relationship_id);
      assert.equal(merchantRelation.merchant_display_name,'M One');
      await assert.rejects(()=>store.listCustomerRelationships({id:'unrelated-customer',role:'customer'},{
        limit:1,cursor:requested.next_cursor
      }),{status:422});
      await store.decideRelationship(customer,relationship.relationship_id,{decision:'accept'});
      assert.equal((await store.listCustomerRelationships(customer,{})).items
        .find(row=>row.merchant_id===merchant.id).status,'approved');
      const after = await store.listContactClaims(merchant,contact.id,{});
      assert.equal(after.items.find(x=>x.claim_id===a.id).stage,'approved');
      assert.equal(after.items.find(x=>x.claim_id===b.id).stage,'rejected');
      assert.equal((await store.listContactClaims(merchant,another.id,{})).items[0].stage,'outside_app');
      assert.equal((await store.listContacts(other,{})).items.length,1);
      await store.verifyPhone(identity,{customer_id:'conflicting-customer-'+suffix,
        phone,proof_reference:'conflict-proof-'+suffix});
      assert.equal((await store.listCustomerRelationships(customer,{})).items.length,0);
    } finally { await pool.end(); }
  });