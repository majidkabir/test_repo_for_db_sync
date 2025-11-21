SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspExportSTDHdr                                    */
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

CREATE PROCEDURE [dbo].[nspExportSTDHdr]
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
   -- select candidate STD for export
   select  whseid=idsstktrfdoc.sourceid,
   batchno =ncounter.keycount,
   Trandate =  RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, getdate()))),4) +
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, getdate()))),2) +
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, getdate()))),2),
   totrec = count(Idsstktrfdocdetail.STDNo), totrej = '0',
   hashtotal=sum(idsstktrfdocdetail.qty/pack.casecnt) ,
   hashcal='0'

   into #temp
   from idsstktrfdocdetail (nolock),pack (nolock),idsstktrfdoc (nolock),ncounter (nolock)
   where  'u'+idsstktrfdocdetail.sku=pack.packkey
   and idsstktrfdoc.stdno=idsstktrfdocdetail.stdno
   and idsstktrfdocdetail.exportstatus = ' '
   and  Ncounter.Keyname = 'STDBatch'
   and idsstktrfdocdetail.printed = 'y'
   group by  IDSstktrfdoc.sourceid,ncounter.keycount
   SELECT  Whseid,
   Batchno,
	  Trandate,
	  Totrec  ,
   Totrej,
   hashtot=(hashtotal)  ,
   Hashcal
   --into #temp1
   FROM	  #TEMP
   GROUP By Whseid,
   Batchno,
	  Trandate,
	  Totrec ,
   Totrej,
   hashtotal,
   Hashcal
   DROP TABLE #Temp
END


GO