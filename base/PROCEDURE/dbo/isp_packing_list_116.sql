SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/          
/* Stored Proc: isp_Packing_List_116                                    */          
/* Creation Date: 01-Nov-2021                                           */          
/* Copyright: LF Logistics                                              */          
/* Written by: WLChooi                                                  */          
/*                                                                      */          
/* Purpose: WMS-18257 - [CN] Stussy outbound shipment list              */          
/*                                                                      */          
/* Called By: r_dw_packing_list_116                                     */          
/*                                                                      */          
/* GitLab Version: 1.0                                                  */          
/*                                                                      */          
/* Version: 7.0                                                         */          
/*                                                                      */          
/* Data Modifications:                                                  */          
/*                                                                      */          
/* Updates:                                                             */          
/* Date         Author    Ver Purposes                                  */   
/* 01-Nov-2021  WLChooi   1.0 DevOps Combine Script                     */   
/* 26-Jan-2022  Mingle    1.1 WMS-18769 Modify logic(ML01)              */
/************************************************************************/          
CREATE PROC [dbo].[isp_Packing_List_116]       
            @c_Sourcekey    NVARCHAR(15)             
                   
AS          
BEGIN          
   SET NOCOUNT ON          
   SET ANSI_NULLS OFF          
   SET QUOTED_IDENTIFIER OFF          
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @c_MBOLKey   NVARCHAR(10)
     
   SET @c_MBOLKey = ''   

   CREATE TABLE #TMP_ORDER (
      Orderkey    NVARCHAR(10)
   )

   CREATE TABLE #TMP_PACKINFO (
      MBOLKey    NVARCHAR(10)
    , Pickslipno NVARCHAR(10)
    , CartonNo   NVARCHAR(10)
    , [Length]   NVARCHAR(20)
    , [Width]    NVARCHAR(20)
    , [Height]   NVARCHAR(20)
    , [Weight]   FLOAT
    , [Cube]     FLOAT
   )
   
   IF EXISTS (SELECT 1 
              FROM MBOLDETAIL MD (NOLOCK)
              WHERE MD.MbolKey = @c_Sourcekey)
   BEGIN
      INSERT INTO #TMP_ORDER (Orderkey)
      SELECT DISTINCT Orderkey
      FROM MBOLDETAIL (NOLOCK)
      WHERE MbolKey = @c_Sourcekey

      SET @c_MBOLKey = @c_Sourcekey
   END
   ELSE
   BEGIN
      INSERT INTO #TMP_ORDER (Orderkey)
      SELECT @c_Sourcekey

      SELECT @c_MBOLKey = ORDERS.MBOLKey
      FROM ORDERS (NOLOCK)
      WHERE OrderKey = @c_Sourcekey
   END 

   INSERT INTO #TMP_PACKINFO (MBOLKey, Pickslipno, CartonNo, [Length], [Width], [Height], [Weight], [Cube])
   SELECT DISTINCT
          @c_MBOLKey
        , PIF.Pickslipno
        , PIF.CartonNo
        , CASE WHEN CAST(ISNULL(CT.CartonLength,0) AS NVARCHAR) = '0' THEN '' ELSE CAST(CT.CartonLength AS NVARCHAR) END
        , CASE WHEN CAST(ISNULL(CT.CartonWidth,0)  AS NVARCHAR) = '0' THEN '' ELSE CAST(CT.CartonWidth  AS NVARCHAR) END
        , CASE WHEN CAST(ISNULL(CT.CartonHeight,0) AS NVARCHAR) = '0' THEN '' ELSE CAST(CT.CartonHeight AS NVARCHAR) END
        , PIF.[Weight]
        , PIF.[Cube]
   FROM PACKHEADER PH (NOLOCK)
   JOIN PACKDETAIL PD (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
   LEFT JOIN PACKINFO PIF (NOLOCK) ON PIF.PickSlipNo = PD.PickSlipNo AND PIF.CartonNo = PD.CartonNo
   JOIN STORER ST (NOLOCK) ON ST.StorerKey = PH.StorerKey
   LEFT JOIN CARTONIZATION CT (NOLOCK) ON CT.CartonType = PIF.CartonType 
                                      AND CT.CartonizationGroup = ST.CartonGroup
                                      AND CT.UseSequence = 1
   JOIN #TMP_ORDER TOR ON TOR.Orderkey = PH.OrderKey

   SELECT OH.MBOLKey
        , ISNULL(OH.C_Company,'') AS C_Company
        , ISNULL(OH.C_Country,'') AS C_Country
        , CASE WHEN ISNULL(OH.C_Address1,'') = '' THEN '' ELSE TRIM(ISNULL(OH.C_Address1,'')) + ',' END + 
          CASE WHEN ISNULL(OH.C_Address2,'') = '' THEN '' ELSE TRIM(ISNULL(OH.C_Address2,'')) + ',' END + 
          CASE WHEN ISNULL(OH.C_Address3,'') = '' THEN '' ELSE TRIM(ISNULL(OH.C_Address3,'')) END AS C_Address1
        , CASE WHEN ISNULL(OH.C_City,'')  = '' THEN '' ELSE TRIM(ISNULL(OH.C_City,''))  + ',' END + 
          CASE WHEN ISNULL(OH.C_State,'') = '' THEN '' ELSE TRIM(ISNULL(OH.C_State,'')) + ',' END + 
          CASE WHEN ISNULL(OH.C_Zip,'')   = '' THEN '' ELSE TRIM(ISNULL(OH.C_Zip,'')) END AS C_Address2
        , OH.ExternOrderKey
        , ISNULL(SKU.Style,'') AS Style
        , ISNULL(SKU.Color,'') AS Color
        , ISNULL(SKU.Measurement,'') AS Measurement
        , ISNULL(SKU.Size,'') AS Size
        , ISNULL(SKU.NOTES1,'') AS NOTES1
        --, ISNULL(SKU.STDNETWGT,0.00) AS STDNETWGT
        , ROUND(ISNULL(SKU.STDNETWGT,0.00) * PD.Qty,2) AS STDNETWGT   --ML01
        , PD.LabelNo
        , PD.SKU
        , PD.Qty
        , CASE WHEN CAST(ISNULL(PIF.[Length],0) AS NVARCHAR) = '0' THEN '' ELSE CAST(PIF.[Length] AS NVARCHAR) END AS [Length]
        , CASE WHEN CAST(ISNULL(PIF.[Width],0)  AS NVARCHAR) = '0' THEN '' ELSE CAST(PIF.[Width]  AS NVARCHAR) END AS [Width] 
        , CASE WHEN CAST(ISNULL(PIF.[Height],0) AS NVARCHAR) = '0' THEN '' ELSE CAST(PIF.[Height] AS NVARCHAR) END AS [Height]
        , PIF.[Weight] AS [Weight]
        , PIF.[Cube] AS [Cube]  
        , ISNULL(ST.Company,'') AS Company
        , CASE WHEN ISNULL(ST.Address1,'') = '' THEN '' ELSE TRIM(ISNULL(ST.Address1,'')) + ',' END + 
          CASE WHEN ISNULL(ST.Address2,'') = '' THEN '' ELSE TRIM(ISNULL(ST.Address2,'')) + ',' END + 
          CASE WHEN ISNULL(ST.Address3,'') = '' THEN '' ELSE TRIM(ISNULL(ST.Address3,'')) END AS Address1
        , CASE WHEN ISNULL(ST.City,'')    = '' THEN '' ELSE TRIM(ISNULL(ST.City,''))    + ',' END + 
          CASE WHEN ISNULL(ST.[State],'') = '' THEN '' ELSE TRIM(ISNULL(ST.[State],'')) + ',' END + 
          CASE WHEN ISNULL(ST.Zip,'')     = '' THEN '' ELSE TRIM(ISNULL(ST.Zip,''))     + ',' END + 
          CASE WHEN ISNULL(ST.Country,'') = '' THEN '' ELSE TRIM(ISNULL(ST.Country,'')) END AS Address2
        , ISNULL(ST.Phone1,'') AS Phone1
        , ROUND(PACKIF.SumCube,2)   --ML01
        , ROUND(PACKIF.SumWeight,2)   --ML01
   FROM ORDERS OH (NOLOCK)
   JOIN PACKHEADER PH (NOLOCK) ON PH.OrderKey = OH.OrderKey
   JOIN PACKDETAIL PD (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
   LEFT JOIN #TMP_PACKINFO PIF (NOLOCK) ON PIF.PickSlipNo = PD.PickSlipNo AND PIF.CartonNo = PD.CartonNo
   JOIN STORER ST (NOLOCK) ON ST.StorerKey = OH.StorerKey
   JOIN SKU (NOLOCK) ON SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU
   JOIN #TMP_ORDER TOR ON TOR.Orderkey = OH.OrderKey
   OUTER APPLY (SELECT SUM(P.[Cube]) AS SumCube, SUM(P.[Weight]) AS SumWeight
                FROM #TMP_PACKINFO P
                WHERE P.MBOLKey = @c_MBOLKey) PACKIF
   ORDER BY PD.LabelNo
     
END   

GO