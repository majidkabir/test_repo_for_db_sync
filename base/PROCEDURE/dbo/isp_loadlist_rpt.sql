SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_loadlist_rpt                                    */
/* Creation Date: 2018-03-08                                             */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: WMS-4171 -HM JP - Load List (For DN) - report printing       */
/*                                                                       */
/* Called By: r_loadlist_rpt                                             */
/*                                                                       */
/* PVCS Version: 1.1                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author  Ver   Purposes                                    */
/* 02-OCT-18   LZG     1.1   INC0409184 - Group and sort by              */
/*                           Loc.LogicalLocation (ZG01)                  */
/* 19-DEC-18   WLCHOOI 1.2   WMS-7316 - Add loadkey range as             */  
/*                           parameter (WL01)                            */  
/*************************************************************************/
CREATE PROC [dbo].[isp_loadlist_rpt]  
         (  @c_loadkeyfrom    NVARCHAR(10) --WL01  
         ,  @c_loadkeyto    NVARCHAR(10) --WL01  
         ,  @c_type     NVARCHAR(10)= '')  

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE --@c_storerkey  NVARCHAR(10)
			@c_storerkeyfrom	NVARCHAR(10) --WL01
		   ,@c_storerkeyto		NVARCHAR(10) --WL01
           ,@n_NoOfLine			INT


   SET @n_NoOfLine = 40
   
   --WL01 START
   SELECT @c_storerkeyfrom = MIN(OH.Storerkey)
         ,@c_storerkeyto = MAX(OH.Storerkey)
   FROM ORDERS OH (NOLOCK)
   WHERE Loadkey BETWEEN @c_loadkeyfrom AND @c_loadkeyto
   --WL01 END

   IF @c_type = '' OR @c_type = '1'
   BEGIN

   	SELECT row_number() over(order by OrdHD.LoadKey,Loc.Score , Loc.LogicalLocation, OrdHD.Orderkey, OrdHD.Route  ) as [RowNo] ,          -- ZG01 --WL01 (Added Loadkey)
              OrdHD.LoadKey AS Loadkey, OrdHD.OrderKey AS Orderkey,
              Sum( OrdDT.OriginalQty ) [TotalQty] , OrdHD.Route AS OHROUTE,
             (Row_Number() OVER (PARTITION BY OrdHD.LoadKey , OrdHD.OrderKey , OrdHD.Route , Loc.Loc , Loc.Score ORDER BY Loc.Score , OrdHD.Route Asc)-1)/@n_NoOfLine AS recgrp
		  FROM ORDERS AS OrdHD WITH (NOLOCK)
		  JOIN ORDERDETAIL as OrdDT WITH (NOlock)
			 ON OrdHD.StorerKey = OrdDT.StorerKey
			AND OrdHD.OrderKey = OrdDt.OrderKey
		  JOIN PICKDETAIL AS PickDT WITH (nolock)
			 ON OrdDT.StorerKey = PickDT.Storerkey
			AND OrdDT.OrderKey = PickDT.OrderKey
			AND OrdDT.OrderLineNumber = PickDT.OrderLineNumber
		  JOIN LOC WITH (nolock)
			 ON PickDT.Loc = Loc.Loc
			AND LOC.Facility = 'HM'
		 WHERE OrdHD.StorerKey BETWEEN @c_storerkeyfrom AND @c_storerkeyto --WL01
			AND OrdHD.LoadKey BETWEEN @c_loadkeyfrom AND @c_loadkeyto --WL01
		 GROUP BY OrdHD.LoadKey , OrdHD.OrderKey , OrdHD.Route , Loc.Loc , Loc.LogicalLocation, Loc.Score       -- ZG01
		 ORDER BY OrdHD.LoadKey, Loc.Score , Loc.LogicalLocation, Loc.Loc, OrdHD.Orderkey             -- ZG01  --WL01 (Added Loadkey)


   END
   ELSE
   BEGIN
   	SELECT row_number() over(order by OrdHD.LoadKey , OrdHD.OrderKey , OrdHD.Route) AS [RowNo] ,
             OrdHD.LoadKey AS Loadkey, OrdHD.OrderKey AS Orderkey, Sum( OrdDT.OriginalQty ) [TotalQty] ,
             OrdHD.Route AS OHROUTE,
             (Row_Number() OVER (PARTITION BY OrdHD.LoadKey , OrdHD.OrderKey , OrdHD.Route ORDER BY OrdHD.LoadKey , OrdHD.OrderKey , OrdHD.Route Asc)-1)/@n_NoOfLine AS recgrp
       FROM ORDERS AS  OrdHD WITH (NOLOCK)
		  JOIN ORDERDETAIL AS OrdDT (NOlock)
			 ON OrdHD.StorerKey = OrdDT.StorerKey
			AND OrdHD.OrderKey = OrdDt.OrderKey
		 WHERE OrdHD.StorerKey BETWEEN @c_storerkeyfrom AND @c_storerkeyto --WL01
			AND OrdHD.LoadKey BETWEEN @c_loadkeyfrom AND @c_loadkeyto --WL01
		 GROUP BY OrdHD.LoadKey , OrdHD.OrderKey , OrdHD.Route
		 ORDER BY OrdHD.LoadKey ,OrdHD.OrderKey

   END

    QUIT_SP:

END


GO