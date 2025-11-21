SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/                
/* Stored Proc: isp_Packing_List_97_gbmax_rdt                           */                
/* Creation Date: 11-AUG-2023                                           */                
/* Copyright: MAersk                                                    */                
/* Written by: CSCHONG                                                  */                
/*                                                                      */                
/* Purpose: WMS-22762 [CN] GBMAX_Ecom_Packinglist_2 sided print by system_CR*/                
/*                                                                      */                
/* Called By: r_dw_packing_list_97_rdt                                  */                
/*                                                                      */                
/* GitLab Version: 1.3                                                  */                
/*                                                                      */                
/* Version: 7.0                                                         */                
/*                                                                      */                
/* Data Modifications:                                                  */                
/*                                                                      */                
/* Updates:                                                             */                
/* Date         Author    Ver Purposes                                  */         
/* 18-Jun-2021  Mingle    1.1 WMS-17272 modify logic(ML01)              */         
/* 15-Oct-2021  WinSern   1.2 INC1643048 add sku.storerkey join(ws01)   */      
/* 20-Oct-2021  WLChooi   1.3 DevOps Combine Script                     */         
/* 20-Oct-2021  WLChooi   1.3 WMS-18129 - Add column (WL01)             */    
/* 01-Nov-2021  WinSern   1.4 INC1657341 chg pack.qty to pick.qty(ws02) */            
/* 22-MAY-2023  CSCHONG   1.5 WMS-22594 add new parameter (CS01)        */    
/************************************************************************/                
CREATE    PROC [dbo].[isp_Packing_List_97_gbmax_rdt]             
            @c_storerkey          NVARCHAR(20)         --CS01    
           ,@c_Pickslipno         NVARCHAR(15) 
           ,@c_StartCartonNo      NVARCHAR(10) = ''    --CS01
           ,@c_EndCartonNo        NVARCHAR(10) = ''    --CS01              
           ,@c_Type               NVARCHAR(1) = 'H'        
           ,@n_recgrp             INT = 0           
                         
