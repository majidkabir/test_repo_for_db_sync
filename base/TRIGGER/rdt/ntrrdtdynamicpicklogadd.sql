SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store Procedure: rdt.ntrRDTDynamicPickLogAdd                               */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Modification log:                                                          */
/* Date         Author     Ver   Purposes                                     */
/* 16-Aug-2013  Ung        1.0   Created                                      */
/* 13-Apr-2014  TLTING     1.2   SQL2012                                      */
/* 15-Aug-2014  Ung        1.3   Add WITH (NOLOCK)                            */
/******************************************************************************/
CREATE TRIGGER rdt.ntrRDTDynamicPickLogAdd ON rdt.rdtDynamicPickLog FOR INSERT AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @n_continue    INT
     ,@n_starttcnt   INT
     ,@n_err         INT
     ,@c_errmsg      NVARCHAR( 20)
     ,@c_Zone        NVARCHAR( 10)
     ,@c_LOC         NVARCHAR( 10)
     ,@c_PickSlipNo  NVARCHAR( 10)

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   DECLARE CURSOR_INSERTED CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT INSERTED.Zone, INSERTED.LOC, INSERTED.PickSlipNo
   FROM INSERTED WITH (NOLOCK)

   OPEN CURSOR_INSERTED               
   FETCH NEXT FROM CURSOR_INSERTED INTO @c_Zone, @c_LOC, @c_PickSlipNo

   WHILE @@FETCH_STATUS = 0          
   BEGIN 
      -- Lock entire pickslip
      IF @c_LOC = ''
      BEGIN
         -- PickSlip already locked by others
         IF EXISTS( SELECT TOP 1 1 
            FROM rdt.rdtDynamicPickLog WITH (NOLOCK)
            WHERE PickSlipNo = @c_PickSlipNo
               AND Zone = @c_Zone
               AND AddWho <> SUSER_NAME())
         BEGIN
            SET @n_continue = 3
            SET @n_err = 84101
            SET @c_errmsg = '84101^LockPSNoFail'
            BREAK
         END
      END
      
      -- Lock pickslip by LOC range
      IF @c_LOC <> ''
      BEGIN
         -- PickSlip already locked by others
         IF EXISTS( SELECT TOP 1 1 
            FROM rdt.rdtDynamicPickLog WITH (NOLOCK)
            WHERE PickSlipNo = @c_PickSlipNo 
               AND Zone = @c_Zone
               AND AddWho <> SUSER_NAME() 
               AND (LOC = '' OR LOC = @c_LOC))
         BEGIN
            SET @n_continue = 3
            SET @n_err = 84102
            SET @c_errmsg = '84102^LockPSNoFail'
            BREAK
         END
      END
      FETCH NEXT FROM CURSOR_INSERTED INTO @c_Zone, @c_LOC, @c_PickSlipNo
   END

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
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
         IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
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
         execute nsp_logerror @n_err, @c_errmsg, "ntrRDTDynamicPickLogAdd"
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
         --RAISERROR @n_err @c_errmsg
         RETURN
      END
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