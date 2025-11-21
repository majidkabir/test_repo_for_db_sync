SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************************/
/* SP: isp_RPT_CB_VICSCBOL_001_Supp_Detail                                      */
/* Creation Date: 06-Sep-2024                                                   */
/* Copyright: Maersk                                                            */
/* Written by: WLChooi                                                          */
/*                                                                              */
/* Purpose: UWP-24135 & FCR-798 - NAM|Maersk Logi Report|LVSUSA| Migrate        */
/*          VICS CBOL report to Maersk WMS V2 for Granite Project               */
/*        :                                                                     */
/* Called By: RPT_CB_VICSCBOL_001_Supp_Detail                                   */
/*          :                                                                   */
/* Github Version: 1.3                                                          */
/*                                                                              */
/* Version: 7.0                                                                 */
/*                                                                              */
/* Data Modifications:                                                          */
/*                                                                              */
/* Updates:                                                                     */
/* Date        Author   Ver   Purposes                                          */
/* 06-Sep-2024 WLChooi  1.0   DevOps Combine Script                             */
/* 11-Oct-2024 CalvinK  1.1   FCR-995 Change ExternOrderkey to BuyerPO (CLVN01) */
/* 24-Oct-2024 WLChooi  1.2   FCR-1076 Add Total Weight (WL01)                  */
/* 05-Dec-2024 WLChooi  1.3   FCR-1459 Calculate weight at the SKU level (WL02) */
/********************************************************************************/
CREATE   PROCEDURE [dbo].[isp_RPT_CB_VICSCBOL_001_Supp_Detail]
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
   DECLARE @c_Userdefine09 NVARCHAR(10) = ''
         , @c_Storerkey    NVARCHAR(15) = ''
         , @n_PalletWgt    FLOAT = 0.00
         , @n_TTLPLT       INT = 0
         , @n_TTLPLTWgt    FLOAT = 0.00
         , @c_Mbolkey      NVARCHAR(10) = ''
         , @c_CtnGrp       NVARCHAR(50)   --WL02

   SELECT @c_Storerkey = MAX(ORDERS.StorerKey)
        , @c_CtnGrp = MAX(STORER.CartonGroup)   --WL02
   FROM MBOL (NOLOCK)
   JOIN ORDERS (NOLOCK) ON ORDERS.MBOLKey = MBOL.MbolKey
   JOIN STORER WITH (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey   --WL02
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

   IF EXISTS ( SELECT 1 FROM ORDERS O (NOLOCK) 
               JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
               JOIN MBOL MB (NOLOCK) ON O.Mbolkey = MB.Mbolkey
               WHERE ISNULL(OD.Consoorderkey,'') <> ''
               AND MB.Cbolkey = @n_Cbolkey 
               AND ISNULL(MB.Cbolkey,0) <> 0 )
   BEGIN
      SELECT DISTINCT ORDERDETAIL.ExternConsoOrderKey, CBOL.CBOLReference
      INTO #CONSOORD
      FROM MBOL WITH (NOLOCK)
      JOIN MBOLDETAIL WITH (NOLOCK) ON ( MBOL.Mbolkey = MBOLDETAIL.Mbolkey )       
      JOIN ORDERS WITH (NOLOCK) ON ( MBOLDETAIL.OrderKey = ORDERS.OrderKey ) 
      JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
      JOIN CBOL WITH (NOLOCK) ON (MBOL.Cbolkey = CBOL.Cbolkey)
      WHERE MBOL.Cbolkey = @n_Cbolkey 
      AND ISNULL(MBOL.Cbolkey, 0) <> 0
      
      SELECT EXTERNCONSOORDERKEY, TTLCTN, TTLWeight  
      INTO #SUMM
      FROM [dbo].[fnc_GetVicsCBOL_CartonInfo](@n_Cbolkey)

      ;WITH CTE (ExternOrderKey, userDefine03, PKG, [WEIGHT], PALLETS, CBOLReference) AS (
         SELECT ORD.ExternConsoOrderKey,
               'Dept: ' AS userDefine03,
               SM.TTLCTN AS PKG,          
               SM.TTLWeight AS [WEIGHT],        
               'Y / N  ' AS PALLETS,
               ORD.CBOLReference 
         FROM #CONSOORD AS ORD
         JOIN #SUMM AS SM ON SM.ExternConsoOrderkey = ORD.ExternConsoOrderkey
      )
      SELECT ExternOrderKey
           , UserDefine03
           , PKG
           , [WEIGHT]
           , PALLETS
           , SumPKG    = (SELECT SUM(PKG) FROM CTE)
           , SumWeight = (SELECT SUM([WEIGHT]) FROM CTE)
           , TotalRow  = (SELECT COUNT(1) FROM CTE)
           , CBOLReference
           , TTLPLTWGT = (@n_TTLPLTWgt) + (SELECT SUM([WEIGHT]) FROM CTE)   --WL01
      FROM CTE
   END
   ELSE
   BEGIN
      ;WITH CTE (ExternOrderKey, userDefine03, PKG, [WEIGHT], PALLETS, CBOLReference) AS (
         --SELECT ORDERS.ExternOrderKey, --(CLVN01)
         SELECT ORDERS.BuyerPO,			 --(CLVN01)
                'Dept: ' + TRIM(ORDERS.userDefine03),
                PKG = SUM(CONVERT(INT, PK.TTLCTN)),   --WL02
                [WEIGHT] = SUM(PK.[WEIGHT]) + SUM(PK.CartonWgt * PK.TTLCTN),   --WL02       
                'Y / N  ' PALLETS,
                CBOL.CBOLReference 
          FROM MBOL WITH (NOLOCK)
          JOIN MBOLDETAIL WITH (NOLOCK) ON ( MBOL.Mbolkey = MBOLDETAIL.Mbolkey )
          JOIN ORDERS WITH (NOLOCK) ON ( MBOLDETAIL.OrderKey = ORDERS.OrderKey ) 
          JOIN CBOL WITH (NOLOCK) ON (MBOL.Cbolkey = CBOL.Cbolkey)
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
          WHERE ( MBOL.Cbolkey = @n_Cbolkey   ) 
          AND ( ISNULL(MBOL.Cbolkey, 0) <> 0 )
          --GROUP BY ORDERS.ExternOrderKey, --(CLVN01)
          GROUP BY ORDERS.BuyerPO,	        --(CLVN01)
                   ORDERS.userDefine03,
                   CBOL.CBOLReference 
         )
      SELECT ExternOrderKey
           , UserDefine03
           , PKG
           , [WEIGHT]
           , PALLETS
           , SumPKG    = (SELECT SUM(PKG) FROM CTE)
           , SumWeight = (SELECT SUM([WEIGHT]) FROM CTE)
           , TotalRow  = (SELECT COUNT(1) FROM CTE)
           , CBOLReference
           , TTLPLTWGT = (@n_TTLPLTWgt) + (SELECT SUM([WEIGHT]) FROM CTE)   --WL01
      FROM CTE
   END

   IF OBJECT_ID('tempdb..#SUMM') IS NOT NULL
      DROP TABLE #SUMM
      
   IF OBJECT_ID('tempdb..#CONSOORD') IS NOT NULL
      DROP TABLE #CONSOORD  

   --WL01
   IF CURSOR_STATUS('LOCAL', 'CUR_PLT') IN (0 , 1)
   BEGIN
      CLOSE CUR_PLT
      DEALLOCATE CUR_PLT   
   END
END -- procedure

GO