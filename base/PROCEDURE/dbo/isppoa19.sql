SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: ispPOA19                                           */    
/* Creation Date: 29-Jun-2021                                           */    
/* Copyright: LFL                                                       */    
/* Written by: WLChooi                                                  */    
/*                                                                      */    
/* Purpose: WMS-17349 - TH-AROMA Auto Calculate Latest Delivery Date    */  
/*                                                                      */    
/* Called By: StorerConfig.ConfigKey = PostAllocationSP                 */    
/*                                                                      */    
/* GitLab Version: 1.0                                                  */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Rev   Purposes                                  */ 
/************************************************************************/    
CREATE PROC [dbo].[ispPOA19]      
     @c_OrderKey    NVARCHAR(10) = ''   
   , @c_LoadKey     NVARCHAR(10) = ''  
   , @c_Wavekey     NVARCHAR(10) = ''  
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
      
   DECLARE  @n_Continue              INT,      
            @n_StartTCnt             INT, -- Holds the current transaction count  
            @c_Pickdetailkey         NVARCHAR(10),  
            @c_GetOrderkey           NVARCHAR(10),
            @c_GetCZip               NVARCHAR(18),  
            @c_GetStorerkey          NVARCHAR(50),
            @c_GetLoadkey            NVARCHAR(10),
            @dt_GetAddDate           DATETIME,
            @dt_GetDeliveryDate      DATETIME,
            @n_LeadDay               INT = 0,
            @c_CLKShort              NVARCHAR(50) = '',
            @dt_FinalDeliveryDate    DATETIME,
            @n_ContinueProceed       INT = 0
                                  
   SELECT @n_StartTCnt = @@TRANCOUNT , @n_Continue = 1, @b_Success = 1, @n_Err = 0, @c_ErrMsg = ''    
   
   CREATE TABLE #TMP_ORD (  
      Orderkey      NVARCHAR(10)  NULL,
      C_Zip         NVARCHAR(18)  NULL,
      Storerkey     NVARCHAR(15)  NULL,
      Loadkey       NVARCHAR(10)  NULL,
      AddDate       DATETIME      NULL,
      DeliveryDate  DATETIME      NULL,
   )
   
   IF @n_continue IN(1,2)   
   BEGIN  
      IF ISNULL(RTRIM(@c_OrderKey), '') <> ''  
      BEGIN  
         INSERT INTO #TMP_ORD (Orderkey, AddDate, C_Zip, DeliveryDate, Storerkey, Loadkey)  
         SELECT DISTINCT O.Orderkey, O.AddDate, O.C_Zip, O.DeliveryDate, O.StorerKey, O.LoadKey
         FROM ORDERS O (NOLOCK)
         WHERE O.Orderkey = @c_OrderKey
      END
      ELSE IF ISNULL(RTRIM(@c_Loadkey), '') <> ''  
      BEGIN
         INSERT INTO #TMP_ORD (Orderkey, Shipperkey, C_Country, TrackingNo, Storerkey, Loadkey)  
         SELECT DISTINCT O.Orderkey, O.AddDate, O.C_Zip, O.DeliveryDate, O.StorerKey, O.LoadKey
         FROM LoadPlanDetail LPD (NOLOCK)  
         JOIN ORDERS O (NOLOCK) ON LPD.OrderKey = O.OrderKey 
         WHERE LPD.LoadKey = @c_Loadkey
      END 
      ELSE IF ISNULL(RTRIM(@c_Wavekey), '') <> ''  
      BEGIN
         INSERT INTO #TMP_ORD (Orderkey, Shipperkey, C_Country, TrackingNo, Storerkey, LoadKey)  
         SELECT DISTINCT O.Orderkey, O.AddDate, O.C_Zip, O.DeliveryDate, O.StorerKey, O.LoadKey
         FROM WaveDetail WD (NOLOCK)  
         JOIN ORDERS O (NOLOCK) ON WD.OrderKey = O.OrderKey
         WHERE WD.Wavekey = @c_Wavekey
      END 
      ELSE 
      BEGIN      
         SELECT @n_Continue = 3      
         SELECT @n_Err = 67000      
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Loadkey, Wave and Orderkey are Blank (ispPOA19)'  
         GOTO EXIT_SP      
      END    
   END  
   
   IF @@TRANCOUNT = 0
      BEGIN TRAN

   IF @n_continue IN(1,2)   
   BEGIN   
      DECLARE cur_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT t.Orderkey    
              , t.C_Zip
              , t.Storerkey   
              , t.Loadkey     
              , CAST(t.AddDate AS DATE)        --Ignore Time, only need date
              , CAST(t.DeliveryDate AS DATE)   --Ignore Time, only need date
         FROM #TMP_ORD t
        
      OPEN cur_ORD    
            
      FETCH NEXT FROM cur_ORD INTO @c_GetOrderkey     
                                 , @c_GetCZip         
                                 , @c_GetStorerkey    
                                 , @c_GetLoadkey      
                                 , @dt_GetAddDate     
                                 , @dt_GetDeliveryDate
        
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  
      BEGIN
         IF ISNULL(@c_GetCZip,'') = ''
         BEGIN
            SET @n_LeadDay = 1
         END
         ELSE IF ISNULL(@dt_GetDeliveryDate,'19000101') = ''
         BEGIN
            SET @n_LeadDay = 1
         END
         ELSE
         BEGIN
            SELECT @c_CLKShort = ISNULL(CLK.Short,'')
            FROM CODELKUP CLK (NOLOCK)
            WHERE CLK.LISTNAME = 'DELIVBRN'
            AND CLK.Storerkey = @c_GetStorerkey
            AND CLK.Code = @c_GetCZip

            IF ISNUMERIC(@c_CLKShort) = 1
            BEGIN
               SET @n_LeadDay = CAST(@c_CLKShort AS INT)
            END
            ELSE  --NULL/Blank/Not a numeric character
            BEGIN
               SET @n_LeadDay = 1
            END
         END

         IF ISNULL(@dt_GetDeliveryDate,'19000101') = ''
         BEGIN
            SET @dt_FinalDeliveryDate = @dt_GetAddDate
         END
         ELSE
         BEGIN
            SET @dt_FinalDeliveryDate = @dt_GetDeliveryDate
         END
         
         --Check next day if it is holiday
         WHILE @n_LeadDay > 0
         BEGIN
            SET @n_ContinueProceed = 1

            --PRINT CAST(DATEADD(DAY, 1, @dt_FinalDeliveryDate) AS NVARCHAR(10)) + ' ' + CAST(@n_LeadDay AS NVARCHAR(10))

            IF EXISTS (SELECT 1 FROM HolidayDetail HD (NOLOCK) 
                       WHERE HD.HolidayDate = DATEADD(DAY, 1, @dt_FinalDeliveryDate)
                       AND HD.UserDefine03 = 'AROMA')
            BEGIN
               SET @n_ContinueProceed = 0
               SET @dt_FinalDeliveryDate = DATEADD(DAY, 1, @dt_FinalDeliveryDate)
            END

            IF DATENAME(DW,  DATEADD(DAY, 1, @dt_FinalDeliveryDate)) = 'Sunday'
            BEGIN
               SET @n_ContinueProceed = 0
               SET @dt_FinalDeliveryDate = DATEADD(DAY, 1, @dt_FinalDeliveryDate)
            END

            IF @n_ContinueProceed = 1 
            BEGIN
               SET @n_LeadDay = @n_LeadDay - 1
               SET @dt_FinalDeliveryDate = DATEADD(DAY, 1, @dt_FinalDeliveryDate)
            END
         END

         --Check current day if it is on Sunday
         IF @n_Continue IN (1,2)
         BEGIN
            IF DATENAME(DW,  @dt_FinalDeliveryDate) = 'Sunday'
            BEGIN
               SET @dt_FinalDeliveryDate = DATEADD(DAY, 1, @dt_FinalDeliveryDate)
            END

            IF EXISTS (SELECT 1 FROM HolidayDetail HD (NOLOCK) 
                       WHERE HD.HolidayDate = @dt_FinalDeliveryDate
                       AND HD.UserDefine03 = 'AROMA')
            BEGIN
               SET @dt_FinalDeliveryDate = DATEADD(DAY, 1, @dt_FinalDeliveryDate)
            END
         END

         IF ISDATE(@dt_FinalDeliveryDate) = 1
         BEGIN
            --Update the Final Delivery Date back to Orders.UserDefine07
            UPDATE ORDERS WITH (ROWLOCK)
            SET UserDefine07 = @dt_FinalDeliveryDate
              , TrafficCop   = NULL
              , EditDate     = GETDATE()
              , EditWho      = SUSER_SNAME()
            WHERE OrderKey   = @c_GetOrderkey

            SELECT @n_err = @@ERROR
            
            IF @n_err <> 0                                                                                                                                                               
            BEGIN                                                                                                                                                                                  
               SELECT @n_Continue = 3                                                                                                                                                              
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                            
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update ORDERS Failed. (ispPOA19)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
            END
         END
         
         FETCH NEXT FROM cur_ORD INTO @c_GetOrderkey     
                                    , @c_GetCZip         
                                    , @c_GetStorerkey    
                                    , @c_GetLoadkey      
                                    , @dt_GetAddDate     
                                    , @dt_GetDeliveryDate
      END  
      CLOSE cur_ORD
      DEALLOCATE cur_ORD    
   END  

EXIT_SP:  
   IF OBJECT_ID('tempdb..#TMP_ORD') IS NOT NULL
      DROP TABLE #TMP_ORD
      
   IF CURSOR_STATUS('LOCAL', 'cur_ORD') IN (0 , 1)
   BEGIN
      CLOSE cur_ORD
      DEALLOCATE cur_ORD   
   END 
   
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPOA19'      
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