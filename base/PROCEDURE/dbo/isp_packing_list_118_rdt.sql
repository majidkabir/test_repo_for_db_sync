SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Proc: isp_Packing_List_118_rdt                                */
/* Creation Date: 03-Dec-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-18458 - Yonex B2C Packing List                          */
/*                                                                      */
/* Called By: r_dw_packing_list_118_rdt                                 */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 03-Dec-2021  WLChooi   1.0 DevOps Combine Script                     */
/* 14-JUL-2022  CSCHONG   1.1 WMS-20190 revised field logic (CS01)      */
/* 19-JUL-2022  CSCHONG   1.2 WMS-20190 fix codelkup retrive issue (CS02)*/
/************************************************************************/
CREATE PROC [dbo].[isp_Packing_List_118_rdt]
            @c_Pickslipno    NVARCHAR(15)

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_RecCount     INT = 0
         , @n_RecPerPage   INT = 3
         , @n_ToAddRow     INT = 0
         , @n_CurrentCnt   INT = 0

   CREATE TABLE #TMP_PACK (
       Ecom_Platform     NVARCHAR(250)
     , C_Contact1        NVARCHAR(100)
     , C_Phone1          NVARCHAR(100)
     , C_Addresses       NVARCHAR(250)
     , Externorderkey    NVARCHAR(50)
     , SKUNotes1         NVARCHAR(250)
     , AltSKU            NVARCHAR(20)
     , SKU               NVARCHAR(20)
     , Qty               INT
     , Notes2            NVARCHAR(250)
     , Notes             NVARCHAR(250)
     , Orderkey          NVARCHAR(10)
   )

   INSERT INTO #TMP_PACK
   --SELECT '[' + CASE WHEN TRIM(ISNULL(OH.Ecom_Platform,'')) = 'TM' THEN N'天猫'   --CS01 S
   --                  WHEN TRIM(ISNULL(OH.Ecom_Platform,'')) = 'JD' THEN N'京东'
   --                  ELSE N'微信' END +
   --       '] ' + N'YONEX旗舰店 发货明细单' AS Ecom_Platform
    SELECT '[' + ISNULL(CLK.udf01,'') +
          '] ' + N'YONEX旗舰店 发货明细单' AS Ecom_Platform                          --CS01 E 
        , ISNULL(OH.C_Contact1,'') AS C_Contact1
        , ISNULL(OH.C_Phone1  ,'') AS C_Phone1
        , TRIM(ISNULL(OH.C_Address1,'')) + TRIM(ISNULL(OH.C_Address2,'')) +
          TRIM(ISNULL(OH.C_Address3,'')) + TRIM(ISNULL(OH.C_Address4,'')) AS C_Addresses
        , OH.Externorderkey
        , ISNULL(S.Notes1,'') AS SKUNotes1
        , ISNULL(S.AltSKU,'') AS AltSKU
        , S.SKU
        , SUM(PD.Qty) AS Qty
        , ISNULL(OH.Notes2,'') AS Notes2
        , ISNULL(OH.Notes ,'') AS Notes
        , OH.OrderKey
   FROM PACKHEADER PH (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.Orderkey
   JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
   JOIN SKU S (NOLOCK) ON S.SKU = PD.SKU AND S.StorerKey = PD.Storerkey
   LEFT JOIN CODELKUP CLK WITH (NOLOCK) ON CLK.LISTNAME = 'ECPlatform'        --CS01 S
                         AND CLK.storerkey = OH.StorerKey and CLK.short = OH.Ecom_Platform     --CS01 E
                         AND CLK.udf02='1'                   --CS02
   WHERE PH.PickSlipNo = @c_Pickslipno
   GROUP BY --TRIM(ISNULL(OH.Ecom_Platform,''))                        --CS01 
            ISNULL(CLK.udf01,'')                                       --Cs01
          , ISNULL(OH.C_Contact1,'')
          , ISNULL(OH.C_Phone1  ,'')
          , TRIM(ISNULL(OH.C_Address1,'')) + TRIM(ISNULL(OH.C_Address2,'')) +
            TRIM(ISNULL(OH.C_Address3,'')) + TRIM(ISNULL(OH.C_Address4,''))
          , OH.Externorderkey
          , ISNULL(S.Notes1,'')
          , ISNULL(S.AltSKU,'')
          , S.SKU
          , ISNULL(OH.Notes2,'')
          , ISNULL(OH.Notes ,'')
          , OH.OrderKey

   SELECT @n_RecCount = @@ROWCOUNT

   IF (@n_RecCount % @n_RecPerPage > 0) AND EXISTS (SELECT 1 FROM #TMP_PACK TP)
   BEGIN
      SET @n_ToAddRow = @n_RecPerPage - (@n_RecCount % @n_RecPerPage)

      WHILE @n_ToAddRow > 0
      BEGIN
         INSERT INTO #TMP_PACK
         SELECT TOP 1 '', '', '', '', '', '', '', '', NULL, ''
                    , '', Orderkey
         FROM #TMP_PACK

         SET @n_ToAddRow = @n_ToAddRow - 1
      END
   END

   SELECT Ecom_Platform
        , C_Contact1
        , C_Phone1
        , C_Addresses
        , Externorderkey
        , SKUNotes1
        , AltSKU
        , SKU
        , Qty
        , Notes2
        , Notes
        , Orderkey
        , (Row_Number() OVER (PARTITION BY Orderkey ORDER BY Orderkey , CASE WHEN ISNULL(Ecom_Platform,'') = ''  THEN 2 ELSE 1 END) - 1 ) / @n_RecPerPage
   FROM #TMP_PACK
   ORDER BY Orderkey
          , CASE WHEN ISNULL(Ecom_Platform,'') = ''  THEN 2 ELSE 1 END

END

GO