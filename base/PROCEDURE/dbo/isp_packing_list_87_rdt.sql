SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Packing_List_87_RDT                            */
/* Creation Date: 01-Oct-2020                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-15375 - [CN] ZCJ PackingList                            */
/*                                                                      */
/* Called By: report dw = r_dw_packing_list_87_RDT                      */
/*                                                                      */
/* GitLab Version: 1.2                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author           Ver.  Purposes                         */
/* 2021-03-21   SeongYaikChua    1.0   Bug Fix for Multiple Order Line  */
/*                                     of same SKU                      */
/* 2021-07-29   WLChooi          1.1   WMS-17508 - Add new column (WL01)*/
/************************************************************************/
CREATE PROC [dbo].[isp_Packing_List_87_RDT] (
   @c_Pickslipno NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF

   DECLARE @c_Orderkey      NVARCHAR(10)
         , @n_MaxLineno     INT = 25
         , @n_CurrentRec    INT
         , @n_MaxRec        INT
         , @n_cartonno      INT

   SET @c_Orderkey = @c_Pickslipno

   IF EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE PickSlipNo = @c_Pickslipno)
   BEGIN
      SELECT @c_Orderkey = OrderKey
      FROM PACKHEADER (NOLOCK)
      WHERE PickSlipNo = @c_Pickslipno
   END

   --CREATE TABLE #TMP_PL84 (
   -- RowID         INT NOT NULL IDENTITY(1,1) PRIMARY KEY
   -- , C_contact1    NVARCHAR(45)
   -- , C_Phone1      NVARCHAR(45)
   -- , C_Addresses   NVARCHAR(250)
   -- , Orderkey      NVARCHAR(10)
   -- , OrderDate     DATETIME
   -- , Sku           NVARCHAR(20)  NULL
   -- , Descr         NVARCHAR(250) NULL
   -- , OriginalQty   INT           NULL
   -- , Logo          NVARCHAR(100)
   -- , t1            NVARCHAR(250)
   -- , t2            NVARCHAR(250)
   -- , t3            NVARCHAR(250)
   -- , t4            NVARCHAR(250)
   -- , t5            NVARCHAR(250)
   -- , t6            NVARCHAR(250)
   -- , t7            NVARCHAR(250)
   -- , t8            NVARCHAR(250)
   -- , t9            NVARCHAR(250)
   --)

   --Start (SeongYaikChua)
   --Add Temp Table to Aggregate Multiple Line in OrderDetail
   IF OBJECT_ID('tempdb..#TEMP_ZCJ_PCKLIST_87_RDT') IS NOT NULL
      DROP TABLE #TEMP_ZCJ_PCKLIST_87_RDT

   CREATE TABLE #TEMP_ZCJ_PCKLIST_87_RDT (
     RowID         INT NOT NULL IDENTITY(1,1) PRIMARY KEY
     , Orderkey     NVARCHAR(20)
     , Sku          NVARCHAR(20)    NULL
     , OriginalQty  INT             NULL
   )

   TRUNCATE TABLE #TEMP_ZCJ_PCKLIST_87_RDT

   INSERT INTO #TEMP_ZCJ_PCKLIST_87_RDT (Orderkey, Sku, OriginalQty)
   SELECT Orderkey, Sku, SUM(OriginalQty)
   FROM ORDERDETAIL (NOLOCK)
   WHERE Orderkey = @c_Orderkey
   GROUP BY Orderkey, Sku

   --End (SeongYaikChua)

   SELECT ISNULL(OH.C_Contact1,'') AS C_Contact1
        , ISNULL(OH.C_Address1,'') AS C_Address1
        , ISNULL(OH.C_Address2,'') AS C_Address2
        , ISNULL(OH.C_Address3,'') AS C_Address3
        , ISNULL(OH.C_Address4,'') AS C_Address4
        , ISNULL(CL.Long,'') AS CLLong
        , ISNULL(CL.UDF01,'') AS CLUDF01
        , ISNULL(CL.UDF02,'') AS CLUDF02
        , ISNULL(CL.UDF03,'') AS CLUDF03
        , ISNULL(CL.UDF04,'') AS CLUDF04
        , PH.EditDate
        , OH.Externorderkey
        , OH.UserDefine04
        , OD.Sku
        , S.Descr
        , SUM(PD.Qty) AS PackedQty
        , SUM(OD.OriginalQty) As OriginalQty
        , SUM(S.StdGrossWgt * PD.qty) AS TotalWgt
        , SUM(S.StdCube * PD.qty) AS TotalCube
        , 'ZCJ_Logo.png' AS Logo
        , OH.OrderKey AS Orderkey
        , ISNULL(CL1.Notes,'') AS CL1Notes   --WL01
        , ISNULL(CL2.Notes,'') AS QRCode     --WL01
   FROM PACKHEADER PH (NOLOCK)
   JOIN PACKDETAIL PD (NOLOCK) ON PD.PickSlipNo = PH.Pickslipno
   JOIN ORDERS OH (NOLOCK) On PH.Orderkey = OH.OrderKey
   JOIN #TEMP_ZCJ_PCKLIST_87_RDT OD (NOLOCK) ON OH.OrderKey = OD.OrderKey AND PD.SKU = OD.SKU  --SeongYaikChua
   JOIN SKU S (NOLOCK) ON S.SKU = OD.SKU AND S.StorerKey = OH.StorerKey
   LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'ZCJPACK'
                                 AND CL.Storerkey = OH.StorerKey AND CL.Code = 'B4'
   LEFT JOIN CODELKUP CL1 (NOLOCK) ON CL1.Listname = 'ZCJPKLIST'                         --WL01
                                  AND CL1.Storerkey = OH.StorerKey AND CL1.Code = 'A1'   --WL01
   LEFT JOIN CODELKUP CL2 (NOLOCK) ON CL2.Listname = 'RPTLOGO'                           --WL01
                                  AND CL2.Long = 'r_dw_packing_list_87_RDT'              --WL01
                                  AND CL2.Storerkey = OH.StorerKey AND CL2.Code = 'ZCJQR'   --WL01
   WHERE OH.Orderkey = @c_Orderkey
   GROUP BY ISNULL(OH.C_Contact1,'')
          , ISNULL(OH.C_Address1,'')
          , ISNULL(OH.C_Address2,'')
          , ISNULL(OH.C_Address3,'')
          , ISNULL(OH.C_Address4,'')
          , ISNULL(CL.Long,'')
          , ISNULL(CL.UDF01,'')
          , ISNULL(CL.UDF02,'')
          , ISNULL(CL.UDF03,'')
          , ISNULL(CL.UDF04,'')
          , PH.EditDate
          , OH.Externorderkey
          , OH.UserDefine04
          , OD.Sku
          , S.Descr
          , OH.OrderKey
          , ISNULL(CL1.Notes,'')   --WL01
          , ISNULL(CL2.Notes,'')   --WL01

END

GO