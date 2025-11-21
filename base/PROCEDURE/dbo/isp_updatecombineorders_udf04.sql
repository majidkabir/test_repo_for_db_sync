SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*------------------------------------------------------------------------------- */                  
/*                                                                                */          
/*Stored Procedure: isp_UpdateCombineOrders_UDF04                                 */                        
/* Creation Date: 22-February-2019                                                */                          
/* Copyright: LF LOGISTICS                                                        */                          
/* Written by: KelvinOngCY                                                        */                          
/*                                                                                */                          
/* Purpose: https://jira.lfapps.net/browse/WMS-7642                               */                          
/*                                                                                */                          
/* Called By: isp_OrdersMerging                                                   */                           
/*                                                                                */                          
/* Parameters:                                                                    */                          
/*                                                                                */                          
/* PVCS Version:                                                                  */                          
/*                                                                                */                          
/* Version:                                                                       */                          
/*                                                                                */                          
/* Data Modifications:                                                            */                          
/*                                                                                */                          
/* Updates:                                                                       */                          
/* Date          Author  Ver. Purposes                                            */                   
/* 09-Jan-2019   kocy    1.0  Update Combine order Orders.UserDefine04 map        */  
/*                            to Child orders Orders.UserDefine04 and Issued = Y  */                                   
/* -------------------------------------------------------------------------------*/          
CREATE PROCEDURE [dbo].[isp_UpdateCombineOrders_UDF04]        
(         
 @c_StorerKey NVARCHAR(15)          
,@b_debug bit = 0          
)          
AS          
   SET NOCOUNT ON                      
   SET ANSI_NULLS OFF                      
   SET QUOTED_IDENTIFIER OFF                     
   SET CONCAT_NULL_YIELDS_NULL OFF       
         
