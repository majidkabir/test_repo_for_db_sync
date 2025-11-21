SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RPT_MB_DELORDER_013_2                          */
/* Creation Date: 18-Aug-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-23404 - SG - PMI - Delivery Note Report [CR]            */
/*                                                                      */
/* Called By: RPT_MB_DELORDER_013                                       */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 18-Aug-2023  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/
CREATE   PROC [dbo].[isp_RPT_MB_DELORDER_013_2]
(@c_Orderkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue     INT = 1
         , @c_errmsg       NVARCHAR(255)
         , @b_success      INT
         , @n_err          INT
         , @n_PrtAll       INT = 0
         , @c_CAddress1    NVARCHAR(100)
         , @c_CAddress2    NVARCHAR(100)
         , @c_CAddress3    NVARCHAR(100)
         , @c_CAddress4    NVARCHAR(100)
         , @c_CZip         NVARCHAR(200)
         , @c_CAddr        NVARCHAR(1000)
         , @c_ColValue     NVARCHAR(500)

   SELECT @c_CAddress1 = ISNULL(OH.C_Address1,'')
        , @c_CAddress2 = ISNULL(OH.C_Address2,'')
        , @c_CAddress3 = ISNULL(OH.C_Address3,'')
        , @c_CAddress4 = ISNULL(OH.C_Address4,'')
        , @c_CZip      = ISNULL(OH.C_Zip,'') + ' ' + ISNULL(OH.C_Country,'')
   FROM ORDERS OH (NOLOCK)
   WHERE OH.Orderkey = @c_Orderkey

   SET @c_CAddr = ISNULL(@c_CAddress1,'') + '^' + ISNULL(@c_CAddress2,'') + '^' + ISNULL(@c_CAddress3,'') + '^' + ISNULL(@c_CAddress4,'') + '^' + ISNULL(@c_CZip,'')

   SET @c_CAddress1 = ''
   SET @c_CAddress2 = ''
   SET @c_CAddress3 = ''
   SET @c_CAddress4 = ''
   SET @c_CZip      = ''

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TRIM(FDS.ColValue)
   FROM FNC_DelimSplit('^', @c_CAddr) FDS
   WHERE FDS.ColValue <> ''

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_ColValue

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @c_CAddress1 = ''
      BEGIN
         SET @c_CAddress1 = @c_ColValue
      END
      ELSE IF @c_CAddress2 = ''
      BEGIN
         SET @c_CAddress2 = @c_ColValue
      END
      ELSE IF @c_CAddress3 = ''
      BEGIN
         SET @c_CAddress3 = @c_ColValue
      END
      ELSE IF @c_CAddress4 = ''
      BEGIN
         SET @c_CAddress4 = @c_ColValue
      END
      ELSE IF @c_CZip = ''
      BEGIN
         SET @c_CZip = @c_ColValue
      END

      FETCH NEXT FROM CUR_LOOP INTO @c_ColValue
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP

   SELECT CASE WHEN P.[Status] = '4' THEN CONVERT(NVARCHAR(10), P.RedeliveryDate, 105)
               ELSE CONVERT(NVARCHAR(10), OH.DeliveryDate, 105)END AS DeliveryDate
        , OH.[Route]
        , OH.ExternOrderKey
        , ISNULL(OH.ConsigneeKey, '') AS ConsigneeKey
        , ISNULL(OH.C_Company, '') AS C_Company
        , ISNULL(@c_CAddress1, '') AS C_Address1
        , ISNULL(@c_CAddress2, '') AS C_Address2
        , ISNULL(@c_CAddress3, '') AS C_Address3
        , ISNULL(@c_CAddress4, '') AS C_Address4
        , ISNULL(@c_CZip, '') AS C_Zip
        , '' AS C_Country
        , PD.CaseID
        , ISNULL(CL.UDF01, '') AS CLUDF01
        , ISNULL(CL.[Description], '') AS DESCR
        , MD.MbolKey
        , (  SELECT COUNT(DISTINCT PDET.CaseID)
             FROM PICKDETAIL PDET (NOLOCK)
             WHERE PDET.OrderKey = OH.OrderKey) AS TTLPackages
        , PDT.PickSlipNo
        , CAST(SUM(PDT.Qty) / PK.OtherUnit1 AS INT) AS PackedQTYCtn
        , OH.OrderKey
        , ISNULL(CL.UDF02, '') AS PACKCODE
        , EAN8Barcode = IIF(LEN(TRIM(ISNULL(CL.UDF02, ''))) = 8 AND LEFT(TRIM(ISNULL(CL.UDF02, '')), 1) = '0', 'N', 'Y')
   FROM MBOLDETAIL MD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON MD.OrderKey = OH.OrderKey
   JOIN ( SELECT DISTINCT PICKDETAIL.Orderkey, PICKDETAIL.Storerkey, PICKDETAIL.SKU, PICKDETAIL.DropID, PICKDETAIL.CaseID
          FROM PICKDETAIL (NOLOCK)
          WHERE PICKDETAIL.OrderKey = @c_Orderkey) PD ON PD.OrderKey = OH.OrderKey
   JOIN ( SELECT DISTINCT ORDERDETAIL.StorerKey, ORDERDETAIL.SKU, ORDERDETAIL.AltSku
          FROM ORDERDETAIL (NOLOCK)
          WHERE ORDERDETAIL.OrderKey = @c_Orderkey) OD ON OD.StorerKey = PD.Storerkey AND OD.SKU = PD.SKU
   JOIN SKU S (NOLOCK) ON S.StorerKey = PD.Storerkey AND S.Sku = PD.Sku
   LEFT JOIN STORER ST (NOLOCK) ON ST.StorerKey = OH.Consigneekey
   LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'GROUPSKU' AND CL.code2 = OD.ALTSKU 
                                 AND CL.Storerkey = OD.StorerKey
                                 AND CL.Code = IIF(ISNULL(ST.[Secondary],'') = '', 'PMIDN', ST.[Secondary])
   LEFT JOIN POD P (NOLOCK) ON P.OrderKey = OH.OrderKey
   JOIN PackHeader PH (NOLOCK) ON PH.OrderKey = OH.OrderKey
   JOIN PackDetail PDT (NOLOCK) ON PDT.PickSlipNo = PH.PickSlipNo AND PDT.DropID = PD.DropID 
                               AND PDT.StorerKey = PD.Storerkey AND PDT.SKU = PD.SKU
   JOIN PACK PK (NOLOCK) ON PK.PackKey = S.PACKKey
   WHERE OH.[Type] = 'CCB2B'
   AND OH.[Status] >= '5'
   AND OH.Orderkey = @c_Orderkey
   GROUP BY CASE WHEN P.[Status] = '4' THEN CONVERT(NVARCHAR(10), P.RedeliveryDate, 105)
                 ELSE CONVERT(NVARCHAR(10), OH.DeliveryDate, 105)END
          , OH.[Route]
          , OH.ExternOrderKey
          , ISNULL(OH.ConsigneeKey, '')
          , ISNULL(OH.C_Company, '')
          , PD.CaseID
          , ISNULL(CL.UDF01, '')
          , MD.MbolKey
          , OH.OrderKey
          , OH.ConsigneeKey
          , PDT.PickSlipNo
          , PK.OtherUnit1
          , OH.OrderKey
          , ISNULL(CL.UDF02, '')
          , ISNULL(CL.[Description], '')
   ORDER BY OH.ConsigneeKey
          , OH.ExternOrderKey
          , PD.CaseID
          , ISNULL(CL.[Description], '')

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END
END -- procedure     

GO