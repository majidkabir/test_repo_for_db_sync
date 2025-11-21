SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspExportLTAHdr                                    */
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

CREATE PROCEDURE [dbo].[nspExportLTAHdr]  -- drop proc nspExportLTAHdr
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_whseid char (2),
   @c_batchno char (5),
   @c_trandate NVARCHAR(8),
   @n_totrec int,
   @n_totrej int,
   @n_hashtot int,
   @n_hashcal int
   -- select candidate tranx with type 'MV' for export
   SELECT whseid = '01',
   batchno =ncounter.keycount,
   Trandate =  RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, Itrn.adddate))),4) +
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, Itrn.adddate))),2) +
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, Itrn.adddate))),2),
   totrec = count(itrn.itrnkey),
   totrej = '0',
   HashTot1=sum(ITrn.Qty)/pack.casecnt,
   HashCal= '0',
   currentdate = RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, getdate()))),4) +
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, getdate()))),2) +
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, getdate()))),2)
   INTO #Temp
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

   GROUP BY  NCounter.Keycount,Itrn.Adddate,Pack.casecnt
   SELECT  Whseid,
   Batchno,
	  Trandate,
	  Totrec=sum(totrec) ,
   Totrej,
   Hashtot=sum(Hashtot1),
   Hashcal
   into #temp1
   FROM #temp
   WHERE TranDate=CurrentDate
   GROUP BY whseid,batchno,trandate,hashcal, totrej
   SELECT  @c_whseid=Whseid,
   @c_batchno=Batchno,
	  @c_trandate=Trandate,
	  @n_totrec=Totrec ,
   @n_totrej=Totrej,
   @n_hashtot=Hashtot,
   @n_hashcal=Hashcal
   FROM	  #TEMP1
   select 	whseid=@c_whseid,
   batchno=@c_batchno,
   trandate=@c_trandate,
   totrec=@n_totrec,
   totrej=@n_totrej,
   hashtot=@n_hashtot,
   hashcal=@n_hashcal
   --  GROUP BY batchno,adddate
   DROP TABLE #Temp  ,#temp1
END


GO