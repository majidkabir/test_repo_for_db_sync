SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_Packing_List_111_rdt                                */
/* Creation Date: 18-Aug-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Mingle                                                   */
/*                                                                      */
/* Purpose:  WMS-17753                                                  */
/*        :                                                             */
/* Called By: r_dw_Packing_List_111_rdt                                 */
/*          :                                                           */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 2021-12-28   SYCHUA    1.0 JSM-42492 Fix Editdate Display issue(SY01)*/
/************************************************************************/

CREATE PROC [dbo].[isp_Packing_List_111_rdt] (
   @c_Pickslipno NVARCHAR(21) )

AS
BEGIN
   SET NOCOUNT ON
  -- SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF

   SELECT DISTINCT OH.ExternOrderKey,
                   (ISNULL(OH.C_contact1,'') + '' + ISNULL(OH.C_contact2,'')) AS OHContact,
                   (ISNULL(OH.C_Address2,'') + '' + ISNULL(OH.C_Address3,'') + ISNULL(OH.C_Address4,'')) AS OHAddress,
                   OH.C_Phone1,
                   --FORMAT(pd.EditDate, N'yyyyÏƒâ•£â”¤MMÂµÂ£ÃªddÂµÃ¹Ã‘') AS editdate,
                   --convert(varchar, PD.EditDate, 3) AS editdate,    --SY01
                   convert(varchar, PD.EditDate, 103) AS editdate,    --SY01
                   --PD.EditDate,
                   OH.Salesman + N'Î¦Â«Ã³ÏƒÃ¬Ã²' AS Salesman,
                   OH.ShipperKey,
                   OH.TrackingNo,
                   S.ALTSKU,
                   PD.Qty,
                   PD.Loc,
                   PD.Sku,
                   CASE WHEN ISNULL(OD.UnitPrice,'') = '' THEN '0' ELSE OD.UnitPrice END AS UnitPrice,
                   CASE WHEN ISNULL(OH.B_Vat,'') = '' THEN '0' ELSE OH.B_Vat END AS B_Vat,
                   SUM(OD.UnitPrice*PD.Qty) AS PQTY
   FROM ORDERS OH WITH (NOLOCK)
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
   JOIN PACKHEADER PH (NOLOCK) ON PH.OrderKey = OH.OrderKey
   JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = OH.Orderkey AND PD.OrderLineNumber = OD.OrderLineNumber
   JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU
   WHERE PH.Pickslipno = @c_Pickslipno
   GROUP BY OH.ExternOrderKey,
            (ISNULL(OH.C_contact1,'') + '' + ISNULL(OH.C_contact2,'')),
            (ISNULL(OH.C_Address2,'') + '' + ISNULL(OH.C_Address3,'') + ISNULL(OH.C_Address4,'')),
            OH.C_Phone1,
            --FORMAT(pd.EditDate, N'yyyyÏƒâ•£â”¤MMÂµÂ£ÃªddÂµÃ¹Ã‘'),
            --convert(varchar, PD.EditDate, 3),    --SY01
            convert(varchar, PD.EditDate, 103),    --SY01
            --PD.EditDate,
            OH.Salesman + N'Î¦Â«Ã³ÏƒÃ¬Ã²',
            OH.ShipperKey,
            OH.TrackingNo,
            S.ALTSKU,
            PD.Qty,
            PD.Loc,
            PD.Sku,
            CASE WHEN ISNULL(OD.UnitPrice,'') = '' THEN '0' ELSE OD.UnitPrice END,
            CASE WHEN ISNULL(OH.B_Vat,'') = '' THEN '0' ELSE OH.B_Vat END


END -- procedure

GO