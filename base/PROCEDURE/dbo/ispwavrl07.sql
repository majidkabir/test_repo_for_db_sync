SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispWAVRL07                                                       */
/* Creation Date: 24-May-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19715 - CN Columbia Case shuttle Wave trigger point     */ 
/*                                                                      */
/* Usage:   Storerconfig WaveReleaseToWCS_SP={SPName} to enable release */
/*          Wave to WCS option                                          */
/*                                                                      */
/* Called By: isp_WaveReleaseToWCS_Wrapper                              */
/*                                                                      */
/* GitLab Version: 1.1                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 24-May-2022  WLChooi  1.0  DevOps Combine Script                     */
/* 21-Nov-2022  WLChooi  1.1  WMS-21215 - Add Validation (WL01)         */
/************************************************************************/

CREATE PROC [dbo].[ispWAVRL07] 
   @c_WaveKey  NVARCHAR(10),
   @b_Success  INT OUTPUT,
   @n_err      INT OUTPUT,
   @c_errmsg   NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue       INT
         , @b_debug          INT
         , @n_StartTranCnt   INT
         , @c_Storerkey      NVARCHAR(15)
         , @c_TableName      NVARCHAR(15)
         , @c_Loadkey        NVARCHAR(10)
         , @c_Orderkey       NVARCHAR(10)
         , @c_WaveType       NVARCHAR(20)
         , @c_Facility       NVARCHAR(5)
         , @c_UserDefine10   NVARCHAR(20)
         , @c_DocType        NVARCHAR(1)
         , @c_trmlogkey      NVARCHAR(10)
         , @c_TransmitBatch  NVARCHAR(50) = ''
         , @c_SkipGen        NVARCHAR(1) = 'Y'

   IF @n_err = 1
      SET @b_debug = 1

   SELECT @n_StartTranCnt = @@TRANCOUNT, @n_continue = 1, @b_success = 1, @n_err = 0, @c_errmsg = ''

   -----Get Wave Info-----
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN      
       SELECT @c_UserDefine10 = MAX(WAVE.UserDefine10)
            , @c_DocType      = MAX(ORDERS.DocType)
            , @c_Storerkey    = MAX(ORDERS.StorerKey)
            , @c_Facility     = MAX(ORDERS.Facility)
            , @c_WaveType     = MAX(WAVE.WaveType)
       FROM WAVE (NOLOCK)    
       JOIN WAVEDETAIL (NOLOCK) ON WAVEDETAIL.WaveKey = WAVE.WaveKey
       JOIN ORDERS (NOLOCK) ON ORDERS.OrderKey = WAVEDETAIL.OrderKey
       WHERE WAVE.Wavekey = @c_Wavekey                  
   END
  
   ------Validation--------
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN          
      IF @c_UserDefine10 = 'CS RELEASED'
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release Failed. The wave has been released. (ispWAVRL07)' 
                          + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO RETURN_SP
      END

      --WL01 S
      IF EXISTS (  SELECT 1
                   FROM WAVEDETAIL WD (NOLOCK)
                   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
                   JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
                   JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'CSDEFLOC' AND CL.Storerkey = PD.StorerKey 
                                            AND CL.Long = PD.Loc
                   WHERE WD.WaveKey = @c_WaveKey
                   AND   (  (ISNULL(PD.PickSlipNo, '') = '') -- CSR
                       OR   ((ISNULL(PD.PickSlipNo, '') = '' AND (ISNULL(PD.Notes, '') = '') ) -- CSOS
                            )
                         ) 
                )
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67111   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Data error found. Please verify. (ispWAVRL07)' 
                          + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO RETURN_SP
      END

      IF NOT EXISTS (  SELECT 1
                       FROM WAVEDETAIL WD (NOLOCK)
                       JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
                       JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
                       JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'CSDEFLOC' AND CL.Storerkey = PD.StorerKey 
                                                AND CL.Long = PD.Loc
                       WHERE WD.WaveKey = @c_WaveKey
                    )
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67112   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': No record release to Case Shuttle. (ispWAVRL07)' 
                          + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO RETURN_SP
      END

      IF @c_WaveType NOT IN ('CSR','CSOS')
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67113   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Please choose the correct wavetype to trigger case shuttle interface. (ispWAVRL07)' 
                          + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO RETURN_SP
      END
      --WL01 E
   END

   ------Insert Into Transmitlog2-------   
   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      IF EXISTS (SELECT 1
                 FROM CODELKUP CL (NOLOCK)
                 WHERE CL.LISTNAME = 'CSWVCON'
                 AND CL.Notes = @c_Facility
                 AND CL.Storerkey = @c_Storerkey
                 AND CL.Short = @c_DocType)
      BEGIN
         SET @c_TableName = 'WSSOWVAECS'

         SELECT @b_success = 1

         EXECUTE nspg_getkey
            'TransmitlogKey2'
            , 10
            , @c_trmlogkey OUTPUT
            , @b_success   OUTPUT
            , @n_err       OUTPUT
            , @c_errmsg    OUTPUT
         
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 67115   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) 
                             + ': Unable to Obtain transmitlogkey. (ispWAVRL07) ( SQLSvr MESSAGE=' 
                             + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            GOTO RETURN_SP 
         END
         ELSE 
         BEGIN
            IF (@n_continue = 1 OR @n_continue = 2)
            BEGIN
               INSERT INTO Transmitlog2 (transmitlogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)
               VALUES (@c_trmlogkey, @c_TableName, @c_WaveKey, @c_WaveType, @c_Storerkey, '0', @c_TransmitBatch)
            
               SELECT @n_err = @@ERROR
            
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67120   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert into TRANSMITLOG2 Failed. (ispWAVRL07)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                  GOTO RETURN_SP 
               END

               SET @c_SkipGen = 'N'
            END
         END

         UPDATE dbo.WAVE
         SET UserDefine10 = 'CS Released'
         WHERE WaveKey = @c_WaveKey

         IF @@ERROR <> 0 
         BEGIN
             SELECT @n_continue = 3  
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67125   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
             SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE WAVE Failed. (ispWAVRL07)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
             GOTO RETURN_SP 
         END
      END
      ELSE
      BEGIN
         IF @@ERROR <> 0 
         BEGIN
             SELECT @n_continue = 3  
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67130   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
             SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': DocType not set up in Codelkup. (ispWAVRL07)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
             GOTO RETURN_SP 
         END
      END
   END

RETURN_SP:
   IF ISNULL(@c_errmsg,'') = ''
   BEGIN
      IF @c_SkipGen = 'N'
         SET @c_errmsg = 'EDI records generated successfully'
      ELSE
         SET @c_errmsg = 'EDI records generated failed.'
   END

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTranCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispWAVRL07'
      --RAISERROR @n_err @c_errmsg
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO