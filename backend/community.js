const admin = require('firebase-admin');
const crypto = require('crypto');
const { getFirestore, initFirebaseAdmin } = require('./fcm');

const C = {
  categories: 'community_categories', topics: 'community_topics', reports: 'community_reports',
  blocks: 'community_blocks', entitlements: 'community_entitlements', config: 'community_config',
  moderation: 'community_moderation_events', users: 'users',
};

const defaultCategories = [
  ['kartimi-yorumlayin', 'Kartımı Yorumlayın', 'style', 'temporary', 15],
  ['baklami-yorumlayin', 'Baklamı Yorumlayın', 'grain', 'temporary', 15],
  ['yorumculara-sor', 'Yorumculara Sor', 'forum', 'temporary', 15],
  ['tarot-ogreniyorum', 'Tarot Öğreniyorum', 'school', 'permanent', null],
  ['fal-sohbetleri', 'Fal Sohbetleri', 'chat', 'permanent', null],
  ['ask-iliskiler', 'Aşk & İlişkiler', 'favorite', 'temporary', 15],
  ['hayat-kararlar', 'Hayat & Kararlar', 'explore', 'temporary', 15],
];

const obviousTerms = ['orospu', 'siktir', 'amına', 'amina', 'piç', 'pic', 'yarrak'];
const limits = { titleMin: 5, titleMax: 120, bodyMin: 10, bodyMax: 4000, replyMax: 2000, pageMax: 20 };

