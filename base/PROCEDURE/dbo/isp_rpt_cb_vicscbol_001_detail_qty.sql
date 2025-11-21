SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: isp_RPT_CB_VICSCBOL_001_Detail_Qty                               */
/* Creation Date: 06-Sep-2024                                           */
/* Copyright: Maersk                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: UWP-24135 & FCR-798 - NAM|Maersk Logi Report|LVSUSA| Migrate*/
/*          VICS CBOL report to Maersk WMS V2 for Granite Project       */
/*        :                                                             */
/* Called By: RPT_CB_VICSCBOL_001_Detail_Qty                            */
/*          :                                                           */
/* Github Version: 1.5                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 06-Sep-2024 WLChooi  1.0   DevOps Combine Script                     */
/* 11-Oct-2024 CalvinK  1.1   Sum Qty and remove Distinct (CLVN01)      */
/* 24-Oct-2024 WLChooi  1.2   FCR-1076 Add Total Pallet & Weight (WL01) */
/* 13-Nov-2024 WLChooi  1.3   FCR-1294 Add Total weight of pallet and   */
/*                            grand total of weight (WL02)              */
/* 25-Nov-2024 WLChooi  1.4   FCR-1459 Split weight by group (WL03)     */
/* 13-Jan-2025 WLChooi  1.5   FCR-2217 Use FreightClass instead of BUSR3*/
/*                            (WL04)                                    */
/* 1-Mar-2025  ALiang   1.6   FCR-3258 add /1728 to change cubic inches */
/*                            to cubic feet.(AL01)                      */
/************************************************************************/
CREATE   PROCEDURE [dbo].[isp_RPT_CB_VICSCBOL_001_Detail_Qty]
(
   @n_Cbolkey  BIGINT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue  INT = 1
         , @n_StartTCnt INT = @@TRANCOUNT
       
   --WL01 S
   CREATE TABLE #T_DUMMY (
         RowID             INT NOT NULL IDENTITY(1,1)
       , BUSR3             NVARCHAR(50) NULL
       , NMFC              NVARCHAR(50) NULL
       , BUSR7             NVARCHAR(50) NULL
       , [DESCRIPTION]     NVARCHAR(250) NULL
       , QTY               INT NULL
       , [WEIGHT]          FLOAT NULL
       , TTLPLT            INT NULL
       , TTLPLTWGT         FLOAT NULL
       , DummyRec          NVARCHAR(1) DEFAULT 'N'
       , UOM               NVARCHAR(10) NULL   --WL02
   )

   --WL03 S
   DECLARE @T_BUSR AS TABLE (
         BUSR3             NVARCHAR(50) NULL
       , BUSR7             NVARCHAR(50) NULL
       , TTLCTN            INT
       , [WEIGHT]          FLOAT NULL
       , [CUBE]            FLOAT NULL
       , Storerkey         NVARCHAR(15)
   )
   --WL03 E

   DECLARE @c_Userdefine09 NVARCHAR(10) = ''
         , @c_Storerkey    NVARCHAR(15) = ''
         , @n_PalletWgt    FLOAT = 0.00
         , @n_TotalRow     INT = 0
         , @n_CurrentCnt   INT = 0
         , @n_MaxRow       INT = 4   --WL02
         , @n_TTLPLT       INT = 0
         , @n_TTLPLTWgt    FLOAT = 0.00
         , @c_Mbolkey      NVARCHAR(10) = ''
         , @c_CtnGrp       NVARCHAR(50)   --WL03

   SELECT @c_Storerkey = MAX(ORDERS.StorerKey)
        , @c_CtnGrp = MAX(STORER.CartonGroup)   --WL03
   FROM MBOL (NOLOCK)
   JOIN ORDERS (NOLOCK) ON ORDERS.MBOLKey = MBOL.MbolKey
   JOIN STORER WITH (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey   --WL03
   WHERE MBOL.CBOLKey = @n_Cbolkey

   SET @n_TTLPLTWgt = 0.00

   DECLARE CUR_PLT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT MBOL.MBOLKey, MBOL.UserDefine09
   FROM MBOL (NOLOCK)
   WHERE MBOL.CBOLKey = @n_Cbolkey

   OPEN CUR_PLT

   FETCH NEXT FROM CUR_PLT INTO @c_Mbolkey, @c_Userdefine09

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_TTLPLT = 0
      SET @n_PalletWgt = 0.00

      ;WITH CTE AS ( SELECT TOP 1 CODELKUP.Short, SeqNo = 2
                     FROM CODELKUP (NOLOCK)
                     WHERE CODELKUP.LISTNAME = 'LVSUSPLT' AND CODELKUP.Storerkey = @c_Storerkey AND CODELKUP.Code = '1'
                     UNION ALL
                     SELECT TOP 1 CODELKUP.Short, SeqNo = 1
                     FROM CODELKUP (NOLOCK)
                     WHERE CODELKUP.LISTNAME = 'LVSUSPLT' AND CODELKUP.Storerkey = @c_Storerkey AND CODELKUP.Code = @c_Userdefine09 )
      SELECT TOP 1 @n_PalletWgt = IIF(ISNUMERIC(CTE.Short) = 1, CAST(CTE.Short AS FLOAT), 1.0)
      FROM CTE
      ORDER BY CTE.SeqNo

      SELECT @n_TTLPLT = COUNT(DISTINCT PLTD.Palletkey)
      FROM ORDERS OH (NOLOCK)
      JOIN PACKHEADER PH (NOLOCK) ON PH.OrderKey = OH.OrderKey
      JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
      JOIN PALLETDETAIL PLTD (NOLOCK) ON PD.LabelNo = PLTD.CaseId AND PD.StorerKey = PLTD.StorerKey
      WHERE OH.MBOLKey = @c_Mbolkey

      SET @n_TTLPLTWgt = @n_TTLPLTWgt + (@n_TTLPLT * @n_PalletWgt)

      FETCH NEXT FROM CUR_PLT INTO @c_Mbolkey, @c_Userdefine09
   END
   CLOSE CUR_PLT
   DEALLOCATE CUR_PLT
   --WL01 E

   --WL03 S
   ;WITH CTE AS (
   SELECT PD.PickSlipNo, PD.LabelNo, '' AS BUSR3, MAX(S.BUSR7) AS BUSR7, SUM(PD.Qty * S.STDGROSSWGT) AS [WEIGHT], C.CartonWeight   --WL04
          --   , SUM(PD.Qty * S.STDCUBE) AS [CUBE]
         ,SUM(PD.Qty * S.STDCUBE)/1728 AS [CUBE] --AL01
   FROM MBOL MB (NOLOCK)
   JOIN MBOLDETAIL MD (NOLOCK) ON MB.MBOLKey = MD.MBOLKey
   JOIN ORDERS OH (NOLOCK) ON MD.OrderKey = OH.OrderKey
   JOIN PACKHEADER PH (NOLOCK) ON OH.OrderKey = PH.Orderkey
   JOIN PACKDETAIL PD (NOLOCK) ON PD.Pickslipno = PH.PickSlipNo
   JOIN SKU S (NOLOCK) ON PD.Storerkey = S.Storerkey AND PD.SKU = S.SKU
   JOIN PACKINFO PF (NOLOCK) ON PF.Pickslipno = PD.Pickslipno AND PF.Cartonno = PD.Cartonno
   JOIN CARTONIZATION C (NOLOCK) ON C.CartonType = PF.CartonType AND C.CartonizationGroup = @c_CtnGrp
   WHERE MB.CBOLKey = @n_Cbolkey
   GROUP BY PD.PickSlipNo, PD.LabelNo, C.CartonWeight   --WL04
   ), CTE2 AS (
   SELECT COUNT(DISTINCT LabelNo) AS TTLCTN, BUSR3, BUSR7, SUM([WEIGHT]) AS [WEIGHT], CartonWeight, SUM([CUBE]) AS [CUBE]
   FROM CTE
   GROUP BY BUSR3, BUSR7, CartonWeight )
   INSERT INTO @T_BUSR ([WEIGHT], BUSR3, BUSR7, TTLCTN, Storerkey, [CUBE])
   SELECT SUM(CartonWeight * TTLCTN) + SUM([WEIGHT]), BUSR3, BUSR7, SUM(TTLCTN), @c_Storerkey, SUM([CUBE])
   FROM CTE2
   GROUP BY BUSR3, BUSR7

   --SELECT DISTINCT SKU.BUSR3 --(CLVN01)
   --SELECT SKU.BUSR3			   --(CLVN01)
   --     , CASE WHEN ROUND((SUM(SKU.GrossWgt * PD.Qty) / IIF(SUM(SKU.StdCube * PD.Qty) = 0, 1, SUM(SKU.StdCube * PD.Qty))), 0) < 1   THEN '49880/1'
   --            WHEN ROUND((SUM(SKU.GrossWgt * PD.Qty) / IIF(SUM(SKU.StdCube * PD.Qty) = 0, 1, SUM(SKU.StdCube * PD.Qty))), 0) < 2   THEN '49880/2'
   --            WHEN ROUND((SUM(SKU.GrossWgt * PD.Qty) / IIF(SUM(SKU.StdCube * PD.Qty) = 0, 1, SUM(SKU.StdCube * PD.Qty))), 0) < 4   THEN '49880/3'
   --            WHEN ROUND((SUM(SKU.GrossWgt * PD.Qty) / IIF(SUM(SKU.StdCube * PD.Qty) = 0, 1, SUM(SKU.StdCube * PD.Qty))), 0) < 6   THEN '49880/4'
   --            WHEN ROUND((SUM(SKU.GrossWgt * PD.Qty) / IIF(SUM(SKU.StdCube * PD.Qty) = 0, 1, SUM(SKU.StdCube * PD.Qty))), 0) < 8   THEN '49880/5'
   --            WHEN ROUND((SUM(SKU.GrossWgt * PD.Qty) / IIF(SUM(SKU.StdCube * PD.Qty) = 0, 1, SUM(SKU.StdCube * PD.Qty))), 0) < 10  THEN '49880/6'
   --            WHEN ROUND((SUM(SKU.GrossWgt * PD.Qty) / IIF(SUM(SKU.StdCube * PD.Qty) = 0, 1, SUM(SKU.StdCube * PD.Qty))), 0) < 12  THEN '49880/7'
   --            WHEN ROUND((SUM(SKU.GrossWgt * PD.Qty) / IIF(SUM(SKU.StdCube * PD.Qty) = 0, 1, SUM(SKU.StdCube * PD.Qty))), 0) < 15  THEN '49880/8'
   --            WHEN ROUND((SUM(SKU.GrossWgt * PD.Qty) / IIF(SUM(SKU.StdCube * PD.Qty) = 0, 1, SUM(SKU.StdCube * PD.Qty))), 0) >= 15 THEN '49880/9'
   --       END AS NMFC
   --     , SKU.BUSR7
   --     , ISNULL(CODELKUP.[Description], SKU.BUSR7) AS [DESCRIPTION]
   --     , QTY = PK.TTLCTN
   --     , [WEIGHT] = CD.TTLWeight
   --     , TTLPLT = MAX(PL.TTLPLT)   --WL01
   --INTO #TEMP --(CLVN01)
   --FROM CBOL WITH (NOLOCK)
   --JOIN MBOL WITH (NOLOCK) ON (CBOL.CBOLKey = MBOL.CBOLKey)
   --JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MbolKey = MBOLDETAIL.MbolKey)
   --JOIN LoadPlan WITH (NOLOCK) ON (MBOLDETAIL.LoadKey = LoadPlan.LoadKey)
   --JOIN ORDERS WITH (NOLOCK) ON (MBOLDETAIL.OrderKey = ORDERS.OrderKey)
   --JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
   --JOIN SKU WITH (NOLOCK) ON (SKU.Sku = ORDERDETAIL.Sku AND SKU.StorerKey = ORDERDETAIL.StorerKey)
   --LEFT JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.LISTNAME = 'NMFC' AND CODELKUP.Code = SKU.BUSR6)
   --JOIN (  SELECT CBOLKey
   --             , SUM(TTLCTN) AS TTLCTN
   --             , SUM(TTLWeight) AS TTLWeight
   --        FROM [dbo].[fnc_GetVicsCBOL_CartonInfo](@n_Cbolkey)
   --        GROUP BY CBOLKey) AS CD ON (CBOL.CBOLKey = CD.CBOLKey)
   --CROSS APPLY ( SELECT COUNT(DISTINCT P.LabelNo) AS TTLCTN 
   --              FROM PACKDETAIL P (NOLOCK)
   --              JOIN PACKHEADER PH (NOLOCK) ON P.Pickslipno = PH.Pickslipno
   --              WHERE PH.Orderkey = ORDERS.Orderkey ) AS PK
   --JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = ORDERDETAIL.OrderKey AND PD.OrderLineNumber = ORDERDETAIL.OrderLineNumber
   --                           AND PD.Storerkey = SKU.StorerKey AND PD.SKU = SKU.SKU
   ----WL01 S
   --CROSS APPLY ( SELECT COUNT(DISTINCT PLTD.Palletkey) AS TTLPLT
   --              FROM MBOL MB (NOLOCK)
   --              JOIN ORDERS OH (NOLOCK) ON MB.MbolKey = OH.MBOLKey
   --              JOIN PACKHEADER PH (NOLOCK) ON PH.OrderKey = OH.OrderKey
   --              JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
   --              JOIN PALLETDETAIL PLTD (NOLOCK) ON PD.LabelNo = PLTD.CaseId AND PD.StorerKey = PLTD.StorerKey
   --              WHERE MB.CBOLKey = CBOL.CBOLKey) AS PL
   ----WL01 E
   --WHERE CBOL.CBOLKey = @n_Cbolkey
   --GROUP BY SKU.BUSR3
   --       , SKU.BUSR7
   --       , CODELKUP.[Description]
   --       , ORDERS.ExternOrderKey
   --       , PK.TTLCTN
   --       , CD.TTLWeight

   SELECT CASE WHEN ROUND((MAX(T1.[WEIGHT]) / IIF(MAX(T1.[CUBE]) = 0, 1, MAX(T1.[CUBE]))), 0) < 1   THEN '400'
               WHEN ROUND((MAX(T1.[WEIGHT]) / IIF(MAX(T1.[CUBE]) = 0, 1, MAX(T1.[CUBE]))), 0) < 2   THEN '300'
               WHEN ROUND((MAX(T1.[WEIGHT]) / IIF(MAX(T1.[CUBE]) = 0, 1, MAX(T1.[CUBE]))), 0) < 4   THEN '250'
               WHEN ROUND((MAX(T1.[WEIGHT]) / IIF(MAX(T1.[CUBE]) = 0, 1, MAX(T1.[CUBE]))), 0) < 6   THEN '150'
               WHEN ROUND((MAX(T1.[WEIGHT]) / IIF(MAX(T1.[CUBE]) = 0, 1, MAX(T1.[CUBE]))), 0) < 8   THEN '125'
               WHEN ROUND((MAX(T1.[WEIGHT]) / IIF(MAX(T1.[CUBE]) = 0, 1, MAX(T1.[CUBE]))), 0) < 10  THEN '100'
               WHEN ROUND((MAX(T1.[WEIGHT]) / IIF(MAX(T1.[CUBE]) = 0, 1, MAX(T1.[CUBE]))), 0) < 12  THEN '92.5'
               WHEN ROUND((MAX(T1.[WEIGHT]) / IIF(MAX(T1.[CUBE]) = 0, 1, MAX(T1.[CUBE]))), 0) < 15  THEN '85'
               WHEN ROUND((MAX(T1.[WEIGHT]) / IIF(MAX(T1.[CUBE]) = 0, 1, MAX(T1.[CUBE]))), 0) >= 15 THEN '70' END AS BUSR3   --WL04
        , CASE WHEN ROUND((MAX(T1.[WEIGHT]) / IIF(MAX(T1.[CUBE]) = 0, 1, MAX(T1.[CUBE]))), 0) < 1   THEN '49880/1'
               WHEN ROUND((MAX(T1.[WEIGHT]) / IIF(MAX(T1.[CUBE]) = 0, 1, MAX(T1.[CUBE]))), 0) < 2   THEN '49880/2'
               WHEN ROUND((MAX(T1.[WEIGHT]) / IIF(MAX(T1.[CUBE]) = 0, 1, MAX(T1.[CUBE]))), 0) < 4   THEN '49880/3'
               WHEN ROUND((MAX(T1.[WEIGHT]) / IIF(MAX(T1.[CUBE]) = 0, 1, MAX(T1.[CUBE]))), 0) < 6   THEN '49880/4'
               WHEN ROUND((MAX(T1.[WEIGHT]) / IIF(MAX(T1.[CUBE]) = 0, 1, MAX(T1.[CUBE]))), 0) < 8   THEN '49880/5'
               WHEN ROUND((MAX(T1.[WEIGHT]) / IIF(MAX(T1.[CUBE]) = 0, 1, MAX(T1.[CUBE]))), 0) < 10  THEN '49880/6'
               WHEN ROUND((MAX(T1.[WEIGHT]) / IIF(MAX(T1.[CUBE]) = 0, 1, MAX(T1.[CUBE]))), 0) < 12  THEN '49880/7'
               WHEN ROUND((MAX(T1.[WEIGHT]) / IIF(MAX(T1.[CUBE]) = 0, 1, MAX(T1.[CUBE]))), 0) < 15  THEN '49880/8'
               WHEN ROUND((MAX(T1.[WEIGHT]) / IIF(MAX(T1.[CUBE]) = 0, 1, MAX(T1.[CUBE]))), 0) >= 15 THEN '49880/9'
          END AS NMFC
        , SKU.BUSR7
        , ISNULL(CODELKUP.[Description], SKU.BUSR7) AS [DESCRIPTION]
        , QTY = MAX(T1.TTLCTN)
        , [WEIGHT] = MAX(T1.[WEIGHT])
        , TTLPLT = MAX(PL.TTLPLT)
   INTO #TEMP
   FROM CBOL WITH (NOLOCK)
   JOIN MBOL WITH (NOLOCK) ON (CBOL.CBOLKey = MBOL.CBOLKey)
   JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MbolKey = MBOLDETAIL.MbolKey)
   JOIN ORDERS WITH (NOLOCK) ON (MBOLDETAIL.OrderKey = ORDERS.OrderKey)
   JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
   JOIN SKU WITH (NOLOCK) ON (SKU.Sku = ORDERDETAIL.Sku AND SKU.StorerKey = ORDERDETAIL.StorerKey)
   LEFT JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.LISTNAME = 'NMFC' AND CODELKUP.Code = SKU.BUSR7)
   CROSS APPLY ( SELECT MAX([WEIGHT]) AS [WEIGHT], MAX(TTLCTN) AS TTLCTN, MAX([CUBE]) AS [CUBE]
                 FROM @T_BUSR T 
                 WHERE SKU.Storerkey = T.Storerkey AND SKU.BUSR7 = T.BUSR7 ) AS T1   --WL04
   CROSS APPLY ( SELECT COUNT(DISTINCT PLTD.Palletkey) AS TTLPLT
                 FROM MBOL MB (NOLOCK)
                 JOIN ORDERS OH (NOLOCK) ON MB.MbolKey = OH.MBOLKey
                 JOIN PACKHEADER PH (NOLOCK) ON PH.OrderKey = OH.OrderKey
                 JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
                 JOIN PALLETDETAIL PLTD (NOLOCK) ON PD.LabelNo = PLTD.CaseId AND PD.StorerKey = PLTD.StorerKey
                 WHERE MB.CBOLKey = CBOL.CBOLKey) AS PL
   --WL01 E
   WHERE CBOL.CBOLKey = @n_Cbolkey
   GROUP BY SKU.BUSR7
          , CODELKUP.[Description]
   

   --WL03 S
   --WL01 S
   --INSERT INTO #T_DUMMY (BUSR3, NMFC, BUSR7, [DESCRIPTION], QTY, [WEIGHT], TTLPLT, TTLPLTWGT, DummyRec, UOM)   --WL02
   --SELECT BUSR3, NMFC, BUSR7, [DESCRIPTION], SUM(QTY) AS QTY, [WEIGHT] --(CLVN01)
   --     , TTLPLT = MAX(TTLPLT)
   --     , TTLPLTWGT = @n_TTLPLTWgt + [WEIGHT]
   --     , 'N'
   --     , 'CTN'   --WL02
   --FROM #TEMP                                                          --(CLVN01)
   --GROUP BY BUSR3, NMFC, BUSR7, [DESCRIPTION], [WEIGHT]                --(CLVN01)

   INSERT INTO #T_DUMMY (BUSR3, NMFC, BUSR7, [DESCRIPTION], QTY, [WEIGHT], TTLPLT, TTLPLTWGT, DummyRec, UOM)
   SELECT DISTINCT 
          BUSR3, NMFC, BUSR7, [DESCRIPTION], QTY, [WEIGHT], TTLPLT
        , (SELECT SUM([WEIGHT]) + @n_TTLPLTWgt FROM #TEMP)
        , 'N', 'CTN'
   FROM #TEMP
   --WL03 E

   --WL02 S
   INSERT INTO #T_DUMMY (BUSR3, NMFC, BUSR7, [DESCRIPTION], QTY, [WEIGHT], TTLPLT, TTLPLTWGT, DummyRec, UOM)
   SELECT TOP 1 NULL, NULL, NULL, NULL, TTLPLT, @n_TTLPLTWgt, TTLPLT, TTLPLTWGT, 'N', 'PLT'
   FROM #T_DUMMY
   --WL02 E

   SELECT @n_TotalRow = COUNT(1)
   FROM #T_DUMMY
   
   SET @n_TotalRow = @n_MaxRow - @n_TotalRow

   --Insert dummy row to push the Grand total to bottom
   WHILE (@n_CurrentCnt < @n_TotalRow)
   BEGIN
      INSERT INTO #T_DUMMY (BUSR3, NMFC, BUSR7, [DESCRIPTION], QTY, [WEIGHT], TTLPLT, TTLPLTWGT, DummyRec)
      SELECT TOP 1 NULL, NULL, NULL, NULL, NULL, NULL, TTLPLT, TTLPLTWGT, 'Y'
      FROM #T_DUMMY
      WHERE DummyRec = 'N'

      SET @n_CurrentCnt = @n_CurrentCnt + 1
   END

   SELECT BUSR3, NMFC, BUSR7, [DESCRIPTION], QTY, [WEIGHT], TTLPLT, TTLPLTWGT, DummyRec
        , UOM   --WL02
   FROM #T_DUMMY
   ORDER BY RowID   --WL03

   IF OBJECT_ID('tempdb..#TEMP') IS NOT NULL
      DROP TABLE #TEMP

   IF OBJECT_ID('tempdb..#T_DUMMY') IS NOT NULL
      DROP TABLE #T_DUMMY

   IF CURSOR_STATUS('LOCAL', 'CUR_PLT') IN (0 , 1)
   BEGIN
      CLOSE CUR_PLT
      DEALLOCATE CUR_PLT   
   END
   --WL01 E
END -- procedure

GO