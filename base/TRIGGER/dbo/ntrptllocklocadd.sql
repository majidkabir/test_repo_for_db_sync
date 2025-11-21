SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store Procedure:  ntrPTLLockLocAdd                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Modification log:                                                          */
/* Date         Author     Ver   Purposes                                     */
/* 07-11-2014   Ung        1.0   Created                                      */
/******************************************************************************/
CREATE TRIGGER [dbo].[ntrPTLLockLocAdd]
ON  [dbo].[PTLLockLoc]
FOR INSERT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int
   SELECT @b_debug = 0

   DECLARE
      @b_Success            int           -- Populated by calls to stored procedures - was the proc successful?
     ,@n_err                int           -- Error number returned by stored procedure or this trigger
     ,@c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger
     ,@n_continue           int
     ,@n_starttcnt          int           -- Holds the current transaction count
     ,@profiler             NVARCHAR(80)

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   DECLARE @c_IPAddress      NVARCHAR(40)
   DECLARE @c_DeviceID       NVARCHAR(20)
   DECLARE @c_DevicePosition NVARCHAR(10)
   DECLARE @c_AddWho         NVARCHAR(18)

   DECLARE @curPTLLockLoc CURSOR
   SET @curPTLLockLoc = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT IPAddress, DeviceID, DevicePosition, AddWho
      FROM inserted WITH (NOLOCK)

   OPEN @curPTLLockLoc
   FETCH NEXT FROM @curPTLLockLoc INTO @c_IPAddress, @c_DeviceID, @c_DevicePosition, @c_AddWho

   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Check location locked by different user
      IF EXISTS( SELECT TOP 1 1
         FROM PTLLockLoc WITH (NOLOCK)
         WHERE IPAddress = @c_IPAddress
            AND DeviceID = @c_DeviceID
            AND DevicePosition = @c_DevicePosition
            AND AddWho <> @c_AddWho)
      BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 59951
            SELECT @c_errmsg = 'LightLOCLocked:' + RTRIM( @c_DevicePosition)
            GOTO Quit
      END
      FETCH NEXT FROM @curPTLLockLoc INTO @c_IPAddress, @c_DeviceID, @c_DevicePosition, @c_AddWho
   END

Quit:

   /* #INCLUDE <TRRDA2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
--      DECLARE @n_IsRDT INT
--      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT
--
--      IF @n_IsRDT = 1
--      BEGIN
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
         -- Instead we commit and raise an error back to parent, let the parent decide

         -- Commit until the level we begin with
         WHILE @@TRANCOUNT > @n_starttcnt
            COMMIT TRAN

         -- Raise error with severity = 10, instead of the default severity 16.
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
         RAISERROR (@n_err, 10, 1) WITH SETERROR

        -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
--      END
--      ELSE
--      BEGIN
--         IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
--         BEGIN
--            ROLLBACK TRAN
--         END
--         ELSE
--         BEGIN
--            WHILE @@TRANCOUNT > @n_starttcnt
--            BEGIN
--               COMMIT TRAN
--            END
--         END
--         execute nsp_logerror @n_err, @c_errmsg, "ntrPTLLockLocAdd"
--         RAISERROR (@c_errmsg, 10, 1) WITH SETERROR
--         RETURN
--      END
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO