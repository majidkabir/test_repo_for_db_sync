SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Packing_List_48                                */
/* Creation Date: 22-MAY-2018                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:WMS-4965 -[CN] - Skechers Packing list                       */
/*                                                                      */
/*                                                                      */
/* Called By: report dw = r_dw_packing_list_48                          */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROC [dbo].[isp_Packing_List_48] (
  @cMBOLKey NVARCHAR( 10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF

   DECLARE @n_rowid int,
           @c_cartontype NVARCHAR(10),
           @c_prevcartontype NVARCHAR(10),
           @n_cnt int


   SELECT DISTINCT ORDERS.c_Company AS con_company,
          ORDERS.c_Address1 AS con_address1,
          ORDERS.c_contact1 AS Con_contact,
          ORDERS.C_City AS Con_City,
          ORDERS.c_phone1 AS Con_Phone1,
          ORDERS.ExternOrderkey AS ExtOrdKey,
          MBOLDETAIL.[WEIGHT] AS MBWGT,   --real
          MBOL.MbolKey AS MBOLKEY,
          MBOLDETAIL.TotalCartons AS TotalCartons, --real
          MBOLDETAIL.[cube] AS MBCube,  --real
          SKU.price AS sprice,   --real
          SKU.[size] AS [ssize],   --nvarchar(10)
          SKU.style AS [sstyle],  --nvarchar(20)
          PACKDETAIL.CartonNo AS cartonno,--integer
          PACKDETAIL.qty   AS PQTY    
          FROM MBOL WITH (NOLOCK)                  
          INNER JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
          INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
          LEFT JOIN ORDERDETAIL OD (NOLOCK) ON (ORDERS.OrderKey = OD.OrderKey)
          INNER JOIN SKU WITH (NOLOCK) ON (OD.StorerKey = SKU.StorerKey AND OD.Sku = SKU.Sku)
          INNER JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
          INNER JOIN PACKHEADER WITH (NOLOCK) ON ( ORDERS.Loadkey = PACKHEADER.Loadkey)
          INNER JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo AND
                                                   OD.Storerkey = PACKDETAIL.Storerkey AND
                                                    OD.Sku = PACKDETAIL.Sku)
   WHERE MBOL.MBOLKey = @cMBOLKey
   ORDER BY MBOL.MBOLKey,ORDERS.ExternOrderkey, PACKDETAIL.CartonNo , SKU.style ,SKU.size

END

GO