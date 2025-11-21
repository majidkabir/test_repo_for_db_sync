SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspRFOP04                                          */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC    [dbo].[nspRFOP04]
 @c_sendDelimiter    NVARCHAR(1)
 ,              @c_ptcid            NVARCHAR(5)
 ,              @c_userid           NVARCHAR(10)
 ,              @c_taskId           NVARCHAR(10)
 ,              @c_databasename     NVARCHAR(30)
 ,              @c_appflag          NVARCHAR(2)
 ,              @c_recordType       NVARCHAR(2)
 ,              @c_server           NVARCHAR(30)
 ,              @c_caseid           NVARCHAR(18)
 ,              @c_snum1            NVARCHAR(20)
 ,              @c_snum2            NVARCHAR(20)
 ,              @c_snum3            NVARCHAR(20)
 ,              @c_snum4            NVARCHAR(20)
 ,              @c_snum5            NVARCHAR(20)
 ,              @c_snum6            NVARCHAR(20)
 ,              @c_snum7            NVARCHAR(20)
 ,              @c_snum8            NVARCHAR(20)
 ,              @c_other11          NVARCHAR(20)
 ,              @c_other12          NVARCHAR(20)
 ,              @c_other13          NVARCHAR(20)
 ,              @c_other14          NVARCHAR(20)
 ,              @c_other15          NVARCHAR(20)
 ,              @c_other16          NVARCHAR(20)
 ,              @c_other17          NVARCHAR(20)
 ,              @c_other18          NVARCHAR(20)
 ,              @c_other21          NVARCHAR(20)
 ,              @c_other22          NVARCHAR(20)
 ,              @c_other23          NVARCHAR(20)
 ,              @c_other24          NVARCHAR(20)
 ,              @c_other25          NVARCHAR(20)
 ,              @c_other26          NVARCHAR(20)
 ,              @c_other27          NVARCHAR(20)
 ,              @c_other28          NVARCHAR(20)
 ,              @c_wgt1             NVARCHAR(20)
 ,              @c_wgt2             NVARCHAR(20)
 ,              @c_wgt3             NVARCHAR(20)
 ,              @c_wgt4             NVARCHAR(20)
 ,              @c_wgt5             NVARCHAR(20)
 ,              @c_wgt6             NVARCHAR(20)
 ,              @c_wgt7             NVARCHAR(20)
 ,              @c_wgt8             NVARCHAR(20)
 ,              @c_outstring        NVARCHAR(255)  OUTPUT
 ,              @b_Success          int        OUTPUT
 ,              @n_err              int        OUTPUT
 ,              @c_errmsg           NVARCHAR(250)  OUTPUT
 AS
 BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF
   
 DECLARE @b_debug int
 SELECT @b_debug = 0
 DECLARE  @n_continue int        ,  
 @n_starttcnt int        , -- Holds the current transaction count
 @c_preprocess NVARCHAR(250) , -- preprocess
 @c_pstprocess NVARCHAR(250) , -- post process
 @n_err2 int               -- For Additional Error Detection
 DECLARE @c_retrec NVARCHAR(2) -- Return Record "01" = Success, "09" = Failure
 DECLARE @c_dbnamestring NVARCHAR(255)
 DECLARE @n_cqty int, @n_returnrecs int
 SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
 SELECT @c_retrec = "01"
 SELECT @n_returnrecs=1
 DECLARE @c_nextlotxiddetailkey NVARCHAR(10), @c_orderkey NVARCHAR(10), @c_orderlinenumber NVARCHAR(5),
 @c_pickdetailkey NVARCHAR(18), @c_lot NVARCHAR(10), @c_id NVARCHAR(18)
      /* #INCLUDE <SPRFOP04_1.SQL> */     
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 SELECT  @c_pickdetailkey =PickDetailKey,
 @c_orderkey = OrderKey,
 @c_orderlinenumber = OrderLineNumber,
 @c_lot = Lot,
 @c_id = ID
 FROM PICKDETAIL
 WHERE PickDetail.CaseId = @c_caseid
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 DECLARE @n_wgt1 float, @n_wgt2 float, @n_wgt3 float, @n_wgt4 float,
 @n_wgt5 float, @n_wgt6 float, @n_wgt7 float, @n_wgt8 float
 SELECT @n_wgt1 = CONVERT(float,@c_wgt1),
 @n_wgt2 = CONVERT(float,@c_wgt2),
 @n_wgt3 = CONVERT(float,@c_wgt3),
 @n_wgt4 = CONVERT(float,@c_wgt4),
 @n_wgt5 = CONVERT(float,@c_wgt5),
 @n_wgt6 = CONVERT(float,@c_wgt6),
 @n_wgt7 = CONVERT(float,@c_wgt7),
 @n_wgt8 = CONVERT(float,@c_wgt8)
 END
 DECLARE @i_set int, @f_cur_wgt float,
 @c_cur_other1 NVARCHAR(20), @c_cur_other2 NVARCHAR(20), @c_cur_other3 NVARCHAR(20)
 SELECT @i_set = 1
 BEGIN TRAN
 WHILE @i_set <= 8 and (@n_continue=1 OR @n_continue=2)
 BEGIN
 IF @i_set = 1 SELECT @f_cur_wgt = @n_wgt1, @c_cur_other1 = @c_snum1,
 @c_cur_other2 = @c_other11, @c_cur_other3 = @c_other21
 IF @i_set = 2 SELECT @f_cur_wgt = @n_wgt2, @c_cur_other1 = @c_snum2,
 @c_cur_other2 = @c_other12, @c_cur_other3 = @c_other22
 IF @i_set = 3 SELECT @f_cur_wgt = @n_wgt3, @c_cur_other1 = @c_snum3,
 @c_cur_other2 = @c_other13, @c_cur_other3 = @c_other23
 IF @i_set = 4 SELECT @f_cur_wgt = @n_wgt4, @c_cur_other1 = @c_snum4,
 @c_cur_other2 = @c_other14, @c_cur_other3 = @c_other24
 IF @i_set = 5 SELECT @f_cur_wgt = @n_wgt5, @c_cur_other1 = @c_snum5,
 @c_cur_other2 = @c_other15, @c_cur_other3 = @c_other25
 IF @i_set = 6 SELECT @f_cur_wgt = @n_wgt6, @c_cur_other1 = @c_snum6,
 @c_cur_other2 = @c_other16, @c_cur_other3 = @c_other26
 IF @i_set = 7 SELECT @f_cur_wgt = @n_wgt7, @c_cur_other1 = @c_snum7,
 @c_cur_other2 = @c_other17, @c_cur_other3 = @c_other27
 IF @i_set = 8 SELECT @f_cur_wgt = @n_wgt8, @c_cur_other1 = @c_snum8,
 @c_cur_other2 = @c_other18, @c_cur_other3 = @c_other28
 IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_cur_other1)) IS NOT NULL
 OR dbo.fnc_LTrim(dbo.fnc_RTrim(@c_cur_other2)) IS NOT NULL
 OR dbo.fnc_LTrim(dbo.fnc_RTrim(@c_cur_other3)) IS NOT NULL
 OR @f_cur_wgt <> 0.0
 BEGIN
 SELECT @b_success = 0
 EXECUTE nspg_getkey
 "LotxIDDetailKey",
 10,
 @c_nextlotxidDetailkey     OUTPUT,
 @b_success                 OUTPUT,
 @n_err                     OUTPUT,
 @c_errmsg                  OUTPUT
 IF NOT @b_success = 1
 BEGIN
 SELECT @n_continue=3
 SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=87301   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Getting Next LotxIDDetail key failed . (nspRFRC03)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 INSERT LOTxIDDetail (LotxIDDetailKey,
 OrderKey,
 OrderLineNumber,
 PickDetailKey,
 IOFlag,
 LOT,
 ID,
 Wgt,
 Other1,
 Other2,
 Other3)
 Values (@c_nextlotxiddetailkey,
 @c_orderkey,
 @c_orderlinenumber,
 @c_pickdetailkey,
 "O",
 @c_lot,
 @c_id,
 @f_cur_wgt,
 @c_cur_other1,
 @c_cur_other2,
 @c_cur_other3)
 SELECT @n_err = @@ERROR
 IF @n_err <> 0
 BEGIN
 SELECT @n_continue = 3
 SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=87302   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On LotxIDDetail. (nspRFRC03)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 END
 END
 END -- if value was entered
 SELECT @i_set = @i_set + 1
 END  -- while next set loop
 IF @n_continue=3
 BEGIN
 IF @c_retrec="01"
 BEGIN
 SELECT @c_retrec="09"
 END
 END
 ELSE
 BEGIN
 IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_id)) IS NOT NULL
 BEGIN
 SELECT @c_errmsg = "Pick Ok. Please press ENTER and fill out the additional information."
 SELECT @c_retrec = "02"
 END
 IF @c_retrec = "" or @c_retrec = "09"
 BEGIN
 SELECT @c_retrec="01"
 END
 END
      /* #INCLUDE <SPRFOP04_2.SQL> */
 SELECT @c_outstring =   @c_ptcid     + @c_senddelimiter
 + dbo.fnc_RTrim(@c_userid)    + @c_senddelimiter
 + dbo.fnc_RTrim(@c_taskid)    + @c_senddelimiter
 + dbo.fnc_RTrim(@c_databasename) + @c_senddelimiter
 + dbo.fnc_RTrim(@c_appflag)   + @c_senddelimiter
 + dbo.fnc_RTrim(@c_retrec)    + @c_senddelimiter
 + dbo.fnc_RTrim(@c_server)    + @c_senddelimiter
 + dbo.fnc_RTrim(@c_errmsg)
 SELECT dbo.fnc_RTrim(@c_outstring)
 IF @n_continue=3  -- Error Occured - Process And Return
 BEGIN
 SELECT @b_success = 0
 IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
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
 execute nsp_logerror @n_err, @c_errmsg, "nspRFOP04"
 RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
 RETURN
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