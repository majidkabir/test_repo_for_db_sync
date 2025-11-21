SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispWAVRL08                                                       */
/* Creation Date: 21-Oct-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-21011 - [TW] GRS - Sortation - Release to WCS - New     */ 
/*                                                                      */
/* Usage:   Storerconfig WaveReleaseToWCS_SP={SPName} to enable release */
/*          Wave to WCS option                                          */
/*                                                                      */
/* Called By: isp_WaveReleaseToWCS_Wrapper                              */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 21-Oct-2022  WLChooi  1.0  DevOps Combine Script                     */
/* 01-Aut-2023  NJOW01   1.1  WMS-23255 Validate scan-in by config      */
/************************************************************************/

CREATE   PROC [dbo].[ispWAVRL08] 
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
         , @c_UserDefine02   NVARCHAR(20)
         , @c_DocType        NVARCHAR(1)
         , @c_Trmlogkey      NVARCHAR(10)
         , @c_TransmitBatch  NVARCHAR(50) = ''
         , @c_ValidateScanIn NVARCHAR(30) = '' --NJOW01
         , @c_Authority      NVARCHAR(30) = '' --NJOW01
         , @c_ValScanIn_Opt5 NVARCHAR(1000) = '' --NJOW01

   IF @n_err = 1
      SET @b_debug = 1

   SELECT @n_StartTranCnt = @@TRANCOUNT, @n_continue = 1, @b_success = 1, @n_err = 0, @c_errmsg = ''

   -----Get Wave Info-----
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN      
       SELECT @c_UserDefine02 = MAX(WAVE.UserDefine02)
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
   	  --NJOW01 S         
   	  SELECT @c_Authority = SC.Authority,
             @c_ValScanIn_Opt5 = SC.Option5
      FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey,'','WaveReleaseToWCS_SP') AS SC
      
      SELECT @c_ValidateScanIn = dbo.fnc_GetParamValueFromString('@c_ValidateScanIn', @c_ValScanIn_Opt5, @c_ValidateScanIn)      
      
      IF @c_Authority = 'ispWAVRL08' AND @c_ValidateScanIn = 'Y'
      BEGIN
         IF EXISTS(SELECT 1 
                   FROM WAVEDETAIL WD (NOLOCK)
                   JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
                   WHERE WD.Wavekey = @c_Wavekey
                   AND O.Status < '3')
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release Failed. Wave not yet picking in progress. Please Scan In. (ispWAVRL08)' 
                             + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
            GOTO RETURN_SP         	
         END          
      END
      --NJOW01 E
   	    	
      IF @c_UserDefine02 = 'GRS Send'
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release Failed. GRS has been sent for this wave. (ispWAVRL08)' 
                          + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO RETURN_SP
      END

      SELECT @c_TableName = ISNULL(CL.UDF01,'')
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = 'WAVETYPE'
      AND CL.Code = @c_WaveType
      AND CL.Storerkey = @c_Storerkey
   END

   ------Insert Into Transmitlog2-------   
   IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@c_TableName,'') <> ''
   BEGIN
      --SET @c_TableName = 'WSWAVERLS1'
      
      SELECT @b_success = 1
      
      EXECUTE nspg_getkey
         'TransmitlogKey2'
         , 10
         , @c_Trmlogkey OUTPUT
         , @b_success   OUTPUT
         , @n_err       OUTPUT
         , @c_errmsg    OUTPUT
      
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 67115   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) 
                          + ': Unable to Obtain transmitlogkey. (ispWAVRL08) ( SQLSvr MESSAGE=' 
                          + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         GOTO RETURN_SP 
      END
      ELSE 
      BEGIN
         IF NOT EXISTS ( SELECT 1
                         FROM dbo.TRANSMITLOG2 TL2 (NOLOCK)
                         WHERE TL2.tablename = @c_TableName
                         AND TL2.key1 = @c_WaveKey
                         AND TL2.key2 = ''
                         AND TL2.key3 = @c_Storerkey )
         BEGIN
            INSERT INTO Transmitlog2 (transmitlogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)
            VALUES (@c_Trmlogkey, @c_TableName, @c_WaveKey, '', @c_Storerkey, '0', @c_TransmitBatch)
         
            SELECT @n_err = @@ERROR
         
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67120   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert into TRANSMITLOG2 Failed. (ispWAVRL08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               GOTO RETURN_SP 
            END
         END
         ELSE
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67121   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': TRANSMITLOG2 already exists! (ispWAVRL08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            GOTO RETURN_SP 
         END
      END
      
      UPDATE dbo.WAVE
      SET UserDefine02 = 'GRS Send'
      WHERE WaveKey = @c_WaveKey
      
      IF @@ERROR <> 0 
      BEGIN
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67125   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE WAVE Failed. (ispWAVRL08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
          GOTO RETURN_SP 
      END
   END

RETURN_SP:
   IF ISNULL(@c_errmsg,'') = ''
      SET @c_errmsg = 'EDI records generated successfully'
   --ELSE
   --   SET @c_errmsg = 'EDI records generated failed.'

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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispWAVRL08'
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