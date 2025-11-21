SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*------------------------------------------------------------------------------------------------------------ */                  
/*                                                                                                             */          
/*Stored Procedure: isp_UpdateSplitOrders_UDF04                                                                */                        
/* Creation Date: 09-October-2020                                                                              */                          
/* Copyright: LF LOGISTICS                                                                                     */                          
/* Written by: JoshYan                                                                                         */                          
/*                                                                                                             */                          
/* Purpose: https://jira.lfapps.net/browse/WMS-                                                                */                          
/*                                                                                                             */                          
/* Called By:                                                                                                  */                           
/*                                                                                                             */                          
/* Parameters:                                                                                                 */                          
/*                                                                                                             */                          
/* PVCS Version:                                                                                               */                          
/*                                                                                                             */                          
/* Version:                                                                                                    */                          
/*                                                                                                             */                          
/* Data Modifications:                                                                                         */                          
/*                                                                                                             */                          
/* Updates:                                                                                                    */                          
/* Date   Author  Ver. Purposes                                                                                */                   
/* 09-Oct-2020  JoshYan 1.0  Split original order Orders.UserDefine04 map to split orders Orders.UserDefine04  */                                   
/* ------------------------------------------------------------------------------------------------------------*/          
CREATE PROCEDURE [dbo].[isp_UpdateSplitOrders_UDF04]        
(         
 @c_StorerKey NVARCHAR(15)          
,@b_debug BIT = 0          
)          
AS          
   SET NOCOUNT ON                      
   SET ANSI_NULLS OFF                      
   SET QUOTED_IDENTIFIER OFF                     
   SET CONCAT_NULL_YIELDS_NULL OFF       
         
