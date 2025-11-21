SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/              
/* Store Procedure: isp_Packing_List_120_rdt                                  */              
/* Creation Date: 07-FEB-2022                                                 */              
/* Copyright: IDS                                                             */              
/* Written by: CSCHONG                                                        */              
/*                                                                            */              
/* Purpose: WMS-18744 [TW]LOR_PackList_CR                                     */  
/*                                                                            */              
/*                                                                            */              
/* Called By:  r_dw_packing_list_120_rdt                                      */              
/*                                                                            */              
/* PVCS Version: 1.0                                                          */              
/*                                                                            */              
/* Version: 1.0                                                               */              
/*                                                                            */              
/* Data Modifications:                                                        */              
/*                                                                            */              
/* Updates:                                                                   */              
/* Date         Author    Ver.  Purposes                                      */ 
/* 30-MAY-2022  MINGLE    1.1   Add new column(ML01)                          */
/* 11-OCT-2022  MINGLE    1.2   WMS-20959 Change codelkup.code from           */
/*                              oh.IntermodalVehicle to OIF.StoreName(ML02)   */
/* 28-DEC-2022  CSCHONG   1.3   Devops Scripts Combine & WMS-21412 (CS01)     */
/******************************************************************************/     
  
CREATE   PROC [dbo].[isp_Packing_List_120_rdt]             
       ( @c_Orderkey   NVARCHAR(10) 
 )
            
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
         , @c_Pic01           NVARCHAR(50)   = ''
         , @c_Pic02           NVARCHAR(50)   = ''
         , @c_Pic03           NVARCHAR(50)   = ''
         , @c_Pic04           NVARCHAR(50)   = ''
         , @c_Pic05           NVARCHAR(50)   = ''

 SET @n_NoOfLine = 6
 SET @c_getOrdKey = ''                
  
IF EXISTS (SELECT 1 FROM dbo.PICKDETAIL WITH (NOLOCK) WHERE PickSlipNo=@c_Orderkey)
BEGIN
     SELECT TOP 1 @c_getOrdKey = orderkey
     FROM PICKDETAIL WITH (NOLOCK) 
     WHERE PickSlipNo=@c_Orderkey
END
ELSE
BEGIN
    SET @c_getOrdKey = @c_Orderkey
