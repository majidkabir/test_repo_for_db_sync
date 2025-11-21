SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************************/
/* SP: isp_RPT_MB_VICSBOL_001_Supp_Detail                                       */
/* Creation Date: 18-Jun-2024                                                   */
/* Copyright: Maersk                                                            */
/* Written by: WLChooi                                                          */
/*                                                                              */
/* Purpose: UWP-20706 - Granite | MWMS | BOL Report                             */
/*        :                                                                     */
/* Called By: RPT_MB_VICSBOL_001_Supp_Detail                                    */
/*          :                                                                   */
/* Github Version: 1.3                                                          */
/*                                                                              */
/* Version: 7.0                                                                 */
/*                                                                              */
/* Data Modifications:                                                          */
/*                                                                              */
/* Updates:                                                                     */
/* Date        Author   Ver   Purposes                                          */
/* 18-Jun-2024 WLChooi  1.0   DevOps Combine Script                             */
/* 08-Oct-2024 CalvinK  1.1   FCR-956 Change Externorderkey to BuyerPO (CLVN01) */
/* 24-Oct-2024 WLChooi  1.2   FCR-1075 Add Total Weight (WL01)                  */
/* 05-Dec-2024 WLChooi  1.3   FCR-1459 Calculate weight at the SKU level (WL02) */
/********************************************************************************/
CREATE   PROCEDURE [dbo].[isp_RPT_MB_VICSBOL_001_Supp_Detail]
(
   @c_Mbolkey      NVARCHAR(10)
 , @c_Consigneekey NVARCHAR(15)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue  INT = 1
         , @n_StartTCnt INT = @@TRANCOUNT
         , @c_Vics_MBOL NVARCHAR(50) = ''

   --WL01 S
   DECLARE @c_Userdefine09 NVARCHAR(10) = ''
         , @c_Storerkey    NVARCHAR(15) = ''
         , @n_PalletWgt    FLOAT = 0.00
         , @n_TTLPLT       INT = 0
         , @c_CtnGrp     NVARCHAR(50)   --WL02

   SELECT @c_Userdefine09 = MBOL.UserDefine09
        , @c_Storerkey = ORDERS.StorerKey
        , @c_CtnGrp = STORER.CartonGroup   --WL02
   FROM ORDERS (NOLOCK)
   JOIN MBOL (NOLOCK) ON ORDERS.MBOLKey = MBOL.MbolKey
   JOIN STORER WITH (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey   --WL02
   WHERE ORDERS.MbolKey = @c_Mbolkey

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
   AND OH.ConsigneeKey = @c_Consigneekey
   --WL01 E

   EXEC [dbo].[isp_GetVicsMbol] @c_Mbolkey = @c_Mbolkey
                              , @c_Vics_MBOL = @c_Vics_MBOL OUTPUT

   IF ISNULL(@c_Vics_MBOL, '') <> ''
   BEGIN
      UPDATE MBOL WITH (ROWLOCK)
      SET ExternMBOLKey = IIF(ExternMBOLKey = @c_Vics_MBOL, ExternMBOLKey, @c_Vics_MBOL)
        , TrafficCop = NULL
      WHERE MBOLkey = @c_Mbolkey
   END

   IF EXISTS (  SELECT 1
                FROM ORDERS O (NOLOCK)
                JOIN ORDERDETAIL OD (NOLOCK) ON O.OrderKey = OD.OrderKey
                WHERE ISNULL(OD.ConsoOrderKey, '') <> ''
                AND   O.MBOLKey = @c_Mbolkey
                AND   O.ConsigneeKey = @c_Consigneekey )
   BEGIN
      SELECT DISTINCT ORDERDETAIL.ExternConsoOrderKey
      INTO #CONSOORD
      FROM MBOLDETAIL WITH (NOLOCK)
      JOIN ORDERS WITH (NOLOCK) ON (MBOLDETAIL.OrderKey = ORDERS.OrderKey)
      JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)
      WHERE MBOLDETAIL.MbolKey = @c_Mbolkey 
      AND ORDERS.ConsigneeKey = @c_Consigneekey

      SELECT ExternConsoOrderkey
           , TTLCTN
           , TTLWeight
      INTO #SUMM
      FROM [dbo].[fnc_GetVicsBOL_CartonInfo](@c_Mbolkey, @c_Consigneekey)

      ;WITH CTE (ExternOrderKey, userDefine03, PKG, [WEIGHT], PALLETS) AS (
         SELECT ORD.ExternConsoOrderKey
              , 'Dept: ' AS userDefine03
              , SM.TTLCTN AS PKG
              , SM.TTLWeight AS [WEIGHT]
              , 'Y / N  ' AS PALLETS
         FROM #CONSOORD AS ORD
         JOIN #SUMM AS SM ON SM.ExternConsoOrderkey = ORD.ExternConsoOrderKey
      )
      SELECT ExternOrderKey
           , UserDefine03
           , PKG
           , [WEIGHT]
           , PALLETS
           , SumPKG    = (SELECT SUM(PKG) FROM CTE)
           , SumWeight = (SELECT SUM([WEIGHT]) FROM CTE)
           , TotalRow  = (SELECT COUNT(1) FROM CTE)
           , ExternMbolkey = @c_Vics_MBOL
           , TTLPLTWGT = (@n_TTLPLT * @n_PalletWgt) + (SELECT SUM([WEIGHT]) FROM CTE)   --WL01
      FROM CTE
   END
   ELSE
   BEGIN
      ;WITH CTE (ExternOrderKey, userDefine03, PKG, [WEIGHT], PALLETS) AS (
         SELECT --ORDERS.ExternOrderKey --(CLVN01)
              ORDERS.BUYERPO          --(CLVN01)
              , 'Dept: ' + ISNULL(TRIM(ORDERS.UserDefine03), '') AS UserDefine03
              , PKG = SUM(CONVERT(INT, PK.TTLCTN))   --WL02
              , [WEIGHT] = SUM(PK.[WEIGHT]) + SUM(PK.CartonWgt * PK.TTLCTN)   --WL02
              , 'Y / N  ' PALLETS
         FROM MBOLDETAIL WITH (NOLOCK)
         JOIN ORDERS WITH (NOLOCK) ON (MBOLDETAIL.OrderKey = ORDERS.OrderKey)
         --WL02 S
         CROSS APPLY ( SELECT COUNT(DISTINCT P.LabelNo) AS TTLCTN 
                            , SUM(P.Qty * S.StdGrossWgt) AS [Weight]
                            , C.CartonWeight AS CartonWgt
                       FROM PACKDETAIL P (NOLOCK)
                       JOIN PACKHEADER PH (NOLOCK) ON P.Pickslipno = PH.Pickslipno
                       JOIN SKU S (NOLOCK) ON S.Storerkey = P.Storerkey AND S.Sku = P.Sku
                       JOIN PACKINFO PF (NOLOCK) ON PF.Pickslipno = P.Pickslipno AND PF.Cartonno = P.Cartonno
                       JOIN CARTONIZATION C (NOLOCK) ON C.CartonType = PF.CartonType AND C.CartonizationGroup = @c_CtnGrp
                       WHERE PH.Orderkey = ORDERS.Orderkey
                       GROUP BY C.CartonWeight ) AS PK
         --WL02 E
         WHERE (MBOLDETAIL.MbolKey = @c_Mbolkey) AND (ORDERS.ConsigneeKey = @c_Consigneekey)
         GROUP BY --ORDERS.ExternOrderKey --(CLVN01)
                ORDERS.BUYERPO        --(CLVN01)
                , ISNULL(TRIM(ORDERS.UserDefine03), '') 
      )
      SELECT ExternOrderKey
           , UserDefine03
           , PKG
           , [WEIGHT]
           , PALLETS
           , SumPKG    = (SELECT SUM(PKG) FROM CTE)
           , SumWeight = (SELECT SUM([WEIGHT]) FROM CTE)
           , TotalRow  = (SELECT COUNT(1) FROM CTE)
           , ExternMbolkey = @c_Vics_MBOL
           , TTLPLTWGT = (@n_TTLPLT * @n_PalletWgt) + (SELECT SUM([WEIGHT]) FROM CTE)   --WL01
      FROM CTE
   END

   IF OBJECT_ID('tempdb..#SUMM') IS NOT NULL
      DROP TABLE #SUMM
      
   IF OBJECT_ID('tempdb..#CONSOORD') IS NOT NULL
      DROP TABLE #CONSOORD  
END -- procedure

GO