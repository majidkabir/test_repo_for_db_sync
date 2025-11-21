SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Stored Procedure: isp_ReplenishmentRpt_PC22                             */  
/* Creation Date: 01/06/2017                                               */  
/* Copyright: LFL                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose: WMS-1986 DYSON pallet replenishment report                     */  
/*          Generate replenishment record for release task                 */  
/*                                                                         */  
/* Called By: Replenishment Report r_replenishment_report_PC22             */  
/*                                                                         */  
/* PVCS Version: 1.4                                                       */  
/*                                                                         */  
/* Version: 7.0                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date         Author  Ver   Purposes                                     */  
/* 13-Sep-2017  NJOW01  1.0   WMS-2868 Allow set maxpallet as 1            */
/* 11-OCT-2017  CSCHONG 1.1   MWS-3181 change sorting (CS01)               */
/* 05-MAR-2018  Wan01   1.2   WM - Add Functype                            */
/* 03-APR-2018  NJOW02  1.3   WMS-4499 qty calculation include deduct      */
/*                            qtyallocated from bulk                       */
/* 24-MAY-2018          1.4   Remove WMS-4499 changes.                     */
/* 28-FEB-2018  Wan02   1.4   WM - Add Functype                            */
/* 14-MAY-2019  WLChooi 1.5   WMS-9023 - Change logic to determine if need */
/*                                       replenishment (WL01)              */
/* 17-Jun-2019  Shong   1.6   Add new column EditDate                      */
/* 15-Apr-2020  CSCHONG 1.7   WMS-12653 revised logic (CS01)               */
/***************************************************************************/  
CREATE PROC [dbo].[isp_ReplenishmentRpt_PC22]  
               @c_Zone01           NVARCHAR(10)  --Facility
