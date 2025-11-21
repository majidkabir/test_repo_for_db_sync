SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RPT_MB_PICKLIST_001_1                          */
/* Creation Date: 09-NOV-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WZPang                                                   */
/*                                                                      */
/* Purpose: WMS-20954 - FRR - Truck Picking List Report(SG)		        */
/*                                                                      */
/* Called By: RPT_MB_PICKLIST_001_1                                     */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/************************************************************************/
CREATE   PROC [dbo].[isp_RPT_MB_PICKLIST_001_1](
            @c_Mbolkey		NVARCHAR(10),
			@c_Company		NVARCHAR(255)
			)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   SELECT	MBOL.MbolKey
		,	MBOL.DRIVERName
		,	MBOL.AddDate
		,	ORDERS.C_Company
		,	ORDERS.C_Address1
		,	ORDERS.C_Address2
		,	ORDERS.C_Address3
		,	ORDERS.C_Address4
		,	ORDERS.C_Zip
		,	ORDERS.C_Country
		,	ORDERS.OrderKey
		,	SKU.AltSKU
		,	PICKDETAIL.SKU
		,	SKU.Descr
		,	LOTATTRIBUTE.Lottable01
		--,	SUM(PICKDETAIL.Qty) / PACK.Casecnt AS Carton
		,	( SELECT SUM(pd.Qty)/CAST(NULLIF(p.casecnt,0) AS INT)
      FROM MBOL MB WITH (NOLOCK)  
      JOIN MBOLDETAIL MBD WITH (NOLOCK) ON MBD.mbolkey = MB.MbolKey  
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON Od.OrderKey=MBD.orderkey  
	  JOIN ORDERS WITH (NOLOCK) ON (MBD.Orderkey = ORDERS.OrderKey)
      JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.OrderKey = OD.OrderKey AND PD.Storerkey=OD.StorerKey AND PD.Sku = OD.Sku AND PD.OrderLineNumber = OD.OrderLineNumber  
      JOIN SKU S WITH (NOLOCK) ON s.StorerKey=PD.Storerkey AND S.sku=PD.Sku  
      JOIN dbo.LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.lot = PD.Lot AND LOTT.Sku=PD.Sku AND LOTT.StorerKey = PD.Storerkey  
      JOIN PACK P WITH (NOLOCK) ON P.PackKey=S.PACKKey  
      WHERE MB.MbolKey = @c_Mbolkey AND PD.SKU = PICKDETAIL.SKU AND PD.Orderkey = PICKDETAIL.Orderkey
      GROUP BY s.ALTSKU,od.Sku,LOTT.Lottable01,p.casecnt,p.InnerPack  
  ) AS Carton
		,	ORDERS.ExternOrderKey
		--,	CASE WHEN  (SUM(PICKDETAIL.Qty)%CAST(NULLIF(PACK.casecnt,0) AS INT)) <> 0 THEN  (SUM(PICKDETAIL.Qty)%CAST(nullif(PACK.casecnt,0) AS INT)/CAST(nullif(PACK.InnerPack,0) AS INT) )  ELSE 0 END AS InnerPack
		,	( SELECT CASE WHEN  (SUM(PD.Qty) % CAST(NULLIF(p.casecnt,0) AS INT)) <> 0 THEN  (SUM(PD.Qty) % CAST(NULLIF(P.casecnt,0) AS INT) / CAST(NULLIF(p.InnerPack,0) AS INT) )  ELSE 0 END
			FROM MBOL MB WITH (NOLOCK)  
			JOIN MBOLDETAIL MBD WITH (NOLOCK) ON MBD.mbolkey = MB.MbolKey  
			JOIN ORDERDETAIL OD WITH (NOLOCK) ON Od.OrderKey=MBD.orderkey  
			JOIN ORDERS WITH (NOLOCK) ON (MBD.Orderkey = ORDERS.OrderKey)
			JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.OrderKey = OD.OrderKey AND PD.Storerkey=OD.StorerKey AND PD.Sku = OD.Sku AND PD.OrderLineNumber = OD.OrderLineNumber  
			JOIN SKU S WITH (NOLOCK) ON s.StorerKey=PD.Storerkey AND S.sku=PD.Sku  
			JOIN dbo.LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.lot = PD.Lot AND LOTT.Sku=PD.Sku AND LOTT.StorerKey = PD.Storerkey  
			JOIN PACK P WITH (NOLOCK) ON P.PackKey=S.PACKKey  
			WHERE MB.MbolKey = @c_Mbolkey AND PD.SKU = PICKDETAIL.SKU AND PD.Orderkey = PICKDETAIL.Orderkey
			GROUP BY od.Sku,LOTT.Lottable01,p.casecnt,p.InnerPack  
  ) AS InnerPack
		,	C_Addr = CASE WHEN TRIM(ISNULL(C_Address1,'')) = '' THEN '' ELSE TRIM(ISNULL(C_Address1,'')) + CHAR(10) + CHAR(13) END +
                 CASE WHEN TRIM(ISNULL(C_Address2,'')) = '' THEN '' ELSE TRIM(ISNULL(C_Address2,'')) + CHAR(10) + CHAR(13) END +
                 CASE WHEN TRIM(ISNULL(C_Address3,'')) = '' THEN '' ELSE TRIM(ISNULL(C_Address3,'')) + CHAR(10) + CHAR(13) END +
                 CASE WHEN TRIM(ISNULL(C_Address4,'')) = '' THEN '' ELSE TRIM(ISNULL(C_Address4,'')) + CHAR(10) + CHAR(13) END +
				 CASE WHEN TRIM(ISNULL(C_Zip,'')) ='' THEN '' ELSE TRIM(ISNULL(C_Zip,''))   END
		,	(ROW_Number() OVER (PARTITION BY ORDERS.C_Company ORDER BY ORDERS.C_Company ASC))  AS RecordNo

	FROM MBOL (NOLOCK)
	JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOLDETAIL.MbolKey = MBOL.MbolKey)
	JOIN ORDERS WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.OrderKey)
	JOIN PICKDETAIL   WITH (NOLOCK) ON  (ORDERS.Orderkey = PICKDETAIL.Orderkey)
	JOIN SKU WITH (NOLOCK)  ON (PICKDETAIL.StorerKey = SKU.StorerKey) AND (PICKDETAIL.Sku = SKU.Sku)
	JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey) 
	JOIN LOTATTRIBUTE WITH (NOLOCK) on (PICKDETAIL.Lot = LOTATTRIBUTE.Lot)
	WHERE MBOL.Mbolkey = @c_Mbolkey AND ORDERS.C_Company = @c_Company
	GROUP BY MBOL.MbolKey
		,	MBOL.DRIVERName
		,	MBOL.AddDate
		,	ORDERS.C_Company
		,	ORDERS.C_Address1
		,	ORDERS.C_Address2
		,	ORDERS.C_Address3
		,	ORDERS.C_Address4
		,	ORDERS.C_Zip
		,	ORDERS.C_Country
		,	ORDERS.OrderKey
		,	SKU.AltSKU
		,	PICKDETAIL.SKU
		,	SKU.Descr
		,	LOTATTRIBUTE.Lottable01
		,	ORDERS.ExternOrderKey
		,	PACK.InnerPack
		,	PACK.Casecnt
		,	PICKDETAIL.Orderkey
	ORDER BY ExternOrderKey, DESCR

END -- procedure

GO