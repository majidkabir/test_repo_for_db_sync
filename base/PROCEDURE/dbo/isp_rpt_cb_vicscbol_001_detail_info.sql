SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************************/
/* SP: isp_RPT_CB_VICSCBOL_001_Detail_Info                                      */
/* Creation Date: 06-Sep-2024                                                   */
/* Copyright: Maersk                                                            */
/* Written by: WLChooi                                                          */
/*                                                                              */
/* Purpose: UWP-24135 & FCR-798 - NAM|Maersk Logi Report|LVSUSA| Migrate        */
/*          VICS CBOL report to Maersk WMS V2 for Granite Project               */
/*        :                                                                     */
/* Called By: RPT_CB_VICSCBOL_001_Detail_Info                                   */
/*          :                                                                   */
/* Github Version: 1.2                                                          */
/*                                                                              */
/* Version: 7.0                                                                 */
/*                                                                              */
/* Data Modifications:                                                          */
/*                                                                              */
/* Updates:                                                                     */
/* Date        Author   Ver   Purposes                                          */
/* 06-Sep-2024 WLChooi  1.0   DevOps Combine Script                             */
/* 11-Oct-2024 CalvinK  1.1   FCR-995 Change ExternOrderkey to BuyerPO (CLVN01) */
/* 05-Dec-2024 WLChooi  1.2   FCR-1459 Calculate weight at the SKU level (WL01) */
/********************************************************************************/
CREATE   PROCEDURE [dbo].[isp_RPT_CB_VICSCBOL_001_Detail_Info]
(
   @n_Cbolkey  BIGINT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_CtnGrp     NVARCHAR(50)   --WL01

   --WL01 S
   SELECT TOP 1 @c_CtnGrp = STORER.CartonGroup
   FROM MBOL WITH (NOLOCK)
   JOIN MBOLDETAIL WITH (NOLOCK) ON ( MBOL.Mbolkey = MBOLDETAIL.Mbolkey )
   JOIN ORDERS WITH (NOLOCK) ON ( MBOLDETAIL.OrderKey = ORDERS.OrderKey ) 
   JOIN STORER WITH (NOLOCK) ON ( ORDERS.Storerkey = STORER.Storerkey )
   WHERE MBOL.Cbolkey = @n_Cbolkey
   --WL01 E

   CREATE TABLE #T_INFO (
         RowID             INT NOT NULL IDENTITY(1,1)
       , ExternOrderKey    NVARCHAR(50)
       , userDefine03      NVARCHAR(50)
       , PKG               INT
       , [WEIGHT]          FLOAT
       , PALLETS           NVARCHAR(10)
       , CBOLReference     NVARCHAR(30)
   )

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
      
      INSERT INTO #T_INFO (ExternOrderKey, userDefine03, PKG, [WEIGHT], PALLETS, CBOLReference)
      SELECT ORD.ExternConsoOrderKey,
            'Dept: ' AS userDefine03,
            SM.TTLCTN AS PKG,          
            SM.TTLWeight AS [WEIGHT],        
            'Y / N  ' AS PALLETS,
            ORD.CBOLReference 
      FROM #CONSOORD AS ORD
      JOIN #SUMM AS SM ON SM.ExternConsoOrderkey = ORD.ExternConsoOrderkey
   END
   ELSE
   BEGIN
      INSERT INTO #T_INFO (ExternOrderKey, userDefine03, PKG, [WEIGHT], PALLETS, CBOLReference)
      --SELECT ORDERS.ExternOrderKey, --(CLVN01)
	   SELECT ORDERS.BuyerPO,		  --(CLVN01)
             'Dept: ' + TRIM(ORDERS.userDefine03),
             PKG = SUM(CONVERT(INT, PK.TTLCTN)),          
             [WEIGHT] = SUM(PK.[WEIGHT]) + SUM(PK.CartonWgt * PK.TTLCTN),   --WL01    
             'Y / N  ' PALLETS,
             CBOL.CBOLReference 
      FROM MBOL WITH (NOLOCK)
      JOIN MBOLDETAIL WITH (NOLOCK) ON ( MBOL.Mbolkey = MBOLDETAIL.Mbolkey )
      JOIN ORDERS WITH (NOLOCK) ON ( MBOLDETAIL.OrderKey = ORDERS.OrderKey ) 
      JOIN CBOL WITH (NOLOCK) ON (MBOL.Cbolkey = CBOL.Cbolkey)
      CROSS APPLY ( SELECT COUNT(DISTINCT P.LabelNo) AS TTLCTN 
                        , SUM(P.Qty * S.StdGrossWgt) AS [Weight]   --WL01
                        , C.CartonWeight AS CartonWgt   --WL01
                    FROM PACKDETAIL P (NOLOCK)
                    JOIN PACKHEADER PH (NOLOCK) ON P.Pickslipno = PH.Pickslipno
                    JOIN SKU S (NOLOCK) ON S.Storerkey = P.Storerkey AND S.Sku = P.Sku   --WL01
                    JOIN PACKINFO PF (NOLOCK) ON PF.Pickslipno = P.Pickslipno AND PF.Cartonno = P.Cartonno   --WL01
                    JOIN CARTONIZATION C (NOLOCK) ON C.CartonType = PF.CartonType AND C.CartonizationGroup = @c_CtnGrp   --WL01
                    WHERE PH.Orderkey = ORDERS.Orderkey
                    GROUP BY C.CartonWeight ) AS PK   --WL01
      WHERE ( MBOL.Cbolkey = @n_Cbolkey   ) 
      AND ( ISNULL(MBOL.Cbolkey, 0) <> 0 )
      --GROUP BY ORDERS.ExternOrderKey, --(CLVN01)
      GROUP BY ORDERS.BuyerPO, 		 --(CLVN01)
               ORDERS.userDefine03,
               CBOL.CBOLReference   
   END

   SELECT ExternOrderKey
        , userDefine03
        , PKG
        , [WEIGHT]
        , PALLETS
        , SumPKG    = (SELECT SUM(PKG) FROM #T_INFO)
        , SumWeight = (SELECT SUM([WEIGHT]) FROM #T_INFO)
        , TotalRow  = (SELECT COUNT(1) FROM #T_INFO)
        , CBOLReference
   FROM #T_INFO
   ORDER BY RowID
   
   IF OBJECT_ID('tempdb..#SUMM') IS NOT NULL
      DROP TABLE #SUMM
      
   IF OBJECT_ID('tempdb..#CONSOORD') IS NOT NULL
      DROP TABLE #CONSOORD

   IF OBJECT_ID('tempdb..#T_INFO') IS NOT NULL
      DROP TABLE #T_INFO
END -- procedure

GO