,              @c_Zone02           NVARCHAR(10)  --ALL
,              @c_Zone03           NVARCHAR(10)  
,              @c_Zone04           NVARCHAR(10)  
,              @c_Zone05           NVARCHAR(10)  
,              @c_Zone06           NVARCHAR(10)  
,              @c_Zone07           NVARCHAR(10)  
,              @c_Zone08           NVARCHAR(10)  
,              @c_Zone09           NVARCHAR(10)  
,              @c_Zone10           NVARCHAR(10)  
,              @c_Zone11           NVARCHAR(10)  
,              @c_Zone12           NVARCHAR(10)  
,              @c_StorerKey        NVARCHAR(15) 
,              @c_ReplGrp          NVARCHAR(30) = 'ALL'     --(Wan02)  
,              @c_Functype         NCHAR(1) = ''            --(Wan01)  
AS  
BEGIN  
   SET NOCOUNT ON       
   SET ANSI_NULLS OFF       
   SET QUOTED_IDENTIFIER OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF      
   
   DECLARE @n_continue           INT  
          ,@n_StartTranCnt       INT
          ,@b_Success            INT  
          ,@n_err                INT
          ,@c_errmsg             NVARCHAR(255)
          ,@c_SKU                NVARCHAR(20)             
          ,@n_PickBalQty         INT
          ,@n_Pallet             INT
          ,@n_MaxPallet          INT            
          ,@c_ToLoc              NVARCHAR(10)
          ,@c_Lot                NVARCHAR(10)
          ,@c_FromLoc            NVARCHAR(10)
          ,@c_ID                 NVARCHAR(18)
          ,@n_Qty                INT
          ,@c_ReplenishmentKey   NVARCHAR(10)
          ,@c_ReplenishmentGroup NVARCHAR(10)
          ,@c_Packkey            NVARCHAR(10)
          ,@c_UOM                NVARCHAR(10)
          ,@n_MaxReplenkey       INT
          ,@c_Retried            NVARCHAR(1)
          --,@n_QtyAllocated       INT  --NJOW01
          ,@c_locGrp             NVARCHAR(30)
          ,@n_qtyPmi            INT
          ,@n_pltqty            INT
          ,@n_vlocqty           INT                   --(CS01)

   SELECT  @n_StartTranCnt=@@TRANCOUNT , @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=''
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN     
       IF ISNULL(@c_Storerkey,'') = ''
       BEGIN
        SELECT @n_continue = 3  
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Storerkey not selected yet. (isp_ReplenishmentRpt_PC22)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
       END
   END

   --(Wan02) - START
   IF @c_ReplGrp = ''
   BEGIN
      SET @c_ReplGrp = 'ALL'
   END
   --(Wan02) - END

   --(Wan01) - START
   IF @c_FuncType IN ( 'P' )                                     
   BEGIN
      GOTO QUIT_SP    
   END
   --(Wan01) - END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
        --Retreive pick loc with qty < min pallet * pack.pallet
      DECLARE cur_PickLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LLI.Storerkey, LLI.Sku, LLI.Loc, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn) AS Qty,
                PACK.Pallet, LOC.MaxPallet, PACK.Packkey, PACK.PACKUOM3 , Loc.LocationGroup,SUM (LLI.Qty+LLI.PendingMoveIn),
                (CASE WHEN ISNUMERIC(SKU.BUSR6) = 0 THEN 0 ELSE SKU.BUSR6 * PACK.Pallet END)
         FROM LOTXLOCXID LLI (NOLOCK)          
         JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
         JOIN SKU (NOLOCK) ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku
         JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey          
         JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
         WHERE SL.LocationType IN('PICK','CASE')
         AND LLI.Storerkey = CASE WHEN @c_StorerKey = 'ALL' OR @c_StorerKey = '' THEN  
                                    LLI.StorerKey ELSE @c_StorerKey END                        
         --AND (LOC.MaxPallet - 1) > 0  --NJOW01
         AND (LOC.locationflag = 'NONE')        --CS01 
         AND PACK.Pallet > 0
         --AND LLI.sku = '389300-01'
         AND (LOC.Facility = @c_zone01 OR ISNULL(@c_Zone01,'') = '')
         AND (LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, 
                                  @c_zone06, @c_zone07, @c_zone08, @c_zone09, 
                                  @c_zone10, @c_zone11, @c_zone12)                     
              OR @c_zone02 = 'ALL' )                    
         GROUP BY LLI.Storerkey, LLI.Sku, LLI.Loc, PACK.Pallet, LOC.MaxPallet, PACK.Packkey, PACK.PACKUOM3, SKU.BUSR6, Loc.LocationGroup --WL01
         --HAVING SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn) <= ((LOC.MaxPallet - 1) * PACK.Pallet) 
         HAVING SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn) < (CASE WHEN ISNUMERIC(SKU.BUSR6) = 0 THEN 0 ELSE SKU.BUSR6 * PACK.Pallet END)  --WL01 
           --HAVING CASE 
           --           WHEN Loc.LocationGroup ='E' AND LLI.Loc = 'RYRP' THEN 
           --(SUM((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn) + SUM (LLI.Qty+LLI.PendingMoveIn)) < (CASE WHEN ISNUMERIC(SKU.BUSR6) = 0 THEN 0 ELSE SKU.BUSR6 * PACK.Pallet END)) 
           --       WHEN Loc.LocationGroup ='N' THEN (SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn) < (CASE WHEN ISNUMERIC(SKU.BUSR6) = 0 THEN 0 ELSE SKU.BUSR6 * PACK.Pallet END) )
           -- ELSE 0 END

      OPEN cur_PickLoc
      
      FETCH FROM cur_PickLoc INTO @c_Storerkey, @c_Sku, @c_ToLoc, @n_PickBalQty, @n_Pallet, @n_MaxPallet, @c_Packkey, @c_UOM,@c_locGrp,@n_qtypmi,@n_pltqty
      
      IF @@FETCH_STATUS = 0
      BEGIN
         
           --CS01 START 
           --SET @c_locGrp = ''
           --SELECT @c_locGrp = L.LocationGroup
           --FROM LOC L WITH (NOLOCK)
           --WHERE L.loc = @c_ToLoc  
           --CS01 END 

