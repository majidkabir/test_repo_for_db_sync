SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************************/ 
/* Trigger: ntrBillOfMaterialDelete                                               	*/ 
/*  Author  : Ricky Yee                                                             */  
/*  Date    : Nov 24th, 2007                                                        */  
/*  Purpose : To Check against the Inventory upon                                   */  
/*         the deletion of the BOM record.                                          */  
/*         If Inventory > 0, Delete Not Allow                                       */  
/*                                                                                  */  
/* Date        Rev  	Author   	Purposes                                           */   
/* 24-Nov-2007 1.0  	Ricky    	Created                                            */  
/* 26-Nov-2007 1.1  	Vicky    	Add in StorerConfigkey to control                  */  
/*                           		deletion (Vicky01)                                 */  
/* 19-Apr-2011 1.2  	TLTING   	Insert Delete log                                  */
/* 14-Jul-2011 1.3  	KHLim02  	GetRight for Delete log                            */
/* 2022-04-12  1.4	kelvinongcy	WMS-19428 prevent bulk update or delete (kocy01)	*/
/************************************************************************************/  
  
CREATE   TRIGGER [dbo].[ntrBillOfMaterialDelete]  
ON  [dbo].[BillOfMaterial]   
FOR DELETE  
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
   
   DECLARE  
        @b_Success         int       -- Populated by calls to stored procedures - was the proc successful?  
      , @n_err             int       -- Error number returned by stored procedure or this trigger  
      , @n_err2            int       -- For Additional Error Detection  
      , @c_errmsg          NVARCHAR(250) -- Error message returned by stored procedure or this trigger  
      , @n_continue        int                   
      , @n_starttcnt       int       -- Holds the current transaction count  
      , @c_preprocess      NVARCHAR(250) -- preprocess  
      , @c_pstprocess      NVARCHAR(250) -- post process  
      , @n_cnt             int        
      , @c_authority       NVARCHAR(1)  -- KHLim02
 
   DECLARE @cStorerkey     NVARCHAR(15) -- (Vicky01)  
   
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT  

   IF (select count(*) from DELETED WITH (NOLOCK)) = (select count(*) from DELETED WITH (NOLOCK) where DELETED.ArchiveCop = '9')
   BEGIN
      SELECT @n_continue = 4
   END 
 
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN   
       -- (Vicky01 - Start)  
       IF EXISTS (SELECT 1 FROM StorerConfig SCFG (NOLOCK)  
                  JOIN DELETED WITH (NOLOCK) ON (DELETED.Storerkey = SCFG.Storerkey)  
                  WHERE SCFG.Configkey = 'PrepackByBOM'  
                  AND   SCFG.sValue = '1')  
       BEGIN -- (Vicky01 - End) 
       
           IF (Select Count(1) from lotattribute la (nolock), lotxlocxid lli (nolock), DELETED WITH (NOLOCK)   
               Where la.lot = lli.lot   
               And DELETED.storerkey = LA.storerkey   
               And DELETED.sku = LA.lottable03   
               And DELETED.componentsku = LA.sku  
               And lli.qty > 0) > 0   
           BEGIN  
             SELECT @n_continue = 3  
             SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60001   -- Should Be Set To The SQL Err message but I don't know how to do so.  
             SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Inventory Exists! Delete trigger On BillOfMaterial Failed. (ntrBillOfMaterialDelete)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "  
           END  
        END -- Configkey  
   END  

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
               ,@c_errmsg = 'ntrBillOfMaterialDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'         --    End   (KHLim02)
      BEGIN
         INSERT INTO dbo.BillOfMaterial_DELLOG ( StorerKey, Sku, ComponentSku )
         SELECT StorerKey, Sku, ComponentSku 
         FROM DELETED WITH (NOLOCK)

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Err message but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table BillOfMaterial Failed. (ntrBillOfMaterialDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
      END
   END

   IF ( (SELECT COUNT(1) FROM Deleted WITH (NOLOCK) ) > 100 )    --kocy01
       AND NOT EXISTS (SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE Listname = 'TrgUserID' AND Short = '1' AND Code = SUSER_NAME()) 
   BEGIN      
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68102   -- Should Be Set To The SQL Err message but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Failed On Table BillOfMaterial. Batch Delete not allow! (ntrBillOfMaterialDelete)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
   END
   
 IF @n_continue=3  -- Error Occured - Process And Return  
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
    execute nsp_logerror @n_err, @c_errmsg, "ntrBillOfMaterialDelete"  
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