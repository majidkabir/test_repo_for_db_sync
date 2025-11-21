SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspexportccdtl                                     */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[nspexportccdtl]  -- drop proc nspexportccdtl
as
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_count int, @n_continue int, @b_success int, @n_err int,  @c_errmsg   NVARCHAR(250)
   DECLARE  @c_whseid char (2),
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
   @c_unique char (15)

   SELECT tranno = 0,
   uniquekey = lot.lot,
   whseid = '01',
   batchno=ncounter.keycount,
   SKU =Lot.SKU,
   WhseCode = '01',
   LocCode = ' ',
   Qty = sum(Lot.Qty-Lot.qtypicked/pack.casecnt),
   UOM ='CS',
   Stockcount = sum(Lot.Qty-Lot.qtypicked/pack.casecnt),
   Trandate =  RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, getdate()))),4) +
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, getdate()))),2) +
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, getdate()))),2),
   currentdate = RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, getdate()))),4) +
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, getdate()))),2) +
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, getdate()))),2),pack.casecnt
   INTO #Result
   FROM  Lot, Ncounter,pack,SKU
   WHERE  Lot.SKU=SKU.SKU and
   Pack.Packkey=SKU.Packkey  and
   Lot.Qty > 0 and
   Ncounter.Keyname ='RRBatch'
   GROUP By Lot.lot,Lot.SKU,NCounter.Keycount,pack.casecnt


   SELECT @c_refno = space(10)
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
      SET tranno = @n_tranno
      WHERE uniquekey = @c_unique
   END
   SELECT whseid ,
   batchno,
   Tranno,
   SKU ,
   WhseCode ,
   LocCode,
   Qty ,
   UOM,
   Stockcount

   From #result,ncounter
   where ncounter.keyname = 'rrbatch'
   and   Trandate =currentdate
   GROUP BY whseid ,
   batchno,
   Tranno,
   SKU ,
   WhseCode ,
   LocCode,
   Qty ,
   UOM,
   Stockcount
   Order by Tranno
   /*
   set rowcount 1
   begin
   EXEC nspg_getkey 'Stocktakebatch', 10, @c_batchno OUTPUT, @b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
   end
   */
   DROP TABLE #result
END


GO