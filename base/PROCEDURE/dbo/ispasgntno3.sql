SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: ispAsgnTNo3                                        */    
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
/* 13-11-2013   Shong   1.0   Initial Version                           */    
/* 23-Oct-2017  TLTING  1.1   Update TrackingNo                         */
/* 29-Nov-2018	 NJOW01  1.2   WMS-7148 CN Xtep add condition searching  */
/*                            delivery place                            */  
/* 18-Sep-2019  TLTING01 1.3  Performance tune                          */
/************************************************************************/    
CREATE PROC [dbo].[ispAsgnTNo3]      
     @c_OrderKey    NVARCHAR(10)    
   , @c_TrackingNo  NVARCHAR(20)  
   , @b_Success     INT           OUTPUT      
   , @n_Err         INT           OUTPUT      
   , @c_ErrMsg      NVARCHAR(250) OUTPUT      
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
            @c_Udef04      NVARCHAR(80),   
            @n_RowRef      INT,   
            @c_StorerKey   NVARCHAR(15), -- (shong02)  
            @c_Udef02      NVARCHAR(20),  
            @c_Udef03      NVARCHAR(20), -- (SOS#332990)  
            @c_OrderType   NVARCHAR(10)  -- (SOS#345781)  
  
  
   DECLARE @c_KeyName      NVARCHAR(30)  
          ,@c_Facility     NVARCHAR(5)  
          ,@c_Shipperkey   NVARCHAR(15)  
          ,@c_CarrierName  NVARCHAR(30)  
  
   DECLARE @c_CLK_UDF02    NVARCHAR(30)  
         , @c_UpdateEComDstntCode CHAR(1)  
   DECLARE @c_CarrierRef1  NVARCHAR(40)  
   DECLARE @n_SuccessFlag       Int  
                            
   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0    
   SELECT @c_ErrMsg=''    

   SET @c_CLK_UDF02 = ''  
   SET @c_UpdateEComDstntCode = '0'  

   SELECT @c_StorerKey = o.StorerKey
   FROM ORDERS AS o WITH(NOLOCK)
   WHERE o.OrderKey = @c_OrderKey
                       
   EXEC nspGetRight  
      @c_Facility  = '',  
      @c_StorerKey = @c_StorerKey,  
      @c_sku       = '',  
      @c_ConfigKey = 'UpdateEComDstntCode',  
      @b_Success   = @b_Success OUTPUT,  
      @c_authority = @c_UpdateEComDstntCode OUTPUT,  
      @n_err       = @n_err OUTPUT,   
      @c_errmsg    = @c_ErrMsg OUTPUT  
                    
   IF @c_UpdateEComDstntCode = '1' 
   BEGIN  
      SET @c_CLK_UDF02 = ''  
                       
      SELECT TOP 1 
             @c_CLK_UDF02 = ISNULL(c.UDF02,'')   
      FROM ORDERS o WITH (NOLOCK)  
      JOIN CODELKUP c WITH (NOLOCK) ON c.LISTNAME = N'CourRule' 
            AND c.[Description] = o.C_City 
            AND c.Long = o.M_City 
      WHERE o.OrderKey = @c_OrderKey                     
   END  
   ELSE IF @c_UpdateEComDstntCode = '2' -- Shong01 
   BEGIN
      SET @c_CLK_UDF02 = ''  
                       
      -- Shong02 
      IF ISNULL(RTRIM(@c_CLK_UDF02),'') = ''
      BEGIN
         SELECT TOP 1 
            @c_CLK_UDF02 = ISNULL(c.UDF03,'')   
         FROM ORDERS o WITH (NOLOCK)  
         JOIN CODELKUP c WITH (NOLOCK) ON c.LISTNAME = N'HMCS' 
            AND c.Notes = o.C_City 
            AND c.Notes2 = o.C_Address1 
         WHERE o.OrderKey = @c_OrderKey 
      END                    
   END   
   ELSE IF @c_UpdateEComDstntCode = '3' --NJOW01
   BEGIN
      SET @c_CLK_UDF02 = ''  
        
      SELECT @c_CLK_UDF02 = ISNULL(c.UDF03,'')   
      FROM ORDERS o WITH (NOLOCK)  
      JOIN CODELKUP c WITH (NOLOCK) ON c.LISTNAME = 'DELPLACE' 
         AND c.Notes = o.C_City 
         AND c.Notes2 = o.C_Address1 
         AND c.Storerkey = o.Storerkey
         AND c.Short = o.Shipperkey
      WHERE o.OrderKey = @c_OrderKey  
      
      IF ISNULL(@c_CLK_UDF02,'') = ''
      BEGIN
         SELECT @c_CLK_UDF02 = MAX(ISNULL(c.UDF03,''))
         FROM ORDERS o WITH (NOLOCK)  
         JOIN CODELKUP c WITH (NOLOCK) ON c.LISTNAME = 'DELPLACE' 
            AND c.Notes = o.C_City 
            AND c.Storerkey = o.Storerkey
            AND c.Short = o.Shipperkey
         WHERE o.OrderKey = @c_OrderKey
         
         HAVING COUNT(DISTINCT c.UDF03) = 1  
      END                  	 
   END
                       
   UPDATE ORDERS WITH (ROWLOCK)    
      SET Userdefine04 = CASE WHEN (UserDefine04 IS NULL OR UserDefine04 = '')   
                                 THEN @c_TrackingNo  
                              ELSE UserDefine04  
                           END,  
          TrackingNo  = CASE WHEN (TrackingNo IS NULL OR TrackingNo = '')     
                                 THEN @c_TrackingNo  
                              ELSE TrackingNo  
                         END,                             
            UserDefine10 = CASE   
                           WHEN ISNULL(RTRIM(@c_CLK_UDF02), '') <> '' AND @c_UpdateEComDstntCode = '1'   
                              THEN @c_CLK_UDF02  
                           ELSE UserDefine10  
                           END,  
            DeliveryPlace = CASE   
                           WHEN ISNULL(RTRIM(@c_CLK_UDF02), '') <> '' AND @c_UpdateEComDstntCode IN('2','3')  --NJOW01   
                              THEN @c_CLK_UDF02  
                           ELSE DeliveryPlace  
                           END,   
            TrafficCop = NULL,   
            EditDate = GETDATE(),   
            EditWho = SUSER_NAME()      
   WHERE ORDERKEY = @c_OrderKey   
   AND  Userdefine04 = ''  -- TLTING01 (Userdefine04 = '' OR Userdefine04 IS NULL)
   IF @@ROWCOUNT = 0
   BEGIN
   	SET @b_Success = 0
   	SET @c_ErrMsg = 'Order ' + @c_OrderKey + ' Already Have Tracking No'
   	RETURN
   END
       
     
   /********************************************************/      
   /* Interface Trigger Points Calling Process - (Start)   */      
   /********************************************************/      
   IF EXISTS(SELECT 1  
               FROM  ITFTriggerConfig ITC WITH (NOLOCK)   
               WHERE ITC.StorerKey = @c_StorerKey      
               AND ITC.SourceTable = N'AsgnTNo'      
               AND ITC.sValue      = '1'  
               AND ITC.ConfigKey   = N'WSCRSOCFM2'  
               AND itc.TargetTable = N'TRANSMITLOG3' )           
   BEGIN        
      EXEC dbo.ispGenTransmitLog3 'WSCRSOCFM2', @c_OrderKey, '', @c_StorerKey, ''      
                        , @b_success OUTPUT      
                        , @n_err OUTPUT      
                        , @c_errmsg OUTPUT      
                    
   END                                  
     
EXIT_SP:          
   IF @n_Continue=3  -- Error Occured - Process And Return      
   BEGIN      
      SELECT @b_Success = 0      
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispAsgnTNo3'      
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012      
      RETURN      
   END      
   ELSE      
   BEGIN      
      SELECT @b_Success = 1      
      WHILE @@TRANCOUNT > @n_StartTCnt      
      BEGIN      
         COMMIT TRAN      
      END      
      RETURN      
   END      
      
END -- Procedure

GO