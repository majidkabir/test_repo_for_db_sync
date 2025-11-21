SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: ispPOA22                                           */    
/* Creation Date: 10-FEB-2022                                           */    
/* Copyright: LFL                                                       */    
/* Written by: CSCHONG                                                  */    
/*                                                                      */    
/* Purpose: WMS-18732 - SG - LOGITECH Ã» Allocation [CR]                 */  
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
/* 10-FEB-2022  CSCHONG 1.0   Devops Scripts Combine                    */
/* 31-MAY-2023  NJOW01  1.1   WMS-22704 modify @c_CountryOTH value      */
/************************************************************************/    
CREATE   PROC [dbo].[ispPOA22]      
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


DECLARE   @c_Country                 NVARCHAR(45)
         ,@c_susr5                   NVARCHAR(18)
         ,@c_lottable11              NVARCHAR(30)
         ,@c_SH                      NVARCHAR(10) = ''
         ,@c_sku                     NVARCHAR(20)
         ,@c_lot                     NVARCHAR(10)
         ,@n_CntLott11               INT = 0
         ,@c_UpdateSH                NVARCHAR(1) = 'N'
         ,@c_CountryCN               NVARCHAR(5)
         ,@c_CountryVN               NVARCHAR(5)
         ,@c_CountryMY               NVARCHAR(5)
         ,@c_susr5NOFORM             NVARCHAR(5)
         ,@c_CountryOTH              NVARCHAR(5)
                                  
   SELECT @n_StartTCnt = @@TRANCOUNT , @n_Continue = 1, @b_Success = 1, @n_Err = 0, @c_ErrMsg = ''    
   
   CREATE TABLE #TMP_ORDSH (  
      Orderkey      NVARCHAR(10)  NULL,
      C_Country     NVARCHAR(18)  NULL,
      Storerkey     NVARCHAR(15)  NULL,
      Loadkey       NVARCHAR(10)  NULL
   )
   
   IF @n_continue IN(1,2)   
   BEGIN  
      IF ISNULL(RTRIM(@c_OrderKey), '') <> ''  
      BEGIN  
         INSERT INTO #TMP_ORDSH (Orderkey, C_Country, Storerkey, Loadkey)  
         SELECT DISTINCT O.Orderkey, O.C_Country, O.StorerKey, O.LoadKey
         FROM ORDERS O (NOLOCK)
         WHERE O.Orderkey = @c_OrderKey
      END
      ELSE IF ISNULL(RTRIM(@c_Loadkey), '') <> ''  
      BEGIN
         INSERT INTO #TMP_ORDSH (Orderkey, C_Country, Storerkey, Loadkey)  
         SELECT DISTINCT O.Orderkey, O.C_Country, O.StorerKey, O.LoadKey
         FROM LoadPlanDetail LPD (NOLOCK)  
         JOIN ORDERS O (NOLOCK) ON LPD.OrderKey = O.OrderKey 
         WHERE LPD.LoadKey = @c_Loadkey
      END 
      ELSE IF ISNULL(RTRIM(@c_Wavekey), '') <> ''  
      BEGIN
         INSERT INTO #TMP_ORDSH (Orderkey, C_Country, Storerkey, Loadkey)  
         SELECT DISTINCT O.Orderkey, O.C_Country, O.StorerKey, O.LoadKey
         FROM WaveDetail WD (NOLOCK)  
         JOIN ORDERS O (NOLOCK) ON WD.OrderKey = O.OrderKey
         WHERE WD.Wavekey = @c_Wavekey
      END 
      ELSE 
      BEGIN      
         SELECT @n_Continue = 3      
         SELECT @n_Err = 67060      
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Loadkey, Wave and Orderkey are Blank (ispPOA22)'  
         GOTO EXIT_SP      
      END    
   END  
   
   IF @@TRANCOUNT = 0
      BEGIN TRAN

   IF @n_continue IN(1,2)   
   BEGIN   
      DECLARE cur_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT t.Orderkey    
              , t.C_Country
              , t.Storerkey   
              , t.Loadkey     
         FROM #TMP_ORDSH t
          WHERE t.C_Country IN ('ID', 'TH', 'VN','MY')
        
      OPEN cur_ORD    
            
      FETCH NEXT FROM cur_ORD INTO @c_GetOrderkey     
                                 , @c_Country         
                                 , @c_GetStorerkey    
                                 , @c_GetLoadkey      

        
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  
      BEGIN

           SET @c_UpdateSH = 'N'
           SET @c_SH = ''

           SET @c_CountryCN = 'N'
           SET @c_CountryMY = 'N'
           SET @c_CountryVN = 'N'
           SET @c_CountryOTH = 'N'
           SET @c_susr5NOFORM = 'N'     


        DECLARE cur_ORDPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT PD.sku,s.SUSR5,LOTT.Lottable11
         FROM PICKDETAIL PD WITH (NOLOCK) 
         JOIN SKU S WITH (NOLOCK) ON S.StorerKey = PD.Storerkey AND S.Sku = PD.Sku
         JOIN dbo.LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.lot = PD.lot AND LOTT.sku = PD.Sku AND LOTT.StorerKey = PD.Storerkey
         WHERE PD.OrderKey = @c_getorderkey  

         OPEN cur_ORDPD    
            
         FETCH NEXT FROM cur_ORDPD INTO  @c_sku     
                                      -- , @c_lot
                                       , @c_susr5   
                                       , @c_lottable11      
         WHILE @@FETCH_STATUS = 0 --AND @n_continue IN(1,2)  
         BEGIN

              IF @c_susr5 LIKE 'FORM%' AND  CHARINDEX(@c_Country,@c_susr5) > 0 
              BEGIN
              	  SET @c_CountryOTH = 'N'  --NJOW01
                  -- SELECT @c_Country '@c_Country', @c_susr5 'susr5', @c_lottable11 'lot11'
                  IF @c_lottable11 = 'VN'
                  BEGIN
                       IF @c_CountryVN = 'N'
                       BEGIN
                          SET @c_CountryVN = 'Y'
                       END
                  END
                  ELSE IF @c_lottable11 = 'MY'
                  BEGIN
                       IF @c_CountryMY = 'N'
                       BEGIN
                          SET @c_CountryMY = 'Y'
                       END
                  END
                  ELSE IF @c_lottable11 = 'CN'
                  BEGIN
                       IF @c_CountryCN = 'N'
                       BEGIN
                          SET @c_CountryCN = 'Y'
                       END
                  END  
                  -- SET @c_getmsg = 'found'
 
             END
             ELSE
             BEGIN
                SET @c_CountryOTH = 'Y'
             END
      
                --Update special handling to 'D' 
                IF @c_CountryCN = 'N' AND (@c_CountryVN = 'Y' OR @c_CountryMY = 'Y') AND @c_CountryOTH = 'N'
                BEGIN
                       SET @c_UpdateSH = 'Y'
                       SET @c_sh = 'D'
                END
                --Update special handling to 'E' 
                ELSE IF @c_CountryCN = 'Y' AND @c_CountryVN = 'N' AND @c_CountryMY = 'N' AND @c_CountryOTH = 'N'
                BEGIN
                       SET @c_UpdateSH = 'Y'
                       SET @c_sh = 'E'
                END
                --Update special handling to 'F' 
                ELSE IF @c_CountryCN = 'Y' AND (@c_CountryVN = 'Y' OR @c_CountryMY = 'Y') AND @c_CountryOTH = 'N'
                BEGIN
                       SET @c_UpdateSH = 'Y'
                       SET @c_sh = 'F'
                END
              --Update special handling to 'N' 
               ELSE IF @c_CountryCN = 'N' AND (@c_CountryVN = 'N' AND @c_CountryMY = 'N') AND @c_CountryOTH = 'Y'
                BEGIN
                       SET @c_UpdateSH = 'Y'
                       SET @c_sh = 'N'
                END

             --SELECT @c_CountryCN  '@c_CountryVN' , @c_CountryVN '@c_CountryVN',@c_CountryMY '@c_CountryMY', @c_CountryOTH '@c_CountryOTH', @c_sh '@c_sh', @c_UpdateSH '@c_UpdateSH'

         FETCH NEXT FROM cur_ORDPD INTO   @c_sku     
                                       -- , @c_lot
                                       , @c_susr5 
                                       , @c_lottable11 
         END  
         CLOSE cur_ORDPD
         DEALLOCATE cur_ORDPD  

         IF @c_UpdateSH = 'Y'
         BEGIN
            --Update the special Handling
            UPDATE ORDERS WITH (ROWLOCK)
            SET SpecialHandling = @c_SH
              , TrafficCop   = NULL
              , EditDate     = GETDATE()
              , EditWho      = SUSER_SNAME()
            WHERE OrderKey   = @c_GetOrderkey

            SELECT @n_err = @@ERROR
            
            IF @n_err <> 0                                                                                                                                                               
            BEGIN                                                                                                                                                                                  
               SELECT @n_Continue = 3                                                                                                                                                              
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                            
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update ORDERS Failed. (ispPOA22)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
            END
         END
         
         FETCH NEXT FROM cur_ORD INTO @c_GetOrderkey     
                                 , @c_Country         
                                 , @c_GetStorerkey    
                                 , @c_GetLoadkey   
      END  
      CLOSE cur_ORD
      DEALLOCATE cur_ORD    
   END  

EXIT_SP:  
   IF OBJECT_ID('tempdb..#TMP_ORDSH') IS NOT NULL
      DROP TABLE #TMP_ORDSH
      
   IF CURSOR_STATUS('LOCAL', 'cur_ORD') IN (0 , 1)
   BEGIN
      CLOSE cur_ORD
      DEALLOCATE cur_ORD   
   END 

  IF CURSOR_STATUS('LOCAL', 'cur_ORDPD') IN (0 , 1)
   BEGIN
      CLOSE cur_ORDPD
      DEALLOCATE cur_ORDPD   
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPOA22'      
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