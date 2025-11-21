SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/              
/* Store Procedure: isp_Packing_List_121_rdt                                  */              
/* Creation Date: 22-FEB-2022                                                 */              
/* Copyright: IDS                                                             */              
/* Written by: CHONGCS                                                        */              
/*                                                                            */              
/* Purpose: WMS-18975 CN - ERNO LASZLO Packing List                           */  
/*                                                                            */ 
/*                                                                            */              
/*                                                                            */              
/* Called By:  r_dw_packing_list_121_rdt                                      */              
/*                                                                            */              
/* PVCS Version: 1.0                                                          */              
/*                                                                            */              
/* Version: 1.0                                                               */              
/*                                                                            */              
/* Data Modifications:                                                        */              
/*                                                                            */              
/* Updates:                                                                   */              
/* Date         Author    Ver.  Purposes                                      */    
/* 22-Feb-2022  CSCHONG   1.0   Devops Scripts Combine                        */
/* 30-May-2022  MINGLE    1.1   Add new column(ML01)                          */
/******************************************************************************/     
  
CREATE PROC [dbo].[isp_Packing_List_121_rdt]             
             (@c_Orderkey NVARCHAR(10),
              @c_labelno  NVARCHAR(20)='')    
            
AS            
BEGIN            
   SET NOCOUNT ON            
   SET ANSI_WARNINGS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @c_MCompany        NVARCHAR(45)  
         , @c_Externorderkey  NVARCHAR(30)  
         , @c_C_Addresses     NVARCHAR(200)   
         , @c_loadkey         NVARCHAR(10)  
         , @c_Userdef03       NVARCHAR(20)  
         , @c_salesman        NVARCHAR(30)  
         , @c_phone1          NVARCHAR(18)
         , @c_contact1        NVARCHAR(30)  
  
         , @n_TTLQty          INT   
         , @c_shippername     NVARCHAR(45)  
         , @c_Sku             NVARCHAR(20)  
         , @c_Size            NVARCHAR(5)  
         , @c_PickLoc         NVARCHAR(10) 
         , @n_NoOfLine        INT  
         , @c_getOrdKey       NVARCHAR(10)
         , @n_ctnrec          INT = 0
         , @n_maxrecgrp       INT
         , @n_AddRec          INT

 SET @n_NoOfLine = 5
 SET @c_getOrdKey = ''                
  
  
 CREATE TABLE #PACKLIST121rdt 
         ( Seqno           INT NOT NULL IDENTITY(1,1) PRIMARY KEY
         , c_Contact1      NVARCHAR(30) NULL   
         , C_Addresses     NVARCHAR(200) NULL  
         , c_Phone1        NVARCHAR(18) NULL  
         , Remarks         NVARCHAR(150) NULL 
         , SKU             NVARCHAR(20)  NULL 
         , Qty            INT               
         , OrderKey        NVARCHAR(10)  NULL     
         , OHNotes         NVARCHAR(100)  NULL        
         , ODLOTT04        NVARCHAR(10)  NULL        
         , PrnDate         NVARCHAR(10)  NULL  
         , Altsku          NVARCHAR(20)  NULL
         , Unit            NVARCHAR(10) NULL
         , OHNotes2        NVARCHAR(120) NULL
         , RecGrp          INT
         , SDESCR          NVARCHAR(120)            
         , ExtenOrdKey     NVARCHAR(50)     
         , companyname     NVARCHAR(80) 
		 , TrackingNo      NVARCHAR(40) NULL	--ML01
         )  
          
  
   CREATE TABLE #TMP_Orders (
      Orderkey   NVARCHAR(10)
   )
 
   IF EXISTS (SELECT 1 FROM orders (NOLOCK) WHERE orderkey = @c_Orderkey AND ISNULL(@c_labelno,'') = '')   --orderkey
   BEGIN
      INSERT INTO #TMP_Orders (Orderkey)
      SELECT @c_Orderkey
   END 
   IF EXISTS (SELECT 1 FROM PACKHEADER PH WITH (NOLOCK) WHERE PH.PickSlipNo = @c_Orderkey AND ISNULL(@c_labelno,'') = '')   --pickslipno
   BEGIN
      INSERT INTO #TMP_Orders (Orderkey)
      SELECT OrderKey 
      FROM PackHeader WITH (NOLOCK)
       WHERE PickSlipNo = @c_Orderkey
   END 
   ELSE IF ISNULL(@c_labelno,'') <> '' AND  EXISTS (SELECT 1 FROM PICKDETAIL (NOLOCK) WHERE orderkey = @c_Orderkey AND caseid = @c_labelno )    --(orderkey + labelno)
   BEGIN
      INSERT INTO #TMP_Orders (Orderkey)
      SELECT pd.OrderKey
      FROM ORDERS OH WITH (NOLOCK)
      JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORDDET.Orderkey = OH.Orderkey
      JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = OH.Orderkey 
                            AND PD.orderlinenumber = ORDDET.orderlinenumber
       WHERE PD.Orderkey = @c_Orderkey
       AND PD.Caseid = @c_labelno
       GROUP BY PD.OrderKey
   END


   --SELECT * FROM #TMP_Orders

   INSERT INTO #PACKLIST121rdt (
                       c_Contact1      
                     , C_Addresses     
                     , c_Phone1        
                     , Remarks              
                     , SKU           
                     , Qty            
                     , OrderKey        
                     , OHNotes         
                     , ODLOTT04        
                     , PrnDate
                     , Altsku   
                     , Unit              
                     , OHNotes2              
                     , RecGrp 
                     , SDESCR    
                     , ExtenOrdKey  
                     , companyname  
					 , TrackingNo	--ML01
                           )             
   SELECT ISNULL(OH.c_Contact1,''),(ISNULL(OH.C_state,'')+ISNULL(OH.C_City,'')+ISNULL(OH.C_address1,'')+ISNULL(OH.C_address2,'') ),
                   ISNULL(OH.C_Phone1,''),'' AS remarks,
                   ORDDET.SKU,(PICKD.Qty),OH.OrderKey,
                   OH.Notes,ISNULL(CONVERT(NVARCHAR(10),LOTT.Lottable04,120),''),CONVERT(NVARCHAR(10),GETDATE(),111) AS prndate,
                   S.ALTSKU,'EA' AS Unit,(ISNULL(Oh.Type,'')+ISNULL(OH.Notes2,'')),
                   (ROW_NUMBER() OVER (PARTITION BY OH.Orderkey ORDER BY ORDDET.sku ASC)-1)/5 
                   , S.DESCR,OH.ExternOrderkey ,'Erno Laszlo ' AS companyname
				   , OH.TrackingNo	--ML01
   FROM ORDERS OH WITH (NOLOCK)
   JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORDDET.Orderkey = OH.Orderkey
   JOIN SKU S WITH (NOLOCK) ON S.SKU = ORDDET.SKU AND S.Storerkey=ORDDET.Storerkey
   JOIN dbo.PICKDETAIL PICKD WITH (NOLOCK) ON PICKD.OrderKey = ORDDET.OrderKey AND PICKD.OrderLineNumber = ORDDET.OrderLineNumber AND PICKD.Storerkey = ORDDET.StorerKey AND PICKD.sku = ORDDET.sku
   JOIN dbo.LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.lot=PICKD.lot 
   JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.OrderKey = OH.OrderKey
  -- JOIN PACKDETAIL PAD WITH (NOLOCK) ON PAD.PickSlipNo = ph.PickSlipNo 
   --CROSS APPLY (SELECT SUM(PACKDETAIL.Qty) AS Qty
   --                FROM PACKHEADER (NOLOCK)
   --                JOIN PACKDETAIL (NOLOCK) ON PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo
   --                WHERE PACKHEADER.PickSlipNo = PH.PickSlipNo) AS PD
   JOIN #TMP_Orders TOS ON TOS.orderkey = OH.Orderkey   
   ORDER BY ORDDET.sku

    SELECT @n_maxrecgrp = MAX(RecGrp)
    FROM #PACKLIST121rdt 


   SELECT @n_ctnrec = COUNT(1)
   FROM #PACKLIST121rdt 
   WHERE orderkey = @c_Orderkey
   AND RecGrp = @n_maxrecgrp


   SET @n_AddRec = @n_NoOfLine -(@n_ctnrec%@n_NoOfLine)

   
    --WHILE @n_AddRec <6 AND @n_AddRec > 0
    --BEGIN
    --  INSERT INTO #PACKLIST121rdt
    --  (
    --      c_Contact1,
    --      C_Addresses,
    --      c_Phone1,
    --      Remarks,
    --      SKU,
    --      Qty,
    --      OrderKey,
    --      OHNotes,
    --      ODLOTT04,
    --      PrnDate,
    --      Altsku,
    --      Unit,
    --      OHNotes2,
    --      RecGrp,
    --      SDESCR,
    --      ExtenOrdKey,
    --      companyname
    --  )
    --  SELECT TOP 1  c_Contact1,
    --      C_Addresses,
    --      c_Phone1,
    --      Remarks,
    --      '',
    --      '',
    --      OrderKey,
    --      OHNotes,
    --      '',
    --      PrnDate,
    --      '',
    --      '',
    --      OHNotes2,
    --      RecGrp,
    --      '',
    --      ExtenOrdKey,
    --      companyname
    --  FROM #PACKLIST121rdt
    --  WHERE orderkey = @c_Orderkey
    --  AND RecGrp = @n_maxrecgrp
    -- ORDER BY Seqno

    --  SET @n_AddRec = @n_AddRec - 1

    --END
  
  
      SELECT           c_Contact1      
                     , C_Addresses     
                     , c_Phone1        
                     , Remarks              
                     , SKU           
                     , Qty            
                     , OrderKey        
                     , OHNotes         
                     , ODLOTT04        
                     , PrnDate
                     , Altsku   
                     , Unit              
                     , OHNotes2              
                     , RecGrp 
                     , SDESCR    
                     , ExtenOrdKey
                     , companyname 
					 , TrackingNo	--ML01
         FROM #PACKLIST121rdt  
         ORDER BY Seqno
END

GO