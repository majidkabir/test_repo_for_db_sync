SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspExportCCHdr                                     */
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

/****** Object:  Stored Procedure dbo.nspExportCCHdr  Script Date: 9/04/00 11:07:02 AM ******/
CREATE PROCEDURE [dbo].[nspExportCCHdr]  -- drop proc nspExportCCHdr
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   /*  DECLARE @n_count int
   SELECT @n_count = COUNT(*)
   FROM ReceiptDetail
   WHERE exportstatus = '0'
   AND qtyreceived > 0
   AND receiptkey NOT LIKE 'DUMMY%'
   */
   DECLARE  @c_whseid char (2),
   @c_batchno char (5),
   @c_trandate NVARCHAR(8),
   @n_totrec int,
   @n_hashtot int,
   @c_extractdate NVARCHAR(8)
   -- select candidate tranx with type 'MV' for export
   SELECT whseid = '01',
   batchno =ncounter.keycount,
   Trandate =  RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year,getdate()))),4) +
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, getdate()))),2) +
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, getdate()))),2),
   totrec = count(lot.lot),
   HashTot1=sum(Lot.Qty-Lot.qtypicked)/Pack.casecnt,
   currentdate = RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, getdate()))),4) +
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, getdate()))),2) +
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, getdate()))),2)
   INTO #Temp
   FROM  Lot,Ncounter,SKU,pack
   WHERE  Lot.SKU=SKU.SKU and
   Pack.Packkey=SKU.packkey and
   Ncounter.Keyname = 'RRBatch' and
   Lot.Qty > 0

   GROUP BY  NCounter.Keycount,Pack.Casecnt
   SELECT  Whseid,
   Batchno,
   Trandate,
   Totrec=sum(totrec) ,
   Hashtot=sum(hashtot1),
   Currentdate
   into #temp1
   FROM	  #TEMP
   WHERE TranDate=CurrentDate
   group by Whseid,
   Batchno,
   Trandate,
   Trandate,
   Currentdate
   SELECT  @c_whseid=Whseid,
   @c_batchno=Batchno,
   @c_trandate=Trandate,
   @n_totrec=Totrec ,
   @n_hashtot=Hashtot,
   @c_extractdate=Currentdate
   FROM #temp1
   SELECT whseid=@c_whseid,
   batchno=@c_batchno,
   trandate=@c_trandate,
   totrec=@n_totrec,
   hashtot=@n_hashtot,
   currentdate=@c_extractdate
   DROP TABLE #Temp
   DROP TABLE #Temp1
END


GO