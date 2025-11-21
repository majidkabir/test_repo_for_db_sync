SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_BackendPTSReleaseToITFByLoad                      */
/* Creation Date: 13-Jul-2023                                              */
/* Copyright: MAERSK                                                       */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-23054 - [CN] ERNO LASZLO_PTS_Orderinfor_Trigger            */
/*                                                                         */
/* Called By: SQL Job                                                      */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 13-Jul-2023  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/  
CREATE   PROC [dbo].[isp_BackendPTSReleaseToITFByLoad]  
(     @c_Storerkey   NVARCHAR(15)  = ''  
  ,   @c_Facility    NVARCHAR(5)   = ''  
  ,   @b_Success     INT           = 1  OUTPUT
  ,   @n_Err         INT           = 0  OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) = '' OUTPUT
)  
AS 
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Debug              INT
         , @n_Continue           INT 
         , @n_StartTCnt          INT 

   DECLARE @c_Loadkey         NVARCHAR(10)
         , @c_TransmitLogKey  NVARCHAR(10)

   SET @b_Success   = 1 
   SET @n_Err       = 0  
   SET @c_ErrMsg    = ''
   SET @b_Debug     = '0' 
   SET @n_Continue  = 1  
   SET @n_StartTCnt = @@TRANCOUNT  
  
   IF (@n_continue = 1 OR @n_continue = 2) 
   BEGIN   
      DECLARE cur_PTS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LP.LoadKey
         FROM LOADPLAN LP (NOLOCK)
         JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.LoadKey = LP.LoadKey
         JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
         JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
         WHERE LP.Load_Userdef1 = 'PTS' AND OH.StorerKey = @c_Storerkey
         AND OH.Facility = CASE WHEN ISNULL(@c_Facility,'') = '' THEN OH.Facility ELSE @c_Facility END
         AND LP.Load_Userdef2 = 'Y'
         GROUP BY LP.LoadKey

      OPEN cur_PTS
      
      FETCH NEXT FROM cur_PTS INTO @c_Loadkey
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF EXISTS ( SELECT 1 
                     FROM LOADPLANDETAIL LPD (NOLOCK)
                     JOIN ORDERS OH (NOLOCK) ON LPD.OrderKey = OH.OrderKey
                     WHERE LPD.LoadKey = @c_Loadkey 
                     AND OH.[Status] NOT IN ('2') )
         BEGIN
            GOTO NEXT_LOAD
         END

         --Insert Transmitlog2
         SELECT @b_success = 1
        
         EXECUTE nspg_getkey      
               'TransmitLogKey2'      
               , 10      
               , @c_TransmitLogKey OUTPUT      
               , @b_success        OUTPUT      
               , @n_err            OUTPUT      
               , @c_errmsg         OUTPUT      
         
         IF NOT @b_success = 1      
         BEGIN      
            SET @n_continue = 3      
            SET @n_err = 71800  
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Unable to Obtain TransmitLogKey2. (isp_BackendPTSReleaseToITFByLoad)' + 
                            ' ( ' + ' SQLSvr MESSAGE=' + TRIM(@c_errmsg) + ' ) '      
            GOTO NEXT_LOAD  
         END 
         
         INSERT INTO TRANSMITLOG2 (transmitlogkey, tablename, key1, key2, key3, transmitflag)
         SELECT @c_TransmitLogKey, 'WSPTSLDLOG', @c_Loadkey, '', @c_Storerkey, '0'
         
         SELECT @n_err = @@ERROR  
         
         IF @n_err <> 0  
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 71805    
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))   
                             + ': Insert Failed On Table TRANSMITLOG2. (isp_BackendPTSReleaseToITFByLoad)'   
                             + ' ( SQLSvr MESSAGE=' + TRIM(@c_errmsg) + ' ) '  
            GOTO NEXT_LOAD
         END 

         UPDATE LOADPLAN WITH (ROWLOCK)
         SET Load_Userdef1 = 'PTS-SENT'
           , TrafficCop =  NULL
           , EditDate = GETDATE()
           , EditWho = SUSER_SNAME()
         WHERE LoadKey = @c_Loadkey

         SELECT @n_err = @@ERROR  
         
         IF @n_err <> 0  
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 71815    
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))   
                             + ': Update Failed On Wave. (isp_BackendPTSReleaseToITFByLoad)'   
                             + ' ( SQLSvr MESSAGE=' + TRIM(@c_errmsg) + ' ) '  
            GOTO NEXT_LOAD
         END 
                  	   
         NEXT_LOAD:
         FETCH NEXT FROM cur_PTS INTO @c_Loadkey
      END
      CLOSE cur_PTS
      DEALLOCATE cur_PTS
   END

QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'cur_PTS') IN (0 , 1)
   BEGIN
      CLOSE cur_PTS
      DEALLOCATE cur_PTS   
   END

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_BackendPTSReleaseToITFByLoad'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
        COMMIT TRAN
      END 
      RETURN
   END 
END

GO