--select @c_ToLoc '@c_ToLoc',@c_locGrp '@c_locGrp', @n_PickBalQty '@n_PickBalQty', @n_MaxPallet '@n_MaxPallet',@n_Pallet '@n_Pallet'
--select @c_locGrp '@c_locGrp',@c_ToLoc '@c_ToLoc',@n_PickBalQty '@n_PickBalQty',@n_qtypmi '@n_qtypmi', @n_pltqty '@n_pltqty'
            --IF @c_locGrp = 'E' AND @c_ToLoc ='RYRP'
            --BEGIN
            --    IF (@n_PickBalQty + @n_qtypmi) > @n_pltqty
            --    BEGIN
            --     GOTO NEXT_Toloc
            --    END
            --END
            --ELSE IF @c_locGrp = 'N'
            --BEGIN
            --    IF (@n_PickBalQty + @n_qtypmi) > @n_pltqty
            --    BEGIN
            --         GOTO NEXT_Toloc
            --     END 
            --END
            --ELSE IF @c_locGrp = ''
            --BEGIN
            --    IF (@n_PickBalQty) > @n_pltqty
            --    BEGIN
            --         GOTO NEXT_Toloc
            --     END 
            --END


         EXECUTE nspg_GetKey                                 
            'REPLENGROUP',                                
            9,                                            
            @c_ReplenishmentGroup OUTPUT,                    
            @b_success OUTPUT,                             
            @n_err OUTPUT,                                 
            @c_errmsg OUTPUT                               
                                                        
         IF @b_success <> 1                             
         BEGIN                                          
            SELECT @n_continue = 3                      
         END                                            
         ELSE
            SELECT @c_ReplenishmentGroup = 'T' + @c_ReplenishmentGroup
      END
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN       
          --NJOW02
          /*
          SET @n_QtyAllocated = 0
          
         SELECT @n_QtyAllocated = SUM(LLI.QtyAllocated) 
         FROM LOTXLOCXID LLI (NOLOCK)          
         JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
         JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
         WHERE SL.LocationType NOT IN('PICK','CASE')
         AND LLI.Storerkey = @c_Storerkey
         AND LLI.Sku = @c_Sku
         AND (LOC.Facility = @c_zone01 OR ISNULL(@c_Zone01,'') = '')
         AND LLI.QtyAllocated > 0
         
         SET @n_PickBalQty = @n_PickBalQty - ISNULL(@n_QtyAllocated,0)  
         */
          SET @n_vlocqty = 0
          SELECT @n_vlocqty = sum(LLI.qty+LLI.PendingMoveIN)
          FROM lotxlocxid LLI with (nolock)
          WHERE LLI.sku = @c_Sku
          AND LLI.loc in('RYRP')
   

   IF @c_locGrp = 'E'
   BEGIN
      SET @n_PickBalQty = @n_PickBalQty + ISNULL(@n_vlocqty,0)
   END                    
           --retrieve pallet from bulk 
         DECLARE cur_BulkPallet CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT LLI.Lot, LLI.Loc, LLI.Id, LLI.Qty 
            FROM LOTXLOCXID LLI (NOLOCK)          
            JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
            JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
            JOIN ID (NOLOCK) ON LLI.Id = ID.Id
            JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
            JOIN LOTATTRIBUTE AS LOTAT WITH (NOLOCK) ON LOTAT.lot = LOT.lot                                   --CS01
            WHERE SL.LocationType NOT IN('PICK','CASE')
            AND LOC.LocationFlag = 'NONE' 
            AND LOC.locationcategory in ('SHUTTLE','VNA')                                                --CS01
            AND LOT.Status = 'OK'
            AND ID.Status = 'OK' 
            AND LOC.Status = 'OK'                         
            AND (LLI.QtyAllocated + LLI.QtyPicked + LLI.QtyReplen) = 0
            AND LLI.Qty > 0
            AND LLI.Storerkey = @c_Storerkey
            AND LLI.Sku = @c_Sku
            AND (LOC.Facility = @c_zone01 OR ISNULL(@c_Zone01,'') = '')
            --AND LOC.LocationGroup = @c_locGrp                                                                --CS01
            ORDER BY CASE WHEN @c_locGrp = 'N' THEN LOC.LocationGroup else '' END desc, 
                     CASE WHEN @c_locGrp = 'E' THEN LOC.LocationGroup else '' END Asc,
                     LOTAT.Lottable05,SL.Qty, LOC.Logicallocation,LOC.Loc                                      --CS01     
            --ORDER BY SL.Qty, LOC.Logicallocation, LOC.Loc, LLI.Lot                                           --CS01
            
         OPEN cur_BulkPallet
        
         FETCH FROM cur_BulkPallet INTO @c_Lot, @c_FromLoc, @c_ID, @n_Qty
         
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) AND @n_PickBalQty <= ((@n_MaxPallet - 1) * @n_Pallet)
         BEGIN
             SET @c_Retried = 'N'     

                 --IF @c_sku = 'SKU601-001'
                 -- BEGIN
                 --    SELECT 'AAA', @n_PickBalQty '@n_PickBalQty',@n_vlocqty '@n_vlocqty'
                 -- END
         
                 SET @n_PickBalQty = @n_PickBalQty + @n_Qty
   
                  --IF @c_sku = 'SKU601-001'
                  --BEGIN
                  --   SELECT 'bbb', @n_PickBalQty '@n_PickBalQty',((@n_MaxPallet - 1) * @n_Pallet) 'maxplt'
                  --END

                   --IF @n_PickBalQty > ((@n_MaxPallet - 1) * @n_Pallet)
                   --BEGIN
                   --  GOTO NEXT_FROMloc 
                   --END 

           RETRY_KEY:
           EXECUTE nspg_GetKey  
                'REPLENISHKEY',  
                10,  
                @c_ReplenishmentKey OUTPUT,              
                @b_success OUTPUT,  
                @n_err OUTPUT,  
                @c_errmsg OUTPUT  
                
                IF @b_success <> 1
                BEGIN  
                   SELECT @n_continue = 3  
                END  

                IF @b_success = 1  
                BEGIN  
                   INSERT REPLENISHMENT (replenishmentgroup,  
                                         ReplenishmentKey,  
                                         StorerKey,  
                                         Sku,  
                                         FromLoc,  
                                         ToLoc,  
                                         Lot,  
                                         Id,  
                                         Qty,  
                                         UOM,  
                                         PackKey,  
                                         Confirmed,
                                         RefNo)  
                   VALUES (@c_ReplenishmentGroup,  
                           @c_ReplenishmentKey,  
                           @c_Storerkey,  
                           @c_Sku,  
                           @c_FromLoc,  
                           @c_ToLoc,  
                           @c_Lot,  
                           @c_ID,  
                           @n_Qty,  
                           @c_UOM,  
                           @c_PackKey,  
                           'N',
                           'PC22')               

                   SELECT @n_err = @@ERROR  
            
                   IF @n_err = 2627 AND @c_Retried <> 'Y'
                   BEGIN
                       SELECT @n_MaxReplenkey = CAST(MAX(Replenishmentkey) AS INT)
                       FROM REPLENISHMENT(NOLOCK) 
                       
                       UPDATE NCOUNTER WITH (ROWLOCK)
                       SET Keycount = @n_MaxReplenKey, EditDate = GETDATE() 
                       WHERE Keyname = 'REPLENISHKEY'
                       
                       SET @c_Retried = 'Y'
                       GOTO RETRY_KEY                                         
                   END
            
                   IF @n_err <> 0                      
                   BEGIN
                       SELECT @n_continue = 3  
                       SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                       SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Replenishment Failed. (isp_ReplenishmentRpt_PC22)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
                   END  
                END
            NEXT_FROMloc: 
            FETCH FROM cur_BulkPallet INTO @c_Lot, @c_FromLoc, @c_ID, @n_Qty
         END
         CLOSE cur_BulkPallet
         DEALLOCATE cur_BulkPallet 
         
      NEXT_Toloc:  
      FETCH FROM cur_PickLoc INTO @c_Storerkey, @c_Sku, @c_ToLoc, @n_PickBalQty, @n_Pallet, @n_MaxPallet, @c_Packkey, @c_UOM,@c_locGrp,@n_qtypmi,@n_pltqty
      END
      CLOSE cur_PickLoc
      DEALLOCATE cur_PickLoc          
   END