END
  
 CREATE TABLE #PACKLIST120rdt 
         ( c_Contact1      NVARCHAR(30)  NULL 
         , C_Addresses     NVARCHAR(250) NULL
         , c_Phone1        NVARCHAR(18)  NULL      
         , EcomOrderId     NVARCHAR(50)  NULL     
         , PmtTerm         NVARCHAR(10)  NULL
         , ODNotes         NVARCHAR(500) NULL
         , ODNotes2        NVARCHAR(500) NULL
         , Pic01           NVARCHAR(50)  NULL
         , Pic02           NVARCHAR(50)  NULL
         , PASKU           NVARCHAR(20)  NULL
         , Pqty            INT              
         , OrderKey        NVARCHAR(10)  NULL          
         , Pic03           NVARCHAR(50)  NULL
         , Pic04           NVARCHAR(50)  NULL     
         , OrdDate         NVARCHAR(10)  NULL  
         , Pic05           NVARCHAR(50) NULL
         , UnitPrice       FLOAT NULL
         , TTLUnitPrice    FLOAT
         , TrackingNo      NVARCHAR(30)
         , CLK1UDF05       NVARCHAR(60)
         , BuyerPO         NVARCHAR(20)  NULL   --ML01
         , SDESCR          NVARCHAR(60)  NULL   --ML01
         , PDRefno2        NVARCHAR(30)  NULL   --CS01
         )  
         


   INSERT INTO #PACKLIST120rdt
   (
       c_Contact1,
       C_Addresses,
       c_Phone1,
       EcomOrderId,
       PmtTerm,
       ODNotes,
       ODNotes2,
       Pic01,
       Pic02,
       PASKU,
       Pqty,
       OrderKey,
       Pic03,
       Pic04,
       OrdDate,
       Pic05,
       UnitPrice,
       TTLUnitPrice,
       TrackingNo,
       CLK1UDF05,
       BuyerPO,   --ML01
       SDESCR, --ML01
       PDRefno2 --CS01
   )      
   SELECT ISNULL(OH.c_Contact1,''),(ISNULL(OH.C_Zip,'')+ISNULL(OH.C_address1,'')+ISNULL(OH.C_address2,'') + ISNULL(OH.C_address3,'') + ISNULL(OH.C_address4,'')),
                   ISNULL(OH.C_Phone1,''),ISNULL(OIF.EcomOrderId,''),CASE WHEN ISNULL(OH.notes2,'') <> '' THEN 'Y' ELSE '' END ,  --CS01
                   ISNULL(ORDDET.Notes,''), ISNULL(ORDDET.Notes2,''),
                   ISNULL(C1.notes,'') AS pic01,ISNULL(C2.notes,'')AS pic02,
                   ISNULL(ORDDET.altsku,ORDDET.SKU),PD.qty,--(ORDDET.ShippedQty+ ORDDET.QtyPreAllocated+ ORDDET.QtyAllocated+ ORDDET.QtyPicked ),
                   OH.OrderKey, ISNULL(C3.notes,'') AS pic03, ISNULL(C4.notes,'') AS pic04,
                   CONVERT(NVARCHAR(10),OH.OrderDate,120) AS ORDDate, ISNULL(C5.notes,'') AS pic05,
                   ORDDET.UnitPrice,pd.qty * ORDDET.UnitPrice,
                   CASE WHEN CLK.short='711' THEN SubString(OH.TrackingNo, 7 , 3)+ Right(OH.TrackingNo,8) ELSE OH.TrackingNo END,
                   ISNULL(CLK1.UDF05,''),
                   OH.BuyerPO,   --ML01
                   S.DESCR --ML01
                   ,PAD.refno2    --CS01
   FROM ORDERS OH WITH (NOLOCK)
   JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORDDET.Orderkey = OH.Orderkey
   JOIN dbo.OrderInfo OIF WITH (NOLOCK) ON OIF.Orderkey = OH.Orderkey 
   JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON PD.Storerkey = ORDDET.StorerKey AND PD.OrderKey = ORDDET.OrderKey AND PD.sku = ORDDET.sku AND PD.OrderLineNumber = ORDDET.OrderLineNumber
   JOIN SKU S WITH (NOLOCK) ON S.StorerKey = ORDDET.StorerKey AND S.Sku = ORDDET.Sku   --ML01 
   JOIN CODELKUP C1 WITH (NOLOCK) ON c1.LISTNAME='ReprotCFG'  AND c1.Storerkey=oh.StorerKey AND c1.Code = OIF.StoreName AND c1.code2='01' --ML02
   JOIN CODELKUP C2 WITH (NOLOCK) ON c2.LISTNAME='ReprotCFG'  AND c2.Storerkey=oh.StorerKey AND c2.Code = OIF.StoreName AND c2.code2='02' --ML02
   JOIN CODELKUP C3 WITH (NOLOCK) ON c3.LISTNAME='ReprotCFG'  AND c3.Storerkey=oh.StorerKey AND c3.Code = OIF.StoreName AND c3.code2='03' --ML02
   JOIN CODELKUP C4 WITH (NOLOCK) ON c4.LISTNAME='ReprotCFG'  AND c4.Storerkey=oh.StorerKey AND c4.Code = OIF.StoreName AND c4.code2='04' --ML02
   JOIN CODELKUP C5 WITH (NOLOCK) ON c5.LISTNAME='ReprotCFG'  AND c5.Storerkey=oh.StorerKey AND c5.Code = OIF.StoreName AND c5.code2='05' --ML02
   LEFT JOIN Codelkup CLK WITH (NoLock) ON CLK.Storerkey = OH.StorerKey And CLK.Listname = 'ECDLMODE' And CLK.Code = OH.Shipperkey And CLK.Code2 = OH.salesman
   LEFT JOIN Codelkup CLK1 WITH (NoLock) ON  CLK1.Storerkey = OH.StorerKey  And CLK1.Listname = 'ECDLMODE' And CLK1.Code = OH.Shipperkey And CLK1.Code2 = OH.salesman
   CROSS APPLY (SELECT TOP 1 PD.refno2 AS refno2  FROM dbo.PackDetail PD WITH (NOLOCK) JOIN PACKHEADER PH (NOLOCK) ON PH.PickSlipNo=PD.PickSlipNo WHERE PH.OrderKey=OH.OrderKey) AS PAD   --CS01
    WHERE OH.Orderkey = @c_getOrdKey
   ORDER By oh.OrderKey
  
  
      SELECT  DISTINCT  c_Contact1,
                C_Addresses,
                c_Phone1,
                EcomOrderId,
                PmtTerm,
                ODNotes,
                ODNotes2,
                Pic01,
                Pic02,
                PASKU,
                SUM(Pqty) AS pqty,
                OrderKey,
                Pic03,
                Pic04,
                OrdDate,
                Pic05,
                UnitPrice,
                TTLUnitPrice,
                TrackingNo,
                CLK1UDF05,
                BuyerPO,   --ML01
                SDESCR, --ML01
                PDRefno2   --CS01
         FROM #PACKLIST120rdt  
         GROUP BY c_Contact1,
                C_Addresses,
                c_Phone1,
                EcomOrderId,
                PmtTerm,
                ODNotes,
                ODNotes2,
                Pic01,
                Pic02,
                PASKU,
                --Pqty,
                OrderKey,
                Pic03,
                Pic04,
                OrdDate,
                Pic05,
                UnitPrice,
                TTLUnitPrice,
                TrackingNo,
                CLK1UDF05,
                BuyerPO,   --ML01
                SDESCR, --ML01
                PDRefno2   --CS01
         ORDER BY OrderKey,paSKU  
               
END

GO