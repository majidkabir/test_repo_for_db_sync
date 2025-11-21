SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_SNStatus_Validation                                 */
/* Creation Date: 20-SEP-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-2931 - CN_DYSON_EXCEED_Serialno_CR                      */
/*        :                                                             */
/* Called By: PB nep_n_cst_serialno                                     */
/*          : PB ue_status_rule                                         */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_SNStatus_Validation]
           @c_SerialNoKey  NVARCHAR(15)
         , @c_Storerkey    NVARCHAR(15)
         , @c_Status_DEL   NVARCHAR(30)
         , @c_Status_INS   NVARCHAR(30)
         , @b_Success      INT            OUTPUT
         , @n_Err          INT            OUTPUT
         , @c_ErrMsg       NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @b_Reject          INT


         , @c_BLKFromStat     NVARCHAR(60)
         , @c_BLKToStat       NVARCHAR(60) 
         , @c_AllowFromStat   NVARCHAR(60)
         , @c_AllowToStat     NVARCHAR(60)
         , @c_ChangeType      NVARCHAR(10)
 
   DECLARE  @cur_CL           CURSOR

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @b_Reject   = 0
   SET @c_ChangeType = ''

   SET @cur_CL = CURSOR FAST_FORWARD READ_ONLY FOR    
   SELECT BLKFromStat = ISNULL(RTRIM(CL.UDF01),'')
         ,BLKToStat   = ISNULL(RTRIM(CL.UDF02),'')  
         ,ChangeType  = ISNULL(RTRIM(CL.Short), 'BLOCK')
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE CL.ListName  = 'SNStatChg'
   AND   CL.Storerkey = @c_Storerkey 
   ORDER BY CL.Short DESC
         
   OPEN @cur_CL

   FETCH NEXT FROM @cur_CL INTO @c_BLKFromStat, @c_BLKToStat, @c_ChangeType
 
   WHILE @@FETCH_STATUS = 0 AND @n_Continue = 1
   BEGIN
      SET @c_AllowFromStat = @c_BLKFromStat
      SET @c_AllowToStat   = @c_BLKToStat
      SET @b_Reject = 0

      IF @c_ChangeType = 'BLOCK'
      BEGIN
         IF    ( @c_BLKFromStat <> '' OR @c_BLKToStat <> '')
         AND   ( @c_BLKFromStat = @c_Status_DEL OR @c_BLKFromStat = '' ) 
         AND   ( @c_BLKToStat   = @c_Status_INS OR @c_BLKToStat   = '' )
         BEGIN
            SET @b_Reject = 1
         END

         IF @b_Reject = 1
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 69710
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Codelkup ''SNStatChg'' block from changing status ' 
                         + RTRIM(@c_Status_DEL) + ' To ' + RTRIM(@c_Status_INS) 
                         + '. Status Change Abort. (isp_SNStatus_Validation)' 
            GOTO QUIT_SP
         END
      END

      IF @c_ChangeType = 'ALLOWONLY'
      BEGIN
         SET @b_Reject  = 1

         IF    ( @c_AllowFromStat <> '' OR @c_AllowToStat <> '')
         AND   ( @c_AllowFromStat = @c_Status_DEL OR @c_AllowFromStat = '' )
         AND   ( @c_AllowToStat   = @c_Status_INS OR @c_AllowToStat   = '' )
         BEGIN 
            SET @b_Reject = 0
            BREAK
         END
      END

      FETCH NEXT FROM @cur_CL INTO @c_BLKFromStat, @c_BLKToStat, @c_ChangeType 
   END

   IF @b_Reject = 1 
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 69720
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Codelkup ''SNStatChg'' disallow to change status from ' 
                     + RTRIM(@c_Status_DEL) + ' To ' + RTRIM(@c_Status_INS) 
                     + '. Status Change Abort. (isp_SNStatus_Validation)' 
      GOTO QUIT_SP
   END  

QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_SNStatus_Validation'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO