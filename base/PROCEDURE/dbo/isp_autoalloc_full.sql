SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/***************************************************************************/      
/* Stored Procedure: isp_autoalloc_full                                    */      
/* Creation Date: 15-APRIL-2022                                            */      
/* Copyright: LFL                                                          */      
/* Written by: WZPang                                                      */      
/*                                                                         */      
/* Purpose: WMS-19251 - Fully Allocated Orders Report                      */      
/*                                                                         */      
/* Called By: isp_autoalloc_full                                           */      
/*                                                                         */      
/* GitLab Version: 1.0                                                     */      
/*                                                                         */      
/* Version: 1.0                                                            */      
/*                                                                         */      
/* Data Modifications:                                                     */      
/*                                                                         */      
/* Updates:                                                                */      
/* Date         Author  Ver   Purposes                                     */    
/* 18-Apr-2022  WLChooi 1.0   DevOps Combine Script                        */  
/***************************************************************************/          
CREATE PROC [dbo].[isp_autoalloc_full] (   
         @c_StorerKey   NVARCHAR(50)  
       , @c_BatchNo     NVARCHAR(50)  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET ANSI_DEFAULTS OFF  
  
   SELECT ORDERS.ADDDATE,  
          ORDERS.OrderKey,  
          ORDERS.ExternOrderkey,  
          ORDERS.C_Company,  
          ORDERS.DeliveryDate,  
          ORDERS.UserDefine01
   FROM ORDERS (NOLOCK)  
   WHERE ORDERS.[STATUS] >= '2'   
   AND ORDERS.Storerkey = @c_Storerkey   
   AND ORDERS.UserDefine01 = @c_BatchNo  
   ORDER BY ORDERS.ADDDATE, ORDERS.ExternOrderkey
  
END 

GO