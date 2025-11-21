SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/******************************************************************************/  
/* Store Procedure:  ntrRDTDynamicPickLogDelete                               */  
/* Copyright: LF Logistics                                                    */  
/*                                                                            */  
/* Purpose:  VFCDC Debugging Script                                           */  
/*                                                                            */  
/* Modification log:                                                          */  
/* Date         Author     Ver   Purposes                                     */  
/* 22-May-2014  Ung        1.0   Add DELLOG for troubleshoot                  */
/* 16-JUN-2016  JayLim      1.1  SQL2012 compatibility modification (Jay01)   */
/******************************************************************************/  
--DROP TRIGGER ntrRDTDynamicPickLogDelete  
CREATE TRIGGER [RDT].[ntrRDTDynamicPickLogDelete]  
ON  [RDT].[RDTDynamicPickLog]  
FOR DELETE  
AS  
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

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
  
   INSERT INTO rdt.RDTDynamicPickLog_DELLOG (Zone, LOC, PickSlipNo, CartonNo, LabelNo, AddWho, AddDate)
   SELECT Zone, LOC, PickSlipNo, CartonNo, LabelNo, AddWho, AddDate
   FROM DELETED
  
QUIT:  
  
   /* #INCLUDE <TRRDA2.SQL> */  
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
         execute nsp_logerror @n_err, @c_errmsg, "ntrRDTDynamicPickLogDelete"  
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR -- SQL 2012 (Jay01)  
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