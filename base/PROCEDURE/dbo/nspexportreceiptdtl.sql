SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspexportreceiptdtl                                */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[nspexportreceiptdtl]
as
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_count int,
   @b_success int,
   @n_err int,
   @c_errmsg   NVARCHAR(250),
   @c_whseid char (2),
   @c_batchno int,
   @c_trantype char (2),
   @c_SKU char (15),
   @c_fromwhse char (2),
   @c_fromloc char (6),
   @n_qty int,
   @c_refno char (8),
   @c_lineno char (3),
   @c_comments char (15),
   @c_reasoncode char (2),
   @c_trandate char (8),
   @c_UOM char (2),
   @c_towhse char (2),
   @c_toloc char (6),
   @c_ercode char (7) ,
   @n_tranno int,
   @c_unique char (15),
   @n_keycount int

   select @n_keycount = keycount
   from ncounter (nolock)
   where keyname = 'rrbatch'

   SELECT whseid = '01',
   batchno = @n_keycount,
   tranno = 0,
   Trantype = 'T',
   SKU =Receiptdetail.SKU,
   Frmwhse = Receiptdetail.VesselKey,
   Frmloc =Receiptdetail.VoyageKey,
   Qty = sum(Receiptdetail.Qtyreceived/pack.casecnt),
   uniquekey = receipt.receiptkey+receiptdetail.receiptlinenumber,
   refno=Receipt.warehousereference,
   Linenum = substring(Receiptdetail.Receiptlinenumber,3,3),
   Comments = convert(NVARCHAR(15),Receipt.Notes),
   ReasonCode= Receipt.ASNReason,
   Trandate =  RIGHT(dbo.fnc_RTrim("00" + CONVERT(Nchar(4), DATEPART(year, Receiptdetail.editdate))),4) +
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(Nchar(2), DATEPART(month, Receiptdetail.editdate))),2) +
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(Nchar(2), DATEPART(day, Receiptdetail.editdate))),2),
   UOM =Receiptdetail.UOM,
   Towhse = '01',
   Toloc = '11' ,
   Ercode = '1'
   INTO #Result
   FROM  Receipt (nolock), ReceiptDetail (nolock) ,Loc (nolock), sku (nolock), pack (nolock)
   WHERE Receipt.receiptkey = ReceiptDetail.receiptkey
   AND Receiptdetail.Toloc=Loc.Loc
   AND ReceiptDetail.exportstatus = '0'
   AND ReceiptDetail.qtyreceived > 0
   AND Receiptdetail.Storerkey = 'ULP'
   and receiptdetail.sku = sku.sku
   and sku.storerkey = receiptdetail.storerkey
   and sku.packkey = pack.packkey
   AND RECEIPT.RECTYPE <> 'RET'
   GROUP BY receipt.receiptkey,
   Receiptdetail.SKU,
   Receipt.Origincountry,
   Loc.SectionKey,
   Receipt.Warehousereference,
   Receiptdetail.receiptlinenumber,
   convert(NVARCHAR(15),Receipt.Notes),
   Receiptdetail.editdate,
   Receiptdetail.UOM,
   Receipt.DestinationCountry,
   receiptdetail.qtyreceived,
   Receipt.ASNReason,
   Receiptdetail.VoyageKey,
   Receiptdetail.Vesselkey

   SELECT @c_refno = space(10)
   SELECT @c_lineno = space(5)
   SELECT @c_unique =space(15)
   SELECT @n_tranno = 0

   WHILE (1=1)
   BEGIN
      SET ROWCOUNT 1
      SELECT @c_unique = uniquekey
      FROM #result
      WHERE  uniquekey > @c_unique
      ORDER BY uniquekey

      IF @@ROWCOUNT = 0
      BEGIN
         SET ROWCOUNT 0
         BREAK
      END

      SET ROWCOUNT 0
      SELECT @n_tranno = @n_tranno + 1
      UPDATE #result
      SET tranno = convert(NVARCHAR(5), @n_tranno)
      WHERE uniquekey = @c_unique
   END

   update ncounter
   set keycount = keycount + 1
   where keyname = 'rrbatch'

   select whseid,
   batchno,
   tranno,
   Trantype,
   SKU,
   Frmwhse,
   Frmloc,
   Qty,
   refno,
   Linenum,
   Comments,
   ReasonCode,
   Trandate,
   UOM,
   Towhse,
   Toloc,
   Ercode,
   uniquekey
   from #result
   order by tranno
   drop table #result
END


GO