SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO


 
   /************************************************************************************************/ 
   /* Store Procedure:  isp_DynamicReplenishment_Granite                                           */ 
   /* Creation Date:  25-June-2024                                                                 */ 
   /* Copyright: Maersk WMS                                                                        */ 
   /* Written by:  USH022                                                                          */ 
   /* JIRA TICKET: UWP-20446                                                                       */ 
   /* Purpose:  Dynamic Replenishment for order                                                    */ 
   /*                                                                                              */ 
   /* Input Parameters:                                                                            */ 
   /*  @c_WaveKey                                                                                  */ 
   /*  @c_StorerKey                                                                                */ 
   /*  @c_Facility                                                                                 */ 
   /*  @c_Uom                                                                                      */ 
   /*  @c_PickMethod                                                                               */ 
   /*  @c_LocationType                                                                             */ 
   /*                                                                                              */ 
   /* Output Parameters:  None                                                                     */ 
   /*                                                                                              */ 
   /* Return Status:  None                                                                         */ 
   /*                                                                                              */ 
   /* Usage:                                                                                       */ 
   /*                                                                                              */ 
   /* Local Variables:                                                                             */ 
   /*                                                                                              */ 
   /* Called By:                                                                                   */ 
   /*                                                                                              */ 
   /* PVCS Version: 1.3                                                                            */ 
   /*                                                                                              */ 
   /* Version: 5.4                                                                                 */ 
   /*                                                                                              */ 
   /* Data Modifications:                                                                          */ 
   /*                                                                                              */ 
   /* Updates:                                                                                     */ 
   /* Date               Author      Ver         Purposes                                          */ 
   /* YYYY-DD-MM         {author}    {ver}       Close Cursor                                      */ 
   /* 2024-07-16         USH022      V.0         Dynamic Replenishment                             */ 
   /* 2024-08-16         TAK047      V.1         TEMP REMOVE MIN MAX REPLEN (CLVN01)               */ 
   /* 2024-08-18         USH022      V.2         REMOVED MIN-MAX SCENARIO                          */ 
   /* 2024-10-08         SWT01       V.3         Demand Replenishment Logic Modification           */ 
   /* 2024-10-29         WLC01       V.5         Consider PendingMoveIn Qty when finding           */ 
   /*                                            friend                                            */
   /* 2024-10-31         PYW009      V.6         Filter Non Damage & Hold Location Flag	           */
   /*                                             (PY01)                                           */
   /* 2025-02-04         TAK047      V.7         FCR-2650 Check Replen Task existence (CLVN02)     */
   /************************************************************************************************/ 
   CREATE   PROCEDURE [dbo].[isp_DynamicReplenishment_Granite]	 
       @c_WaveKey NVARCHAR(10), 
       @b_Success int OUTPUT, 
       @n_err     int OUTPUT, 
       @c_errmsg  NVARCHAR(250) OUTPUT, 
       @c_Code    NVARCHAR(10) 
   AS 
   BEGIN 
		   SET NOCOUNT ON 
		   --SQL 2005 Standard 
		   SET QUOTED_IDENTIFIER OFF 
		   SET ANSI_NULLS OFF 
		   SET CONCAT_NULL_YIELDS_NULL OFF 
 
		   DECLARE 
		   @c_StorerKey     NVARCHAR(10), 
		   @c_Facility          NVARCHAR(20), 
		   @c_LocationType      NVARCHAR(10), 
		   @c_PickMethod        NVARCHAR(10), 
		   @c_Sku               NVARCHAR(20), 
		   @c_Lot               NVARCHAR( 10), 
		   @c_Id                NVARCHAR( 18), 
		   @c_UomQty            NVARCHAR( 10), 
		   @c_DropId            NVARCHAR(20), 
		   @c_MoveRefKey        NVARCHAR(10), 
		   @n_continue          INT, 
		   @c_PickFaceLocation  NVARCHAR(50), 
		   @c_DynamicPickFaceLocation NVARCHAR(50), 
		   @n_MinQty           INT, 
		   @n_MaxQty           INT, 
		   @n_StartTranCnt     INT, 
		   @c_ReplenishmentKey NVARCHAR(50), 
		   @c_UCCNo            NVARCHAR(20), 
		   @c_PickDetailKey    NVARCHAR(18), 
		   @c_Loc              NVARCHAR(10), 
		   @c_PutawayZone      NVARCHAR(10), 
		   @c_UOM              NVARCHAR(10), 
		   @c_PackKey			  NVARCHAR(10), 
		   @c_OrderKey         NVARCHAR(10), 
		   @n_UCCQty           INT, 
		   @c_FromLoc          NVARCHAR(50), 
		   @c_ToLoc            NVARCHAR(50), 
		   @n_UCC_RowRef       INT, 
		   @n_qtytoReplen      INT , 
		   @c_SuccessFlag		  NVARCHAR(1), 
         @c_LocAisle         NVARCHAR(10) = '' 
 
		   -- Error check for WaveKey existence 
		   IF NOT EXISTS(SELECT 1 FROM WaveDetail WITH (NOLOCK) WHERE WaveKey = @c_WaveKey) 
		   BEGIN 
			   SELECT @n_continue = 3; 
			   SELECT @n_err = 562801; 
			   SELECT @c_errmsg='NSQL' + CONVERT(char(6), @n_err) + ': No Orders is being populated into WaveDetail. (isp_DynamicReplenishment)'; 
			   GOTO RETURN_SP; 
		   END; 
		   --(CLVN02) START--
		   -- Error check for Replenishment existence
		   IF EXISTS(SELECT 1 FROM Replenishment WITH (NOLOCK) WHERE WaveKey = @c_WaveKey) 
		   BEGIN 
			   SELECT @n_continue = 3; 
			   SELECT @n_err = 562801; 
			   SELECT @c_errmsg='NSQL' + CONVERT(char(6), @n_err) + ': Replenishment Tasks exist for the Wave. (isp_DynamicReplenishment)'; 
			   GOTO RETURN_SP; 
		   END; 
		   --(CLVN02) END--
		   -- Begin Transaction 
		   SET @n_continue = 1; 
		   SET @c_SuccessFlag = 'N'; 
		   SELECT @n_StartTranCnt = @@TRANCOUNT; 
 
		   BEGIN TRAN; 
		   SELECT TOP 1  
            @c_StorerKey = o.StorerKey,  
            @c_Facility = o.Facility  
         FROM ORDERS O (NOLOCK) 
         JOIN WAVEDETAIL WD (nolock) ON O.OrderKey = WD.OrderKey 
         WHERE WD.Wavekey = @c_WaveKey 
 
         -- SWT01  
		   IF EXISTS( SELECT 1 
			   FROM dbo.PICKDETAIL PD (NOLOCK) 
            JOIN dbo.SKU SKU (NOLOCK) ON SKU.StorerKey = PD.Storerkey AND SKU.SKU = PD.SKU  
			   JOIN dbo.WAVEDETAIL WD (NOLOCK) ON pd.Orderkey = wd.orderkey 
            JOIN dbo.LOC L (NOLOCK) ON PD.loc = L.LOC  
			   LEFT OUTER JOIN dbo.SKUXLOC sl WITH (NOLOCK) on  sl.Storerkey = pd.StorerKey  
                           AND sl.Sku = pd.sku AND sl.Locationtype = 'PICK'			    
			   WHERE wd.WaveKey = @c_WaveKey             
            AND l.Facility = @c_Facility 
            AND ( SKU.PrePackIndicator <> 'Y' OR SKU.PrePackIndicator IS NULL ) 
			   AND sl.loc IS NULL) 
		   BEGIN 
			   SELECT @n_continue = 3 
			   SELECT @n_err = 562802 
			   SELECT @c_errmsg='NSQL'+CONVERT(char(6),@n_err)+': Pick Face Not Setup. (isp_DynamicReplenishment)' 
			   GOTO RETURN_SP; 
		   END 
 
         IF NOT EXISTS(SELECT 1 
            FROM dbo.PickDetail PD (NOLOCK)  
            JOIN dbo.WAVEDETAIL WD (NOLOCK) ON WD.OrderKey = PD.OrderKey -- SWT01 
			   JOIN dbo.LOC loc WITH (NOLOCK) ON (PD.loc = loc.loc) 
			   WHERE WD.WaveKey = @c_WaveKey -- SWT01 
			   AND PD.UOM = '6' 
			   AND loc.LocationType = 'CASE' 
			   AND PD.STATUS = '0'  
            AND NOT EXISTS (SELECT 1 FROM Replenishment r(NOLOCK)									 
			   					WHERE r.ReplenishmentGroup = loc.LocAisle 
			   					AND  r.DropID = pd.DropID 
			   					AND  r.Confirmed = 'N' 
			   					AND  r.Wavekey = @c_Wavekey)) 
         BEGIN 
            SET @c_SuccessFlag = 'Y'  
         END  
 
		   IF @n_continue = 1 OR @n_continue = 2 
		   BEGIN 
			   DECLARE cur_repleinshment CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
			   SELECT PD.StorerKey, PD.Sku, PD.Lot, PD.ID,  PD.DropID,  PD.Loc , PD.UOM, PD.PackKey, 
			   loc.LocAisle   
            FROM dbo.PickDetail PD (NOLOCK)  
            JOIN dbo.WAVEDETAIL WD (NOLOCK) ON WD.OrderKey = PD.OrderKey -- SWT01 
			   JOIN dbo.LOC loc WITH (NOLOCK) ON (PD.loc = loc.loc) 
			   WHERE WD.WaveKey = @c_WaveKey -- SWT01 
			   AND PD.UOM = '6' 
			   AND loc.LocationType = 'CASE' 
			   AND PD.STATUS = '0' 
			   AND NOT EXISTS (SELECT 1 FROM Replenishment r(NOLOCK)									 
			   					WHERE r.ReplenishmentGroup = loc.LocAisle 
			   					AND  r.DropID = pd.DropID 
			   					AND  r.Confirmed = 'N' 
			   					AND  r.Wavekey = @c_Wavekey) 
			   GROUP BY PD.StorerKey, PD.Sku, PD.Lot, PD.ID,  PD.DropID,  PD.Loc, PD.UOM, PD.PackKey, loc.LocAisle 
			   ORDER BY PD.StorerKey, PD.Sku, PD.Loc 
			   OPEN cur_repleinshment 
			   FETCH NEXT FROM cur_repleinshment INTO @c_StorerKey, @c_Sku, @c_Lot, @c_Id, @c_DropId, @c_FromLoc, @c_UOM, @c_PackKey, @c_LocAisle 
			   WHILE @@FETCH_STATUS = 0 
			   BEGIN 
				   DECLARE @n_ReplenQty INT; 
 
				   SELECT Top 1 
				      @n_ReplenQty = UCC.Qty 
				   FROM UCC WITH (NOLOCK) 
				   WHERE UCC.UCCno = @c_DropId 
				   AND UCC.Storerkey = @c_Storerkey 
				   SET @n_UCCQty = @n_ReplenQty; 
				   SET @c_ToLoc = '' 
 
				   -- 1. Find Pick Face 
					SELECT TOP 1 @c_ToLoc = LOC.Loc  
					FROM dbo.LOTxLOCxID lli (NOLOCK) 
					JOIN dbo.SKUXLOC sl (NOLOCK) ON lli.StorerKey = SL.StorerKey AND lli.sku = SL.SKU AND lli.loc = sl.loc 
					JOIN dbo.LOC LOC (NOLOCK) ON loc.loc = lli.loc 
					WHERE lli.SKU = @c_Sku 
					AND lli.StorerKey = @c_StorerKey 
					AND sl.LocationType = 'PICK' 
					AND loc.Facility = @c_Facility 
					AND  loc.MaxCarton > 0
					AND loc.LocationFlag not in ('DAMAGE','HOLD') -- PY01
					GROUP BY LOC.Loc, loc.LogicalLocation, LOC.LocAisle 
					HAVING SUM(lli.Qty - lli.QtyPicked + lli.PendingMoveIn) + @n_UCCQty <= MAX(sl.QtyLocationLimit) 
					ORDER BY loc.LogicalLocation 
 
				   -- SELECT TOP 1 @c_ToLoc = loc.Loc 
				   -- FROM LOC loc (NOLOCK) 
				   -- JOIN dbo.SKUXLOC sl (NOLOCK) ON loc.loc = sl.loc 
				   -- WHERE sl.SKU = @c_Sku 
				   -- AND sl.StorerKey = @c_StorerKey 
				   -- AND sl.LocationType = 'PICK' 
				   -- AND loc.Facility = @c_Facility 
				   -- GROUP BY loc.Loc, loc.LogicalLocation, sl.QtyLocationLimit, sl.StorerKey, sl.Loc, sl.Sku 
				   -- HAVING (SELECT ISNULL(SUM(lli.Qty - lli.QtyPicked + lli.PendingMoveIn), 0)  
					-- 		  FROM LOTXLOCXID lli (NOLOCK)  
					--         WHERE lli.SKU = sl.sku AND lli.Loc = sl.loc 
				   --         AND lli.StorerKey = sl.StorerKey) + @n_UCCQty <= sl.QtyLocationLimit ORDER BY loc.LogicalLocation 
 
				   -- Find Same Friend in DP loc can fit in 
				   IF @c_ToLoc = '' 
				   BEGIN 
					   SELECT TOP 1 @c_ToLoc = loc.Loc  
					   FROM LOC LOC (NOLOCK)  
					JOIN LOTxLOCxID LLI (NOLOCK) ON LLI.Loc = LOC.Loc 
					   WHERE lli.SKU = @c_Sku 
					   AND lli.StorerKey = @c_StorerKey 
					   AND loc.LocationType = 'DYNAMICPK' 
					   AND loc.Facility = @c_Facility
						AND loc.LocationFlag not in ('DAMAGE','HOLD') -- PY01
					   AND  loc.MaxCarton > 0 
						AND (LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIn) > 0   --WLC01  
					   GROUP BY loc.Loc, loc.MaxCarton, loc.LogicalLocation, LOC.LocAisle 
					   HAVING (CEILING(SUM(lli.Qty - lli.QtyPicked + lli.PendingMoveIn)/@n_UCCQty) < LOC.MaxCarton) 
					   ORDER BY loc.LogicalLocation 
				   END 
				   -- Find Empty in DP loc can fit in 
				   IF @c_ToLoc = '' 
				   BEGIN 
					   SELECT TOP 1  
                     @c_ToLoc = loc.Loc  
					   FROM LOC loc (NOLOCK) 
					   LEFT OUTER JOIN LOTxLOCxID lli (NOLOCK)  ON  loc.loc = lli.loc 
					   WHERE loc.LocationType = 'DYNAMICPK' 
					   AND  loc.Facility = @c_Facility
						AND loc.LocationFlag not in ('DAMAGE','HOLD') -- PY01
					   AND  loc.MaxCarton > 0 
					   GROUP BY loc.Loc, loc.LogicalLocation, LOC.LocAisle 
					   HAVING (SUM(ISNULL(lli.Qty,0) - ISNULL(lli.QtyPicked,0) + ISNULL(lli.PendingMoveIn,0)) = 0) 
					   ORDER BY loc.LogicalLocation 
				   END 
				   IF @c_ToLoc = '' 
				   BEGIN 
					   SELECT @n_continue = 3 
					   SELECT @n_err = 562803 
					   SELECT @c_errmsg='NSQL' + CONVERT(char(6), @n_err) + ':No empty dynamic/pick face location available for SKU. (isp_DynamicReplenishment)' 
					   GOTO RETURN_SP; 
				   END 
 
				   -- REPLNISHMENT START 
				   -- generate REPLENISHKEY key and holding into @c_ReplenishmentKey variable 
				   EXECUTE dbo.nspg_GetKey 'REPLENISHKEY', 10, 
				   @keystring     = @c_ReplenishmentKey OUTPUT, 
				   @b_Success     = @b_success          OUTPUT, 
				   @n_err         = @n_err              OUTPUT, 
				   @c_errmsg      = @c_errmsg           OUTPUT 
 
				   --Generating the MoveRefKey 
				   EXECUTE nspg_getkey 
				   @KeyName       ='MoveRefKey' 
				   ,@fieldlength   = 10 
				   ,@keystring     = @c_MoveRefKey       OUTPUT 
				   ,@b_Success     = @b_success          OUTPUT 
				   ,@n_err         = @n_err              OUTPUT 
				   ,@c_errmsg      = @c_errmsg           OUTPUT 
 
				   INSERT INTO Replenishment 
				   (ReplenishmentKey, ReplenishmentGroup, StorerKey, Sku, Lot, FromLoc, toloc, Id, Qty, UOM, 
				   PackKey, DropId, Wavekey, MoveRefkey, QtyReplen, PendingMoveIn, RefNo, Confirmed) 
				   VALUES 
				   (@c_ReplenishmentKey, @c_LocAisle, @c_StorerKey, @c_Sku, @c_Lot, @c_FromLoc, @c_Toloc, 
				   @c_Id, @n_ReplenQty, @c_UOM, @c_PackKey, @c_DropId, @c_Wavekey, @c_MoveRefkey,0 
				   ,@n_ReplenQty, @c_DropId, 'N'); 
 
				   IF @@ERROR <> 0 
				   BEGIN 
					   SET @n_continue  = 3 
                  SELECT @n_err = 562804 
					   SET  @c_ErrMsg =  'NSQL' + CONVERT(char(6), @n_err) + 'Replenishement data inserting failed' 
					   GOTO RETURN_SP; 
				   END 
				   -- CURSOR TO UPDATE MoveRef Key 
				   DECLARE updateMoveRefKeyCursor CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
				   SELECT PickDetailKey 
				   FROM PICKDETAIL (NOLOCK) PD 
               	   JOIN dbo.WAVEDETAIL WD (NOLOCK) ON WD.OrderKey = PD.OrderKey -- SWT01 
				   WHERE PD.Storerkey = @c_StorerKey  
					AND PD.DropID = @c_DropId 
					AND WD.WaveKey = @c_WaveKey -- SWT01 
					AND PD.status = '0'; 
 
				   OPEN updateMoveRefKeyCursor; 
 
				   FETCH NEXT FROM updateMoveRefKeyCursor INTO @c_PickDetailKey 
				   WHILE @@FETCH_STATUS = 0 
				   BEGIN 
					   UPDATE PICKDETAIL WITH (ROWLOCK)  
							SET MoveRefKey = @c_MoveRefKey 
					   		,trafficcop = null 
					   WHERE PickDetailKey = @c_PickDetailKey; 
 
				   	FETCH NEXT FROM updateMoveRefKeyCursor INTO @c_PickDetailKey; 
				   END; 
				   CLOSE updateMoveRefKeyCursor; 
				   DEALLOCATE updateMoveRefKeyCursor; 
 
				   -- UPDATE UCC SATTUS 
				   UPDATE UCC WITH (ROWLOCK) SET STATUS = '3'  
					WHERE SKU = @c_Sku AND StorerKey = @c_StorerKey 
				   and UCC_RowRef = @n_UCC_RowRef; 
 
				   SELECT @c_SuccessFlag = 'Y'; 
 
			      FETCH NEXT FROM cur_repleinshment INTO @c_StorerKey, @c_Sku, @c_Lot, @c_Id, @c_DropId, @c_FromLoc, @c_UOM, @c_PackKey, @c_LocAisle 
			   END 
			   CLOSE cur_repleinshment; 
			   DEALLOCATE cur_repleinshment; 
		   END 
 
		   IF @n_continue = 1 OR @n_continue = 2 
		   BEGIN 
				-- UPdate Wave to Indicate Replenishment Done 
				UPDATE Wave with (ROWLOCK) 
					SET UserDefine01 = 'Y', EditDate=GETDATE(), TrafficCop=NULL  
				Where WaveKey = @c_WaveKey 
			END  
 
 
		   -- Response Message setting based on @n_continue and @c_SuccessFlag variable 
		   IF (@n_continue = 1 OR @n_continue = 2) AND @c_SuccessFlag = 'Y' 
		   BEGIN 
			   SELECT @c_errmsg = 'Replenishment Done' 
		   END 
		   ELSE 
		   BEGIN 
            SET @n_err = 562805 
			   SELECT @c_errmsg = 'NSQL' + CONVERT(char(6), @n_err) + 'Replenishment not done, Something went wrong in current transaction' 
		   END 
 
	   RETURN_SP: 
		   IF CURSOR_STATUS('LOCAL', 'cur_repleinshment') IN (0, 1) 
		   BEGIN 
			   CLOSE cur_repleinshment; 
			   DEALLOCATE cur_repleinshment; 
		   END; 
 
		   IF CURSOR_STATUS('LOCAL', 'updateMoveRefKeyCursor') IN (0, 1) 
		   BEGIN 
			   CLOSE updateMoveRefKeyCursor; 
			   DEALLOCATE updateMoveRefKeyCursor; 
		   END; 
 
		   IF CURSOR_STATUS('LOCAL', 'cur_toCheckEnoughStock') IN (0, 1) 
		   BEGIN 
			   CLOSE cur_toCheckEnoughStock; 
			   DEALLOCATE cur_toCheckEnoughStock; 
		   END; 
 
		   IF @n_continue = 3  -- Error Occurred - Process And Return 
		   BEGIN 
			   SELECT @b_Success = 0; 
			   IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt 
			   BEGIN 
				   ROLLBACK TRAN; 
			   END 
			   ELSE 
			   BEGIN 
				   WHILE @@TRANCOUNT > @n_StartTranCnt 
				   BEGIN 
					   COMMIT TRAN 
				   END 
			   END 
			   EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_DynamicReplenishment_Granite' 
			   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012 
			   RETURN 
		   END 
		   ELSE 
		   BEGIN 
			   SELECT @b_Success = 1; 
			   IF @@TRANCOUNT > @n_StartTranCnt 
			   BEGIN 
				   COMMIT TRAN; 
			   END; 
			   RETURN; 
		   END; 
   END 

GO