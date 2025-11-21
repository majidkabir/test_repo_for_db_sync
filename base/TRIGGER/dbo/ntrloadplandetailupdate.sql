SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrLoadPlanDetailUpdate                           */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: LOADPLANDETAIL UPDATE TRIGGER                               */
/*                                                                      */
/* Called By: LOADPLANDETAIL TABLE                                      */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.4	                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 17-Mar-2009  TLTING    1.1   Change user_name() to SUSER_SNAME()     */
/* 30-Jun-2009  NJOW01    1.2   Disable field in loadplan detail screen */
/*                              SOS#138667                              */
/* 10-Sep-2009  NJOW02    1.3   SOS#142570 - update userdefine01 to     */
/*                              orders.issued                           */
/* 22-May-2012  TLTING01  1.4   DM integrity - add update editdate B4   */
/*                              TrafficCop for status < '9'             */ 
/* 28-Oct-2013  TLTING    1.5   Review Editdate column update           */  
/* 16-May-2017  NJOW03    1.6   WMS-1798 Allow config to call custom sp */
/* 28-Sep-2018  TLTING    1.7   remove row lock                         */  
/************************************************************************/

CREATE TRIGGER [dbo].[ntrLoadPlanDetailUpdate]
 ON  [dbo].[LoadPlanDetail]
 FOR UPDATE
 AS
 IF @@ROWCOUNT = 0
 BEGIN
     RETURN
 END
 SET NOCOUNT ON
 SET ANSI_NULLS OFF
 SET QUOTED_IDENTIFIER OFF
 SET CONCAT_NULL_YIELDS_NULL OFF

 DECLARE
 @b_Success            int       -- Populated by calls to stored procedures - was the proc successful?
 ,         @n_err                int       -- Error number returned by stored procedure or this trigger
 ,         @n_err2 int              -- For Additional Error Detection
 ,         @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger
 ,         @n_continue int                 
 ,         @n_starttcnt int                -- Holds the current transaction count
 ,         @c_preprocess NVARCHAR(250)         -- preprocess
 ,         @c_pstprocess NVARCHAR(250)         -- post process
 ,         @n_cnt int                  
 SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

 IF UPDATE(ArchiveCop)
 BEGIN
    SELECT @n_continue = 4 
 END
 
 -- TLTING01
 IF EXISTS ( SELECT 1 FROM INSERTED, DELETED 
               WHERE INSERTED.LoadKey = DELETED.LoadKey AND INSERTED.LoadLineNumber = DELETED.LoadLineNumber
               AND ( INSERTED.[status] < '9' OR DELETED.[status] < '9' ) ) 
       AND (@n_continue = 1 or @n_continue = 2)
       AND NOT UPDATE(EditDate)
 BEGIN
    UPDATE LoadPlanDetail  
    SET EditDate = GETDATE(), EditWho = SUSER_SNAME(), Trafficcop = NULL
    FROM LoadPlanDetail, INSERTED
    WHERE LoadPlanDetail.LoadKey = INSERTED.LoadKey AND LoadPlanDetail.LoadLineNumber = INSERTED.LoadLineNumber
    AND LoadPlanDetail.[status] < '9'
    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=73102   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LoadPlanDetail. (ntrLoadPlanDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
    END
 END


 IF UPDATE(TrafficCop)
 BEGIN
    SELECT @n_continue = 4 
 END
      /* #INCLUDE <TRMBODU1.SQL> */     
 
 --SOS#138667 remove the loadplandetail update blocking. By NJOW 08JUN09
 /*IF @n_continue = 1 or @n_continue = 2
 BEGIN
     SELECT @n_continue = 3
     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=73102   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update of LoadPlanDetail is illegal. (ntrLoadPlanDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
 END*/

 IF ( @n_continue = 1 or @n_continue = 2 ) AND NOT UPDATE(EditDate)
 BEGIN
    UPDATE LoadPlanDetail  
    SET EditDate = GETDATE(), EditWho = SUSER_SNAME(), Trafficcop = NULL
    FROM LoadPlanDetail, INSERTED
    WHERE LoadPlanDetail.LoadKey = INSERTED.LoadKey AND LoadPlanDetail.LoadLineNumber = INSERTED.LoadLineNumber
    AND INSERTED.[status] in ( '9', 'C', 'CANC' )   -- tlting01
    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=73102   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LoadPlanDetail. (ntrLoadPlanDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
    END
 END
 
 --NJOW03
 IF @n_continue=1 or @n_continue=2          
 BEGIN   	  
    IF EXISTS (SELECT 1 FROM DELETED d   ----->Put INSERTED if INSERT action
               JOIN ORDERS o WITH (NOLOCK) ON d.Orderkey = o.Orderkey
               JOIN storerconfig s WITH (NOLOCK) ON  o.storerkey = s.storerkey    
               JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue
               WHERE  s.configkey = 'LoadPlanDetailTrigger_SP')   -----> Current table trigger storerconfig
    BEGIN        	  
       IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
          DROP TABLE #INSERTED
 
    	 SELECT * 
    	 INTO #INSERTED
    	 FROM INSERTED
        
       IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
          DROP TABLE #DELETED
 
    	 SELECT * 
    	 INTO #DELETED
    	 FROM DELETED
 
       EXECUTE dbo.isp_LoadPlanDetailTrigger_Wrapper ----->wrapper for current table trigger
                 'UPDATE'  -----> @c_Action can be INSERT, UPDATE, DELETE
               , @b_Success  OUTPUT  
               , @n_Err      OUTPUT   
               , @c_ErrMsg   OUTPUT  
 
       IF @b_success <> 1  
       BEGIN  
          SELECT @n_continue = 3  
                ,@c_errmsg = 'ntrLoadPlanDetailUpdate ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))  -----> Put current trigger name
       END  
       
       IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
          DROP TABLE #INSERTED
 
       IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
          DROP TABLE #DELETED
    END
 END    
 
/*
 -- Add for IDSV5, Extract from IDSPH
 /* Modified by June (FBR018) 20010920 */
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
    IF UPDATE(Weight) OR UPDATE(CUBE) OR UPDATE(ORDERKEY)
    BEGIN
       SELECT @c_insertloadkey = INSERTED.LoadKey
       FROM INSERTED
       SELECT  @n_weight = SUM(Weight), 
             @n_cube = SUM(Cube),
             @n_ordercnt = COUNT(OrderKey)
       FROM  LoadPlanDetail (NOLOCK)
       WHERE LoadKey = @c_insertloadkey
       SELECT @n_custcnt = COUNT(DISTINCT ORDERS.ConsigneeKey),
              @n_casecnt = SUM(LoadPlanDetail.casecnt)
       FROM  LoadPlanDetail (NOLOCK), ORDERS (NOLOCK)
       WHERE LoadPlanDetail.LoadKey = @c_insertloadkey
       AND   LoadPlanDetail.OrderKey = ORDERS.OrderKey
       AND   LoadPlanDetail.Loadkey = ORDERS.Loadkey
       SELECT @n_palletcnt = CONVERT(Integer, SUM(CASE WHEN PACK.Pallet = 0 THEN 0
          ELSE (ORDERDETAIL.OpenQty / PACK.Pallet) END))
       FROM  ORDERDETAIL (NOLOCK), LoadPlanDetail (NOLOCK), PACK (NOLOCK), SKU (NOLOCK)
       WHERE ORDERDETAIL.OrderKey = LoadPlanDetail.OrderKey
       AND ORDERDETAIL.Loadkey = LoadPlanDetail.Loadkey
       AND LoadPlanDetail.LoadKey = @c_insertloadkey
       AND ORDERDETAIL.Packkey = PACK.Packkey
       AND ORDERDETAIL.SKU = SKU.SKU
       IF @n_casecnt IS NULL SELECT @n_casecnt = 0
       IF @n_weight IS NULL SELECT @n_weight = 0
       IF @n_cube IS NULL SELECT @n_cube = 0
       IF @n_ordercnt IS NULL SELECT @n_ordercnt = 0
       IF @n_palletcnt IS NULL SELECT @n_palletcnt = 0
       IF @n_custcnt IS NULL SELECT @n_custcnt = 0
       UPDATE LoadPlan
       SET CustCnt = @n_custcnt,
          OrderCnt = @n_ordercnt,
          Weight = @n_weight,
          Cube = @n_cube,
          PalletCnt = @n_palletcnt,
          LoadPlan.CaseCnt = @n_casecnt,
          EditDate = GETDATE(),        --tlting
          EditWho = SUSER_SNAME()
       WHERE LoadPlan.LoadKey = @c_insertloadkey
       SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72601   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LoadPlan. (ntrLoadPlanDetailAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
       END
    END 
 END /* End of Modified by June (FBR018) 20010920 */
*/

--NJOW02 Start
IF @n_continue = 1 or @n_continue = 2
BEGIN
	IF UPDATE(userdefine01)
	BEGIN		 
		 UPDATE ORDERS 
		 SET ORDERS.Issued = LEFT(ISNULL(INSERTED.Userdefine01,''),1),
		     ORDERS.Trafficcop = NULL,
		     EditDate = GETDATE(),    --tlting
           EditWho = SUSER_SNAME()
		 FROM ORDERS (NOLOCK) 
		 JOIN INSERTED ON (ORDERS.Orderkey = INSERTED.Orderkey)
		 JOIN STORERCONFIG SC (NOLOCK) ON (SC.Storerkey = ORDERS.Storerkey)
		 WHERE SC.svalue = '1' AND SC.Configkey = 'LPMapUdf01ToOrdIssued'		

     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
     IF @n_err <> 0
     BEGIN
        SELECT @n_continue = 3
        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72602   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LoadPlanDetail. (ntrLoadPlanDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
     END
  END
END
--NJOW02 End

/* -- Remark for IDSV5 by June 28.Jun.02, Extract from IDSMY
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
    UPDATE ORDERS
    SET ORDERS.LoadKey = INSERTED.LoadKey,
        Trafficcop = NULL
    FROM ORDERS, INSERTED
    WHERE ORDERS.OrderKey = INSERTED.OrderKey
    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=73114   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table ORDERS. (ntrLoadPlanDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
    END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
    UPDATE ORDERDETAIL
    SET ORDERDETAIL.LoadKey = INSERTED.LoadKey,
        Trafficcop = NULL
    FROM ORDERDETAIL, INSERTED
    WHERE ORDERDETAIL.OrderKey = INSERTED.OrderKey
    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=73114   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table ORDERDETAIL. (ntrLoadPlanDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
    END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
    UPDATE ORDERS
    SET Status = '5'
    FROM ORDERS, INSERTED
    WHERE ORDERS.OrderKey = INSERTED.OrderKey
    AND INSERTED.Status = '5'
    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=73104   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table ORDERS. (ntrLoadPlanDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
    END
 END
*/
      /* #INCLUDE <TRMBODU2.SQL> */
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
    execute nsp_logerror @n_err, @c_errmsg, 'ntrLoadPlanDetailUpdate'
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



GO