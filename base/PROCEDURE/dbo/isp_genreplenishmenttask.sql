SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Procedure: isp_GenReplenishmentTask                              */
/* Creation Date: 25-Mar-2024                                              */
/* Copyright: Maersk                                                       */
/* Written by: Shong                                                       */
/*                                                                         */
/* Purpose:                                                                */
/*                                                                         */
/* Called By: Copy from isp_GenReplenishment                               */
/*            @c_ReplenFlag --  N = Normal                                 */
/*                                                                         */
/* PVCS Version: 1.1                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author     Ver   Purposes                                  */
/* 09-JUL-2010  Shong      1.3   Revised Replenishment Calculation         */
/***************************************************************************/
CREATE   PROC [dbo].[isp_GenReplenishmentTask]
   @c_Zone01     NVARCHAR(10),
   @c_Zone02     NVARCHAR(10),
   @c_Zone03     NVARCHAR(10),
   @c_Zone04     NVARCHAR(10),
   @c_Zone05     NVARCHAR(10),
   @c_Zone06     NVARCHAR(10),
   @c_Zone07     NVARCHAR(10),
   @c_Zone08     NVARCHAR(10),
   @c_Zone09     NVARCHAR(10),
   @c_Zone10     NVARCHAR(10),
   @c_Zone11     NVARCHAR(10),
   @c_Zone12     NVARCHAR(10),
   @c_ReplenFlag NVARCHAR(10) = 'N', -- N = Normal
   @c_StorerKey  NVARCHAR(15) 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @n_continue INT
   /* continuation flag
   1=Continue
   2=failed but continue processsing
   3=failed do not continue processing
   4=successful but skip furthur processing */
   DECLARE @n_starttcnt INT
   SELECT  @n_starttcnt = @@TRANCOUNT
   DECLARE @b_debug              INT,
           @c_Packkey            NVARCHAR(10),
           @c_UOM                NVARCHAR(10),
           @n_qtytaken           INT,
           @n_Pallet             INT,
           @n_FullPackQty        INT,
           @n_FullPackQtyPP      INT,
           @c_LocationType       NVARCHAR(10),
           @c_Facility           NVARCHAR(5),
           @n_Qty                INT,
           @n_QtyLocationLimit   INT,
           @n_QtyPicked          INT,
           @n_QtyAllocated       INT,
           @n_QtyLocationMinimum INT,
           @n_CaseCnt            INT,
           @n_ReplenQty          INT,
           @c_PickCode           NVARCHAR(10),
           @c_LogicalLocation    NVARCHAR(20),
           @c_SortColumn         NVARCHAR(30),
           @n_Cnt                INT,
           @n_QtyAvailable       INT,
           @c_priority           NVARCHAR(5),
           @c_ReplenQtyFlag      NVARCHAR(1),
           @c_ReplenishmentGroup NVARCHAR(10),
           @c_ReplExclProdNearExpiry   NVARCHAR(10), 
           @n_NearExpiryDay INT 
   DECLARE @b_Success INT,
           @n_Err INT,
           @c_ErrMsg NVARCHAR(255)
   SET @c_Facility = @c_Zone01
   SET @c_ReplenQtyFlag = '0'
   SELECT @n_continue = 1,
          @b_debug = 0
   IF ISNUMERIC(@c_Zone12) = 1 AND @c_Zone12 <> ''
   BEGIN
      SELECT @b_debug = CAST(@c_Zone12 AS INT)
   END
   IF ISNULL(RTRIM(@c_StorerKey),'') = '' -- SOS#156197
   BEGIN
      SELECT @c_StorerKey = 'ALL'
   END
   CREATE TABLE #LOT_SORT
   (
      LOT        NVARCHAR(10),
      SortColumn NVARCHAR(20)
   )
   EXECUTE nspg_GetKey
            @keyname       = 'REPLENISHGROUP',
            @fieldlength   = 10,
            @keystring     = @c_ReplenishmentGroup  OUTPUT,
            @b_Success     = @b_Success   OUTPUT,
            @n_Err         = @n_Err       OUTPUT,
            @c_ErrMsg      = @c_ErrMsg    OUTPUT
   IF NOT @b_Success = 1
   BEGIN
      SELECT @n_continue = 3
   END
   DECLARE @c_CurrentSKU                  NVARCHAR(20),
            @c_CurrentStorer              NVARCHAR(15),
            @c_CurrentLOC                 NVARCHAR(10),
            @c_CurrentPriority            NVARCHAR(5),
            @n_CurrentFullCase            INT,
            @n_CurrentSeverity            INT,
            @c_FromLOC                    NVARCHAR(10),
            @c_FromLot                    NVARCHAR(10),
            @c_FromId                     NVARCHAR(18),
            @n_FromQty                    INT,
            @n_RemainingQty               INT,
            @n_PossibleCases              INT,
            @n_remainingcases             INT,
            @n_OnHandQty                  INT,
            @n_fromcases                  INT,
            @c_ReplenishmentKey           NVARCHAR(10),
            @n_numberofrecs               INT,
            @n_limitrecs                  INT,
            @c_FromLot2                   NVARCHAR(10),
            @b_DoneCheckOverAllocatedLots INT,
            @n_SKULocAvailableQty         INT,
            @n_LotSKUQTY                  INT,
            @c_ExecSP                     NVARCHAR(200)  = '',
            @c_ExecSPParm                 NVARCHAR(2000)  = '',
            @c_Option1                    NVARCHAR(50)   = '',
            @c_Option2                    NVARCHAR(50)   = '',
            @c_Option3                    NVARCHAR(50)   = '',
            @c_Option4                    NVARCHAR(50)   = '',
            @c_Option5                    NVARCHAR(50)   = '',
            @c_ExecSQL                    NVARCHAR(4000) = '', 
            @c_SQLStatement               NVARCHAR(4000), 
            @c_SQLCondition               NVARCHAR(2000) 
   SELECT  @c_CurrentSKU      = SPACE(20),
            @c_CurrentStorer   = SPACE(15),
            @c_CurrentLOC      = SPACE(10),
            @c_CurrentPriority = SPACE(5),
            @n_CurrentFullCase = 0,
            @n_CurrentSeverity = 9999999,
            @n_FromQty         = 0,
            @n_RemainingQty    = 0,
            @n_PossibleCases   = 0,
            @n_remainingcases  = 0,
            @n_fromcases       = 0,
            @n_numberofrecs    = 0,
            @n_limitrecs       = 5,
            @n_LotSKUQTY       = 0,
            @c_SQLCondition    = '' 
   IF @c_StorerKey <> 'ALL'
   BEGIN
      SELECT @c_SQLCondition = @c_SQLCondition + ' AND SKUxLOC.StorerKey = ''' + RTRIM(@c_StorerKey) + ''''
      -- Default to first SP
      SET @c_ExecSP = 'isp_ODMRPL01'
      SELECT @c_ExecSP = SC.sValue, 
             @c_Option1 = Option1,
             @c_Option2 = Option2,
             @c_Option3 = Option3,
             @c_Option4 = Option4,
             @c_Option5 = Option5
      FROM StorerConfig SC WITH (NOLOCK)
      WHERE SC.StorerKey = @c_StorerKey
      AND ConfigKey = 'GenReplenTaskSP'
   END
   IF @c_Zone02 <> 'ALL'
   BEGIN
      SELECT @c_SQLCondition = @c_SQLCondition + ' AND LOC.PutawayZone IN ( '''+ RTRIM(ISNULL(@c_Zone02,'')) +''',''' + 
                                                      	                        RTRIM(ISNULL(@c_Zone03,'')) +''',''' +  
                                                      	                        RTRIM(ISNULL(@c_Zone04,'')) +''',''' +  
                                                      	                        RTRIM(ISNULL(@c_Zone05,'')) +''',''' +  
                                                      	                        RTRIM(ISNULL(@c_Zone06,'')) +''',''' +  
                                                      	                        RTRIM(ISNULL(@c_Zone07,'')) +''',''' +  
                                                      	                        RTRIM(ISNULL(@c_Zone08,'')) +''',''' +  
                                                      	                        RTRIM(ISNULL(@c_Zone09,'')) +''',''' +  
                                                      	                        RTRIM(ISNULL(@c_Zone10,'')) +''',''' +  
                                                      	                        RTRIM(ISNULL(@c_Zone11,'')) +''',''' +  
                                                      	                        RTRIM(ISNULL(@c_Zone12,'')) +''')'      	 
   END
	SELECT @c_SQLStatement = 'DECLARE Cur_ReplenSkuLoc CURSOR FAST_FORWARD READ_ONLY FOR ' +
                              'SELECT SKUxLOC.ReplenishmentPriority, ' +
                              'SKUxLOC.StorerKey, '+
                              'SKUxLOC.SKU, ' +
                              'SKUxLOC.LOC, ' +
                              'SKUxLOC.Qty, ' +
                              'SKUxLOC.QtyPicked, ' +
                              'SKUxLOC.QtyAllocated, ' +
                              'SKUxLOC.QtyLocationLimit, ' +
                              'SKUxLOC.QtyLocationMinimum, ' +
                              'PACK.CaseCnt, ' +
                              'PACK.Pallet, ' +
                              'SKU.PickCode, ' +
                              'SKUxLOC.LocationType ' +
                              'FROM    SKUxLOC (NOLOCK) ' +
                              'JOIN    LOC WITH ( NOLOCK ) ON SKUxLOC.Loc = LOC.Loc ' +
                              'JOIN    SKU WITH ( NOLOCK ) ON SKU.StorerKey = SKUxLOC.StorerKey AND ' +
                              '                               SKU.SKU = SKUxLOC.SKU ' +
                              'JOIN    PACK WITH ( NOLOCK ) ON PACK.PackKey = SKU.PACKKey ' +
                              'WHERE   LOC.Facility = ''' + RTRIM(ISNULL(@c_Facility,'')) +''' ' +
                              'AND SKUxLOC.LocationType IN ( ''PICK'', ''CASE'' ) ' +
                              'AND LOC.LocationFlag NOT IN ( ''DAMAGE'', ''HOLD'' ) ' +
                              RTRIM(ISNULL(@c_SQLCondition,'')) + ' ' +
                              'ORDER BY SKUxLOC.ReplenishmentPriority, SKUxLOC.Loc ' 
   EXEC(@c_SQLStatement)
   OPEN Cur_ReplenSkuLoc
   FETCH NEXT FROM cur_ReplenSkuLoc INTO @c_CurrentPriority, @c_CurrentStorer, @c_CurrentSKU, @c_CurrentLoc, @n_Qty,
                                          @n_QtyPicked, @n_QtyAllocated, @n_QtyLocationLimit, @n_QtyLocationMinimum,
                                          @n_CaseCnt, @n_Pallet, @c_PickCode, @c_LocationType 
   WHILE @@FETCH_STATUS <> -1
   BEGIN		
		SET @c_ReplenQtyFlag = '0'
      IF EXISTS(SELECT 1 FROM TASKDETAIL TD WITH (NOLOCK) 
                  WHERE TD.Status IN ( '0','3') 
                  AND TD.TaskType IN ('DRP', 'VNAOUT')
                  AND TD.ToLoc = @c_CurrentLoc 
                  AND TD.Storerkey = @c_CurrentStorer  
                  AND TD.Sku       = @c_CurrentSKU)
      BEGIN
      	   IF @b_debug = 1
      	   BEGIN
      	      PRINT 'Skip Replenishement, Work In Progress TM task found'
      	      PRINT '  SKU: ' + @c_CurrentSKU 
      	      PRINT '  LOC: ' + @c_CurrentLOC 
      	   END
         GOTO GET_NEXT_RECORD 
      END
      SET @c_ExecSQL = N'EXEC ' + @c_ExecSP + ' ' + 
         + N'@c_Facility = @c_Facility,'
         + N'@c_StorerKey = @c_Storerkey,'
         + N'@c_SKU = @c_SKU,'
         + N'@c_LOC = @c_LOC,'
         + N'@c_ReplenType = @c_ReplenType, '
         + N'@c_ReplenishmentGroup = @c_ReplenishmentGroup, '
         + N'@b_Success = @b_Success OUTPUT,'
         + N'@n_Err = @n_Err OUTPUT,'
         + N'@c_ErrMsg = @c_ErrMsg OUTPUT,'
         + N'@b_Debug = @b_Debug'
      SET @c_ExecSPParm = N'
         @c_Facility   NVARCHAR(5) ,
         @c_Storerkey  NVARCHAR(15),
         @c_SKU        NVARCHAR(20),
         @c_LOC        NVARCHAR(10),
         @c_ReplenType NVARCHAR(50),
         @c_ReplenishmentGroup NVARCHAR(10),
         @b_Success    INT OUTPUT,
         @n_Err        INT OUTPUT,
         @c_ErrMsg     NVARCHAR(255) OUTPUT,
         @b_Debug      INT'
      IF @b_Debug = 1
      BEGIN
         PRINT '@c_SKU: ' + TRIM(@c_CurrentSKU) + ', @c_LOC: ' + @c_CurrentLoc
      END 
      EXEC sp_ExecuteSQL @c_ExecSQL, @c_ExecSPParm, 
            @c_Facility, 
            @c_CurrentStorer, 
            @c_CurrentSKU, 
            @c_CurrentLoc, 
            'T',
            @c_ReplenishmentGroup,
            @b_Success OUTPUT,
            @n_Err OUTPUT, 
            @c_ErrMsg OUTPUT, 
            @b_Debug
      GET_NEXT_RECORD:
      FETCH NEXT FROM cur_ReplenSkuLoc INTO @c_CurrentPriority, @c_CurrentStorer, @c_CurrentSKU, @c_CurrentLoc, @n_Qty,
                                             @n_QtyPicked, @n_QtyAllocated, @n_QtyLocationLimit, @n_QtyLocationMinimum,
                                             @n_CaseCnt, @n_Pallet, @c_PickCode, @c_LocationType         
	END -- while cur_replenskuloc
	CLOSE Cur_ReplenSkuLoc
	DEALLOCATE Cur_ReplenSkuLoc
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT   @b_Success = 0
      IF @@TRANCOUNT = 1 AND
         @@TRANCOUNT > @n_starttcnt
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg,
         'isp_GenReplenishmentTask'
      RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN
   END
   ELSE
   BEGIN
      SELECT   @b_Success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
   END   
END --SP end

GO