--(Wan01) - START
QUIT_SP:
   IF @c_FuncType IN ( 'G' )                                     
   BEGIN
      RETURN
   END
--(Wan01) - END

   SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,  
          SKU.Descr, R.Priority, LOC.PutawayZone, PACK.PACKUOM1, PACK.PACKUOM3, 
          R.ReplenishmentKey, ReplenishmentGroup, LOC.Facility
   From  REPLENISHMENT R (NOLOCK)   
   JOIN  SKU (NOLOCK) ON (SKU.Sku = R.Sku AND  SKU.StorerKey = R.StorerKey)  
   JOIN  LOC (NOLOCK) ON (LOC.Loc = R.ToLoc)  
   JOIN  PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)  
   WHERE (LOC.putawayZone IN (@c_Zone02, @c_Zone03, @c_Zone04, @c_Zone05, @c_Zone06, @c_Zone07, @c_Zone08, @c_Zone09, @c_Zone10, @c_Zone11, @c_Zone12)
          OR @c_Zone02 = 'ALL'
         )
   AND (LOC.Facility = @c_Zone01 OR ISNULL(@c_Zone01,'') = '')  
   AND R.Confirmed = 'N'  
   AND R.StorerKey = CASE WHEN @c_StorerKey = 'ALL' OR @c_StorerKey = '' THEN  
                                R.StorerKey ELSE @c_StorerKey END      
   AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  --(Wan02)                                                
   ORDER BY R.ReplenishmentGroup, R.Storerkey, LOC.Facility, R.Sku, R.FromLoc, R.Id, R.Lot

--RETURN_SP:                                                         --(Wan01)

    IF @n_continue=3  -- Error Occured - Process And Return  
    BEGIN  
       SELECT @b_success = 0  
       IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt  
       BEGIN  
          ROLLBACK TRAN  
       END  
       ELSE  
       BEGIN  
          WHILE @@TRANCOUNT > @n_StartTranCnt  
          BEGIN  
             COMMIT TRAN  
          END  
       END  
       execute nsp_logerror @n_err, @c_errmsg, "isp_ReplenishmentRpt_PC22"  
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
       RETURN  
    END  
    ELSE  
    BEGIN  
       SELECT @b_success = 1  
       WHILE @@TRANCOUNT > @n_StartTranCnt  
       BEGIN  
          COMMIT TRAN  
       END  
       RETURN  
    END            
END   

GO