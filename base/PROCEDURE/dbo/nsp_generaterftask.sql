SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nsp_GenerateRFTask                                 */
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
/* Date         Author   ver  Purposes                                  */
/* 14-09-2009   TLTING   1.1  ID field length	(tlting01)              */
/* 21-06-2017   TLTING   1.2  Performance tune - rtrim                  */
/************************************************************************/

CREATE PROC [dbo].[nsp_GenerateRFTask] (@c_loadkey NVARCHAR(10), @n_taskdetailcheck int OUTPUT)     
AS    
BEGIN    
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_pickheaderkey NVARCHAR(10),    
   @n_continue  int,    
   @c_errmsg  NVARCHAR(255),    
   @b_success  int,    
   @n_err  int,    
   @c_sku  NVARCHAR(20),    
   @n_qty  float,    
   @c_loc  NVARCHAR(10),    
   @c_storer  NVARCHAR(15),    
   @c_orderkey  NVARCHAR(10),    
   @c_TrfRoom           NVARCHAR(5), -- LoadPlan.TrfRoom       
   @c_UOM               NVARCHAR(10),    
   @c_Lot               NVARCHAR(10),    
   @c_StorerKey         NVARCHAR(15),
   @n_RowNo             int,    
   @n_PalletCnt         int,
   @c_pickdetailkey NVARCHAR(10),    
   @c_id NVARCHAR(18),  					-- tlting01
   @b_debug int,
   @c_taskdetailkey NVARCHAR(10) ,
   @c_packkey NVARCHAR(10),
   @n_pallet int,
   @n_sumloadqty int
   ,@n_starttcnt int
   ,@c_UOM4PickMethod NVARCHAR(1)

   select @b_debug = 0, @n_continue = 1

   DECLARE @n_PrevGroup        int,    
           @n_RowCount         int,    
           @n_TotCases         int,    
           @c_PrevOrderKey     NVARCHAR(10),    
           @c_Transporter      NVARCHAR(60),    
           @c_VehicleNo        NVARCHAR(10),    
           @c_firsttime        NVARCHAR(1) ,
           @n_AccumQty     int   

   DECLARE  @c_previous_storerkey NVARCHAR(15),
         @c_previous_lot NVARCHAR(10),
         @c_previous_loc NVARCHAR(10),
         @c_previous_id NVARCHAR(18),			-- tlting01
         @c_previous_sku NVARCHAR(20),
         @c_breakgroup NVARCHAR(1),
         @c_update NVARCHAR(1),
         @n_groupno int,
         @n_uomqty int,
         @c_pickmethod NVARCHAR(1),
         @n_count int

   Create table #temp_pick 
   (Pickdetailkey NVARCHAR(10) NULL,
   Storerkey NVARCHAR(15) NULL,
   SKU NVARCHAR(20) NULL,
   LOT NVARCHAR(10) NULL,
   LOC NVARCHAR(10) NULL,
   ID NVARCHAR(18) NULL,				-- tlting01
   UOM NVARCHAR(10) NULL,
   Qty int NULL,
   Palletcount int null,
   TotalPallet int null,
   groupno int null,
   taskdetailkey NVARCHAR(10) NULL,
   Pickmethod NVARCHAR(1) NULL )

-- ***********************************************************************************************************
-- NOTE TO DEVELOPERS.
-- this stored procedure has to be executed first - controlled in front end
-- this is because the we want to batch case/piece picks together, and if they make up a pallet, we will send to RF based on setup in putawayzone
-- we cannot update the pickdetail.uom for fear of affecting other processes, especially the inventory.
-- A new flag called RF_BATCH_PICK in NSQLCONFIG table is introduced. THis allows user to turn on/off the RF batch picking.
-- We will use the putawayzone table, pickmethod setup to identify if the tasks should be sent as RF pick tasks or Paper Pick tasks
-- Current version only supports RF Pallet batch picking. RF Cases/Piece pickings are not supported. Therefore, if the putawayzone setup will not be applicable.

