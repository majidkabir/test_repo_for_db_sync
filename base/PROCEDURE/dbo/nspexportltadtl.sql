SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspExportLTADtl                                    */
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

CREATE PROCEDURE [dbo].[nspExportLTADtl]  -- drop proc nspExportLTADtl
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_whseid char (2),
   @c_batchno char (5),
   @c_receiptkey char (9),
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
   @b_success int,
   @n_err int,
   @c_errmsg   NVARCHAR(250),
   @n_tranno int,
   @c_unique char (15)
   -- select candidate tranx with type 'MV' for export
   SELECT tranno = 0,
   uniquekey = itrn.itrnkey,
   whseid = '01',
   batchno=ncounter.keycount,
   Trantype = 'T',
   SKU =ITRN.SKU,
   Frmwhse = '01',
   Frmloc = Case
   When Itrn.Fromloc=Loc.loc Then '13'
Else '11'
End,
Qty = sum(Itrn.Qty)/Pack.Casecnt,
RefNo = substring(ITRN.ITRNKey,3,8),
Linenum = '001',
Comments = ' ',
ReasonCode= '17',
Trandate =  RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, Itrn.adddate))),4) +
RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, Itrn.adddate))),2) +
RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, Itrn.adddate))),2),
UOM ='CS',
Towhse = '01',
Toloc =  Case
When Itrn.Fromloc=Loc.loc Then '11'
Else '13'
End,
Ercode = '1',
CurrentDate =   RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, getdate()))),4) +
RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, getdate()))),2) +
RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, getdate()))),2)
INTO  #Temp
FROM  ITRN (nolock), LOC (nolock), Ncounter (nolock),Pack (nolock)
WHERE  (ITRN.Toloc=LOC.loc or ITRN.FromLoc = LOC.loc) and
ITRN.Trantype = 'MV' and
--LOC.LocationFlag = 'Hold' and
LOC.LocationFlag <> 'DAMAGE' and
LOC.LocationType <> 'DMAGE'  and
LOC.Loc like '%Fresh%' and
Itrn.Storerkey = 'ULP' and
NCounter.Keyname = 'LTAbatch'  and
Pack.Packkey=Itrn.Packkey and
Loc.loc in (select loc from loc (nolock) where sectionkey = '13')

GROUP BY Loc.Loc,Pack.Casecnt,ITRN.ITRNKey, ITRN.adddate,ITRN.SKU,ITRN.UOM,LOC.SectionKey,ITRN.Fromloc,ITRN.Toloc,Ncounter.Keycount,Loc.Sectionkey
SELECT @c_refno = space(10)
SELECT @c_lineno = space(5)
SELECT @c_unique =space(15)
SELECT @n_tranno = 0
WHILE (1=1)
BEGIN
   SET ROWCOUNT 1
   SELECT @c_unique = uniquekey
   FROM #temp
   WHERE  uniquekey > @c_unique
   ORDER BY uniquekey

   IF @@ROWCOUNT = 0
   BEGIN
      SET ROWCOUNT 0
      BREAK
   END
   SET ROWCOUNT 0
   SELECT @n_tranno = @n_tranno + 1
   UPDATE #temp
   SET tranno = @n_tranno
   WHERE uniquekey = @c_unique
END
SELECT whseid,
batchno =ncounter.keycount,
tranno,
Trantype ,
SKU ,
Frmwhse,
Frmloc ,
Qty ,
refno,
Linenum ,
Comments ,
ReasonCode,
Trandate ,
UOM ,
Towhse ,
Toloc,
Ercode
From #temp,ncounter (nolock)
WHERE ncounter.keyname = 'LTAbatch'
and   Trandate =currentdate
ORDER by tranno
EXEC nspg_getkey 'LTAbatch', 10, @c_batchno OUTPUT, @b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
DROP TABLE #Temp
END


GO