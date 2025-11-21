SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: ispPOA18                                           */    
/* Creation Date: 17-Mar-2021                                           */    
/* Copyright: LFL                                                       */    
/* Written by: WLChooi                                                  */    
/*                                                                      */    
/* Purpose: WMS-16567 - ANFQHW - Generate TrackingNo for DHL Order      */  
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
/* 2021-07-19   WLChooi 1.1   Bug Fix - Insert CartonShipmentDetail     */
/*                            record (WL01)                             */
/************************************************************************/    
CREATE PROC [dbo].[ispPOA18]      
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
            @c_GetShipperkey         NVARCHAR(15),
            @c_GetCCountry           NVARCHAR(100),  
            @c_GetStorerkey          NVARCHAR(15),
            @c_AgentNo               NVARCHAR(50),
            @c_CountryNo             NVARCHAR(50),
            @c_Label_PreFix          NVARCHAR(10) = '',
            @c_PrefixListName        NVARCHAR(10) = 'ANFTNoPfix',
            @c_Label_SeqNo           NVARCHAR(20) = '',
            @c_TrackNo               NVARCHAR(40),
            @c_GetLoadkey            NVARCHAR(10),
            @c_GetTrackingNo         NVARCHAR(50) = ''
                                                                            
   SELECT @n_StartTCnt = @@TRANCOUNT , @n_Continue = 1, @b_Success = 1, @n_Err = 0, @c_ErrMsg = ''    
   
   CREATE TABLE #TMP_ORD (  
      Orderkey      NVARCHAR(10)  NULL,
      Shipperkey    NVARCHAR(15)  NULL,
      C_Country     NVARCHAR(100) NULL,
      TrackingNo    NVARCHAR(40)  NULL,
      Storerkey     NVARCHAR(15)  NULL,
      Loadkey       NVARCHAR(10)  NULL
   )
   
   IF @n_continue IN(1,2)   
   BEGIN  
      IF ISNULL(RTRIM(@c_OrderKey), '') <> ''  
      BEGIN  
         INSERT INTO #TMP_ORD (Orderkey, Shipperkey, C_Country, TrackingNo, Storerkey, Loadkey)  
         SELECT DISTINCT O.Orderkey, O.ShipperKey, O.C_Country, O.Userdefine04, O.StorerKey, O.LoadKey
         FROM ORDERS O (NOLOCK)
         WHERE O.Orderkey = @c_OrderKey
      END
      ELSE IF ISNULL(RTRIM(@c_Loadkey), '') <> ''  
      BEGIN
         INSERT INTO #TMP_ORD (Orderkey, Shipperkey, C_Country, TrackingNo, Storerkey, Loadkey)  
         SELECT DISTINCT O.Orderkey, O.ShipperKey, O.C_Country, O.Userdefine04, O.StorerKey, O.LoadKey
         FROM LoadPlanDetail LPD (NOLOCK)  
         JOIN ORDERS O (NOLOCK) ON LPD.OrderKey = O.OrderKey 
         WHERE LPD.LoadKey = @c_Loadkey
      END 
      ELSE IF ISNULL(RTRIM(@c_Wavekey), '') <> ''  
      BEGIN
         INSERT INTO #TMP_ORD (Orderkey, Shipperkey, C_Country, TrackingNo, Storerkey, LoadKey)  
         SELECT DISTINCT O.Orderkey, O.ShipperKey, O.C_Country, O.Userdefine04, O.StorerKey, O.LoadKey
         FROM WaveDetail WD (NOLOCK)  
         JOIN ORDERS O (NOLOCK) ON WD.OrderKey = O.OrderKey
         WHERE WD.Wavekey = @c_Wavekey
      END 
      ELSE 
      BEGIN      
         SELECT @n_Continue = 3      
         SELECT @n_Err = 67000      
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Loadkey, Wave and Orderkey are Blank (ispPOA18)'  
         GOTO EXIT_SP      
      END    
   END  
   
   IF @@TRANCOUNT = 0
      BEGIN TRAN

   --If new record - TrackingNo = ''
   IF @n_continue IN(1,2)   
   BEGIN   
      DECLARE cur_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT t.Orderkey
              , t.Shipperkey
              , t.C_Country
              , t.Storerkey
              , t.Loadkey
              , ISNULL(t.TrackingNo,'') 
         FROM #TMP_ORD t
         --WHERE ISNULL(t.TrackingNo,'') = ''
        
      OPEN cur_ORD    
            
      FETCH NEXT FROM cur_ORD INTO @c_GetOrderkey  
                                 , @c_GetShipperkey
                                 , @c_GetCCountry  
                                 , @c_GetStorerkey
                                 , @c_GetLoadkey
                                 , @c_GetTrackingNo
        
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  
      BEGIN      
         SELECT @c_Label_PreFix = ISNULL(Short,'')
         FROM CODELKUP WITH (NOLOCK)
         WHERE LISTNAME = @c_PrefixListName
         AND Code = @c_GetShipperkey
         AND Storerkey = @c_GetStorerkey

         IF @c_GetShipperkey = 'DHL' AND ISNULL(@c_GetTrackingNo,'') = ''
         BEGIN
         	IF ISNULL(@c_Label_PreFix,'') = ''
         	BEGIN
               SET @c_Label_PreFix = 'HKANF'   
            END
      
            EXECUTE dbo.nspg_GetKey
               'DHLTrackNo',
               15,
               @c_Label_SeqNo OUTPUT,
               @b_Success     OUTPUT,
               @n_err         OUTPUT,
               @c_errmsg      OUTPUT
      
            IF @n_err <> 0                                                                                                                                                               
            BEGIN                                                                                                                                                                                  
               SELECT @n_Continue = 3                                                                                                                                                              
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                            
               SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': EXEC nspg_GetKey Failed. (ispPOA18)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) ' 
               GOTO EXIT_SP            
            END  

            SET @c_TrackNo = @c_Label_PreFix + @c_Label_SeqNo
            
            IF @b_debug = 1   
            BEGIN
               SELECT @c_Label_PreFix '@c_Label_PreFix', @c_Label_SeqNo '@c_Label_SeqNo' 
            END
            
            --Update TrackingNo into ORDERS.UserDefine04 & ORDERS.TrackingNo
            UPDATE ORDERS WITH (ROWLOCK)
            SET UserDefine04 = @c_TrackNo
              , TrackingNo   = @c_TrackNo
              , TrafficCop   = NULL 
              , EditDate     = GETDATE()
              , EditWho      = SUSER_SNAME()
            WHERE OrderKey = @c_GetOrderkey
            
            SELECT @n_err = @@ERROR
            
            IF @n_err <> 0                                                                                                                                                               
            BEGIN                                                                                                                                                                                  
               SELECT @n_Continue = 3                                                                                                                                                              
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                            
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update ORDERS Failed. (ispPOA18)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
            END  
            
            --Insert Carton Track, check before updating
            IF NOT EXISTS (SELECT 1
                           FROM CartonTrack CT (NOLOCK)
                           WHERE CT.CarrierName = 'DHL' AND CT.LabelNo = @c_GetOrderkey
                             AND CT.CarrierRef2 = 'GET')
            BEGIN
               INSERT INTO CartonTrack (CarrierName, LabelNo, CarrierRef2, TrackingNo)
               SELECT 'DHL', @c_GetOrderkey, 'GET', @c_TrackNo
               
               SELECT @n_err = @@ERROR
               
               IF @n_err <> 0                                                                                                                                                               
               BEGIN                                                                                                                                                                                  
                  SELECT @n_Continue = 3                                                                                                                                                              
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67015   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                            
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert CartonTrack Failed. (ispPOA18)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
               END 
            END

            --Insert CartonShipmentDetail, check before updating
            IF EXISTS (SELECT 1
                       FROM CartonShipmentDetail CSD (NOLOCK)
                       WHERE CSD.Storerkey = @c_GetStorerkey 
                       AND CSD.Orderkey = @c_GetOrderkey)
            BEGIN
               DELETE FROM CartonShipmentDetail
               WHERE Storerkey = @c_GetStorerkey 
               AND Orderkey = @c_GetOrderkey

               SELECT @n_err = @@ERROR
               
               IF @n_err <> 0                                                                                                                                                               
               BEGIN                                                                                                                                                                                  
                  SELECT @n_Continue = 3                                                                                                                                                              
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                            
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete CartonShipmentDetail Failed. (ispPOA18)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
               END
            END   --WL01

            INSERT INTO CartonShipmentDetail (Storerkey, Orderkey, Loadkey, TrackingNumber)
            SELECT @c_GetStorerkey, @c_GetOrderkey, @c_GetLoadkey, @c_TrackNo

            SELECT @n_err = @@ERROR
            
            IF @n_err <> 0                                                                                                                                                               
            BEGIN                                                                                                                                                                                  
               SELECT @n_Continue = 3                                                                                                                                                              
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67025   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                            
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert CartonShipmentDetail Failed. (ispPOA18)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
            END
            --END   --WL01
         END
         ELSE IF @c_GetShipperkey = 'DHL' AND ISNULL(@c_GetTrackingNo,'') <> ''
         BEGIN
            IF EXISTS (SELECT 1
                       FROM CartonShipmentDetail CSD (NOLOCK)
                       WHERE CSD.Storerkey = @c_GetStorerkey 
                       AND CSD.Orderkey = @c_GetOrderkey)
            BEGIN
               UPDATE CartonShipmentDetail WITH (ROWLOCK)
               SET Loadkey = @c_GetLoadkey
               WHERE Storerkey = @c_GetStorerkey AND Orderkey = @c_GetOrderkey

               SELECT @n_err = @@ERROR
               
               IF @n_err <> 0                                                                                                                                                               
               BEGIN                                                                                                                                                                                  
                  SELECT @n_Continue = 3                                                                                                                                                              
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                            
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE CartonShipmentDetail Failed. (ispPOA18)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
               END
            END
         END
  
         FETCH NEXT FROM cur_ORD INTO @c_GetOrderkey  
                                    , @c_GetShipperkey
                                    , @c_GetCCountry 
                                    , @c_GetStorerkey 
                                    , @c_GetLoadkey
                                    , @c_GetTrackingNo
      END      
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPOA18'      
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