function db() {
  if (!initFirebaseAdmin() || !getFirestore()) throw Object.assign(new Error('Firestore kullanılamıyor.'), { statusCode: 503 });
  return getFirestore();
}
function fail(message, statusCode = 400, code = 'invalid_request') { throw Object.assign(new Error(message), { statusCode, code }); }
function clean(value) { return String(value || '').trim(); }
function normalize(value) {
  return clean(value).toLocaleLowerCase('tr-TR').normalize('NFKD').replace(/[\u0300-\u036f]/g, '')
    .replace(/[013457@$]/g, (x) => ({ '0':'o','1':'i','3':'e','4':'a','5':'s','7':'t','@':'a','$':'s' }[x]))
    .replace(/(.)\1{2,}/g, '$1$1').replace(/[^a-zçğıöşü]+/gi, ' ').replace(/\s+/g, ' ').trim();
}
async function moderationTerms() {
  const snap = await db().collection(C.config).doc('moderation').get();
  return [...obviousTerms, ...((snap.data()?.blockedTerms || []).map(clean).filter(Boolean))];
}
async function moderate(...values) {
  const normalized = normalize(values.join(' '));
  const compact = normalized.replace(/\s/g, '');
  for (const term of await moderationTerms()) {
    const n = normalize(term); if (!n) continue;
    const pattern = new RegExp(`(^|\\s)${n.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(\\s|$)`, 'i');
    if (pattern.test(normalized) || (n.length >= 4 && compact.includes(n.replace(/\s/g, '')))) fail('Metin topluluk kurallarına aykırı ifade içeriyor.', 422, 'content_rejected');
  }
}
async function ensureSeedCategories() {
  const ref = db().collection(C.categories); const snap = await ref.limit(1).get(); if (!snap.empty) return;
  const batch = db().batch();
  defaultCategories.forEach(([id, name, icon, retentionMode, retentionDays], order) => batch.set(ref.doc(id), {
    name, icon, description: '', enabled: true, order, retentionMode, retentionDays, createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }));
  await batch.commit();
}
async function profile(uid) {
  const snap = await db().collection(C.users).doc(uid).get(); const d = snap.data() || {};
  let joinedAt=d.createdAt?.toMillis?.()||d.registeredAt?.toMillis?.()||0;
  if(!joinedAt){try{const user=await admin.auth().getUser(uid);joinedAt=Date.parse(user.metadata.creationTime)||Date.now();}catch(_){joinedAt=Date.now();}}
  const months=Math.max(0,Math.floor((Date.now()-joinedAt)/(30.4375*86400000)));
  const contribution=Math.max(0,Number(d.communityTopicCount)||0)+Math.max(0,Number(d.communityReplyCount)||0);
  const level=Math.max(1,Math.min(99,1+Math.floor(months/2)+Math.floor(contribution/10)));
  return { displayName: clean(d.displayName || d.name || 'Meclis Üyesi').slice(0, 50), avatarUrl: clean(d.avatarUrl || d.photoUrl), role: d.communityRole === 'verified_reader' ? 'verified_reader' : 'member', joinedAt, memberMonths:months, memberLevel:level };
}
async function entitlement(uid, force = false) {
  const ref = db().collection(C.entitlements).doc(uid); const snap = await ref.get(); const d = snap.data() || {};
  const expires = d.expiresAt?.toMillis?.() || 0; const active = d.status === 'active' && expires > Date.now() && !d.revokedAt;
  if (!active && force) return { active: false, status: expires && expires <= Date.now() ? 'expired' : (d.status || 'none'), expiresAt: expires || null };
  return { active, status: active ? 'active' : (d.status || 'none'), expiresAt: expires || null };
}
async function requirePremium(uid) { const e = await entitlement(uid, true); if (!e.active) fail('Tombik Teyze+ üyeliği gerekli.', 403, 'premium_required'); return e; }
async function suspension(uid) { const d = (await db().collection(C.users).doc(uid).get()).data() || {}; if (d.communityBanned || (d.communitySuspendedUntil?.toMillis?.() || 0) > Date.now()) fail('Fal Meclisi katılımınız sınırlandırılmış.', 403, 'community_suspended'); }
function cursorFrom(doc) { return doc ? Buffer.from(JSON.stringify({ id: doc.id, t: doc.get('lastActivityAt')?.toMillis?.() || 0 })).toString('base64url') : null; }
function topicJson(doc) { const d = doc.data(); return { id: doc.id, title:d.title, body:d.body, categoryId:d.categoryId, categoryName:d.categoryName, authorDisplayName:d.authorDisplayName, authorRole:d.authorRole, authorMemberMonths:d.authorMemberMonths||0, authorMemberLevel:d.authorMemberLevel||1, createdAt:d.createdAt?.toMillis?.() || null, lastActivityAt:d.lastActivityAt?.toMillis?.() || null, expiresAt:d.expiresAt?.toMillis?.() || null, replyCount:d.replyCount || 0, viewCount:d.viewCount||0, likeCount:d.likeCount||0, dislikeCount:d.dislikeCount||0, verifiedReaderReplyCount:d.verifiedReaderReplyCount || 0, resolved:d.resolved === true, acceptedAnswerId:d.acceptedAnswerId || null, locked:d.locked === true, thumbnailUrl:d.thumbnailUrl || null, imageUrls:d.imageUrls || [] }; }

