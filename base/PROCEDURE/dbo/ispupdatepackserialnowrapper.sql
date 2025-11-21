SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Stored Procedure: ispUpdatePackSerialNoWrapper                             */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Date         Author  Rev   Purposes                                        */
/* 26-05-2017   Ung     1.0   WMS-1919 Created                                */
/******************************************************************************/
CREATE PROC [dbo].[ispUpdatePackSerialNoWrapper]
     @c_Storerkey  NVARCHAR(15)
   , @c_Facility   NVARCHAR(5)
   , @c_PickSlipNo NVARCHAR(10)
   , @c_OrderKey   NVARCHAR(10)
   , @c_loadKey    NVARCHAR(10)
   , @b_Success    INT           OUTPUT
   , @n_Err        INT           OUTPUT
   , @c_ErrMsg     NVARCHAR(250) OUTPUT
   , @b_debug      INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_starttcnt INT
   DECLARE @n_Continue  INT
   DECLARE @c_SQL       NVARCHAR( MAX)
   DECLARE @c_SQLParm   NVARCHAR( MAX)
   DECLARE @c_UpdatePackSerialNoSP NVARCHAR(30)

   SET @n_starttcnt = @@TRANCOUNT
   SET @n_Continue  = 1
   SET @b_Success   = 1
   SET @n_Err       = 0
   SET @c_ErrMsg    = ''
   SET @c_UpdatePackSerialNoSP = ''

   EXEC nspGetRight
        @c_Facility  = NULL
      , @c_StorerKey = @c_StorerKey
      , @c_sku       = NULL
      , @c_ConfigKey = 'UpdatePackSerialNoSP'
      , @b_Success   = @b_Success              OUTPUT
      , @c_authority = @c_UpdatePackSerialNoSP OUTPUT
      , @n_err       = @n_err                  OUTPUT
      , @c_errmsg    = @c_errmsg               OUTPUT

   IF @b_success <> 1      
      SELECT @n_continue = 3    
   ELSE
   BEGIN
      IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_UpdatePackSerialNoSP AND TYPE = 'P')
      BEGIN
         SET @c_SQL = 'EXECUTE ' + @c_UpdatePackSerialNoSP +
            ' @c_Storerkey, @c_Facility, @c_PickSlipNo, @c_OrderKey, @c_loadKey, ' + 
            ' @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '
   
         SET @c_SQLParm =
            ' @c_Storerkey  NVARCHAR(15), ' + 
            ' @c_Facility   NVARCHAR(5),  ' + 
            ' @c_PickSlipNo NVARCHAR(10), ' + 
            ' @c_OrderKey   NVARCHAR(10), ' + 
            ' @c_loadKey    NVARCHAR(10), ' + 
            ' @b_Success    INT           OUTPUT, ' +
            ' @n_Err        INT           OUTPUT, ' +
            ' @c_ErrMsg     NVARCHAR(250) OUTPUT  '
   
         EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm,
            @c_Storerkey, @c_Facility, @c_PickSlipNo, @c_OrderKey, @c_loadKey, 
            @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT 
   
         IF @@ERROR <> 0 OR @b_Success <> 1 OR @n_Err <> 0
            SET @n_Continue= 3
      END
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

      IF @n_IsRDT = 1
      BEGIN
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
         -- Instead we commit and raise an error back to parent, let the parent decide

         -- Commit until the level we begin with
         WHILE @@TRANCOUNT > @n_starttcnt
            COMMIT TRAN

         -- Raise error with severity = 10, instead of the default severity 16.
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
         RAISERROR (@n_err, 10, 1) WITH SETERROR

         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN
         IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
         BEGIN
            ROLLBACK TRAN
         END

     EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispUpdatePackSerialNoWrapper'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      RETURN
   END

END -- Procedure

GO