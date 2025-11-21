SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Trigger: ntrPalletMgmtUpdate                                            */
/* Creation Date: 03-Mar-2016                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose: Pallet Management Maintenance Screen                           */
/*        : PalletMgmt Update Trigger                                      */
/*                                                                         */
/* Return Status:                                                          */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Called By: When records Updated                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Modifications:                                                          */
/* Date         Author  Ver   Purposes                                     */
/***************************************************************************/
CREATE TRIGGER ntrPalletMgmtUpdate ON PALLETMGMT
FOR UPDATE
AS
BEGIN
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue        INT                     
         , @n_StartTCnt       INT            -- Holds the current transaction count    
         , @b_Success         INT            -- Populated by calls to stored procedures - was the proc successful?    
         , @n_err             INT            -- Error number returned by stored procedure or this trigger    
         , @c_errmsg          NVARCHAR(255)  -- Error message returned by stored procedure or this trigger    

         , @b_debug           INT

   SET @n_Continue  = 1
   SET @n_StartTCnt = @@TRANCOUNT   

   IF UPDATE(ArchiveCop)
   BEGIN
      SET @n_Continue = 4
      GOTO QUIT
   END

   IF ( @n_continue=1 or @n_continue=2 ) AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE PALLETMGMT WITH (ROWLOCK)
      SET EditDate = GETDATE() 
         ,EditWho  = SUSER_SNAME() 
         ,TrafficCop = NULL
      FROM PALLETMGMT
      JOIN DELETED  ON (DELETED.PMKey = PALLETMGMT.PMKey)
      JOIN INSERTED ON (DELETED.PMKey = INSERTED.PMKey)
      WHERE ( DELETED.Status < '9' OR DELETED.Status < '9' )

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 63210  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table PALLETMGMT. (ntrPalletMgmtUpdate)'
                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO QUIT
      END
   END

   IF UPDATE(TrafficCop)
   BEGIN
      SET @n_Continue = 4
      GOTO QUIT
   END
  
   --Checking
   IF EXISTS ( SELECT 1
               FROM  INSERTED
               JOIN  DELETED ON (INSERTED.PMKey = DELETED.PMKey)
               JOIN  PALLETMGMTDETAIL PMD WITH (NOLOCK) ON (INSERTED.PMKey = PMD.PMKey)
               LEFT JOIN  ORDERS      SO  WITH (NOLOCK) ON (INSERTED.Facility   = SO.Facility)
                                                        AND(INSERTED.SourceKey  = SO.Orderkey)
               LEFT JOIN  ORDERS      LP  WITH (NOLOCK) ON (INSERTED.Facility   = LP.Facility)
                                                        AND(INSERTED.SourceKey  = LP.Loadkey)
               LEFT JOIN  ORDERS      MB  WITH (NOLOCK) ON (INSERTED.Facility   = MB.Facility)
                                                        AND(INSERTED.SourceKey  = MB.Mbolkey)  
               WHERE INSERTED.Sourcetype = 'ASN'
               AND INSERTED.Sourcekey <> '' 
               AND PMD.Type = 'WD'
              )
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 63220   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg= 'Unmatch Inbound Source type with Withdrawal PM Transaction type. (ntrPalletMgmtUpdate)' 
      GOTO QUIT 
   END

   IF EXISTS ( SELECT 1
               FROM  INSERTED
               JOIN  DELETED ON (INSERTED.PMKey = DELETED.PMKey)
               JOIN  PALLETMGMTDETAIL PMD WITH (NOLOCK) ON (INSERTED.PMKey = PMD.PMKey)
               LEFT JOIN  ORDERS      SO  WITH (NOLOCK) ON (INSERTED.Facility   = SO.Facility)
                                                        AND(INSERTED.SourceKey  = SO.Orderkey)
               LEFT JOIN  ORDERS      LP  WITH (NOLOCK) ON (INSERTED.Facility   = LP.Facility)
                                                        AND(INSERTED.SourceKey  = LP.Loadkey)
               LEFT JOIN  ORDERS      MB  WITH (NOLOCK) ON (INSERTED.Facility   = MB.Facility)
                                                        AND(INSERTED.SourceKey  = MB.Mbolkey)  
               WHERE INSERTED.Sourcetype IN ('SO', 'LOADPLAN', 'MBOL' )
               AND INSERTED.Sourcekey <> '' 
               AND PMD.Type = 'DP'
              )
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 63230   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg= 'Unmatch Outbound Source type with Deposit PM Transaction type. (ntrPalletMgmtUpdate)' 
      GOTO QUIT 
   END
QUIT:
   /* #INCLUDE <TRRDA2.SQL> */    
   IF @n_Continue=3  -- Error Occured - Process And Return    
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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrPalletMgmtUpdate'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR  

      RETURN    
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