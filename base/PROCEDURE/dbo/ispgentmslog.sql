SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  ispGenTMSLog                                       */
/* Creation Date: 21-July-2005                                          */
/* Copyright: IDS                                                       */
/* Written by: YokeBeen                                                 */
/*                                                                      */
/* Purpose:  Trigger records into the TMSLog table for Interfaces.      */
/*                                                                      */
/* Input Parameters:  @c_TableName     - Tablename                      */
/*                    @c_Key1          - Key #1                         */
/*                    @c_Key2          - Key #2                         */
/*                    @c_Key3          - Key #3                         */
/*                    @c_TransmitBatch - Transmit Batch                 */
/*                                                                      */
/* Output Parameters: @b_Success      - Success Flag  = 0               */
/*                    @n_err          - Error Code    = 0               */
/*                    @c_errmsg       - Error Message = ''              */
/*                                                                      */
/* Usage:  Store Records for Interfaces.                                */
/*                                                                      */
/* Called By:  Trigger/Store Procedure.                                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/*                                                                      */
/************************************************************************/

CREATE PROC   [dbo].[ispGenTMSLog]
               @c_TableName     NVARCHAR(30)
,              @c_Key1          NVARCHAR(10)
,              @c_Key2          NVARCHAR(5)
,              @c_Key3          NVARCHAR(20)
,              @c_TransmitBatch NVARCHAR(10)
,              @b_Success       int          OUTPUT
,              @n_err           int          OUTPUT
,              @c_errmsg        NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int,
           @n_starttcnt int,           -- Holds the current transaction count
           @c_preprocess NVARCHAR(250), -- preprocess
           @c_pstprocess NVARCHAR(250), -- post process
           @n_err2 int                 -- For Additional Error Detection

   DECLARE @c_trmlogkey NVARCHAR(10)

   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0, @n_err=0, @c_errmsg='', @n_err2=0
   /* #INCLUDE <SPIAD1.SQL> */

   IF ISNULL(dbo.fnc_RTrim(@c_Key1),'') = ''
   BEGIN
      RETURN
   END

   SELECT @c_Key2 = ISNULL(dbo.fnc_RTrim(@c_Key2), '')
   SELECT @c_Key3 = ISNULL(dbo.fnc_RTrim(@c_Key3), '')
   SELECT @c_TransmitBatch = ISNULL(dbo.fnc_RTrim(@c_TransmitBatch), '')

   IF @n_continue=1 OR @n_continue=2
   BEGIN
      SELECT @b_success = 1
      IF NOT EXISTS ( SELECT 1 FROM TMSLog (NOLOCK) WHERE TableName = @c_TableName
                         AND Key1 = @c_Key1 AND Key2 = @c_Key2 AND Key3 = @c_Key3)
      BEGIN
         INSERT INTO TMSLog (tablename, key1, key2, key3, transmitflag, TransmitBatch)
         VALUES (@c_TableName, @c_Key1, @c_Key2, @c_Key3, '0', @c_TransmitBatch)

         IF @@ERROR <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @n_err = 61000
            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Insert into TMSLog failed (ispGenTMSLog)'  
         END
      END

      /* #INCLUDE <SPIAD2.SQL> */
      IF @n_continue=3  -- Error Occured - Process And Return
      BEGIN
         SELECT @b_success = 0
         IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
         BEGIN
            ROLLBACK TRAN
         END
         ELSE
         BEGIN
            WHILE @@TRANCOUNT > @n_starttcnt
            BEGIN
               COMMIT TRAN
            END
         END
         EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, "ispGenTMSLog"
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
      ELSE
      BEGIN
         SELECT @b_success = 1
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
         RETURN
      END
   END -- IF @n_continue=1 OR @n_continue=2
END -- procedure

GO