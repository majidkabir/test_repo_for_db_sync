SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspExportSCHeader                                  */
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

CREATE PROCEDURE [dbo].[nspExportSCHeader]
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_count int, @n_continue int, @b_success int, @n_err int,  @c_errmsg   NVARCHAR(250),@c_batchno int
   declare @d_addtime datetime
   select
   Warehouse = '01',
   MBOLKEY=MBOL.MBOLKey,
   WEIGHT = LOADPLAN.Weight,
   CAPACITY =Routemaster.volume,
   VESSELQUALIFIER=MBOL.VesselQualifier,
   CARRIER=MBOL.CarrierKey,
   ROUTE=Loadplan.Route,
   VESSEL=MBOL.Vessel,
   Pickedflag = 'P',
   CreationDate =  RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, MBOL.ADDDate))),4) +
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, MBOL.ADDDate))),2)
   + RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, MBOL.ADDDate))),2) ,
   ADDTIME=MBOL.Adddate,batchno = '00000'
   into #temp
   FROM MBOL (nolock),
   MBOLDETAIL (nolock),
   LOADPLAN (nolock),
   TRANSMITLOG (nolock),
   ORDERS (nolock),
   ROUTEMASTER (nolock)
   WHERE  MBOL.mbolkey=MBOLDETAIL.mbolkey
   and 	MBOLDetail.Loadkey=Loadplan.Loadkey
   and 	ORDERS.orderkey=mboldetail.orderkey
   and 	TRANSMITLOG.key1 = MBOL.mbolkey
   and  transmitlog.key3 = orders.externorderkey
   AND	Transmitlog.Transmitflag = '0'
   AND  	Transmitlog.TableName = 'MBOL'
   AND 	Orders.Status = '9'
   AND orders.type = '0'
   AND 	Routemaster.Route=Loadplan.Route
   GROUP BY MBOL.MBOLKey,LOADPLAN.Weight,MBOL.Capacity,MBOL.VesselQualifier,MBOL.CarrierKey,LOADPLAN.Route,MBOL.Vessel,MBOL.ADDDate,Routemaster.volume
   select 	 Warehouse,
   MBOLKey,
   Weight,
   Capacity ,
   VesselQualifier,
   Carrier,
   Route,
   Vessel,
   Pickedflag,
   CreationDate,
   addtime,
   batchno=ncounter.keycount
   from #temp,ncounter
   where ncounter.keyname = 'SCbatch'
   order by mbolkey
   EXEC nspg_getkey 'SCbatch', 10, @c_batchno OUTPUT, @b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
   drop table #temp
END


GO