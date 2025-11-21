SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  ispGenVitalLog                                     */
/* Creation Date: 30-Jun-2008                                           */
/* Copyright: IDS                                                       */
/* Written by: YokeBeen                                                 */
/*                                                                      */
/* Purpose:  Store Records into VITALLOG for Interface to VITAL.        */
/*                                                                      */
/* Input Parameters:   @c_TableName     - Tablename                     */
/*                     @c_Key1          - Key #1                        */
/*                     @c_Key2          - Key #2                        */
/*                     @c_Key3          - Key #3                        */
/*                     @c_TransmitBatch - Transmit Batch                */
/*                                                                      */
/* Output Parameters:  @b_Success                                       */
/*                     @n_err                                           */
/*                     @c_errmsg                                        */
/*                                                                      */
/* Return Status:  @b_Success = 0 or 1                                  */
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
/* Date         Author    Ver.  Purposes                                */
/*                                                                      */
/************************************************************************/

CREATE PROC   [dbo].[ispGenVitalLog]
               @c_TableName     NVARCHAR(30)
,              @c_Key1          NVARCHAR(10)
,              @c_Key2          NVARCHAR(5)
,              @c_Key3          NVARCHAR(20)
,              @c_TransmitBatch NVARCHAR(10)
,              @b_Success       int        OUTPUT
,              @n_err           int        OUTPUT
,              @c_errmsg        NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON

   DECLARE @n_continue int  
         , @n_starttcnt int     -- Holds the current transaction count
         , @n_err2 int          -- For Additional Error Detection

   SET @n_starttcnt = @@TRANCOUNT 
   SET @n_continue = 1 
   SET @b_success = 0 
   SET @n_err = 0 
   SET @c_errmsg = '' 
   SET @n_err2 = 0 
   /* #INCLUDE <SPIAD1.SQL> */

   IF ISNULL(dbo.fnc_RTRIM(@c_Key1),'') = ''
   BEGIN
      RETURN
   END

   SET @c_Key2 = ISNULL(dbo.fnc_RTRIM(@c_Key2), '')
   SET @c_Key3 = ISNULL(dbo.fnc_RTRIM(@c_Key3), '')
   SET @c_TransmitBatch = ISNULL(dbo.fnc_RTRIM(@c_TransmitBatch), '')

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @b_success = 1
      IF NOT EXISTS ( SELECT 1 FROM VITALLOG WITH (NOLOCK) WHERE TableName = @c_TableName
                         AND Key1 = @c_Key1 AND Key2 = @c_Key2 AND Key3 = @c_Key3)
      BEGIN
         INSERT INTO VITALLOG (Tablename, Key1, Key2, Key3, Transmitflag, TransmitBatch)
         VALUES (@c_TableName, @c_Key1, @c_Key2, @c_Key3, '0', @c_TransmitBatch)

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 68000
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) + 
                            ': Insert into VITALLOG Failed. (ispGenVitalLog)' + 
                            ' ( ' + ' SQLSvr MESSAGE = ' + ISNULL(dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)),'') + ' ) '
         END
      END

      /* #INCLUDE <SPIAD2.SQL> */
      IF @n_continue=3  -- Error Occured - Process And Return
      BEGIN
         SET @b_success = 0
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
         EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'ispGenVitalLog'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
      ELSE
      BEGIN
         SET @b_success = 1
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
         RETURN
      END
   END
END -- procedure

GO