BEGIN        
        
   DECLARE @c_OriginalOrderKey  NVARCHAR (20)        
     , @c_SplitOrderKey  NVARCHAR (15)                           
     , @c_SplitTrackingNo NVARCHAR (40)    
  , @n_err         INT   
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
      Issued  NVARCHAR (10)            
   )        
        
   INSERT INTO #Temp_FinalOrders ( [OrderKey],[Status], [SOStatus], [OrderGroup],[Issued])        
   SELECT o.OrderKey, o.[Status],o.SOStatus, o.[OrderGroup], o.[Issued]        
   FROM ORDERS AS o WITH (NOLOCK)        
   WHERE o.StorerKey = @c_StorerKey        
   AND TRY_CAST (o.[Status] AS INT) <= 5   -- prevent 'CANC' status        
   AND o.SOStatus = '0'        
   AND o.OrderGroup = 'ORI_ORDER'        
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
      SELECT 'Updating original orders UDF04 to split orders UDF04.'        
     SELECT * FROM #Temp_FinalOrders        
   --SELECT TrackingNo, UserDefine04, SOStatus, Status, OrderGroup, Issued, * FROM ORDERS (NOLOCK) WHERE OrderKey = @c_NewOrderkey          
   --SELECT ConsoOrderKey FROM OrderDetail (NOLOCK) WHERE Orderkey = @c_NewOrderkey          
   END         
        
   DECLARE CUR_READ_UD04_SplitOrders CURSOR LOCAL FAST_FORWARD READ_ONLY FOR         
   SELECT DISTINCT orio.OrderKey, oriod.ConsoOrderKey          
   FROM #Temp_FinalOrders        
   JOIN ORDERS  AS orio WITH (NOLOCK)        
   ON orio.OrderKey = #Temp_FinalOrders.[OrderKey]        
   JOIN ORDERDETAIL AS oriod WITH (NOLOCK)        
   ON orio.OrderKey = oriod.Orderkey        
   JOIN ORDERS AS splo WITH (NOLOCK)   
   ON splo.OrderKey = oriod.ConsoOrderKey  
   WHERE orio.OrderGroup = #Temp_FinalOrders.[OrderGroup]         
   AND oriod.ConsoOrderKey <> '' AND splo.UserDefine04 = ''        
             
   OPEN CUR_READ_UD04_SplitOrders                        
   FETCH NEXT FROM CUR_READ_UD04_SplitOrders INTO @c_OriginalOrderKey, @c_SplitOrderKey                    
                
   WHILE (@@FETCH_STATUS <> -1)           
   BEGIN          
     
   SET @c_SplitTrackingNo=''  
  
   SELECT TOP 1 @c_SplitTrackingNo= TrackingNo FROM CartonTrack WITH (NOLOCK) WHERE LabelNo=@c_OriginalOrderKey  
  
   IF (@b_debug = 1)          
   BEGIN          
    SELECT @c_OriginalOrderKey 'OriginalOrderKey', @c_SplitTrackingNo 'Split TrackNo' , @c_SplitOrderKey 'Split ConsoOrderKey'        
   END          
     
   IF (ISNULL(@c_SplitTrackingNo,'')<>'')                      
   BEGIN                                    
        
      BEGIN TRAN        
       SET @n_err = 0  
  
       UPDATE [dbo].[CartonTrack] WITH (ROWLOCK)      
       SET [CarrierRef2] = 'SPLIT'  
       WHERE TrackingNo=@c_SplitTrackingNo   --trigger not allow update cartontrack when Ref02 = GET  
      
    IF @@ROWCOUNT = 0 OR @@ERROR <> 0   
    BEGIN   
       SET @n_err = 1  
    END   
  
    UPDATE [dbo].[CartonTrack] WITH (ROWLOCK)      
    SET [LabelNo] = @c_SplitOrderKey  
       ,[UDF01] = @c_OriginalOrderKey  
    ,[CarrierRef2] = 'GET'  
    WHERE TrackingNo=@c_SplitTrackingNo  
  
    IF @@ROWCOUNT = 0 OR @@ERROR <> 0   
    BEGIN   
       SET @n_err = 2  
    END  
  
       UPDATE [dbo].[ORDERS] WITH (ROWLOCK)                     
          SET TrackingNo = @c_SplitTrackingNo                      
             ,UserDefine04 = @c_SplitTrackingNo        
             ,[Issued] = 'Y'        
             ,TrafficCop = NULL                        
             ,EditDate = GETDATE()                        
             ,EditWho = SUSER_SNAME()                                         
         WHERE Orderkey =  @c_SplitOrderKey        
         AND Storerkey = @c_StorerKey      
     
   IF @@ROWCOUNT = 0 OR @@ERROR <> 0   
    BEGIN   
       SET @n_err = 3  
    END  
  
   IF NOT EXISTS(SELECT 1 FROM CartonTrack WITH (NOLOCK) WHERE LabelNo=@c_OriginalOrderKey)  
   BEGIN  
            UPDATE [dbo].[ORDERS] WITH (ROWLOCK)                     
            SET [Issued] = 'Y'  
               ,[SOStatus] = 'HOLD'  
               ,TrafficCop = NULL                        
               ,EditDate = GETDATE()                        
               ,EditWho = SUSER_SNAME()                                         
              WHERE Orderkey =  @c_OriginalOrderKey        
              AND Storerkey = @c_StorerKey     
       
     IF @@ROWCOUNT = 0 OR @@ERROR <> 0   
        BEGIN   
           SET @n_err = 4  
        END  
         END  
        --ROLLBACK TRAN      
     
        IF @n_err <> 0                        
        BEGIN                           
            ROLLBACK TRAN                              
            SET @c_errmsg = N'FAIL SPLTTING, Unable to update original orders UDF04 to split orders UDF04.'        
            GOTO QUIT        
        END                    
        COMMIT TRAN         
  
   END     
                         
   FETCH NEXT FROM CUR_READ_UD04_SplitOrders INTO @c_OriginalOrderKey, @c_SplitOrderKey          
   END  --WHILE (@@FETCH_STATUS <> -1)          
   CLOSE CUR_READ_UD04_SplitOrders                        
   DEALLOCATE CUR_READ_UD04_SplitOrders             
  END              
  
 QUIT:       
 IF (@b_debug = 1)          
 BEGIN          
     PRINT @n_err  
     PRINT @c_errmsg      
 END          
 IF CURSOR_STATUS('LOCAL' , 'CUR_READ_UD04_SplitOrders') IN (0 , 1)         
 BEGIN                      
    CLOSE CUR_READ_UD04_SplitOrders           
    DEALLOCATE CUR_READ_UD04_SplitOrders             
 END          
        
END

GO