-- ***********************************************************************************************************  

   -- Find out if tasks has been generated for that load before....
   IF EXISTS (SELECT 1 FROM TASKDETAIL (NOLOCK) WHERE SOURCEKEY = @c_loadkey AND SOURCETYPE = 'BATCHPICK')
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81004   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Tasks have been generated previously. (nsp_GenerateRFTask)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "     
   END

   -- check if the RF_BATCH_PICK is turned on 
   -- IF Turned OFF, everything will be on picklist.
   IF NOT EXISTS (SELECT 1 FROM NSQLCONFIG (NOLOCK) WHERE CONFIGKEY = 'RF_BATCH_PICK' AND NSQLVALUE = '1')
   BEGIN
      SELECT @n_continue = 4, @n_taskdetailcheck = 0
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE @n_line int

      SELECT @c_trfroom = TRFROOM FROM LOADPLAN (NOLOCK) WHERE LOADKEY = @c_loadkey

      SELECT @n_line = 0, @n_taskdetailcheck = 0
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN --@n_continue  tag 02            
         SELECT @n_AccumQty = 0
         SELECT @n_count = 0

         SELECT @c_previous_storerkey = ''
               ,@c_previous_sku = ''
               ,@c_previous_lot = ''
               ,@c_previous_id  = ''
               ,@c_previous_loc = ''

         DECLARE CURSOR_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
         SELECT P1.Pickdetailkey, P1.STORERKEY, P1.SKU, P1.LOT, P1.LOC, P1.ID, P1.UOM, P2.Pallet, P1.QTY  
         FROM LOADPLANDETAIL L1 (NOLOCK) 
         JOIN ORDERS O1 (NOLOCK) ON (O1.ORDERKEY =  L1.ORDERKEY)
         JOIN PICKDETAIL P1 (NOLOCK) ON (P1.ORDERKEY = O1.ORDERKEY)
         JOIN PACK P2 (NOLOCK) ON (P2.PACKKEY = P1.PACKKEY)
         WHERE L1.LOADKEY = @c_loadkey
         AND P1.STATUS < '3'  
         AND O1.USERDEFINE08 = 'N' -- FOR NON-Discrete ORDERS ONLY.  
         AND O1.Type NOT IN ('M', 'I') -- exclude manual orders
          AND ( ISNULL(RTRIM(P1.PICKSLIPNO),'') = ''   )
         ORDER BY P1.Storerkey, P1.SKU, Lot, Loc, Id, P1.QTY desc, UOM

         OPEN CURSOR_PICK 
         WHILE ( 1 = 1)-- while tag 01
         BEGIN  
            FETCH NEXT FROM CURSOR_PICK INTO @c_pickdetailkey, @c_storerkey, @c_sku, @c_lot, @c_loc, @c_id, @c_uom, @n_PalletCnt, @n_qty  
     
            IF @@FETCH_STATUS = -1 BREAK  
            
            IF @b_debug = 1  
            BEGIN  
               SELECT 'Line Number', @n_line
               SELECT '@c_pickdetailkey' = @c_pickdetailkey, '@c_storerkey' = @c_storerkey, '@c_sku' = @c_sku, '@c_lot' = @c_lot,   
               '@c_loc' = @c_loc, '@c_id' = @c_id, '@n_qty' = @n_qty  , '@c_uom' = @c_uom, '@n_PalletCnt' = @n_PalletCnt
            END   

            SELECT @c_breakgroup = '0'

            IF ( @c_storerkey <> @c_previous_storerkey ) OR
               ( @c_sku <> @c_previous_sku ) OR
               ( @c_lot <> @c_previous_lot ) OR
               ( @c_id  <> @c_previous_id )  OR
               ( @c_loc <> @c_previous_loc) 
            BEGIN
               IF @b_debug = 2
               BEGIN
                  SELECT '@c_previous_storerkey' ,@c_previous_storerkey, '@c_storerkey', @c_storerkey, '@c_previous_id', @c_previous_id
                  SELECT '@c_id', @c_id, '@c_previous_loc', @c_previous_loc, '@c_loc', @c_loc, '@c_previous_lot', @c_previous_lot, '@c_lot', @c_lot 
                  SELECT '@c_sku', @c_sku
               END
               SELECT @c_previous_storerkey = @c_storerkey 
               SELECT @c_previous_sku = @c_sku
               SELECT @c_previous_lot = @c_lot
               SELECT @c_previous_id = @c_id
               SELECT @c_previous_loc = @c_loc
               SELECT @c_breakgroup = '1'
               SELECT @n_AccumQty = 0
            END
            
            SELECT @n_AccumQty = @n_AccumQty + @n_qty

            IF ( @n_AccumQty > @n_PalletCnt )
            BEGIN
               SELECT @n_AccumQty = @n_qty, @c_breakgroup = '1'
            END

            IF  @c_breakgroup = '1' SELECT @n_line = @n_line + 1

            SELECT @c_pickmethod = '1'

            INSERT INTO #TEMP_PICK VALUES (@c_pickdetailkey, @c_storerkey, @c_sku, @c_lot, @c_loc, @c_id, @c_uom, @n_qty, @n_AccumQty, @n_PalletCnt, @n_line, null, @c_pickmethod)

            SELECT @n_err = @@ERROR    
            IF @n_err <> 0    
            BEGIN    
               SELECT @n_continue = 3    
               SELECT @c_errmsg = CONVERT(char(250), @n_err), @n_err = 81002   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg = "NSQL" + CONVERT(char(5), @n_err) + ": Insert into Taskdetail Failed (nsp_GenerateRFTask)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "    
               BREAK
            END
            ELSE
            BEGIN
               -- IF @c_pickmethod = '1' 
               SELECT @n_count = @n_count + 1
               IF ( @n_AccumQty = @n_PalletCnt ) SELECT @n_line = @n_line + 1
            END
         END -- while
         CLOSE CURSOR_PICK
         DEALLOCATE CURSOR_PICK
      END -- @n_continue

      IF @b_debug = 1
      BEGIN
         SELECT 'Cut 1 from #temp_pick'
         select * from #temp_pick
      END            

      IF @n_count = 0
      BEGIN
         SELECT @n_continue = 4, @n_taskdetailcheck = 0
         IF @b_debug = 1 
         SELECT 'Temp pick does not have pickmethod = 1 and @n_continue ', @n_continue
      END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN

         DECLARE CURSOR_GROUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT GROUPNO, LOC 
         FROM  #TEMP_PICK
         WHERE PalletCount = TotalPallet
   
         OPEN CURSOR_GROUP 
         WHILE ( 1 = 1)-- while tag 01
         BEGIN  
            FETCH NEXT FROM CURSOR_GROUP INTO @n_groupno, @c_loc

            IF @@FETCH_STATUS = -1 
            BEGIN
               IF @b_debug = 1 SELECT 'break'
               BREAK  
            END

            IF @c_loc <> '' 
            BEGIN
               SELECT @c_UOM4PickMethod = UOM4PickMethod FROM PUTAWAYZONE (NOLOCK) 
               WHERE PutawayZone IN (SELECT PUTAWAYZONE FROM LOC (NOLOCK) WHERE LOC = @c_loc)

               IF @c_uom4pickmethod <> '1' -- they don't want it to be in RF Task.
               BEGIN
                  CONTINUE
               END 
            END

            -- for each group, we want to generate a taskdetailkey         
            EXECUTE nspg_getkey    
            "TaskDetailKey",    
            10,    
            @c_taskdetailkey OUTPUT,    
            @b_success OUTPUT,    
            @n_err OUTPUT,    
            @c_errmsg OUTPUT                 
            IF NOT @b_success = 1    
            BEGIN    
               SELECT @n_continue = 3    
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81004   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Unable to Get TaskDetailKey (nsp_GenerateRFTask)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "    
               BREAK
            END 
            IF @b_debug = 1
            BEGIN
               SELECT 'Generate taskdetailkey and n_continue = ', @n_continue       
               SELECT '@c_taskdetailkey' = @c_taskdetailkey
            END

            IF @n_continue = 1 OR @n_continue = 2
            BEGIN -- @n_continue 1
               UPDATE #TEMP_PICK
               SET TASKDETAILKEY = @c_taskdetailkey
               WHERE GROUPNO = @n_groupno
   
               SELECT @n_err = @@ERROR
               IF @n_err <> 0    
               BEGIN    
                  SELECT @n_continue = 3    
                  SELECT @c_errmsg = CONVERT(char(250), @n_err), @n_err = 81002   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                  SELECT @c_errmsg = "NSQL" + CONVERT(char(5), @n_err) + ": Update of #temp_pick Failed (nsp_GenerateRFTask)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "    
                  BREAK
               END
               IF @b_debug = 1 SELECT 'Complete updating TEMPPICK with taskdetailkey  and n_continue = ', @n_continue
   
               IF @n_continue = 1 or @n_continue = 2
               BEGIN -- @n_continue = 2
                  SELECT @c_storerkey = '', @c_sku = '', @c_lot = '', @c_uom = '', @n_uomqty = 0, @n_qty = 0, @c_loc = '', @c_id = ''
   
                  SELECT distinct @c_storerkey = Storerkey,
                         @c_sku = SKU,
                         @c_lot = LOT,
                         @c_uom = '1',
                         @n_uomqty = 1,
                         @n_qty = PalletCount,
                         @c_loc = LOC,
                         @c_id = ID,
                         @c_pickmethod = PICKMETHOD
                  FROM #TEMP_PICK (NOLOCK)
                  WHERE Taskdetailkey = @c_taskdetailkey
                  AND GROUPNO = @n_groupno
                  AND  PalletCount = TotalPallet
                  AND ISNULL(RTRIM(Taskdetailkey),'') <> ''  
         
                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0    
                  BEGIN                      
                     SELECT @n_continue = 3    
                     SELECT @c_errmsg = CONVERT(char(250), @n_err), @n_err = 81032   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                     SELECT @c_errmsg = "NSQL" + CONVERT(char(5), @n_err) + ": Unable to retrieve records from #temp_pick (nsp_GenerateRFTask)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "    
                     BREAK
                  END

                  IF @b_debug = 1
                  BEGIN
                     SELECT 'storerkey' = @c_storerkey, 
                            'sku' = @c_sku, 'lot' = @c_lot, 'uom' = @c_uom, 'uomqty' = @n_uomqty, 
                            'qty' = @n_qty, 'loc' = @c_loc, 'id' = @c_id, 'pickmethod' = @c_pickmethod,
                            'taskdetailkey' = @c_taskdetailkey
                     SELECT 'Select distinct records based on taskdetailkey and groupno  and n_continue = ', @n_continue
                  END

                  IF @n_continue = 1 OR @n_continue = 2
                  BEGIN -- @n_continue 3
                     -- Get the full pallet record as we need to insert that into taskdetail. the rest are just for reference.
                     INSERT INTO TASKDETAIL (taskdetailkey, tasktype, storerkey, sku, lot, UOM, UOMQTY,
                                       qty, FromLoc, FromID, ToLoc, TOID, PickMethod, Status, Sourcetype,
                                       sourcekey , priority)
                     VALUES (@c_taskdetailkey, 'PK', @c_storerkey, @c_sku, @c_lot, @c_uom, @n_uomqty,
                              @n_qty, @c_loc, @c_id, @c_trfroom, @c_id, @c_pickmethod, '0', 'BATCHPICK',
                              @c_loadkey , '3')
            
                     SELECT @n_err = @@ERROR
                     IF @n_err <> 0    
                     BEGIN    
                        SELECT @n_continue = 3    
                        SELECT @c_errmsg = CONVERT(char(250), @n_err), @n_err = 81032   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                        SELECT @c_errmsg = "NSQL" + CONVERT(char(5), @n_err) + ": Unable to retrieve records from #temp_pick (nsp_GenerateRFTask)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "    
                        BREAK
                     END
                     ELSE
                     BEGIN
                        SELECT @n_taskdetailcheck = @n_taskdetailcheck + 1
                     END
                  END -- @n_continue 3       
                  IF @b_debug = 1 SELECT 'Completed insertion of taskdetail record and n_continue = ', @n_continue
               END -- @n_continue 2
            END -- @n_continue 1 
         END -- WHILE
         CLOSE CURSOR_GROUP
         DEALLOCATE CURSOR_GROUP
      END
      IF @b_debug = 1
      BEGIN
         SELECT 'Cut 2 from #temp_pick'
         select * from #temp_pick
      END   

      -- UPDATE PICKDETAILs with the taskdetailkey...
      IF @b_debug  = 1 SELECT 'Updating Pickdetail records with Taskdetailkey'

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN -- update pickdetail with the appropriate taskkey . we can't update UOM field, as it will affect reduction of inventory quantity.
         DECLARE CURSOR_UPDATEPICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT PICKDETAILKEY, Taskdetailkey 
         FROM #TEMP_PICK 
         WHERE ISNULL(RTRIM(Taskdetailkey), '') <> ''
         
         OPEN CURSOR_UpdatePICK
   
         WHILE ( 1 = 1)-- while tag 01
         BEGIN  
            SELECT @c_pickdetailkey = '', @c_taskdetailkey = ''
               -- SELECT @c_storerkey = '', @c_sku = '', @c_lot = '', @c_loc = '', @c_id = '', @c_uom = '', @n_PalletCnt = 0, @n_qty = 0
            FETCH NEXT FROM CURSOR_UpdatePick INTO @c_pickdetailkey, @c_taskdetailkey
            IF @@FETCH_STATUS = -1 BREAK  
   
            -- we need to update the pickmethod = '1' after assigning to RF task... this will ensure that the REPRINT pick slip does not pick up that record
   
            UPDATE PICKDETAIL
            SET PICKSLIPNO = @c_taskdetailkey, pickmethod = '1' , trafficcop = null, editdate = getdate()
            WHERE PICKDETAILKey = @c_pickdetailkey
            AND STATUS < '3'        
   

            SELECT @n_err = @@ERROR
            IF @n_err <> 0    
            BEGIN    
               SELECT @n_continue = 3    
               SELECT @c_errmsg = CONVERT(char(250), @n_err), @n_err = 81032   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg = "NSQL" + CONVERT(char(5), @n_err) + ": Unable to retrieve records from #temp_pick (nsp_GenerateRFTask)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "    
               BREAK
            END         
            IF @b_debug = 1 SELECT 'Complete updating pickdetail for pickdetailkey  = ', @c_pickdetailkey                  
         END -- while      
   
         CLOSE CURSOR_UPDATEPICK
         DEALLOCATE CURSOR_UPDATEPICK
      END
   END -- @n_continue (before checktask)
-- end of updating of pickdetail table.

   IF @b_debug = 1 
   BEGIN
      SELECT 'n_continue at the end ' , @n_continue
      SELECT 'n_taskdetailcheck', @n_taskdetailcheck
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @n_taskdetailcheck > 0
      BEGIN
         UPDATE LOADPLAN
         SET PROCESSFLAG = 'Y', trafficcop = NULL, editdate = getdate()
         WHERE LOADKEY = @c_loadkey
         SELECT @n_err = @@ERROR
         IF @n_err <> 0    
         BEGIN    
            SELECT @n_continue = 3    
            SELECT @c_errmsg = CONVERT(char(250), @n_err), @n_err = 81032   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SELECT @c_errmsg = "NSQL" + CONVERT(char(5), @n_err) + ": Unable to update Loadplan process flag (nsp_GenerateRFTask)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "    
         END         

      END -- @n_taskdetail
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
      execute nsp_logerror @n_err, @c_errmsg, "nsp_GenerateRFTask"  
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
END -- End of procedure...

GO