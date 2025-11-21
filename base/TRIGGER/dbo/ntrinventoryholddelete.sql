SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Trigger: ntrInventoryHoldDelete                                      */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Called By: When delete records in Inventoryhold                      */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 2010-06-18   SHONG    1.1  Insert TableDeleteLog                     */
/* 27-Apr-2011  KHLim01  1.2  Insert Delete log                         */
/* 14-Jul-2011  KHLim02  1.3  GetRight for Delete log                   */
/************************************************************************/  
  
CREATE TRIGGER [dbo].[ntrInventoryHoldDelete]
ON [dbo].[INVENTORYHOLD]
FOR  DELETE
AS
BEGIN
    IF @@ROWCOUNT=0
    BEGIN
        RETURN
    END  

    SET NOCOUNT ON 
    SET ANSI_NULLS OFF  
    SET QUOTED_IDENTIFIER OFF  
    SET CONCAT_NULL_YIELDS_NULL OFF  
        
    DECLARE @b_Success    INT	-- Populated by calls to stored procedures - was the proc successful?
           ,@n_err        INT	-- Error number returned by stored procedure or this trigger
           ,@c_errmsg     NVARCHAR(250)	-- Error message returned by stored procedure or this trigger
           ,@n_continue   INT	-- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing
           ,@n_starttcnt  INT	-- Holds the current transaction count
           ,@n_cnt        INT -- Holds the number of rows affected by the DELETE statement that fired this trigger.  
           ,@c_authority  NVARCHAR(1)  -- KHLim02
    SELECT @n_continue = 1
          ,@n_starttcnt = @@TRANCOUNT
    
    IF (
           SELECT COUNT(*)
           FROM   DELETED
       )=(
           SELECT COUNT(*)
           FROM   DELETED
           WHERE  DELETED.ArchiveCop = '9'
       )
    BEGIN
        SELECT @n_continue = 4
    END 
    
    /* #INCLUDE <TRWAVEHD1.SQL> */       
    IF @n_continue=1
       OR @n_continue=2
    BEGIN
        IF EXISTS (
               SELECT 1
               FROM   DELETED
               WHERE  Hold = '1'
           )
        BEGIN
            SELECT @n_continue = 3  
            SELECT @n_err = 84502  
            SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                   ': DELETE rejected. Inventory Still On Hold. (ntrInventoryHoldDelete)'
        END
    END  

    IF @n_continue=1 OR @n_continue=2
    BEGIN
       INSERT INTO TableDeleteLog
       (
          TableName,   Col1,    Col2,    Col3,   Col4,  Col5, Remarks
       )
       SELECT 'INVENTORYHOLD', InventoryHoldKey, LOT, LOC, ID, SKU, ''
       FROM   DELETED       
    END
        
    IF @n_continue=1
       OR @n_continue=2
    BEGIN
        DELETE InventoryHold
        FROM   InventoryHold
              ,DELETED
        WHERE  InventoryHold.InventoryHoldKey = DELETED.InventoryHoldKey  
        
        SELECT @n_err = @@ERROR
              ,@n_cnt = @@ROWCOUNT  
        
        IF @n_err<>0
        BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                  ,@n_err = 84501 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                   ': Delete Trigger On Table InventoryHold Failed. (ntrInventoryHoldDelete)' 
                  +' ( '+' SQLSvr MESSAGE='+LTRIM(RTRIM(@c_errmsg))+' ) '
        END
    END 

   -- Start (KHLim01) 
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 0         --    Start (KHLim02)
      EXECUTE nspGetRight  NULL,             -- facility  
                           NULL,             -- Storerkey  
                           NULL,             -- Sku  
                           'DataMartDELLOG', -- Configkey  
                           @b_success     OUTPUT, 
                           @c_authority   OUTPUT, 
                           @n_err         OUTPUT, 
                           @c_errmsg      OUTPUT  
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
               ,@c_errmsg = 'ntrINVENTORYHOLDDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'         --    End   (KHLim02)
      BEGIN
         INSERT INTO dbo.INVENTORYHOLD_DELLOG ( InventoryHoldKey )
         SELECT InventoryHoldKey FROM DELETED

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table INVENTORYHOLD Failed. (ntrINVENTORYHOLDDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
      END
   END
   -- End (KHLim01) 

    /* #INCLUDE <TRWAVEHD2.SQL> */  
    IF @n_continue=3 -- Error Occured - Process And Return
    BEGIN
        IF @@TRANCOUNT=1
           AND @@TRANCOUNT>=@n_starttcnt
        BEGIN
            ROLLBACK TRAN
        END
        ELSE
        BEGIN
            WHILE @@TRANCOUNT>@n_starttcnt
            BEGIN
                COMMIT TRAN
            END
        END 
        EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrInventoryHoldDelete' 
        RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012 
        RETURN
    END
    ELSE
    BEGIN
        WHILE @@TRANCOUNT>@n_starttcnt
        BEGIN
            COMMIT TRAN
        END 
        RETURN
    END
END  
  

GO