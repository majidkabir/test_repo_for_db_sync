SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Trigger: ntrPackSerialNoDelete                                       */    
/* Creation Date: 2017-May-29                                           */    
/* Copyright: LFL                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: PackSerialNo Delete trigger                                 */
/*                                                                      */
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Ver.  Purposes                                  */   
/* 2017-May-29  Ung     1.1   WMS-1919 Created                          */
/* 2021-Dec-08  NJOW01  1.2   WMS-18599 remove orderkey when reverse    */
/*                            serial number.                            */
/* 2021-Dec-08  NJOW01  1.2   DEVOPS combine script                     */
/************************************************************************/    

CREATE TRIGGER [ntrPackSerialNoDelete] ON [PackSerialNo] 
FOR  DELETE
AS
BEGIN
   IF @@ROWCOUNT = 0
      RETURN
   
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success   int,       -- Populated by calls to stored procedures - was the proc successful?      
           @n_err       int,       -- Error number returned by stored procedure or this trigger      
           @c_errmsg    NVARCHAR(250), -- Error message returned by stored procedure or this trigger      
           @n_continue  int,       -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing      
           @n_starttcnt int,       -- Holds the current transaction count      
           @n_cnt       int        -- Holds the number of rows affected by the Update statement that fired this trigger.      
  
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT, @b_success=0, @n_err=0, @c_errmsg=''

   if (select count(*) from DELETED) = 
      (select count(*) from DELETED where DELETED.ArchiveCop = '9')
   BEGIN
      SELECT @n_continue = 4
   END

   -- Check pack confirmed
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS( SELECT TOP 1 1 
         FROM DELETED
            JOIN PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = DELETED.PickSlipNo)
         WHERE PH.Status = '9')    
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 110251
         SELECT @c_errmsg="NSQL"+CONVERT(char(6), @n_err)+": Delete fail due to Pack confirmed (ntrPackSerialNoDelete) (SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + ") "
      END
   END

   -- Reverse SerialNo.Status
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE @c_SerialNoKey NVARCHAR(10)
      DECLARE @curPSNO CURSOR
      SET @curPSNO = CURSOR FOR
         SELECT SerialNoKey
         FROM DELETED D
            JOIN SerialNo SNO WITH (NOLOCK) ON (D.StorerKey = SNO.StorerKey AND D.SKU = SNO.SKU AND D.SerialNo = SNO.SerialNo)
         WHERE SNO.Status = '6'
      OPEN @curPSNO 
      FETCH NEXT FROM @curPSNO INTO @c_SerialNoKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE SerialNo SET
            Status = '1', -- Received
            Orderkey = '',  --NJOW01
            OrderLineNumber = '',  --NJOW01
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME()
         WHERE SerialNoKey = @c_SerialNoKey
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 110252
            SELECT @c_errmsg="NSQL"+CONVERT(char(6), @n_err)+": Update SerialNo table fail (ntrPackSerialNoDelete) (SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + ") "
         END
         FETCH NEXT FROM @curPSNO INTO @c_SerialNoKey
      END
   END

   IF @n_continue = 3  -- Error Occured - Process And Return      
   BEGIN      
      SELECT @b_success = 0      
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
         IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt      
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrPackSerialNoDelete'      
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012      
         RETURN      
      END      
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
END

GO