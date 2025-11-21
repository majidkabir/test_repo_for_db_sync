SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_PackListBySku35_rdt                            */
/* Creation Date: 18-Sep-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-23672 - [CN] Gentle Monster Packing List_New            */
/*                                                                      */
/* Called By: report dw = r_dw_packing_list_by_sku35_rdt                */
/*                                                                      */
/* GitHub Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver.  Purposes                                 */
/* 18-Sep-2023  WLChooi  1.0   DevOps Combine Script                    */
/************************************************************************/

CREATE   PROC [dbo].[isp_PackListBySku35_rdt]
(@c_Pickslipno NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF

   DECLARE @n_Continue INT = 1

   SELECT C_contact1 = TRIM(OH.C_contact1)
        , C_Phone = ISNULL(TRIM(OH.C_Phone1), '') + ISNULL(TRIM(OH.C_Phone2), '')
        , M_Company = TRIM(OH.M_Company)
        , C_Address = ISNULL(TRIM(OH.C_Address1), '') + ISNULL(TRIM(OH.C_Address2), '') + ISNULL(TRIM(OH.C_Address3), '') + ISNULL(TRIM(OH.C_Address4), '')
        , OrderDate = CONVERT(NVARCHAR(10), OH.OrderDate, 111)
        , DESCR = ISNULL(TRIM(S.DESCR),'')
        , Qty = SUM(PD.Qty)
        , Unitprice = ISNULL(OD.Unitprice,0.00)
        , Notes = ISNULL(TRIM(OH.Notes),'')
        , Notes2 = ISNULL(TRIM(OH.Notes2),'')
        , PH.Pickslipno
        , OH.Orderkey
        , ExternOrderkey = TRIM(OH.ExternOrderkey)
   FROM PACKHEADER PH (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.Orderkey = PH.Orderkey
   JOIN ORDERDETAIL OD (NOLOCK) ON OH.Orderkey = OD.Orderkey
   JOIN PICKDETAIL PD (NOLOCK) ON PD.Orderkey = OD.Orderkey
                              AND PD.OrderLineNumber = OD.OrderLineNumber
                              AND PD.SKU = OD.SKU
   JOIN SKU S (NOLOCK) ON S.Storerkey = PD.Storerkey
                      AND S.SKU = PD.SKU
   WHERE PH.Pickslipno = @c_Pickslipno
   GROUP BY TRIM(OH.C_contact1)
          , ISNULL(TRIM(OH.C_Phone1), '') + ISNULL(TRIM(OH.C_Phone2), '')
          , TRIM(OH.M_Company)
          , ISNULL(TRIM(OH.C_Address1), '') + ISNULL(TRIM(OH.C_Address2), '') + ISNULL(TRIM(OH.C_Address3), '') + ISNULL(TRIM(OH.C_Address4), '')
          , CONVERT(NVARCHAR(10), OH.OrderDate, 111)
          , ISNULL(TRIM(S.DESCR),'')
          , ISNULL(OD.Unitprice,0.00)
          , ISNULL(TRIM(OH.Notes),'')
          , ISNULL(TRIM(OH.Notes2),'')
          , PH.Pickslipno
          , OH.Orderkey
          , TRIM(OH.ExternOrderkey)
          , S.SUSR1
   ORDER BY CASE WHEN S.SUSR1 = N'商品' THEN 10 ELSE 20 END
          , ISNULL(TRIM(S.DESCR),'')
END

GO