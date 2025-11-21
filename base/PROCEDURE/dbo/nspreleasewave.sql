SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: nspReleaseWave                                      */  
/* Creation Date: 24-Sep-2012                                            */  
/* Copyright: IDS                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: Standard SP that called by isp_ReleaseWave_Wrapper if custom */  
/*          SP not setup                                                 */
/*                                                                       */  
/* Called By: wave                                                       */  
/*                                                                       */  
/* PVCS Version: 1.1                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */  
/* 01-04-2020  Wan08    1.1   Sync Exceed & SCE                          */
/*************************************************************************/   
CREATE PROC    [dbo].[nspReleaseWave]  
 @c_wavekey      NVARCHAR(10)  
 ,              @b_Success      int        OUTPUT  
 ,              @n_err          int        OUTPUT  
 ,              @c_errmsg       NVARCHAR(250)  OUTPUT  
 AS  
 BEGIN  
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
--  SET NOCOUNT ON
 DECLARE        @n_continue int        ,    
 @n_starttcnt int        , -- Holds the current transaction count  
 @n_cnt int              , -- Holds @@ROWCOUNT after certain operations  
 @c_preprocess NVARCHAR(250) , -- preprocess  
 @c_pstprocess NVARCHAR(250) , -- post process  
 @n_err2 int             , -- For Additional Error Detection  
 @b_debug int               -- Debug On Or Off  
 SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0, @b_debug = 0  
      /* #INCLUDE <SPRW1.SQL> */       
 IF @n_continue=1 or @n_continue=2  
 BEGIN  
    IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_wavekey)) IS NULL  
    BEGIN  
       SELECT @n_continue = 3  
       SELECT @n_err = 81000  
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Invalid Parameters Passed (nspReleaseWave)"  
    END  
 END -- @n_continue =1 or @n_continue = 2  

-- commented: wally 20.mar.03
-- update not needed since another update is being done below
/*
 IF @n_continue = 1 or @n_continue = 2  
 BEGIN  
    UPDATE WAVEDETAIL SET PROCESSFLAG = "", TrafficCop = NULL  
    WHERE WAVEKEY = @c_wavekey  
    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
    IF @n_err <> 0  
    BEGIN  
       SELECT @n_continue = 3  
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81008   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update of WaveDetail Failed (nspReleaseWave)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
    END  
 END  
*/

 -- Comment by SHONG 11-Jun-2003
 -- Not necessary
 /*
 IF @n_continue = 1 or @n_continue = 2  
 BEGIN  
    UPDATE WAVEDETAIL 
         SET PROCESSFLAG = "1", TrafficCop = NULL  
    FROM WAVEDETAIL, ORDERDETAIL (NOLOCK)
    WHERE WAVEDETAIL.WAVEKEY = @c_wavekey  
    and WAVEDETAIL.orderkey = ORDERDETAIL.orderkey  
    and (ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked) > 0  
    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
    IF @n_err <> 0  
    BEGIN  
       SELECT @n_continue = 3  
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81009   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update of WaveDetail Failed (nspReleaseWave)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
    END  
 END  
 */

   DECLARE @c_orderkey NVARCHAR(10), @c_taskdetailkey NVARCHAR(10)  

