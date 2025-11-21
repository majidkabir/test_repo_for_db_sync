SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_Packing_List_126_rdt                                */
/* Creation Date: 12-JUL-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CHONGCS                                                  */
/*                                                                      */
/* Purpose: WMS-20126 - [CN] PVHSZ Ecom PackingList                     */
/*                                                                      */
/* Called By: r_dw_packing_list_126_rdt                                 */
/*                                                                      */
/* GitLab Version: 1.5                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 12-JUL-2022  CHONGCS   1.0 DevOps Combine Script                     */
/* 01-SEP-2022  CHONGCS   1.1 WMS-20126 revised field logic (CS01)      */
/* 19-SEP-2022  CHONGCS   1.2 WMS-20126 fix duplicate qty (CS02)        */
/* 20-OCT-2022  LZG       1.3 JSM-101324 - Display only packed SKU(ZG01)*/
/* 10-Nov-2022  WLChooi   1.4 WMS-21156 - Revamp new layout (WL01)      */
/* 11-Dec-2022  WLChooi   1.5 WMS-21156 - Print By Carton (WL02)        */
/************************************************************************/
CREATE PROC [dbo].[isp_Packing_List_126_rdt]
            @c_Storerkey      NVARCHAR(15),   --WL02
            @c_Pickslipno     NVARCHAR(20),
            @c_CartonNoStart  NVARCHAR(10) = '',   --WL02
            @c_CartonNoEnd    NVARCHAR(10) = ''    --WL02

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   --WL01 S
   /*
   SELECT PH.PickSlipNo
        , ISNULL(OH.userdefine03,'') AS Logo
        , TRIM(ISNULL(OH.C_contact1,'')) + TRIM(ISNULL(OH.C_Contact2,'')) AS C_Contact
        , TRIM(ISNULL(OH.C_Address1,'')) + SPACE(1) + TRIM(ISNULL(OH.C_Address2,'')) + SPACE(1)  +
          TRIM(ISNULL(OH.C_Address3,'')) + SPACE(1) + TRIM(ISNULL(OH.C_Address4,''))  AS C_Address1
        , TRIM(ISNULL(OH.C_Zip,'')) + SPACE(1) + TRIM(ISNULL(OH.C_City,''))  AS C_ZipCity
        , OH.ExternOrderKey
        , TRIM(ISNULL(OH.C_State,'')) + SPACE(1) + TRIM(ISNULL(OH.C_Country,''))  AS C_State
        , ISNULL(OD.notes,'') AS ODnotes                    --CS01
        , ISNULL(OH.C_Phone1,'') AS CPhone
        , ISNULL(SKU.Size,'') AS Size
        , ISNULL(C.long,'') AS ShipFrom
        , ISNULL(C.UDF01,'') AS CustSrv
        , ISNULL(C.UDF02,'') AS CustSrvEmail
        , OD.SKU                           --CS02
        , PAD.Qty  AS qty                   --CS02
        , ISNULL(C.UDF03,'') AS CustSrvTel
        , ISNULL(C.UDF04,'') AS CustSrvHLH
        , ISNULL(C.UDF05,'') AS CustSrvWH
        , ISNULL(C.Notes,'') AS CustSrvWD
        , ISNULL(C.Notes2,'') AS CustSrvURL
        , ISNULL(OH.UserDefine01,'') AS ShpNo
        , CONVERT(nvarchar(10),OH.OrderDate,120) AS ORDDate
        , ISNULL(sku.descr,'') AS Sdescr
        , ISNULL(C1.long,'') AS RtnR1
        , ISNULL(C1.UDF01,'') AS RtnR2
        , ISNULL(C1.UDF02,'') AS RtnR3
        , ISNULL(C1.UDF03,'') AS RtnR4
        , ISNULL(C1.UDF04,'') AS RtnR5
        , ISNULL(C1.UDF05,'') AS RtnR6
        , ISNULL(C2.long,'') AS FN1
        , ISNULL(C2.Notes,'') AS FN2
        , ISNULL(C2.Notes2,'') AS FN3
   FROM ORDERS OH (NOLOCK)
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
   JOIN PACKHEADER PH (NOLOCK) ON PH.OrderKey = OH.OrderKey
   --JOIN PACKDETAIL PD (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo   --CS02
   CROSS APPLY (
      SELECT SUM(Qty) AS Qty FROM PACKDETAIL (NOLOCK)
      WHERE PACKDETAIL.PickSlipNo = PH.PickSlipNo
      AND PACKDETAIL.STORERKEY = od.STORERKEY 
      AND PACKDETAIL.SKU = OD.SKU
      GROUP BY SKU   -- ZG01
   )  AS PAD --CS02
   JOIN STORER ST (NOLOCK) ON ST.StorerKey = OH.StorerKey
   JOIN SKU (NOLOCK) ON SKU.StorerKey = OD.StorerKey AND SKU.SKU = OD.SKU               --CS02
   LEFT JOIN dbo.CODELKUP C WITH (NOLOCK) ON C.Storerkey = OH.StorerKey and C.LISTNAME = 'PVHSZEPKL' and C.code = OH.userdefine03
   LEFT JOIN dbo.CODELKUP C1 WITH (NOLOCK) ON C1.Storerkey = OH.StorerKey and C1.LISTNAME = 'PVHSZEPKL' and C1.code = '00020'
   LEFT JOIN dbo.CODELKUP C2 WITH (NOLOCK) ON C2.Storerkey = OH.StorerKey and C2.LISTNAME = 'PVHSZEPKL' and C2.code ='00030'
   WHERE PH.PickSlipNo = @c_pickslipno
   AND oh.doctype ='E'
   GROUP BY PH.PickSlipNo
        , ISNULL(OH.userdefine03,'')
        , TRIM(ISNULL(OH.C_contact1,'')) + TRIM(ISNULL(OH.C_Contact2,''))
        , TRIM(ISNULL(OH.C_Address1,'')) + SPACE(1) + TRIM(ISNULL(OH.C_Address2,'')) + SPACE(1)  +
          TRIM(ISNULL(OH.C_Address3,'')) + SPACE(1) + TRIM(ISNULL(OH.C_Address4,''))
        , TRIM(ISNULL(OH.C_Zip,'')) + SPACE(1) + TRIM(ISNULL(OH.C_City,''))
        ,TRIM(ISNULL(OH.C_State,'')) + SPACE(1) + TRIM(ISNULL(OH.C_Country,''))
        ,ISNULL(OH.C_Phone1,''), ISNULL(C.long,''),ISNULL(C.UDF01,''),ISNULL(C.UDF02,'')
        ,ISNULL(C.UDF03,''),ISNULL(C.UDF04,''),ISNULL(C.UDF05,''),ISNULL(C.notes,''),ISNULL(C.Notes2,'')
        ,ISNULL(OH.UserDefine01,'') ,CONVERT(nvarchar(10),OH.OrderDate,120) ,ISNULL(sku.descr,'')
        , ISNULL(C1.long,'') , ISNULL(C1.long,''),ISNULL(C1.udf01,''),ISNULL(C1.udf02,''),ISNULL(C1.udf03,'')
        ,ISNULL(C1.udf04,''),ISNULL(C1.udf05,'') ,ISNULL(C2.long,''),ISNULL(C2.Notes,''),ISNULL(C2.Notes2,'')
        ,OH.ExternOrderKey,ISNULL(OD.notes,''),ISNULL(SKU.size,''),OD.SKU,PAD.qty   --CS01    --CS02
   ORDER BY PH.PickSlipNo*/

   --WL02 S
   IF ISNULL(@c_CartonNoStart,'') = ''
      SET @c_CartonNoStart = '1'

   IF ISNULL(@c_CartonNoEnd,'') = ''
      SET @c_CartonNoEnd = '99999'
   --WL02 E

   SELECT TRIM(ISNULL(CL2.Notes, '')) AS Logo
        , ISNULL(CL.Short, '') AS ShipTo_t
        , ISNULL(CL.UDF01, '') AS OrderNumber_t
        , ISNULL(CL.UDF02, '') AS ShipmentNumber_t
        , ISNULL(CL.UDF03, '') AS OrderDate_t
        , ISNULL(CL.UDF04, '') AS ItemNumber_t
        , ISNULL(CL.UDF05, '') AS SKU_t
        , ISNULL(CL1.UDF01, '') AS Description_t
        , ISNULL(CL1.UDF02, '') AS Size_t
        , ISNULL(CL1.UDF03, '') AS QtyShipped_t
        , ISNULL(CL1.UDF04, '') AS TotalQty_t
        , TRIM(ISNULL(OH.C_contact1, '')) + ' ' + TRIM(ISNULL(OH.C_Contact2, '')) AS C_Contact   --WL02
        , TRIM(ISNULL(OH.C_Address1, '')) + TRIM(ISNULL(OH.C_Address2, '')) + TRIM(ISNULL(OH.C_Address3, ''))
          + TRIM(ISNULL(OH.C_Address3, '')) AS C_Addresses
        , TRIM(ISNULL(OH.C_Zip, '')) + ' ' + TRIM(ISNULL(OH.C_City, '')) AS C_ZipCity
        , TRIM(ISNULL(OH.C_State, '')) + ' ' + TRIM(ISNULL(OH.C_Country, '')) AS C_StateCountry
        , TRIM(ISNULL(OH.C_Phone1, '')) AS C_Phone1
        , CASE WHEN CHARINDEX(':', OH.ExternOrderKey) - 1 > 1 THEN
                  SUBSTRING(OH.ExternOrderKey, 1, CHARINDEX(':', OH.ExternOrderKey) - 1)
               ELSE OH.ExternOrderKey END AS ExternOrderKey
        , TRIM(ISNULL(OH.UserDefine01,'')) AS UserDefine01
        , CONVERT(NVARCHAR(10),OH.OrderDate,120) AS OrderDate
        , OH.OrderKey
        , TRIM(OD.SKU) AS ItemNumber
        , TRIM(ISNULL(S.Style, '')) + TRIM(ISNULL(S.Color, '')) + TRIM(ISNULL(S.BUSR6, '')) AS SKU
        , TRIM(ODT.Notes) AS Notes
        , ISNULL(S.Size, '') AS Size
        , PAD.Qty
        , PH.PickSlipNo
        , ISNULL(CL3.[Description],'') AS CountryName
   FROM PACKHEADER PH (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.OrderKey
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
   JOIN PACKDETAIL PD (NOLOCK) ON PD.Pickslipno = PH.Pickslipno    --WL02
   CROSS APPLY (  SELECT SUM(Qty) AS Qty
                  FROM PackDetail (NOLOCK)
                  WHERE PackDetail.PickSlipNo = PH.PickSlipNo
                  AND   PackDetail.StorerKey = OD.StorerKey
                  AND   PackDetail.SKU = OD.Sku
                  AND   PackDetail.CartonNo = PD.CartonNo   --WL02
                  GROUP BY SKU) AS PAD
   JOIN SKU S (NOLOCK) ON S.StorerKey = OD.StorerKey AND S.Sku = OD.Sku
   LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'PVHSZUEPKL' AND CL.Code = OH.C_ISOCntryCode AND CL.code2 = '00010'
   LEFT JOIN CODELKUP CL1 (NOLOCK) ON CL1.LISTNAME = 'PVHSZUEPKL' AND CL1.Code = OH.C_ISOCntryCode AND CL1.code2 = '00020'
   LEFT JOIN CODELKUP CL2 (NOLOCK) ON  CL2.LISTNAME = 'RPTLOGO'
                                   AND CL2.Storerkey = OH.StorerKey
                                   AND CL2.Long = 'r_dw_Packing_List_126_rdt'
                                   AND CL2.Code = OH.UserDefine03
   LEFT JOIN CODELKUP CL3 (NOLOCK) ON CL3.LISTNAME = 'ITNSF' AND CL3.Code = OH.C_ISOCntryCode 
                                  AND CL3.Storerkey = OH.StorerKey
   CROSS APPLY (  SELECT TOP 1 ISNULL(ORDERDETAIL.Notes, '') AS Notes
                  FROM ORDERDETAIL (NOLOCK)
                  WHERE ORDERDETAIL.OrderKey = OH.OrderKey
                  AND   ORDERDETAIL.Sku = OD.Sku
                  AND   ORDERDETAIL.StorerKey = OD.StorerKey) AS ODT
   WHERE PH.PickSlipNo = @c_pickslipno
   AND OH.DocType = 'E'
   AND PD.CartonNo BETWEEN @c_CartonNoStart AND @c_CartonNoEnd   --WL02
   GROUP BY TRIM(ISNULL(CL2.Notes, ''))
          , ISNULL(CL.Short, '')
          , ISNULL(CL.UDF01, '')
          , ISNULL(CL.UDF02, '')
          , ISNULL(CL.UDF03, '')
          , ISNULL(CL.UDF04, '')
          , ISNULL(CL.UDF05, '')
          , ISNULL(CL1.UDF01, '')
          , ISNULL(CL1.UDF02, '')
          , ISNULL(CL1.UDF03, '')
          , ISNULL(CL1.UDF04, '')
          , TRIM(ISNULL(OH.C_contact1, '')) + ' ' + TRIM(ISNULL(OH.C_Contact2, ''))   --WL02
          , TRIM(ISNULL(OH.C_Address1, '')) + TRIM(ISNULL(OH.C_Address2, '')) + TRIM(ISNULL(OH.C_Address3, ''))
            + TRIM(ISNULL(OH.C_Address3, ''))
          , TRIM(ISNULL(OH.C_Zip, '')) + ' ' + TRIM(ISNULL(OH.C_City, ''))
          , TRIM(ISNULL(OH.C_State, '')) + ' ' + TRIM(ISNULL(OH.C_Country, ''))
          , TRIM(ISNULL(OH.C_Phone1, ''))
          , CASE WHEN CHARINDEX(':', OH.ExternOrderKey) - 1 > 1 THEN
                    SUBSTRING(OH.ExternOrderKey, 1, CHARINDEX(':', OH.ExternOrderKey) - 1)
                 ELSE OH.ExternOrderKey END
          , TRIM(ISNULL(OH.UserDefine01,''))
          , CONVERT(NVARCHAR(10),OH.OrderDate,120)
          , OH.OrderKey
          , TRIM(OD.SKU)
          , TRIM(ISNULL(S.Style, '')) + TRIM(ISNULL(S.Color, '')) + TRIM(ISNULL(S.BUSR6, ''))
          , TRIM(ODT.Notes)
          , ISNULL(S.Size, '')
          , PAD.Qty
          , PH.PickSlipNo
          , ISNULL(CL3.[Description],'')
          , PD.CartonNo   --WL02
   --WL01 E
   ORDER BY PH.Pickslipno, PD.CartonNo   --WL02

END

GO