AS                
BEGIN                
   SET NOCOUNT ON                
   SET ANSI_NULLS OFF                
   SET QUOTED_IDENTIFIER OFF                
   SET CONCAT_NULL_YIELDS_NULL OFF        
           
   DECLARE @n_NoOfLine        INT   
          ,@n_Fromcarton      INT     --CS01  
          ,@n_ToCarton        INT     
          ,@n_ctnRec          INT = 1
          ,@n_GetCtnNo        INT   
          ,@c_GetExtOrdkey    NVARCHAR(50) 
          ,@n_GetRecGrp       INT
           
   SET @n_NoOfLine = 12           
  
   --CS01 S  
     IF ISNULL(@c_StartCartonNo,'') = ''  
     BEGIN  
          SET @n_Fromcarton = 1  
     END  
     ELSE  
     BEGIN  
       SET @n_Fromcarton = CAST(@c_StartCartonNo AS INT)  
     END  
  
     IF ISNULL(@c_EndCartonNo,'') = ''  
     BEGIN  
          SET @n_ToCarton = 9999  
     END  
     ELSE  
     BEGIN  
       SET @n_ToCarton = CAST(@c_EndCartonNo AS INT)  
     END  
  
  
  
   CREATE TABLE #TMP_PLIST27RDT  
   (  
     Externorderkey      NVARCHAR(50),  
     Adddate             DATETIME,  
     C_contact1          NVARCHAR(100),  
     Descr               NVARCHAR(60),  
     BUSR6               NVARCHAR(45),  
     Size                NVARCHAR(45),  
     SKU                 NVARCHAR(20),  
     Unitprice           NVARCHAR(20),  
     Qty                 INT,  
     totalmara           NVARCHAR(10),  
     recgrp              INT,  
     trackingno          NVARCHAR(50),  
     cartonno            INT,
     MCompany            NVARCHAR(45),
     Storerkey           NVARCHAR(20),
     RptType             NVARCHAR(10)   
    )  
  
  INSERT INTO #TMP_PLIST27RDT  
  (  
      Externorderkey,  
      Adddate,  
      C_contact1,  
      Descr,  
      BUSR6,  
      Size,  
      SKU,  
      Unitprice,  
      Qty,  
      totalmara,  
      recgrp,  
      trackingno,  
      cartonno,MCompany,Storerkey,RptType  
  )  
                    
   SELECT Orders.Externorderkey,            
          Orders.Adddate,            
          Orders.C_contact1,            
          left(SKU.Descr,len(SKU.Descr)- CHARINDEX('-',REVERSE(SKU.Descr))),            
          SKU.BUSR6,            
          SKU.Size,            
          packdetail.SKU,             
          0 AS Unitprice,            
          --Packdetail.QTY AS qty,     --ML01     
          SUM(Packdetail.QTY) AS qty,    --(ws02)        
          0 as totalmara,               
          ((Row_Number() OVER (PARTITION BY Packdetail.CartonNo,Orders.OrderKey ORDER BY Packdetail.CartonNo,packdetail.SKU Asc)-1)/@n_NoOfLine) + 1 AS RecGrp,   --CS01   
          PIF.TrackingNo,   --WL01         --CS01     
          Packdetail.CartonNo,   --CS01  
          ISNULL(Orders.M_Company,''),Orders.storerkey ,cl.Short
   FROM Packdetail (NOLOCK)            
   --JOIN SKU (NOLOCK) ON packdetail.SKU = SKU.SKU         --(ws01)          
   JOIN Packheader (NOLOCK) ON Packdetail.Pickslipno = Packheader.Pickslipno             
   JOIN Orders (NOLOCK) ON Packheader.orderkey = Orders.Orderkey             
   --JOIN Orderdetail (NOLOCK) ON Orders.orderkey = Orderdetail.orderkey         
   JOIN SKU (NOLOCK) ON packdetail.SKU = SKU.SKU  and SKU.storerkey=Orders.storerkey       --(ws01)        
   --JOIN Pickdetail (NOLOCK) ON Pickdetail.Orderkey = Orderdetail.Orderkey           
   --                        AND Pickdetail.OrderlineNumber = Orderdetail.OrderlineNumber           
   --                        AND Pickdetail.SKu = Orderdetail.SKU          
   --                        AND Pickdetail.CaseID = Packdetail.Labelno          
   --                        AND Pickdetail.Sku = PackDetail.SKU   
   JOIN dbo.CODELKUP CL WITH (NOLOCK) ON CL.LISTNAME ='GBMAXPLST' AND CL.Code=orders.userdefine03 AND CL.Storerkey=orders.storerkey 
   JOIN dbo.PackInfo PIF WITH (NOLOCK) ON PIF.PickSlipNo = PackDetail.PickSlipNo AND PIF.CartonNo = Packdetail.CartonNo      --CS01              
   WHERE Packdetail.Pickslipno = @c_Pickslipno      
   AND ( Packdetail.CartonNo BETWEEN @n_Fromcarton AND @n_ToCarton )     --CS01      
   GROUP BY --CAST(Orderdetail.Unitprice AS INT),        
            ORDERS.ExternOrderKey,        
            ORDERS.AddDate,        
            C_contact1,        
            DESCR,        
            BUSR6,        
            Size,        
            PackDetail.SKU,        
       --     PickDetail.Qty,    --(ws02)    
            Orders.OrderKey,Orders.StorerKey,        
            --,orders.UserDefine03          
            PIF.TrackingNo,   --WL01       --CS01
            Packdetail.CartonNo,   --CS01  
          ISNULL(Orders.M_Company,'') ,Orders.storerkey ,cl.Short
  
  
   IF @c_Type='H' OR @c_Type ='F'    
   BEGIN    
  
          SELECT DISTINCT @c_Pickslipno AS pickslipno  , CAST(@n_Fromcarton AS NVARCHAR(5)) AS StartCartonNo,CAST(@n_ToCarton AS NVARCHAR(5)) AS EndCartonNo,  
                          TP27.recgrp AS recgrp,CAST(TP27.cartonno AS NVARCHAR(5)) AS cartonno,      
                          (SELECT MAX(recgrp) FROM #TMP_PLIST27RDT TP WHERE TP.Externorderkey = TP27.Externorderkey AND TP.cartonno = TP27.cartonno) AS TTLPAGE ,     
                          MCompany,TP27.Storerkey,TP27.RptType
          FROM #TMP_PLIST27RDT TP27    
     
   END  
ELSE IF @c_Type ='D'    
BEGIN  

   DECLARE CUR_RecLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Externorderkey,cartonno,recgrp,COUNT(1)
   FROM #TMP_PLIST27RDT 
   GROUP BY Externorderkey,cartonno,recgrp
   HAVING COUNT(1) < @n_NoOfLine
   ORDER BY Externorderkey,cartonno,recgrp

 OPEN CUR_RecLoop

   FETCH NEXT FROM CUR_RecLoop INTO @c_GetExtOrdkey,@n_GetCtnNo,@n_GetRecGrp,@n_ctnRec

   WHILE @@FETCH_STATUS <> -1
   BEGIN

   WHILE @n_ctnRec < @n_NoOfLine
   BEGIN

     INSERT INTO #TMP_PLIST27RDT
     (
         Externorderkey,
         Adddate,
         C_contact1,
         Descr,
         BUSR6,
         Size,
         SKU,
         Unitprice,
         Qty,
         totalmara,
         recgrp,
         trackingno,
         cartonno,
         MCompany,
         Storerkey,
         RptType
     )
SELECT TOP 1 Externorderkey,
         Adddate,
         C_contact1,
         '',
         '',
         '',
         '',
         '',
         '',
         '',
         recgrp,
         trackingno,
         cartonno,
         MCompany,
         Storerkey,
         RptType
FROM #TMP_PLIST27RDT
WHERE Externorderkey = @c_GetExtOrdkey 
AND cartonno = @n_GetCtnNo
AND recgrp = @n_GetRecGrp  


SET @n_ctnRec = @n_ctnRec + 1

   END
    

   FETCH NEXT FROM CUR_RecLoop INTO @c_GetExtOrdkey,@n_GetCtnNo,@n_GetRecGrp,@n_ctnRec

   END

SELECT Externorderkey,  
      Adddate,  
      C_contact1,  
      Descr,  
      BUSR6,  
      Size,  
      SKU,  
      Unitprice,  
      Qty,  
      totalmara,  
      recgrp,  
      trackingno,  
      cartonno,  
       MCompany ,
      (SELECT MAX(recgrp) FROM #TMP_PLIST27RDT TP WHERE TP.Externorderkey = TP27.Externorderkey AND TP.cartonno = TP27.cartonno) AS TTLPAGE  
FROM #TMP_PLIST27RDT TP27  
WHERE TP27.recgrp = CASE WHEN ISNULL(@n_recgrp,0) <> 0 THEN @n_recgrp ELSE TP27.recgrp END   
ORDER BY Externorderkey,trackingno,cartonno,recgrp  
END  
  
   IF OBJECT_ID('tempdb..#TMP_PLIST27RDT','u') IS NOT NULL  
      DROP TABLE #TMP_PLIST27RDT;  
           
END         

GO