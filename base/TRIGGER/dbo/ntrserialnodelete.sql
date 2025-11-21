SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/        
/* Trigger: ntrSerialNoDelete                                           */        
/* Creation Date:                                                       */        
/* Copyright: IDS                                                       */        
/* Written by:                                                          */        
/*                                                                      */        
/* Purpose: SOS#293687                                                  */        
/*                                                                      */        
/* Usage:                                                               */        
/*                                                                      */        
/* Called By: When records delete from SerialNo                         */        
/*                                                                      */        
/* PVCS Version: 1.0                                                    */        
/*                                                                      */        
/* Version: 5.4                                                         */        
/*                                                                      */        
/* Modifications:                                                       */        
/* Date         Author     Ver.  Purposes                               */    
/* 21-Oct-2014  KHLim      1.1   Insert Delete log  (KH01)              */
/* 03-Aug-2018  TLTING     1.2   ArchiveCop                             */
/************************************************************************/        
CREATE TRIGGER [ntrSerialNoDelete] ON [SerialNo]      
FOR  DELETE      
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
          
 DECLARE @b_Success          INT -- Populated by calls to stored procedures - was the proc successful?      
        ,@n_err              INT -- Error number returned by stored procedure or this trigger      
        ,@n_err2             INT -- For Additional Error Detection      
        ,@c_errmsg           NVARCHAR(250) -- Error message returned by stored procedure or this trigger      
        ,@n_continue         INT      
        ,@n_starttcnt        INT -- Holds the current transaction count      
        ,@c_preprocess       NVARCHAR(250) -- preprocess      
        ,@c_pstprocess       NVARCHAR(250) -- post process      
        ,@n_cnt              INT      
        ,@c_authority        NVARCHAR(1)      
 
 DECLARE @c_Pickdetailkey     NVARCHAR(10)    --(Kc01)
         ,@n_ShortPackQty     INT            --(Kc01)
        
 SELECT @n_continue = 1      
       ,@n_starttcnt = @@TRANCOUNT      

 IF (select count(*) from DELETED) =
 (select count(*) from DELETED where DELETED.ArchiveCop = '9')
 BEGIN
 SELECT @n_continue = 4
 END
                         
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 0         --    Start
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
               ,@c_errmsg = 'ntrSerialNoDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'       
      BEGIN
         INSERT INTO dbo.SerialNo_DELLOG ( SerialNoKey ) -- KH01
         SELECT SerialNoKey FROM DELETED                 -- KH01

         INSERT INTO dbo.DEL_SerialNo ( SerialNoKey, OrderKey, OrderLineNumber, StorerKey, SKU, SerialNo, Qty, Status, LotNo )     
         SELECT SerialNoKey, OrderKey, OrderLineNumber, StorerKey, SKU, SerialNo, Qty, Status, LotNo FROM DELETED  

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table SerialNo Failed. (ntrSerialNoDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END                  
      END
   END

 IF @n_continue=3 -- Error Occured - Process And Return      
 BEGIN      
     IF @@TRANCOUNT = 1      
     AND @@TRANCOUNT >= @n_starttcnt      
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
     EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrSerialNoDelete'       
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012       
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