-- commented by wally: 20.mar.03
-- not being executed at all
/*
 IF @n_continue=1 or @n_continue=2  
 BEGIN  
    DECLARE @c_orderkey NVARCHAR(10), @c_taskdetailkey NVARCHAR(10)  
    SELECT @c_orderkey = SPACE(10)  
    WHILE (1=1)  
    BEGIN  
       SET ROWCOUNT 1  
       SELECT @c_orderkey = ORDERKEY  
       FROM WAVEDETAIL  
       WHERE orderkey > @c_orderkey  
       AND WAVEKEY = @c_wavekey  
       AND PROCESSFLAG = "1"
       -- Added By SHONG
       AND 1=2 -- Force this select statement failed, we not allow to reallocate. Interface for order allocate was done  
       ORDER BY orderkey  
       IF @@ROWCOUNT = 0  
       BEGIN  
          SET ROWCOUNT 0  
          BREAK  
       END  
       SET ROWCOUNT 0  
       DELETE FROM PICKDETAIL  
       WHERE CASEID LIKE "C%"  
       AND ORDERKEY = @c_orderkey  
       AND STATUS < "9"  
       SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
       IF @n_err <> 0  
       BEGIN  
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81015   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete from PickDetail Failed (nspReleaseWave)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
       END  
       IF @n_continue = 1 or @n_continue = 1  
       BEGIN  
          SELECT @b_success = 1  
          EXECUTE nspOrderProcessing  
          @c_orderkey,  
          "",  
      "N",  
          "N",  
          "",  
          @b_success   = @b_success OUTPUT,  
          @n_err       = @n_err OUTPUT,  
          @c_errmsg    = @c_errmsg OUTPUT  
          IF @b_success = 1  
          BEGIN  
             UPDATE PICKDETAIL  
             SET WAVEKEY = @c_wavekey,  
             TRAFFICCOP = NULL -- NOTE, this update line prevents pickdetail trigger from firing!  
             WHERE ORDERKEY = @c_orderkey  
             AND WAVEKEY = SPACE(10)  
             SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
             IF @n_err <> 0  
             BEGIN  
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update of PickDetail Failed (nspReleaseWave)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
             END  
             IF @n_continue = 1 or @n_continue = 2  
             BEGIN  
                UPDATE WAVEDETAIL SET processflag = "2"  
                WHERE ORDERKEY = @c_orderkey  
                AND WAVEKEY = @c_wavekey  
                SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
                IF @n_err <> 0  
                BEGIN  
                   SELECT @n_continue = 3  
                   SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81011   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                   SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update of WaveDetail Failed (nspReleaseWave)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
                END  
             END  
          END -- (IF @b_success = 1)  
       END -- (IF @n_continue = 1 or @n_continue = 1)  
    END  
    SET ROWCOUNT 0  
 END  
*/

 -- added by Jeff. This is required as they consider partial pallets for RF picking.
 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
    IF NOT EXISTS (SELECT 1 FROM NSQLCONFIG (NOLOCK) WHERE Configkey = 'RF_Enable' AND NSQLVALUE = '1' ) -- RF is enabled.
    BEGIN
       SELECT @n_continue = 4
    END
 END

 IF @n_continue = 1 or @n_continue = 2  
 BEGIN  
    -- Modify By SHONG 11-JUN-2003
    -- For Performance Tuning
    DECLARE @c_pickdetailkey NVARCHAR(10), 
            @c_pickmethod    NVARCHAR(1),
            @c_LOT           NVARCHAR(10),
            @c_LOC           NVARCHAR(10),
            @c_ID            NVARCHAR(10), 
            @n_Qty           int 

    

    SELECT @c_pickmethod = SPACE(1)  
    SELECT @c_OrderKey = SPACE(10)

    WHILE (1=1) and (@n_continue = 1 or @n_continue = 2)  
    BEGIN  
       SELECT @c_OrderKey = MIN(OrderKey)
       FROM   WAVEDETAIL (NOLOCK)
       WHERE  WaveKey = @c_WaveKey
       AND    OrderKey > @c_OrderKey

       IF dbo.fnc_RTrim(@c_OrderKey) IS NULL OR dbo.fnc_RTrim(@c_OrderKey) = '' 
          BREAK

       SELECT @c_pickdetailkey = SPACE(10)
       WHILE (2=2) and (@n_continue = 1 or @n_continue = 2)  
       BEGIN
          SELECT @c_pickdetailkey = MIN(pickdetailkey)
          FROM PICKDETAIL (NOLOCK) 
          WHERE OrderKey = @c_OrderKey  
            AND STATUS = '0'  
            AND pickdetailkey > @c_pickdetailkey
     
          IF dbo.fnc_RTrim(@c_pickdetailkey) IS NULL OR dbo.fnc_RTrim(@c_pickdetailkey) = ''
             BREAK

          SELECT @c_pickmethod = PICKMETHOD,
                 @c_LOT = LOT,
                 @c_LOC = LOC,
                 @c_ID  = ID,
                 @n_Qty = Qty 
          FROM PICKDETAIL (NOLOCK)
          WHERE PICKDETAILKEY = @c_pickdetailkey

          -- we will update the pickdetail candidates for RF picking to have pickmethod = '1' if they are partial pallets
          -- The rules are :
          -- 1. The pallet must not be commingle sku or commingle lot. Therefore cannot group by SKU, LOT
          IF @c_pickmethod <> '1' 
          BEGIN
             IF EXISTS (SELECT LT.LOC, LT.ID FROM LOTxLOCxID LT (NOLOCK)
                        WHERE LT.LOC = @c_LOC AND LT.ID = @c_ID AND LT.Qty > 0 
             GROUP BY LT.LOC, LT.ID
             HAVING COUNT(*) > 1 )
             BEGIN
                CONTINUE
             END
             -- 2. The location must be single pallet location (determined by the locationcategory setup in Codelkup table. The CODELKUP.SHORT value = 'S'
             -- 3. The location the pallet is sitting should have chargingtype = '1'
             -- 4. The Putawayzone for that location must have the UOM4Pickmethod set to 1 - RF Pallet picks
             IF NOT EXISTS ( SELECT 1 FROM LOTXLOCXID LT (NOLOCK)
                             JOIN LOC L (NOLOCK) ON ( L.LOC = LT.LOC 
                                  AND L.Loseid = '0'
                                  AND L.ChargingPallet = 1 ) 
                             JOIN CODELKUP C (NOLOCK) ON (L.LocationCategory = C.Code
                                  AND C.Listname = 'LOCCATEGRY'
                                  AND C.Short = 'S' )
                             JOIN PUTAWAYZONE PA (NOLOCK) ON (PA.PutawayZone = L.PutawayZone
                                                          AND PA.UOM4PickMethod = '1')
                             WHERE LT.LOT = @c_LOT
                             AND   LT.LOC = @c_LOC
                             AND   LT.ID  = @c_ID
                             AND   LT.Qty = @n_Qty -- pickdetail.qty = lotxlocxid.qty for the same loc and id
             )
             BEGIN
                -- The location does not have charging pallet = 1 or not a single pallet location.
                CONTINUE -- we don't want to include those 
             END  
          END -- pickmethod <> '1'
          IF EXISTS (SELECT 1 FROM TASKDETAIL (NOLOCK) WHERE pickdetailkey = @c_pickdetailkey  
                     and STATUS >="0" and STATUS < "9"  
          )  
          BEGIN  
             CONTINUE -- Go to the next line because this task already exists in taskdetail!  
          END  
          IF @n_continue = 1 or @n_continue = 2  
          BEGIN  
             BEGIN TRANSACTION tran_insert  
          END  
          IF @n_continue=1 or @n_continue=2  
          BEGIN  
             SELECT @b_success = 1  
             EXECUTE   nspg_getkey  
             "TaskDetailKey"  
             , 10  
             , @c_taskdetailkey OUTPUT  
             , @b_success OUTPUT  
             , @n_err OUTPUT  
             , @c_errmsg OUTPUT  
             IF NOT @b_success = 1  
             BEGIN  
                SELECT @n_continue = 3  
             END  
          END  
          IF @b_success = 1  
          BEGIN  
             INSERT TASKDETAIL  
             (  
             TaskDetailKey  
             ,TaskType  
             ,Storerkey  
             ,Sku  
             ,Lot  
             ,UOM  
             ,UOMQty  
             ,Qty  
             ,FromLoc  
             ,FromID  
             ,ToLoc  
             ,ToId  
             ,SourceType  
             ,SourceKey  
             ,WaveKey  
             ,Caseid  
             ,Priority  
             ,SourcePriority  
             ,OrderKey  
             ,OrderLineNumber  
             ,PickDetailKey  
             ,PickMethod  
             )  
             SELECT  
             @c_taskdetailkey  
             ,"PK"  
             ,PickDetail.Storerkey  
             ,PickDetail.Sku  
             ,PickDetail.Lot  
             ,PickDetail.UOM  
             ,PickDetail.UOMQty  
             ,PickDetail.Qty  
             ,PickDetail.Loc  
             ,PickDetail.ID  
             ,PickDetail.ToLoc  
             ,PickDetail.DropId  
             ,"PICKDETAIL"  
             ,PickDetail.pickdetailkey  
             ,PickDetail.WaveKey  
             ,PickDetail.Caseid  
             ,Orders.Priority  
             ,Orders.Priority  
             ,PickDetail.Orderkey  
             ,PickDetail.OrderLineNumber  
             ,PickDetail.PickDetailkey  
    --       ,PickDetail.PickMethod  
             , '1' -- we have to have pickmethod = '1' in order for the TM RF Task to show it.
             FROM PICKDETAIL (NOLOCK), ORDERS (NOLOCK)  
             WHERE PickDetail.Orderkey = Orders.Orderkey  
             AND pickdetailkey = @c_pickdetailkey  
             SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
             IF @n_err <> 0  
             BEGIN  
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81012   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Into TaskDetail Failed (nspReleaseWave)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
             END  
             IF @n_continue = 1 or @n_continue = 2  
             BEGIN  
                UPDATE PICKDETAIL SET STATUS = "1", PICKMETHOD = '1', -- we want to make sure that whatever goes to Taskdetail has pickmethod = '1' (coz it could be '8')
                       Trafficcop = NULL -- Prevent pickdetail trigger from firing so increasing performance  
                WHERE PICKDETAILKEY = @c_pickdetailkey  

                SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
                IF @n_err <> 0  
                BEGIN  
                   SELECT @n_continue = 3  
                   SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81013   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                   SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update on PickDetail Failed (nspReleaseWave)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
                END  
             END  
          END  
          IF @n_continue = 3  
          BEGIN  
             ROLLBACK TRANSACTION tran_insert  
          END  
          ELSE  
          BEGIN  
             COMMIT TRANSACTION tran_insert  
          END  
       END -- while 2=2 
    END -- while 1=1  
 END 

 IF @n_continue = 1 or @n_continue = 2  
 BEGIN  
    UPDATE WAVE 
       --SET STATUS = "1" -- Released     --(Wan01)  
      SET TMReleaseFlag = 'Y'             --(Wan01)   
         ,Trafficcop = NULL               --(Wan01) 
         ,EditWho = SUSER_SNAME()         --(Wan01)  
         ,EditDate= GETDATE()             --(Wan01) 
    WHERE WAVEKEY = @c_wavekey  
    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
    IF @n_err <> 0  
    BEGIN  
       SELECT @n_continue = 3  
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81014   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update on wave Failed (nspReleaseWave)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
    END  
 END  

      /* #INCLUDE <SPRW2.SQL> */  
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
    execute nsp_logerror @n_err, @c_errmsg, "nspReleaseWave"  
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