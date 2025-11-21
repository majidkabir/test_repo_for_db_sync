SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO









CREATE View [dbo].[V_UnCloseASN] as
   select distinct receipt.receiptkey
   from receipt (nolock), storerconfig (nolock), receiptdetail a (nolock)
   where receipt.storerkey = storerconfig.storerkey
   and storerconfig.configkey = 'OWITF'
   and storerconfig.svalue = '1'
   and receipt.asnstatus <> '9'
   and receipt.facility = '1101'
   and receipt.receiptkey = a.receiptkey
   and a.finalizeflag = 'Y'
   and not exists(select 1 from lotxlocxid (nolock)
                          join receiptdetail (nolock) on receiptdetail.toloc = lotxlocxid.loc
                                          and receiptdetail.toid = lotxlocxid.id
                                          and lotxlocxid.qty > 0
                                          and receiptdetail.finalizeflag = 'Y'
                                          and receiptdetail.receiptkey = receipt.receiptkey)











GO