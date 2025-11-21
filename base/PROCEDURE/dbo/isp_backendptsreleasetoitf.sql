SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_BackendPTSReleaseToITF                            */
/* Creation Date: 26-Jul-2021                                              */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-17559 - [CN] Coach_PTS_Orderinfor_Trigger                  */
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
/* 26-Jul-2021  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/  
CREATE PROC [dbo].[isp_BackendPTSReleaseToITF]  
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

   DECLARE @c_Wavekey         NVARCHAR(10)
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
         SELECT W.WaveKey
         FROM WAVE W (NOLOCK)
         JOIN WAVEDETAIL WD (NOLOCK) ON WD.WaveKey = W.WaveKey
         JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
         JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
         WHERE W.UserDefine01 = 'PTS' AND OH.StorerKey = @c_Storerkey
         AND OH.Facility = CASE WHEN ISNULL(@c_Facility,'') = '' THEN OH.Facility ELSE @c_Facility END
         GROUP BY W.WaveKey
         HAVING MAX(PD.[Status]) >= '3'

      OPEN cur_PTS
      
      FETCH NEXT FROM cur_PTS INTO @c_Wavekey
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
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
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Unable to Obtain TransmitLogKey2. (isp_BackendPTSReleaseToITF)' + 
                            ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '      
            GOTO NEXT_WAVE  
         END 
         
         INSERT INTO TRANSMITLOG2 (transmitlogkey, tablename, key1, key2, key3, transmitflag)
         SELECT @c_TransmitLogKey, 'WSPTSWVLOG', @c_Wavekey, '', @c_Storerkey, '0'
         
         SELECT @n_err = @@ERROR  
         
         IF @n_err <> 0  
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 71805    
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))   
                             + ': Insert Failed On Table TRANSMITLOG2. (isp_BackendPTSReleaseToITF)'   
                             + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
            GOTO NEXT_WAVE
         END 

         UPDATE WAVE WITH (ROWLOCK)
         SET UserDefine01 = 'PTS-SENT', TrafficCop =  NULL
         WHERE WaveKey = @c_Wavekey

         SELECT @n_err = @@ERROR  
         
         IF @n_err <> 0  
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 71815    
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))   
                             + ': Update Failed On Wave. (isp_BackendPTSReleaseToITF)'   
                             + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
            GOTO NEXT_WAVE
         END 
                  	   
         NEXT_WAVE:
         FETCH NEXT FROM cur_PTS INTO @c_Wavekey
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_BackendPTSReleaseToITF'
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