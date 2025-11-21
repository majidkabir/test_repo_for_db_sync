SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_shipment_handover_02_rdt                        */  
/* Creation Date: 2023-06-01                                             */  
/* Copyright: IDS                                                        */  
/* Written by:CSCHONG                                                    */  
/*                                                                       */  
/* Purpose: WMS-22639 -[CN]ZFrontire MBOL Detail Report                  */  
/*                                                                       */  
/* Called By: r_shipment_handover_02_rdt                                 */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author  Ver   Purposes                                    */  
/* 01-Jun-2023 CSCHONG 1.0   DevOps Scripts Combine                      */
/*************************************************************************/  
CREATE   PROC [dbo].[isp_shipment_handover_02_rdt]  
         (  @c_mbolkey   NVARCHAR(20)     
          )    
  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE --@c_storerkey  NVARCHAR(10)  
          @c_storerkey      NVARCHAR(10)   
         ,@n_NoOfLine       INT  
         ,@n_recgrpsort     INT   
         ,@c_AddWho         NVARCHAR(128)           
 
  
      
  
SELECT  OH.storerkey AS storerkey,MB.mbolkey AS mbolkey,ISNULL(C.long,'') AS storername,MB.externmbolkey AS externmbolkey,
        OH.externorderkey AS Externorderkey,OH.Orderkey AS orderkey,OH.c_state AS c_state,OH.c_city AS c_city , 
        ISNULL(OH.c_address1,'') AS C_Address1, ISNULL(OH.c_address2,'') AS C_Address2,ISNULL(OH.c_address3,'') AS C_Address3,
        ISNULL(OH.c_address4,'') AS C_Address4,SUM(OD.qtyAllocated + OD.qtyPicked + OD.ShippedQty) AS qty,
        MD.totalcartons AS TTLCTN,MD.weight AS WGT,MD.[CUBE] AS [cube],ISNULL(OH.notes,'') AS OHNotes
FROM MBOL MB WITH (NOLOCK)
JOIN MBOLDETAIL MD WITH (NOLOCK) ON MB.mbolkey = MD.mbolkey
JOIN ORDERS OH WITH (NOLOCK) ON OH.orderkey = MD.orderkey
JOIN ORDERDETAIL OD WITH (NOLOCK) ON OH.orderkey = OD.orderkey
LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname='STORENAME' AND C.short = OH.storerkey
WHERE MB.mbolkey = @c_mbolkey
GROUP BY MB.mbolkey,OH.storerkey ,ISNULL(C.long,''),MB.externmbolkey,
               OH.externorderkey ,OH.Orderkey ,OH.c_state ,OH.c_city  , 
               ISNULL(OH.c_address1,'') , ISNULL(OH.c_address2,'') ,ISNULL(OH.c_address3,'') ,
              ISNULL(OH.c_address4,'') ,MD.totalcartons,MD.weight,MD.[CUBE],ISNULL(OH.notes,'')
ORDER BY MB.mbolkey,OH.c_state,OH.c_city,OH.Orderkey
  
  
  
  
QUIT_SP:  
END  

GO