async function categories() {
  await ensureSeedCategories();
  // Kategori sayısı admin tarafından sınırlı tutulur. Sadece `order` ile
  // sorgulayıp aktiflik filtresini sunucuda yapmak, yeni kurulumlarda composite
  // index oluşturulmasını bekletmeden konu formunu kullanılabilir tutar.
  const snapshot = await db()
    .collection(C.categories)
    .orderBy('order')
    .limit(50)
    .get();
  return snapshot.docs
    .filter((doc) => doc.get('enabled') === true)
    .map((doc) => ({ id: doc.id, ...doc.data() }));
}
async function listTopics({ categoryId, search, cursor, limit = 15, uid }) {
  const n = Math.min(limits.pageMax, Math.max(1, Number(limit)||15)); let q = db().collection(C.topics).where('visibility','==','public').where('moderationStatus','==','published');
  if (categoryId) q=q.where('categoryId','==',clean(categoryId));
  if (search) { const keyword=normalize(search).split(' ').filter(x=>x.length>1)[0]; if (!keyword) return {items:[],nextCursor:null}; q=q.where('searchKeywords','array-contains',keyword); }
  q=q.orderBy('lastActivityAt','desc').orderBy(admin.firestore.FieldPath.documentId(),'desc');
  if (cursor) { try { const c=JSON.parse(Buffer.from(cursor,'base64url')); q=q.startAfter(admin.firestore.Timestamp.fromMillis(c.t), c.id); } catch (_) { fail('Geçersiz sayfalama anahtarı.'); } }
  const snap=await q.limit(Math.min(40,n*2)).get();let docs=snap.docs;if(uid){const blocked=await db().collection(C.blocks).where('ownerId','==',uid).limit(200).get();const ids=new Set(blocked.docs.map(x=>x.get('blockedUserId')));docs=docs.filter(x=>!ids.has(x.get('userId')));}docs=docs.slice(0,n);return { items:docs.map(topicJson), nextCursor:snap.size>=n?cursorFrom(snap.docs.at(-1)):null };
}
async function topicDetail(uid, id, replyCursor) {
  const snap=await db().collection(C.topics).doc(id).get(); if(!snap.exists) fail('Konu bulunamadı.',404,'not_found'); const d=snap.data();
  if(d.visibility!=='public'||d.moderationStatus!=='published') fail('Konu bulunamadı.',404,'not_found');
  const blocked=await db().collection(C.blocks).doc(`${uid}_${d.userId}`).get();if(blocked.exists)fail('Konu bulunamadı.',404,'not_found');
  const viewRef=snap.ref.collection('views').doc(uid);await db().runTransaction(async tx=>{const v=await tx.get(viewRef);if(!v.exists){tx.create(viewRef,{userId:uid,createdAt:admin.firestore.FieldValue.serverTimestamp()});tx.update(snap.ref,{viewCount:admin.firestore.FieldValue.increment(1)});}});
  const [fresh,vote,e,author]=await Promise.all([snap.ref.get(),snap.ref.collection('votes').doc(uid).get(),entitlement(uid),profile(d.userId)]);const topic={...topicJson(fresh),authorMemberMonths:author.memberMonths,authorMemberLevel:author.memberLevel,viewerVote:vote.exists?vote.get('value'):0};
  if(!e.active) return {topic,entitlement:e,repliesLocked:true,replies:[],nextReplyCursor:null};
  let q=snap.ref.collection('replies').where('visibility','==','public').where('moderationStatus','==','published').orderBy('createdAt').limit(20);
  if(replyCursor) q=q.startAfter(admin.firestore.Timestamp.fromMillis(Number(replyCursor)));
  const replies=await q.get();const replyProfiles=new Map((await Promise.all([...new Set(replies.docs.map(x=>x.get('authorId')).filter(Boolean))].map(async authorId=>[authorId,await profile(authorId)]))).map(x=>x));return {topic,entitlement:e,repliesLocked:false,replies:replies.docs.map(x=>{const p=replyProfiles.get(x.get('authorId'));return{id:x.id,...x.data(),authorMemberMonths:p?.memberMonths||0,authorMemberLevel:p?.memberLevel||1,createdAt:x.get('createdAt')?.toMillis?.()||null,editedAt:x.get('editedAt')?.toMillis?.()||null};}),nextReplyCursor:replies.size===20?String(replies.docs.at(-1).get('createdAt').toMillis()):null};
}
function keywords(title, body) { return [...new Set(normalize(`${title} ${body}`).split(' ').filter(x=>x.length>1).slice(0,40))]; }
async function createTopic(uid, body) {
  await requirePremium(uid); await suspension(uid); const title=clean(body.title), text=clean(body.body), categoryId=clean(body.categoryId);
  if(title.length<limits.titleMin||title.length>limits.titleMax||text.length<limits.bodyMin||text.length>limits.bodyMax) fail('Başlık veya açıklama uzunluğu geçersiz.'); await moderate(title,text);
  const cat=await db().collection(C.categories).doc(categoryId).get(); if(!cat.exists||cat.get('enabled')!==true) fail('Kategori kullanılamıyor.');
  const dayAgo=admin.firestore.Timestamp.fromMillis(Date.now()-86400000); const recent=await db().collection(C.topics).where('userId','==',uid).where('createdAt','>=',dayAgo).limit(6).get(); if(recent.size>=5) fail('Günlük konu açma sınırına ulaştınız.',429,'rate_limited');
  const p=await profile(uid); const ref=db().collection(C.topics).doc(); const retention=cat.get('retentionMode'); const days=Number(cat.get('retentionDays')||15); const expiresAt=retention==='temporary'?admin.firestore.Timestamp.fromMillis(Date.now()+days*86400000):null;
  await ref.set({title,body:text,categoryId,categoryName:cat.get('name'),userId:uid,authorDisplayName:p.displayName,authorAvatarUrl:p.avatarUrl,authorRole:p.role,authorMemberMonths:p.memberMonths,authorMemberLevel:p.memberLevel,createdAt:admin.firestore.FieldValue.serverTimestamp(),lastActivityAt:admin.firestore.FieldValue.serverTimestamp(),expiresAt,moderationStatus:'published',replyCount:0,viewCount:0,likeCount:0,dislikeCount:0,verifiedReaderReplyCount:0,resolved:false,acceptedAnswerId:null,reportCount:0,visibility:'public',locked:false,imageUrls:[],searchKeywords:keywords(title,text)});
  await db().collection(C.users).doc(uid).set({communityTopicCount:admin.firestore.FieldValue.increment(1)},{merge:true});
  return {id:ref.id};
}
async function createReply(uid,id,body) {
  await requirePremium(uid); await suspension(uid); const text=clean(body.body); if(text.length<2||text.length>limits.replyMax) fail('Cevap uzunluğu geçersiz.'); await moderate(text);
  const hourAgo=admin.firestore.Timestamp.fromMillis(Date.now()-3600000);const recent=await db().collectionGroup('replies').where('authorId','==',uid).where('createdAt','>=',hourAgo).limit(21).get();if(recent.size>=20)fail('Saatlik cevap sınırına ulaştınız.',429,'rate_limited');
  const topicRef=db().collection(C.topics).doc(id); const topic=await topicRef.get(); if(!topic.exists||topic.get('locked')) fail('Bu konuya cevap verilemiyor.',409); const p=await profile(uid); const replyRef=topicRef.collection('replies').doc();
  await db().runTransaction(async tx=>{tx.set(replyRef,{topicId:id,authorId:uid,authorDisplayName:p.displayName,authorAvatarUrl:p.avatarUrl,authorRole:p.role,authorMemberMonths:p.memberMonths,authorMemberLevel:p.memberLevel,body:text,createdAt:admin.firestore.FieldValue.serverTimestamp(),editedAt:null,moderationStatus:'published',helpfulCount:0,isAcceptedSolution:false,reportCount:0,visibility:'public'});tx.update(topicRef,{replyCount:admin.firestore.FieldValue.increment(1),verifiedReaderReplyCount:admin.firestore.FieldValue.increment(p.role==='verified_reader'?1:0),lastActivityAt:admin.firestore.FieldValue.serverTimestamp()});tx.set(db().collection(C.users).doc(uid),{communityReplyCount:admin.firestore.FieldValue.increment(1)},{merge:true});}); return {id:replyRef.id,topicOwnerId:topic.get('userId'),verifiedReader:p.role==='verified_reader'};
}
async function voteTopic(uid,topicId,value){
  await suspension(uid);value=Number(value);if(![-1,0,1].includes(value))fail('Geçersiz oy.');const topic=db().collection(C.topics).doc(clean(topicId)),vote=topic.collection('votes').doc(uid);
  let result;await db().runTransaction(async tx=>{const [ts,vs]=await Promise.all([tx.get(topic),tx.get(vote)]);if(!ts.exists)fail('Konu bulunamadı.',404);const old=vs.exists?Number(vs.get('value'))||0:0;const likes=Math.max(0,(Number(ts.get('likeCount'))||0)+(value===1?1:0)-(old===1?1:0));const dislikes=Math.max(0,(Number(ts.get('dislikeCount'))||0)+(value===-1?1:0)-(old===-1?1:0));if(value===0)tx.delete(vote);else tx.set(vote,{userId:uid,value,updatedAt:admin.firestore.FieldValue.serverTimestamp()});tx.update(topic,{likeCount:likes,dislikeCount:dislikes});result={likeCount:likes,dislikeCount:dislikes,viewerVote:value};});return result;
}
async function adminAcceptSolution(adminUid,topicId,replyId) {
  const t=db().collection(C.topics).doc(clean(topicId)), r=t.collection('replies').doc(clean(replyId));
  await db().runTransaction(async tx=>{const [ts,rs]=await Promise.all([tx.get(t),tx.get(r)]);if(!ts.exists||!rs.exists)fail('Konu veya cevap bulunamadı.',404);const old=ts.get('acceptedAnswerId');if(old&&old!==replyId)tx.set(t.collection('replies').doc(old),{isAcceptedSolution:false},{merge:true});tx.update(r,{isAcceptedSolution:true});tx.update(t,{acceptedAnswerId:replyId,resolved:true});});await db().collection(C.moderation).add({adminUid,type:'reply',topicId,targetId:replyId,action:'solution',createdAt:admin.firestore.FieldValue.serverTimestamp()});return{success:true};
}
async function report(uid, body) { const type=body.targetType==='reply'?'reply':'topic', targetId=clean(body.targetId), topicId=clean(body.topicId), reason=clean(body.reason), allowed=['Küfür / hakaret','Taciz','Spam','Uygunsuz içerik','Kişisel bilgi','Diğer']; if(!targetId||!allowed.includes(reason))fail('Rapor bilgileri geçersiz.'); const id=`${uid}_${type}_${targetId}`; await db().collection(C.reports).doc(id).create({reporterId:uid,targetType:type,targetId,topicId:topicId||null,reason,details:clean(body.details).slice(0,500),status:'open',createdAt:admin.firestore.FieldValue.serverTimestamp()}).catch(e=>{if(e.code!==6)throw e;}); return {success:true}; }
async function block(uid,targetUid,topicId){if(!targetUid&&topicId){const t=await db().collection(C.topics).doc(clean(topicId)).get();targetUid=t.exists?t.get('userId'):null;}if(!targetUid||targetUid===uid)fail('Kullanıcı engellenemedi.');await db().collection(C.blocks).doc(`${uid}_${targetUid}`).set({ownerId:uid,blockedUserId:targetUid,createdAt:admin.firestore.FieldValue.serverTimestamp()});return{success:true};}
async function attachImages(uid, topicId, images) {
  await requirePremium(uid); await suspension(uid);
  const ref=db().collection(C.topics).doc(topicId), snap=await ref.get();
  if(!snap.exists||snap.get('userId')!==uid)fail('Konu bulunamadı.',404);
  if(!Array.isArray(images)||images.length<1||images.length>3)fail('En fazla 3 görsel yüklenebilir.');
  const existing=snap.get('storagePaths')||[]; if(existing.length+images.length>3)fail('Görsel sınırı aşıldı.');
  const bucketName=process.env.COMMUNITY_STORAGE_BUCKET||process.env.FIREBASE_STORAGE_BUCKET||'tombikteyze.appspot.com';
  const bucket=admin.storage().bucket(bucketName), urls=[], paths=[];
  for(const item of images){
    const raw=clean(item.base64); let buffer; try{buffer=Buffer.from(raw,'base64');}catch(_){fail('Görsel okunamadı.');}
    if(buffer.length<100||buffer.length>1200*1024)fail('Her görsel en fazla 1,2 MB olabilir.');
    const mime=clean(item.mime); if(!['image/jpeg','image/webp','image/png'].includes(mime))fail('Yalnızca görsel yüklenebilir.');
    const id=crypto.randomUUID(), ext=mime==='image/png'?'png':mime==='image/webp'?'webp':'jpg';
    const path=`community/topics/${topicId}/${id}.${ext}`, token=crypto.randomUUID();
    await bucket.file(path).save(buffer,{resumable:false,metadata:{contentType:mime,cacheControl:'public,max-age=604800',metadata:{firebaseStorageDownloadTokens:token}}});
    paths.push(path); urls.push(`https://firebasestorage.googleapis.com/v0/b/${encodeURIComponent(bucketName)}/o/${encodeURIComponent(path)}?alt=media&token=${token}`);
  }
  await ref.update({storagePaths:admin.firestore.FieldValue.arrayUnion(...paths),imageUrls:admin.firestore.FieldValue.arrayUnion(...urls),thumbnailUrl:snap.get('thumbnailUrl')||urls[0]});
  return {imageUrls:urls};
}
async function adminOverview(){const [t,r,p,c]=await Promise.all([db().collection(C.topics).where('visibility','==','public').count().get(),db().collection(C.reports).where('status','==','open').count().get(),db().collection(C.topics).where('moderationStatus','==','pending').count().get(),db().collection(C.categories).count().get()]);return{activeTopics:t.data().count,openReports:r.data().count,pendingModeration:p.data().count,totalCategories:c.data().count};}
async function adminTopicDetail(topicId){const ref=db().collection(C.topics).doc(clean(topicId)),snap=await ref.get();if(!snap.exists)fail('Konu bulunamadı.',404);const replies=await ref.collection('replies').orderBy('createdAt').limit(200).get();return{topic:{id:snap.id,...snap.data()},replies:replies.docs.map(x=>({id:x.id,...x.data()}))};}
async function adminReply(adminUid,topicId,body){const text=clean(body.body);if(text.length<2||text.length>limits.replyMax)fail('Yorum uzunluğu geçersiz.');await moderate(text);const topic=db().collection(C.topics).doc(clean(topicId)),reply=topic.collection('replies').doc();await db().runTransaction(async tx=>{const t=await tx.get(topic);if(!t.exists)fail('Konu bulunamadı.',404);tx.set(reply,{topicId,authorId:adminUid,authorDisplayName:'Tombik Teyze Moderatörü',authorRole:'moderator',body:text,createdAt:admin.firestore.FieldValue.serverTimestamp(),editedAt:null,moderationStatus:'published',helpfulCount:0,isAcceptedSolution:false,reportCount:0,visibility:'public',moderatorApproved:true,pinned:false});tx.update(topic,{replyCount:admin.firestore.FieldValue.increment(1),lastActivityAt:admin.firestore.FieldValue.serverTimestamp()});});return{id:reply.id};}
async function adminReplyAction(adminUid,topicId,replyId,action){if(!['remove','restore','pin','unpin','approve','unapprove'].includes(action))fail('Geçersiz yorum işlemi.');const ref=db().collection(C.topics).doc(clean(topicId)).collection('replies').doc(clean(replyId));const updates=action==='remove'?{visibility:'removed',moderationStatus:'removed'}:action==='restore'?{visibility:'public',moderationStatus:'published'}:action==='pin'?{pinned:true}:action==='unpin'?{pinned:false}:action==='approve'?{moderatorApproved:true}:{moderatorApproved:false};await ref.set(updates,{merge:true});await db().collection(C.moderation).add({adminUid,type:'reply',topicId,targetId:replyId,action,createdAt:admin.firestore.FieldValue.serverTimestamp()});return{success:true};}
async function adminGrantTestEntitlement(email,days,adminUid){const normalized=clean(email).toLowerCase();if(!normalized.includes('@'))fail('Geçerli e-posta gerekli.');let user;try{user=await admin.auth().getUserByEmail(normalized);}catch(_){fail('Firebase kullanıcısı bulunamadı.',404);}const duration=Math.min(90,Math.max(1,Number(days)||30));await db().collection(C.entitlements).doc(user.uid).set({uid:user.uid,productId:'admin_test_access',status:'active',source:'admin_test',grantedBy:adminUid,expiresAt:admin.firestore.Timestamp.fromMillis(Date.now()+duration*86400000),verifiedAt:admin.firestore.FieldValue.serverTimestamp()},{merge:true});return{success:true,uid:user.uid,email:normalized,days:duration};}
async function adminUserAction(body,adminUid){const uid=clean(body.userId),action=clean(body.action),ref=db().collection(C.users).doc(uid);if(!uid||!['suspend','unsuspend','ban'].includes(action))fail('Geçersiz kullanıcı işlemi.');const update=action==='ban'?{communityBanned:true}:action==='suspend'?{communitySuspendedUntil:admin.firestore.Timestamp.fromMillis(Date.now()+Math.min(30,Math.max(1,Number(body.days)||7))*86400000)}:{communityBanned:false,communitySuspendedUntil:admin.firestore.FieldValue.delete()};await ref.set(update,{merge:true});await db().collection(C.moderation).add({adminUid,type:'user',targetId:uid,action,createdAt:admin.firestore.FieldValue.serverTimestamp()});return{success:true};}
async function adminList(collection,status,limit=50){let q=db().collection(collection);if(status)q=q.where('status','==',status);const s=await q.orderBy('createdAt','desc').limit(Math.min(100,Number(limit)||50)).get();return s.docs.map(x=>({id:x.id,...x.data()}));}
async function adminModerate(body,adminUid){const type=body.targetType==='reply'?'reply':'topic';const topic=db().collection(C.topics).doc(clean(body.topicId));const ref=type==='reply'?topic.collection('replies').doc(clean(body.targetId)):topic;const action=clean(body.action);if(!['remove','restore','lock','unlock'].includes(action))fail('Geçersiz işlem.');const update=action==='remove'?{moderationStatus:'removed',visibility:'removed',removedAt:admin.firestore.FieldValue.serverTimestamp(),...(type==='topic'?{expiresAt:admin.firestore.Timestamp.now()}:{})}:action==='restore'?{moderationStatus:'published',visibility:'public'}:action==='lock'?{locked:true}:{locked:false};await ref.set(update,{merge:true});if(body.reportId)await db().collection(C.reports).doc(clean(body.reportId)).set({status:'resolved',resolvedAt:admin.firestore.FieldValue.serverTimestamp(),resolvedBy:adminUid},{merge:true});await db().collection(C.moderation).add({adminUid,type,targetId:ref.id,topicId:topic.id,action,createdAt:admin.firestore.FieldValue.serverTimestamp()});return{success:true};}
async function cleanupExpired(){const s=await db().collection(C.topics).where('expiresAt','<=',admin.firestore.Timestamp.now()).limit(100).get();let count=0;for(const doc of s.docs){const paths=doc.get('storagePaths')||[];if(paths.length){const bucket=admin.storage().bucket(process.env.COMMUNITY_STORAGE_BUCKET||process.env.FIREBASE_STORAGE_BUCKET||'tombikteyze.appspot.com');await Promise.all(paths.map(p=>bucket.file(p).delete({ignoreNotFound:true}).catch(()=>null)));}const [replies,views,votes]=await Promise.all(['replies','views','votes'].map(name=>doc.ref.collection(name).limit(500).get()));const batch=db().batch();[...replies.docs,...views.docs,...votes.docs].forEach(x=>batch.delete(x.ref));batch.delete(doc.ref);await batch.commit();count++;}return{deleted:count};}

let cleanupTimer=null;
function startCleanupLoop(){if(cleanupTimer)return;const run=()=>cleanupExpired().then(x=>{if(x.deleted)console.log(`COMMUNITY CLEANUP deleted=${x.deleted}`);}).catch(e=>console.error('COMMUNITY CLEANUP ERROR:',e.message));void run();cleanupTimer=setInterval(run,6*60*60*1000);cleanupTimer.unref?.();}

module.exports={C,categories,listTopics,topicDetail,createTopic,createReply,voteTopic,adminAcceptSolution,report,block,attachImages,entitlement,adminOverview,adminList,adminTopicDetail,adminReply,adminReplyAction,adminGrantTestEntitlement,adminModerate,adminUserAction,cleanupExpired,startCleanupLoop,normalize,moderate,limits};
