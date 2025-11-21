SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_Pallet_outboundlist_rdt                             */
/* Creation Date: 19-JUNE-2017                                          */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-2152 - CN_DYSON_Report_POD                              */
/*        :                                                             */
/* Called By: r_dw_pod_08 (reporttype = 'MBOLPOD')                      */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 28-MAR-2018  CSCHONG   1.0 WMS-4380 - add new field (CS01)           */
/* 05-JUL-2019  WLCHOOI   1.1 WMS-9634 - Show all externorderkey within */
/*                                       a pallet and some fixes (WL01) */
/* 19-JUN-2020  WLChooi   1.2 WMS-13831 - New layout based on C_Country */
/*                            (WL02)                                    */
/* 03-Aug-2020  WLChooi   1.3 WMS-14530 - JOIN Palletdetail & Packdetail*/
/*                            with Storerkey (WL03)                     */
/************************************************************************/
CREATE PROC [dbo].[isp_Pallet_outboundlist_rdt]
           @c_PalletKey   NVARCHAR(30)

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT
         , @c_PLTKey          NVARCHAR(30)
         , @c_storerkey       NVARCHAR(20)
         , @c_sku             NVARCHAR(20)  
         , @n_TTLCase         INT
         , @c_caseid          NVARCHAR(20)  --WL01
         , @n_Qty             INT           --WL01
        
   SET @n_StartTCnt = @@TRANCOUNT
   
   SET @n_TTLCase = 1

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   CREATE TABLE #TMP_PLTOUTList
      (  RowID          INT IDENTITY (1,1) NOT NULL 
      ,	PalletKey      NVARCHAR(30)   NULL  DEFAULT('')
      ,  OHUdf09        NVARCHAR(10)   NULL  DEFAULT('')
      ,  ExtOrdKey      NVARCHAR(30)   NULL  DEFAULT('')
      ,  C_Address4     NVARCHAR(45)   NULL  DEFAULT('')
      ,  C_Country      NVARCHAR(45)   NULL  DEFAULT('')
      ,  consigneekey   NVARCHAR(45)   NULL  DEFAULT('')
      ,  Storerkey      NVARCHAR(15)   NULL  DEFAULT('')
      ,  OHUdf03        NVARCHAR(10)   NULL  DEFAULT('')
      ,  C_Company      NVARCHAR(45)   NULL  DEFAULT('')
      ,  SKU            NVARCHAR(20)   NULL  DEFAULT('')
      ,  TTLCase        INT            NULL  DEFAULT(0)
      ,  SKUSUSR3       NVARCHAR(18)   NULL  DEFAULT('')           --CS01 
      ,  CaseID         NVARCHAR(20)   NULL  DEFAULT('')           --WL01
      ,  Qty            INT            NULL  DEFAULT(0)            --WL01
      ,  TrackingNo     NVARCHAR(30)   NULL  DEFAULT('')           --WL02
      )

      --WL01 Start
      CREATE TABLE #TMP_PLTOUTListFinal
      (  RowID          INT IDENTITY (1,1) NOT NULL 
      ,	PalletKey      NVARCHAR(30)   NULL  DEFAULT('')
      ,  OHUdf09        NVARCHAR(10)   NULL  DEFAULT('')
      ,  ExtOrdKey      NVARCHAR(4000) NULL  DEFAULT('')
      ,  C_Address4     NVARCHAR(45)   NULL  DEFAULT('')
      ,  C_Country      NVARCHAR(45)   NULL  DEFAULT('')
      ,  consigneekey   NVARCHAR(45)   NULL  DEFAULT('')
      ,  Storerkey      NVARCHAR(15)   NULL  DEFAULT('')
      ,  OHUdf03        NVARCHAR(10)   NULL  DEFAULT('')
      ,  C_Company      NVARCHAR(45)   NULL  DEFAULT('')
      ,  SKU            NVARCHAR(20)   NULL  DEFAULT('')
      ,  TTLCase        INT            NULL  DEFAULT(0)
      ,  SKUSUSR3       NVARCHAR(18)   NULL  DEFAULT('')           --CS01 
      ,  CaseID         NVARCHAR(20)   NULL  DEFAULT('')           --WL01
      ,  Qty            INT            NULL  DEFAULT(0)            --WL01
      ,  TrackingNo     NVARCHAR(30)   NULL  DEFAULT('')           --WL02
      )
      --WL01 End

   INSERT INTO #TMP_PLTOUTList
      (  PalletKey      
      ,  OHUdf09       
      ,  ExtOrdKey     
      ,  C_Address4   
      ,  C_Country    
      ,  consigneekey  
      ,  Storerkey   
      ,  OHUdf03       
      ,  C_Company      
      ,  SKU            
      ,  TTLCase  
      ,  SKUSUSR3                                 --CS01  
      ,  CaseID                                   --WL01
      ,  Qty                                      --WL01
      ,  TrackingNo                               --WL02
      )
  
   SELECT DISTINCT PLTD.PalletKey,ord.UserDefine09,ord.ExternOrderKey,
                   ord.C_Address4,ord.C_Country,ord.ConsigneeKey,ord.StorerKey,ord.UserDefine03,
                   ord.C_Company,pd.sku,0,s.SUSR3,                                                     --CS01
                   PLTD.CaseId,0,ISNULL(ord.TrackingNo,'')                                             --WL01   --WL02
   FROM PACKHEADER PH WITH (NOLOCK)
   JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
   JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey = PH.OrderKey
   JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON PLTD.CaseId = PD.LabelNo AND PLTD.Storerkey = PD.Storerkey   --WL03
   JOIN SKU S WITH (NOLOCK) ON PD.StorerKey = S.Storerkey AND PD.SKU = S.Sku                      --CS01
   WHERE PLTD.Palletkey = @c_PalletKey
   ORDER BY PLTD.PalletKey ,pd.sku

   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT palletkey,storerkey,sku,caseid   --WL01
   FROM   #TMP_PLTOUTList L   
   WHERE palletkey = @c_PalletKey
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @c_PLTKey,@c_storerkey,@c_sku,@c_caseid  --WL01    
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN   
      SET @n_TTLCase = 1
      	
      SELECT @n_TTLCase = COUNT(Caseid)
      FROM Palletdetail (NOLOCK)
      WHERE PalletKey = @c_PLTKey
      AND sku = @c_sku
      AND StorerKey = @c_storerkey
      AND CaseID = @c_caseid                  --WL01
      
      --WL01 Start
      SELECT @n_Qty = SUM(Qty)
      FROM Palletdetail (NOLOCK)
      WHERE PalletKey = @c_PLTKey
      AND sku = @c_sku
      AND StorerKey = @c_storerkey
      AND CaseID = @c_caseid 
      --WL01 End                 
      
      UPDATE #TMP_PLTOUTList
      SET TTLCase = @n_TTLCase,
              Qty = @n_Qty                    --WL01
      WHERE PalletKey = @c_PLTKey
      AND sku = @c_sku
      AND StorerKey = @c_storerkey
      AND CaseID = @c_caseid                  --WL01
      
      FETCH NEXT FROM CUR_RESULT INTO @c_PLTKey,@c_storerkey,@c_sku,@c_caseid  --WL01    
   END   
  
   CLOSE CUR_RESULT
   DEALLOCATE CUR_RESULT
  
  --WL01 Start
   INSERT INTO #TMP_PLTOUTListFinal (  PalletKey      
      ,  OHUdf09       
      ,  ExtOrdKey    
      ,  C_Company 
      ,  C_Address4   
      ,  C_Country    
      ,  consigneekey  
      ,  Storerkey   
      ,  OHUdf03          
      ,  SKU            
      ,  TTLCase  
      ,  SKUSUSR3                                  
      ,  Qty   
      ,  TrackingNo   --WL02                                   
      )
   --WL01 End
   SELECT   UPPER(PalletKey)      
         ,  OHUdf09       
         ,  CAST( SUBSTRING( (SELECT DISTINCT RTRIM(ExtOrdKey)+', ' FROM #TMP_PLTOUTList FOR XML PATH('') )                --WL01
                              , 1                                                                                          --WL01
                              , LEN((SELECT DISTINCT RTRIM(ExtOrdKey)+', ' FROM #TMP_PLTOUTList FOR XML PATH('') ) ) - 1 ) --WL01
         AS NVARCHAR(4000) ) AS ExtOrdKey                                                                                  --WL01
         ,  C_Company    
         ,  C_Address4   
         ,  C_Country    
         ,  consigneekey  
         ,  Storerkey   
         ,  OHUdf03           
         ,  SKU            
         ,  TTLCase  
         ,  SKUSUSR3                       --CS03 
         ,  Qty                            --WL01
         ,  TrackingNo                     --WL02
   FROM #TMP_PLTOUTList

   --WL01 Start
   SELECT   PalletKey     
         ,  OHUdf09       
         ,  ExtOrdKey 
         ,  C_Company    
         ,  C_Address4   
         ,  C_Country    
         ,  consigneekey  
         ,  Storerkey   
         ,  OHUdf03           
         ,  SKU            
         ,  SUM(TTLCase)  
         ,  SKUSUSR3                      
         ,  SUM(Qty)  
         ,  TrackingNo   --WL02                    
   FROM #TMP_PLTOUTListFinal
   GROUP BY PalletKey     
         ,  OHUdf09       
         ,  ExtOrdKey 
         ,  C_Company       
         ,  C_Address4   
         ,  C_Country    
         ,  consigneekey  
         ,  Storerkey   
         ,  OHUdf03           
         ,  SKU            
         ,  SKUSUSR3  
         ,  TrackingNo   --WL02         
   --WL01 End                  

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO