SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/      
/* Stored Procedure: ispAsgnRtnTNo                                      */      
/* Creation Date: 13-Nov-2013                                           */      
/* Copyright: IDS                                                       */      
/* Written by: Shong                                                    */      
/*                                                                      */      
/* Purpose:                                                             */      
/*                                                                      */      
/* Called By: StorerConfig.ConfigKey = PostAllocationSP                 */      
/*                                                                      */      
/* PVCS Version: 1.0                                                    */      
/*                                                                      */      
/* Version: 1.0                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author  Rev   Purposes                                  */      
/************************************************************************/      
CREATE PROC [dbo].[ispAsgnRtnTNo]  
     @b_Success     INT           = 0  OUTPUT  
   , @n_Err         INT           = 0  OUTPUT  
   , @c_ErrMsg      NVARCHAR(250) = '' OUTPUT      
   , @b_debug       INT = 0      
     
     
AS        
BEGIN        
   SET NOCOUNT ON       
   SET QUOTED_IDENTIFIER OFF       
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF     
        
   DECLARE  @n_Continue    INT,        
            @n_StartTCnt   INT, -- Holds the current transaction count    
            @n_Retry       INT,          
            @c_RtnTrackingNo  NVARCHAR(20),    --(Wan01)   
            @n_RowRef      INT,  
            @c_OrderKey    NVARCHAR (10),     -- (kelvinongcy01)   
            @n_Cnt         INT = 0            -- (kelvinongcy02)   
  
   DECLARE @c_KeyName      NVARCHAR(30)    
          ,@c_Facility     NVARCHAR(5)    
          ,@c_Shipperkey   NVARCHAR(15)    
          ,@c_CarrierName  NVARCHAR(30)    
          ,@c_labelNo      NVARCHAR(20)  --(Wan02)  
          ,@c_StorerKey    NVARCHAR(20)  -- (kelvinongcy02)  
    
   DECLARE @c_CLK_UDF02           NVARCHAR(30)    
         , @c_UpdateEComDstntCode CHAR(1)    
   DECLARE @c_CarrierRef1  NVARCHAR(40)    
   DECLARE @n_SuccessFlag       Int    
                              
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
    
   DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT ISNULL(RTRIM(LTRIM(OrderKey)),'')  
           , ISNULL(RTRIM(LTRIM(RtnTrackingNo)),'')  
           , ISNULL(RTRIM(LTRIM(ShipperKey)),'')  
           , ISNULL(RTRIM(LTRIM(Facility)),'')  
           , ISNULL(RTRIM(LTRIM(StorerKey)),'')    -- (kelvinongcy02)  
      FROM ORDERS WITH (NOLOCK)    
      WHERE ISNULL(ShipperKey,'') <> ''  
      AND   sostatus <> 'PENDGET'      -- tlting01  
      AND   status BETWEEN '0' AND '6'   --(kelvinongcy01)  
      AND   TrackingNo <> ''                --(kelvinongcy01)  
      AND   RtnTrackingNo  = ''             --(kelvinongcy01)   
  
   OPEN CUR_ORDERKEY        
   FETCH NEXT FROM CUR_ORDERKEY INTO @c_OrderKey, @c_RtnTrackingNo, @c_ShipperKey, @c_Facility, @c_StorerKey    -- (kelvinongcy02)  
   WHILE @@FETCH_STATUS <> -1            
   BEGIN  
      IF ISNULL(RTRIM(@c_RtnTrackingNo),'') = ''  
      BEGIN    
         SET @n_Retry = 0              
         Get_NextTrackingNo:    
           
         -- Initail  
         SET @c_RtnTrackingNo = ''    
         SET @n_RowRef        = 0    
         SET @c_labelNo       = ''  
         SET @c_KeyName       = ''    
         SET @c_CarrierName   = ''   
                             
         SELECT TOP 1     
               @c_KeyName     = ISNULL(RTRIM(LTRIM(Long)),'') ,              -- (Wan01)    
               @c_CarrierName = ISNULL(RTRIM(LTRIM(Short)),'')  
         FROM CODELKUP WITH (NOLOCK)    
         WHERE Storerkey = @c_StorerKey     
         AND   Short     = @c_Shipperkey    
         AND   Notes     = @c_Facility     
         AND   LISTNAME  = 'AsgnRTNTNo'   
  
         --Debug  
         IF @b_debug = 1  
         BEGIN  
            SELECT  @c_KeyName      '@c_KeyName'   
                  , @c_CarrierName  '@c_CarrierName'   
                  , @c_StorerKey    '@c_StorerKey'  
                  , @c_Shipperkey   '@c_Shipperkey'  
                  , @c_Facility     '@c_Facility'  
                  , @c_OrderKey     '@c_OrderKey'  
         END  
  
         IF @c_KeyName <> '' AND @c_CarrierName <> ''  
         BEGIN  
            SET @c_RtnTrackingNo = ''   
            SET @c_CarrierRef1  = ''                
            SET @n_RowRef = 0    
            SET @n_SuccessFlag = 0    
     
            SELECT TOP 1   
                  @c_RtnTrackingNo = CT.TrackingNo,  
                  @n_RowRef        = CT.RowRef,  
                  @c_CarrierRef1   = CT.CarrierRef1   
            FROM CARTONTRACK_Pool CT WITH (NOLOCK)      
            WHERE CT.KeyName     = @c_KeyName    
            AND   CT.CarrierName = @c_CarrierName     
            ORDER BY CT.RowRef              
                 
            IF  @@ROWCOUNT = 0  
            BEGIN  
               IF @b_debug = 1  
               BEGIN  
                  SELECT  @c_RtnTrackingNo '@c_RtnTrackingNo'   
                        , @n_RowRef        '@n_RowRef'   
                        , @c_CarrierRef1   '@c_CarrierRef1'  
               END  
  
               INSERT INTO TraceInfo (TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5)  
               VALUES( 'ispAsgnRtnTNo', GETDATE(), @c_KeyName, @c_CarrierName, @c_StorerKey, @c_Facility, @c_Shipperkey)                    
               GOTO EXIT_SP      
            END      
    
            IF ISNULL(RTRIM(LTRIM(@c_RtnTrackingNo)), '') <> ''    
            BEGIN  
               SET @n_SuccessFlag = 0        
                             
               DELETE FROM dbo.CartonTrack_Pool WITH (ROWLOCK)  
               WHERE RowRef = @n_RowRef   
                 
               SET @n_SuccessFlag = @@ROWCOUNT  
            END    
                           
            IF @n_SuccessFlag > 0    
            BEGIN   
               SET @n_SuccessFlag = 0  
               INSERT INTO dbo.CARTONTRACK (TrackingNo, CarrierName, KeyName, LabelNo, CarrierRef1, CarrierRef2, udf01)   --(kelvinongcy02)  
               VALUES ( @c_RtnTrackingNo, @c_CarrierName, @c_KeyName , @c_OrderKey, @c_CarrierRef1, 'GET', 'RTN' )         
                                     
               SET @n_SuccessFlag = @@ROWCOUNT          
            END      
                         
            IF @n_SuccessFlag = 0     
            BEGIN    
               SET @n_Retry = ISNULL(@n_Retry, 0) + 1    
                       
               IF @n_Retry > 3     
                  GOTO EXIT_SP    
               ELSE    
                  GOTO Get_NextTrackingNo    
            END    
            ELSE    
            BEGIN          
               UPDATE ORDERS WITH (ROWLOCK)      
               SET RtnTrackingNo = @c_RtnTrackingNo,   
                   TrafficCop    = NULL,     
                   EditDate      = GETDATE(),     
                   EditWho       = SUSER_NAME()        
               WHERE OrderKey = @c_OrderKey                         
            END             
         END -- IF @c_KeyName <> '' AND @c_CarrierName <> ''   
   
      END --ISNULL(RTRIM(@c_RtnTrackingNo),'') = ''               
      FETCH NEXT FROM CUR_ORDERKEY INTO @c_OrderKey, @c_RtnTrackingNo, @c_ShipperKey, @c_Facility, @c_StorerKey  
   END -- WHILE @@FETCH_STATUS <> -1        
       
   CLOSE CUR_ORDERKEY            
   DEALLOCATE CUR_ORDERKEY      
       
EXIT_SP:    
        
   IF @n_Continue=3  -- Error Occured - Process And Return        
   BEGIN        
      SET @b_Success = 0        
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt        
      BEGIN        
         ROLLBACK TRAN        
      END        
      ELSE        
      BEGIN        
         WHILE @@TRANCOUNT > @n_StartTCnt        
         BEGIN        
            COMMIT TRAN        
         END        
      END        
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispAsgnRtnTNo'        
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012        
      RETURN        
   END        
   ELSE        
   BEGIN        
      SET @b_Success = 1        
      WHILE @@TRANCOUNT > @n_StartTCnt        
      BEGIN        
         COMMIT TRAN        
      END        
      RETURN        
   END        
        
END -- Procedure   

GO