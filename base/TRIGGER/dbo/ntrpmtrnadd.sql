SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Trigger: ntrPMTRNAdd                                                    */
/* Creation Date: 03-MAR-2016                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose: SOS#358752 - PM_Transaction_Screen                             */
/*        : PMTRN Insert Trigger                                           */
/*                                                                         */
/* Return Status:                                                          */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Called By: When records Inserted                                        */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Modifications:                                                          */
/* Date         Author  Ver   Purposes                                     */
/***************************************************************************/
CREATE TRIGGER ntrPMTRNAdd ON PMTRN
FOR INSERT
AS
BEGIN
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

         , @c_Facility        NVARCHAR(5)
         , @c_Storerkey       NVARCHAR(15) 
         , @c_AccountNo       NVARCHAR(30)
         , @c_TranType        NVARCHAR(10)
         , @c_PalletType      NVARCHAR(30)
         , @n_Qty             INT


   SET @n_Continue  = 1
   SET @n_StartTCnt = @@TRANCOUNT   

   IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
   BEGIN
      SET @n_continue = 4
      GOTO QUIT
   END

   DECLARE CUR_PMTRAN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT INSERTED.TranType
         ,INSERTED.Facility
         ,INSERTED.StorerKey
         ,INSERTED.AccountNo
         ,INSERTED.PalletType
         ,INSERTED.Qty
   FROM   INSERTED

   OPEN CUR_PMTRAN

   FETCH NEXT FROM CUR_PMTRAN INTO @c_TranType
                                 , @c_Facility
                                 , @c_Storerkey
                                 , @c_AccountNo
                                 , @c_PalletType
                                 , @n_Qty

   WHILE @@FETCH_STATUS <> -1 AND (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      IF @c_TranType = 'WD' 
      BEGIN
         UPDATE PMINV WITH (ROWLOCK)
         SET Qty = Qty + @n_Qty
            ,EditWho = SUSER_NAME()
            ,EditDate = GETDATE()
         WHERE Facility= @c_Facility
         AND Storerkey = @c_Storerkey
         AND AccountNo = @c_AccountNo
         AND PalletType = @c_PalletType

         SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(CHAR(250),@n_err)
            SET @n_err = 64110  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table PMINV fail. (ntrPMTRNAdd)'
                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            GOTO QUIT
         END
      END

      IF @c_TranType = 'DP' 
      BEGIN
         IF NOT EXISTS( SELECT 1
                        FROM PMINV WITH (NOLOCK)
                        WHERE Facility= @c_Facility
                        AND Storerkey = @c_Storerkey
                        AND AccountNo = @c_AccountNo
                        AND PalletType = @c_PalletType
                      )
         BEGIN
            INSERT INTO PMINV 
                  (Facility
                  ,Storerkey
                  ,AccountNo
                  ,PalletType
                  ,Qty
                  )
            VALUES(@c_Facility
                  ,@c_Storerkey
                  ,@c_AccountNo
                  ,@c_PalletType
                  ,@n_Qty)

            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(CHAR(250),@n_err)
               SET @n_err = 64120  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On to Table PMINV. (ntrPMTRNAdd)'
                         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO QUIT
            END
         END
         ELSE
         BEGIN
            UPDATE PMINV WITH (ROWLOCK)
            SET Qty = Qty + @n_Qty
               ,EditWho = SUSER_NAME()
               ,EditDate = GETDATE()
            WHERE Facility= @c_Facility
            AND Storerkey = @c_Storerkey
            AND AccountNo = @c_AccountNo
            AND PalletType = @c_PalletType

            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(CHAR(250),@n_err)
               SET @n_err = 64130  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table PMINV fail. (ntrPMTRNAdd)'
                         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO QUIT
            END
         END
      END

      FETCH NEXT FROM CUR_PMTRAN INTO @c_TranType
                                    , @c_Facility
                                    , @c_Storerkey
                                    , @c_AccountNo
                                    , @c_PalletType
                                    , @n_Qty
   END

   QUIT:
   IF CURSOR_STATUS( 'LOCAL', 'CUR_PMTRAN') in (0 , 1)  
   BEGIN
      CLOSE CUR_PMTRAN
      DEALLOCATE CUR_PMTRAN
   END

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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrPMTRNAdd'    
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