BEGIN        
        
   DECLARE @c_ParentOrderKey  NVARCHAR (20)        
     , @c_childOrderKey  NVARCHAR (15)                           
     , @c_childTrackingNo NVARCHAR (15)                     
     , @c_childUserDefine04 NVARCHAR (20)        
     , @c_errmsg    NVARCHAR(128)        
        
   IF ISNULL(OBJECT_ID('tempdb..#Temp_FinalOrders'), '') <> ''                      
   BEGIN                      
      DROP TABLE #Temp_FinalOrders                      
   END                      
                      
   CREATE TABLE #Temp_FinalOrders                      
   (                      
      OrderKey NVARCHAR(20),          
      [Status] NVARCHAR(10),          
      SOStatus NVARCHAR(10),        
      OrderGroup NVARCHAR (20),        
      TrackingNo NVARCHAR (20),        
      UserDefine04 NVARCHAR (20),        
      Issued  NVARCHAR (10)            
   )        
        
   INSERT INTO #Temp_FinalOrders ( [OrderKey],[TrackingNo],[UserDefine04],[Status], [SOStatus], [OrderGroup],[Issued])        
   SELECT o.OrderKey, o.TrackingNo, o.UserDefine04, o.[Status],o.SOStatus, o.[OrderGroup], o.[Issued]        
   FROM ORDERS AS o WITH (NOLOCK)        
   WHERE o.StorerKey = @c_StorerKey        
   AND TRY_CAST (o.[Status] AS INT) <= 5   -- prevent 'CANC' status        
   AND o.SOStatus = '0'        
   AND o.OrderGroup = 'COM_ORDER'        
   AND o.Issued = 'N'        
   AND o.UserDefine04 <> ''        
   AND o.TrackingNo <> ''        
        
  IF NOT EXISTS (SELECT 1 FROM #Temp_FinalOrders)                      
  BEGIN                                
     SET @c_errmsg = N' No columns acquire from ''#Temp_FinalOrders'' table. '         
  GOTO QUIT        
  END        
        
  IF EXISTS ( SELECT 1 FROM #Temp_FinalOrders)         
  BEGIN                                
   IF(@b_debug = 1)                    
   BEGIN            
      SELECT 'Updating combinable orders UDF04 to child orders UDF04.'        
     SELECT * FROM #Temp_FinalOrders        
   --SELECT TrackingNo, UserDefine04, SOStatus, Status, OrderGroup, Issued, * FROM ORDERS (NOLOCK) WHERE OrderKey = @c_NewOrderkey          
   --SELECT ConsoOrderKey FROM OrderDetail (NOLOCK) WHERE Orderkey = @c_NewOrderkey          
   END         
        
   DECLARE CUR_READ_UD04_CombineOrders CURSOR LOCAL FAST_FORWARD READ_ONLY FOR         
   SELECT o.OrderKey, o.TrackingNo, od.ConsoOrderKey , o.UserDefine04          
   FROM #Temp_FinalOrders        
   JOIN ORDERS  AS o WITH (NOLOCK)        
   ON o.OrderKey = #Temp_FinalOrders.[OrderKey]        
   JOIN ORDERDETAIL AS od WITH (NOLOCK)        
   ON o.OrderKey = od.Orderkey        
   WHERE o.OrderGroup = #Temp_FinalOrders.[OrderGroup]         
   AND od.ConsoOrderKey <> ''        
   AND EXISTS ( SELECT 1 FROM ORDERS AS child WITH (NOLOCK) WHERE child.OrderKey = od.ConsoOrderKey            
       --AND child.SOStatus = 'HOLD'          
       AND child.[OrderGroup] = 'CHILD_ORD'        
       AND child.UserDefine04 <> o.UserDefine04        
       AND child.TrackingNo  <> o.TrackingNo )        
             
   OPEN CUR_READ_UD04_CombineOrders                        
   FETCH NEXT FROM CUR_READ_UD04_CombineOrders INTO @c_ParentOrderKey, @c_childTrackingNo, @c_childOrderKey, @c_childUserDefine04                    
                
   WHILE (@@FETCH_STATUS <> -1)           
   BEGIN          
              
   IF (@b_debug = 1)          
   BEGIN          
    SELECT @c_ParentOrderKey 'ParentOrderKey', @c_childTrackingNo 'child TrackNo' , @c_childOrderKey 'child ConsoOrderKey', @c_childUserDefine04 'child UDF04'          
   END          
                 
      BEGIN TRAN        
        
          UPDATE [dbo].[ORDERS] WITH (ROWLOCK)                     
          SET [Issued] = 'Y'        
             ,TrafficCop = NULL                        
             ,EditDate = GETDATE()                        
             ,EditWho = SUSER_SNAME()                                         
            WHERE Orderkey =  @c_ParentOrderKey        
            AND Storerkey = @c_StorerKey        
        
        
          UPDATE [dbo].[ORDERS] WITH (ROWLOCK)                     
          SET TrackingNo = @c_childTrackingNo                      
             ,UserDefine04 = @c_childUserDefine04        
             ,[Issued] = 'Y'        
             ,TrafficCop = NULL                        
             ,EditDate = GETDATE()                        
             ,EditWho = SUSER_SNAME()                                         
         WHERE Orderkey =  @c_childOrderKey        
         AND Storerkey = @c_StorerKey        
      --ROLLBACK TRAN                    
                             
        IF @@ROWCOUNT = 0 OR @@ERROR <> 0                        
        BEGIN                        
            ROLLBACK TRAN                              
      SET @c_errmsg = N'FAIL MERGING, Unable to update parent orders UDF04 to child orders UDF04.'        
            GOTO QUIT        
        END                    
        COMMIT TRAN         
             
                         
   FETCH NEXT FROM CUR_READ_UD04_CombineOrders INTO @c_ParentOrderKey, @c_childTrackingNo, @c_childOrderKey, @c_childUserDefine04          
   END  --WHILE (@@FETCH_STATUS <> -1)          
   CLOSE CUR_READ_UD04_CombineOrders                        
   DEALLOCATE CUR_READ_UD04_CombineOrders             
  END              
    
 QUIT:          
 IF CURSOR_STATUS('LOCAL' , 'CUR_T3 ') in (0 , 1)         
 BEGIN          
    PRINT @c_errmsg          
    CLOSE CUR_READ_UD04_CombineOrders           
    DEALLOCATE CUR_READ_UD04_CombineOrders             
 END          
        
END

GO