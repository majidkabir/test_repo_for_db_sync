SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*******************************************************************************/
/* Store Procedure:  nspASNPASTD                                               */
/* Creation Date: 05-Aug-2002                                                  */
/* Copyright: IDS                                                              */
/* Written by:                                                                 */
/*                                                                             */
/* Purpose:  Stored Procedure for PUTAWAY from ASN                             */
/*                                                                             */
/* Input Parameters:  @c_userid,          - User Id                            */
/*                    @c_storerkey,       - Storerkey                          */
/*                    @c_LOT,             - Lot                                */
/*                    @c_SKU,             - Sku                                */
/*                    @c_ID,              - Id                                 */
/*                    @c_FromLoc,         - From Location                      */
/*                    @n_Qty,             - Putaway Qty                        */
/*                    @c_uom,             - UOM unit                           */
/*                    @c_PackKey,         - Packkey for sku                    */
/*                    @n_PutawayCapacity  - Putaway Capacity                   */
/*                                                                             */
/* Output Parameters: @c_Final_ToLoc      - Final ToLocation                   */
/*                                                                             */
/* Return Status:  None                                                        */
/*                                                                             */
/* Usage:                                                                      */
/*                                                                             */
/* Local Variables:                                                            */
/*                                                                             */
/* Called By:                                                                  */
/*                                                                             */
/* PVCS Version: 2.1                                                           */
/*                                                                             */
/* Version: 5.4                                                                */
/*                                                                             */
/* Data Modifications:                                                         */
/*                                                                             */
/* Updates:                                                                    */
/* Date         Author        Ver   Purposes                                   */
/* 06-Aug-2002  June                Include changes for ULP (SOS3265)          */
/* 28-Aug-2002  Administrator       Check in by Ricky                          */
/* 05-Jun-2003  Ricky               Branch From 1.2.1.4 - Version 5.1          */
/*                                  to include putaway by Facility based on    */
/*                                  receiptloc, Max Pallet control and         */
/*                                  new type '88'                              */
/* 26-Jul-2004  Shong               Performance Tuning                         */
/* 27-Jul-2004  Shong               Bug Fixed                                  */
/* 03-Aug-2004  Wally               SOS25754 - GOTO fixes for patype '04'      */
/* 16-Dec-2004  Shong               Remove comments                            */
/* 20-Jul-2005  MaryVong            SOS36712 KCPI PutawayStrategy - Add in     */
/*                                  new patype '17','18' and '19'              */
/*                                  Note: Changes applied to nspPASTD          */
/* 31-Mar-2007  MaryVong            SOS69388 KFP PutawayStrategy - Add in      */
/*                                  '55','56','57' and '58'                    */
/*                                  Add LocationStateRestriction '6' and '7'   */
/*                                  Note: Changes applied to nspPASTD          */
/* 08-Nov-2008  Shong               Performance Tuning                         */
/* 08-Nov-2008  Leong               SOS#121517 - Bug Fix                       */
/* 02-Dec-2008  Leong               SOS#122545 - Bug fix                       */
/* 08-Apr-2009  Shong               SOS#133180 Add New Putaway Logic:          */
/*                                  IF ID Held, PUT TO Specified ZONE or LOC   */
/* 14-Apr-2009  Shong               SOS#133381 Add new restriction on Location */
/*                                  Aisle and Level                            */
/* 26-Jun-2009  Shong               SOS#140197 Do not commingle Lottable05     */
/* 29-Jun-2009  Shong         1.2   Modify to allow multiple LOT Putaway       */
/* 23-Jul-2009  Leong         1.3   SOS# 143046 - Change Trace Type from       */
/*                                  'nspAutoPASTD'to 'nspASNPASTD'             */
/* 12-Jul-2010  Leong         1.4   SOS# 181262 - Include ISNULL check for     */
/*                                                integer calculation          */
/* 24-Aug-2010  Shong         1.5   Add new Strategy 03 - Put to Pick Loc If   */  
/*                                  from Specified Location                    */  
/* 30-JUL-2012  YTWan         1.7   SOS#251326:Add Commingle Lottables         */
/*                            1.8   validation to Exceed and RDT (Wan01)       */ 
/* 02-APR-2013  YTWan         1.9   SOS#251326: Allow place to loc that had    */
/*                                  been picked (Wan02)                        */
/* 16-APR-2014  SHONG         2.0   SQL2012 RaiseError                         */
/* 19-AUG-2014  Audrey        2.1   SOS318213 - Bug fixed              (ang01) */    
/* 18-MAY-2015  YTWan         2.1   SOS#341733 - ToryBurch HK SAP - Allow      */
/*                                  CommingleSKU with NoMixLottablevalidation  */
/*                                  to Exceed and RDT (Wan03)                  */
/* 01-JUN-2015  YTWan         2.1   SOS#343525 - UA - NoMixLottable validation */
/*                                  CR(Wan04)                                  */
/* 23-Mar-2021  WLChooi       2.2   Correct table name to LOTxLOCxID (WL01)    */
/* 10-Feb-2023  NJOW01        2.3   WMS-21722 Allow check nomixlottable for all*/
/*                                  commingle sku in a loc.                    */
/* 10-Feb-2023  NJOW01        2.3   DEVOPS Combine Script                      */
/*******************************************************************************/

CREATE   PROCEDURE nspASNPASTD
               @c_userid           NVARCHAR(18)
,              @c_StorerKey        NVARCHAR(15)
,              @c_LOT              NVARCHAR(10)
,              @c_SKU              NVARCHAR(20)
,              @c_ID               NVARCHAR(18)
,              @c_FromLoc          NVARCHAR(10)
,              @n_Qty              INT = 0
,              @c_Uom              NVARCHAR(10) = ''
,              @c_PackKey          NVARCHAR(10) = ''
,              @n_PutawayCapacity  INT
,              @c_Final_ToLoc      NVARCHAR(10) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_err int
   DECLARE @c_errmsg NVARCHAR(255)
   DECLARE @b_debug int
   -- Added By Shong
   DECLARE @n_RowCount int
   DECLARE @c_ToLoc NVARCHAR(10),
   @c_orderkey NVARCHAR(10),
   @n_IdCnt int,
   @b_MultiProductID int,
   @b_MultiLotID int ,
   @c_PutawayStrategyKey NVARCHAR(10),
   @c_userequipmentprofilekey NVARCHAR(10),
   @b_success int, @n_StdGrossWgt float(8),
   @n_pTraceHeadKey NVARCHAR(10),   -- Unique key value for the putaway trace header
   @n_PtraceDetailKey NVARCHAR(10), -- part of key value for the putaway trace detail
   @n_locsreviewed int,         -- counter for the number of location reviewed
   @c_Reason NVARCHAR(80),          -- putaway trace rejection reason text for putaway trace detail
   @d_startdtim datetime,       -- Start time of this stored procedure
   @n_QtylocationLimit int,      -- Location Qty Capacity for Case/Piece Pick Locations
   @c_Facility NVARCHAR(5), -- CDC Migration
   @n_MaxPallet int,
   @n_PalletQty int,
   @n_StackFactor int,           -- SOS36712 KCPI
   @n_MaxPalletStackFactor int,  -- SOS36712 KCPI
   @c_ToHostWhCode NVARCHAR(10),      -- SOS69388 KFP 
   @c_ChkLocByCommingleSkuFlag  NVARCHAR(10),      --(Wan03)
   @c_ChkNoMixLottableForAllSku NVARCHAR(30) = ''  --NJOW01      

--(Wan01) - START
DECLARE @b_CurrIDMultiLot01   INT    
      , @b_CurrIDMultiLot02   INT    
      , @b_CurrIDMultiLot03   INT    
      , @b_CurrIDMultiLot04   INT 
      , @b_CurrIDMultiLot06	INT	            		--(Wan04)     
      , @b_CurrIDMultiLot07	INT	            		--(Wan04)     
      , @b_CurrIDMultiLot08	INT	            		--(Wan04)     
      , @b_CurrIDMultiLot09	INT	            		--(Wan04)     
      , @b_CurrIDMultiLot10	INT	            		--(Wan04)     
      , @b_CurrIDMultiLot11	INT	            		--(Wan04)     
      , @b_CurrIDMultiLot12	INT	            		--(Wan04)     
      , @b_CurrIDMultiLot13	INT	                 	--(Wan04)     
      , @b_CurrIDMultiLot14	INT	                 	--(Wan04)     
      , @b_CurrIDMultiLot15	INT	                 	--(Wan04)     

      

      , @c_NoMixLottable01    NVARCHAR(1)
      , @c_NoMixLottable02    NVARCHAR(1)
      , @c_NoMixLottable03    NVARCHAR(1)
      , @c_NoMixLottable04    NVARCHAR(1)
      , @c_NoMixLottable06    NVARCHAR(1)             --(Wan04)
      , @c_NoMixLottable07    NVARCHAR(1)             --(Wan04)
      , @c_NoMixLottable08    NVARCHAR(1)             --(Wan04)
      , @c_NoMixLottable09    NVARCHAR(1)             --(Wan04)
      , @c_NoMixLottable10    NVARCHAR(1)             --(Wan04)
      , @c_NoMixLottable11    NVARCHAR(1)             --(Wan04)
      , @c_NoMixLottable12    NVARCHAR(1)             --(Wan04)
      , @c_NoMixLottable13    NVARCHAR(1)             --(Wan04)
      , @c_NoMixLottable14    NVARCHAR(1)             --(Wan04)
      , @c_NoMixLottable15    NVARCHAR(1)             --(Wan04)

   SET @b_CurrIDMultiLot01= 0
   SET @b_CurrIDMultiLot02= 0
   SET @b_CurrIDMultiLot03= 0
   SET @b_CurrIDMultiLot04= 0
   SET @b_CurrIDMultiLot06= 0                         --(Wan04)
   SET @b_CurrIDMultiLot07= 0                         --(Wan04)
   SET @b_CurrIDMultiLot08= 0                         --(Wan04)
   SET @b_CurrIDMultiLot09= 0                         --(Wan04)
   SET @b_CurrIDMultiLot10= 0                         --(Wan04)
   SET @b_CurrIDMultiLot11= 0                         --(Wan04) 
   SET @b_CurrIDMultiLot12= 0                         --(Wan04) 
   SET @b_CurrIDMultiLot13= 0                         --(Wan04) 
   SET @b_CurrIDMultiLot14= 0                         --(Wan04) 
   SET @b_CurrIDMultiLot15= 0                         --(Wan04) 

   SET @c_NoMixLottable01  = '0'
   SET @c_NoMixLottable02  = '0'
   SET @c_NoMixLottable03  = '0'
   SET @c_NoMixLottable04  = '0'
   SET @c_NoMixLottable06  = '0'                      --(Wan04)
   SET @c_NoMixLottable07  = '0'                      --(Wan04)
   SET @c_NoMixLottable08  = '0'                      --(Wan04)
   SET @c_NoMixLottable09  = '0'                      --(Wan04)
   SET @c_NoMixLottable10  = '0'                      --(Wan04)
   SET @c_NoMixLottable11  = '0'                      --(Wan04)
   SET @c_NoMixLottable12  = '0'                      --(Wan04)
   SET @c_NoMixLottable13  = '0'                      --(Wan04)
   SET @c_NoMixLottable14  = '0'                      --(Wan04)      
   SET @c_NoMixLottable15  = '0'                      --(Wan04)
--(Wan01) - END

   SELECT @c_ToLoc = SPACE(10),
   @n_IdCnt = 0,
   @b_MultiProductID = 0,
   @b_MultiLotID = 0,
   @n_LocsReviewed = 0,
   @d_StartDtim = getdate()

   SET @c_Final_ToLoc = ''

   /* Added By Vicky 10 Apr 2003 - CDC Migration */
   SELECT  @c_Facility = Facility
   FROM    LOC (NOLOCK)
   WHERE   Loc =  @c_FromLoc
   /* END Add */

   -- Modification for Unilever Philippines
   -- SOS 3265
   -- start : by Wally 18.jan.2002
   DECLARE @c_Lottable01 NVARCHAR(18),
           @c_Lottable02 NVARCHAR(18),
           @c_Lottable03 NVARCHAR(18), -- SOS#140197
           @d_Lottable04 datetime,
           @d_Lottable05 datetime, -- SOS#140197
           @c_lottable06   NVARCHAR(30)  		   --(Wan04)
         , @c_lottable07   NVARCHAR(30)  	      --(Wan04)
         , @c_lottable08   NVARCHAR(30)  	      --(Wan04)
         , @c_lottable09   NVARCHAR(30) 	      --(Wan04)
         , @c_lottable10   NVARCHAR(30)  	      --(Wan04)
         , @c_lottable11   NVARCHAR(30)  		   --(Wan04)
         , @c_lottable12   NVARCHAR(30)  		   --(Wan04)
         , @d_lottable13   datetime 	         --(Wan04)
         , @d_lottable14   datetime  		      --(Wan04)
         , @d_lottable15   datetime  			   --(Wan04)
         , @d_CurrentLottable05 datetime

   DECLARE @c_PTraceType NVARCHAR(30)
   SELECT @c_PTraceType = 'nspASNPASTD'

   -- If SKU not provided, then get from LOT
   IF ISNULL(RTRIM(@c_SKU),'') = ''
   BEGIN
      IF ISNULL(RTRIM(@c_LOT),'') <> ''
      BEGIN
         SELECT @c_StorerKey = StorerKey ,
                @c_SKU = SKU
         FROM LOT (NOLOCK)
         WHERE LOT = @c_LOT
      END
   END
   -- Check if Pallet contain Conmingle LOT?
   IF ISNULL(RTRIM(@c_ID),'') <> ''
   BEGIN
      SELECT @n_IdCnt = COUNT(DISTINCT LOT),
             @b_MultiProductID = CASE WHEN COUNT(DISTINCT SKU) > 1 THEN 1 ELSE 0 END
      FROM LOTxLOCxID (NOLOCK)
      WHERE ID = @c_ID
      AND LOC = @c_FromLoc
      AND QTY > 0
      IF @n_IdCnt = 1
      BEGIN
         SELECT @c_StorerKey = StorerKey ,
                @c_SKU = SKU,
                @n_Qty = CASE WHEN @n_Qty = 0 Then QTY ELSE @n_Qty END,
                @c_LOT = LOT
         FROM LOTxLOCxID (NOLOCK)
         WHERE ID = @c_ID
         AND LOC = @c_FromLoc
         AND QTY > 0
      END
      ELSE
      BEGIN
         SELECT @b_MultiLotID = 1  -- Multiproduct is multilot by definition of lot
         SET    @c_LOT = ''
      END
   END
   ELSE
   BEGIN
      IF ISNULL(RTRIM(@c_LOT),'') <> ''
      BEGIN
         SELECT @n_IdCnt = COUNT(DISTINCT ID)
         FROM LOTxLOCxID (NOLOCK)
         WHERE ID = @c_LOT
         AND LOC = @c_FromLoc
         AND QTY > 0
         IF @n_IdCnt = 1
         BEGIN
            SELECT @c_StorerKey = StorerKey ,
                   @c_SKU = SKU,
                   @c_ID = ID, @n_Qty = CASE WHEN @n_Qty = 0 Then QTY ELSE @n_Qty END
            FROM LOTxLOCxID (NOLOCK)
            WHERE ID = @c_LOT
            AND LOC = @c_FromLoc
            AND QTY > 0
         END
      END
   END

   IF @b_MultiLotID <> 1
   BEGIN
      -- SHONG SOS#140197
      SELECT @c_Lottable01 = Lottable01,
             @c_Lottable02 = Lottable02,
             @c_Lottable03 = Lottable03,
             @d_Lottable04 = Lottable04,
             @d_Lottable05 = Lottable05
            ,@c_Lottable06 = RTRIM(Lottable06)                                               --(Wan04) 
            ,@c_Lottable07 = RTRIM(Lottable07)                                               --(Wan04) 
            ,@c_Lottable08 = RTRIM(Lottable08)                                               --(Wan04) 
            ,@c_Lottable09 = RTRIM(Lottable09)                                               --(Wan04) 
            ,@c_Lottable10 = RTRIM(Lottable10)                                               --(Wan04) 
            ,@c_Lottable11 = RTRIM(Lottable11)                                               --(Wan04)       
            ,@c_Lottable12 = RTRIM(Lottable12)                                               --(Wan04) 
            ,@d_Lottable13 = ISNULL(Lottable13, CONVERT(DATETIME,'19000101'))                --(Wan04) 
            ,@d_Lottable14 = ISNULL(Lottable14, CONVERT(DATETIME,'19000101'))                --(Wan04)     
            ,@d_Lottable15 = ISNULL(Lottable15, CONVERT(DATETIME,'19000101'))                --(Wan04) 
      FROM   LotAttribute (NOLOCK)
      WHERE  LOT = @c_LOT
   END
   ELSE
   BEGIN
      -- If Multiple LOT Found, Get the last Lottables
      SELECT TOP 1
         @c_Lottable01 = Lottable01,
         @c_Lottable02 = Lottable02,
         @c_Lottable03 = Lottable03,
         @d_Lottable04 = Lottable04,
         @d_Lottable05 = Lottable05
        ,@c_Lottable06 = RTRIM(Lottable06)                                                   --(Wan04) 
        ,@c_Lottable07 = RTRIM(Lottable07)                                                   --(Wan04) 
        ,@c_Lottable08 = RTRIM(Lottable08)                                                   --(Wan04) 
        ,@c_Lottable09 = RTRIM(Lottable09)                                                   --(Wan04) 
        ,@c_Lottable10 = RTRIM(Lottable10)                                                   --(Wan04) 
        ,@c_Lottable11 = RTRIM(Lottable11)                                                   --(Wan04)       
        ,@c_Lottable12 = RTRIM(Lottable12)                                                   --(Wan04) 
        ,@d_Lottable13 = ISNULL(Lottable13, CONVERT(DATETIME,'19000101'))                    --(Wan04) 
        ,@d_Lottable14 = ISNULL(Lottable14, CONVERT(DATETIME,'19000101'))                    --(Wan04)     
        ,@d_Lottable15 = ISNULL(Lottable15, CONVERT(DATETIME,'19000101'))                    --(Wan04) 
      FROM  LotAttribute WITH (NOLOCK)
      JOIN  LOTxLOCxID WITH (NOLOCK) ON LotAttribute.LOT = LOTxLOCxID.LOT
      WHERE ID = @c_ID
      ORDER BY LotAttribute.LOT DESC
      
      --(Wan01) - START
      SELECT @b_CurrIDMultiLot01 = CASE WHEN COUNT(DISTINCT LA.Lottable01) > 1 THEN 1 ELSE 0 END  
            ,@b_CurrIDMultiLot02 = CASE WHEN COUNT(DISTINCT LA.Lottable02) > 1 THEN 1 ELSE 0 END 
            ,@b_CurrIDMultiLot03 = CASE WHEN COUNT(DISTINCT LA.Lottable03) > 1 THEN 1 ELSE 0 END 
            ,@b_CurrIDMultiLot04 = CASE WHEN COUNT(DISTINCT LA.Lottable04) > 1 THEN 1 ELSE 0 END 
            ,@b_CurrIDMultiLot06 = CASE WHEN COUNT(DISTINCT LA.Lottable06) > 1 THEN 1 ELSE 0 END   --(Wan04)   
            ,@b_CurrIDMultiLot07 = CASE WHEN COUNT(DISTINCT LA.Lottable07) > 1 THEN 1 ELSE 0 END   --(Wan04)
            ,@b_CurrIDMultiLot08 = CASE WHEN COUNT(DISTINCT LA.Lottable08) > 1 THEN 1 ELSE 0 END   --(Wan04)
            ,@b_CurrIDMultiLot09 = CASE WHEN COUNT(DISTINCT LA.Lottable09) > 1 THEN 1 ELSE 0 END   --(Wan04)
            ,@b_CurrIDMultiLot10 = CASE WHEN COUNT(DISTINCT LA.Lottable10) > 1 THEN 1 ELSE 0 END   --(Wan04)
            ,@b_CurrIDMultiLot11 = CASE WHEN COUNT(DISTINCT LA.Lottable11) > 1 THEN 1 ELSE 0 END   --(Wan04)    
            ,@b_CurrIDMultiLot12 = CASE WHEN COUNT(DISTINCT LA.Lottable12) > 1 THEN 1 ELSE 0 END   --(Wan04)
            ,@b_CurrIDMultiLot13 = CASE WHEN COUNT(DISTINCT LA.Lottable13) > 1 THEN 1 ELSE 0 END   --(Wan04)
            ,@b_CurrIDMultiLot14 = CASE WHEN COUNT(DISTINCT LA.Lottable14) > 1 THEN 1 ELSE 0 END   --(Wan04)
            ,@b_CurrIDMultiLot15 = CASE WHEN COUNT(DISTINCT LA.Lottable15) > 1 THEN 1 ELSE 0 END   --(Wan04)
      FROM LOTATTRIBUTE LA WITH (NOLOCK)
      JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
      WHERE LLI.ID = @c_ID
      AND   LLI.Loc= @c_FromLoc
      AND   LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIn > 0   --(Wan02)
      --(Wan01) - END      
   END


   EXEC nspGetPack @c_StorerKey,
      @c_SKU,
      @c_LOT,
      @c_FromLoc,
      @c_ID,
      @c_PackKey OUTPUT,
      @b_success OUTPUT,
      @n_err OUTPUT,
      @c_errmsg OUTPUT
   IF @b_success = 0
   BEGIN
      SELECT @c_ToLoc = ''
      GOTO LOCATION_ERROR
   END

   IF @b_MultiProductID = 0
   BEGIN
      SELECT @c_PutawayStrategyKey = STRATEGY.PutAwayStrategyKey,
             @n_StdGrossWgt = SKU.StdGrossWgt
      FROM STRATEGY (NOLOCK)
      JOIN SKU (NOLOCK) ON SKU.STRATEGYKEY = STRATEGY.Strategykey
      WHERE SKU.StorerKey = @c_StorerKey
      AND SKU.SKU = @c_SKU

   END
   ELSE
   BEGIN
      SELECT @c_PutawayStrategyKey = Strategy.Putawaystrategykey
      FROM STRATEGY (NOLOCK)
      WHERE STRATEGYKEY = 'SYSTEM'
   END

   IF LTRIM(@c_ID) IS NOT NULL AND LTRIM(@c_ID) <> ''
      AND @n_Qty = 0
      AND @b_MultiProductID = 0
   BEGIN
      SELECT @n_Qty = SUM(Qty)
      --FROM LOTxLOCxID.ID (NOLOCK)   --WL01
      FROM LOTxLOCxID (NOLOCK)   --WL01
      WHERE ID = @c_ID
   END

   SELECT @b_debug = CONVERT(int, NSQLValue)
   FROM NSQLCONFIG (NOLOCK)
   WHERE ConfigKey = 'PutawayTraceReport'
   IF @b_debug IS NULL
   BEGIN
      SELECT @b_debug = 0
   END
   IF @b_debug = 1
   BEGIN
      -- insert records into PTRACEHEAD table
      EXEC nspPTH @c_PTraceType, @c_userid, @c_StorerKey,
           @c_SKU, @c_LOT, @c_ID, @c_PackKey, @n_Qty,
           @b_MultiProductID, @b_MultiLotID,
           @d_startdtim, NULL, 0, NULL, @n_pTraceHeadKey OUTPUT
   END

   --(Wan03) - START
   SET @c_ChkLocByCommingleSkuFlag = '0'
   SET @b_success = 0
   Execute nspGetRight 
           @c_facility
         , @c_StorerKey               -- Storer
         , @c_Sku                     -- Sku
         , 'ChkLocByCommingleSkuFlag'  -- ConfigKey
         , @b_success                     OUTPUT 
         , @c_ChkLocByCommingleSkuFlag    OUTPUT 
         , @n_err                         OUTPUT 
         , @c_errmsg                      OUTPUT
   
   IF @b_success <> 1
   BEGIN
      SET @c_ToLoc = ''
      GOTO LOCATION_ERROR
   END
   --(Wan03) - END
   
   --NJOW01 S
   SET @b_success = 0
   Execute nspGetRight 
           @c_facility
         , @c_StorerKey                -- Storer
         , @c_Sku                      -- Sku
         , 'ChkNoMixLottableForAllSku' -- ConfigKey
         , @b_success                     OUTPUT 
         , @c_ChkNoMixLottableForAllSku   OUTPUT 
         , @n_err                         OUTPUT 
         , @c_errmsg                      OUTPUT
   
   IF @b_success <> 1
   BEGIN
      SET @c_ToLoc = ''
      GOTO LOCATION_ERROR
   END
   --NJOW01 E

   DECLARE
   @c_PutawayStrategyLineNumber        NVARCHAR(5)   ,
   @b_RestrictionsPassed               int ,
   @b_GotLoc                           int ,
   @cpa_PAType                         NVARCHAR(5)   ,
   @cpa_FROMLOC                        NVARCHAR(10)  ,
   @cPA_ToLoc                          NVARCHAR(10)  ,
   @cpa_AreaKey                        NVARCHAR(10)  ,
   @cpa_Zone                           NVARCHAR(10)  ,
   @cpa_LocType                        NVARCHAR(10)  ,
   @cpa_LocSearchType                  NVARCHAR(10)  ,
   @cpa_DimensionRestriction01         NVARCHAR(5)   ,
   @cpa_DimensionRestriction02         NVARCHAR(5)   ,
   @cpa_DimensionRestriction03         NVARCHAR(5)   ,
   @cpa_DimensionRestriction04         NVARCHAR(5)   ,
   @cpa_DimensionRestriction05         NVARCHAR(5)   ,
   @cpa_DimensionRestriction06         NVARCHAR(5)   ,
   @cpa_LocationTypeExclude01          NVARCHAR(10)  ,
   @cpa_LocationTypeExclude02          NVARCHAR(10)  ,
   @cpa_LocationTypeExclude03          NVARCHAR(10)  ,
   @cpa_LocationTypeExclude04          NVARCHAR(10)  ,
   @cpa_LocationTypeExclude05          NVARCHAR(10)  ,
   @cpa_LocationFlagExclude01          NVARCHAR(10)  ,
   @cpa_LocationFlagExclude02          NVARCHAR(10)  ,
   @cpa_LocationFlagExclude03          NVARCHAR(10)  ,
   @cpa_LocationCategoryExclude01      NVARCHAR(10)  ,
   @cpa_LocationCategoryExclude02      NVARCHAR(10)  ,
   @cpa_LocationCategoryExclude03      NVARCHAR(10)  ,
   @cpa_LocationHandlingExclude01      NVARCHAR(10)  ,
   @cpa_LocationHandlingExclude02      NVARCHAR(10)  ,
   @cpa_LocationHandlingExclude03      NVARCHAR(10)  ,
   @cpa_LocationFlagInclude01          NVARCHAR(10)  ,
   @cpa_LocationFlagInclude02          NVARCHAR(10)  ,
   @cpa_LocationFlagInclude03          NVARCHAR(10)  ,
   @cpa_LocationCategoryInclude01      NVARCHAR(10)  ,
   @cpa_LocationCategoryInclude02      NVARCHAR(10)  ,
   @cpa_LocationCategoryInclude03      NVARCHAR(10)  ,
   @cpa_LocationHandlingInclude01      NVARCHAR(10)  ,
   @cpa_LocationHandlingInclude02      NVARCHAR(10)  ,
   @cpa_LocationHandlingInclude03      NVARCHAR(10)  ,
   @cpa_AreaTypeExclude01              NVARCHAR(10)  ,
   @cpa_AreaTypeExclude02              NVARCHAR(10)  ,
   @cpa_AreaTypeExclude03              NVARCHAR(10)  ,
   @cpa_LocationTypeRestriction01      NVARCHAR(5)   ,
   @cpa_LocationTypeRestriction02      NVARCHAR(5)   ,
   @cpa_LocationTypeRestriction03      NVARCHAR(5)   ,
   @cpa_LocationTypeRestriction04      NVARCHAR(5)   ,
   @cpa_LocationTypeRestriction05      NVARCHAR(5)   ,
   @cpa_LocationTypeRestriction06      NVARCHAR(5)   ,
   @cpa_FitFullReceipt                 NVARCHAR(5)  ,
   @cpa_OrderType                      NVARCHAR(10)  ,
   @npa_NumberofDaysOffSet             int       ,
   @cpa_LocationStateRestriction1      NVARCHAR(5)   ,
   @cpa_LocationStateRestriction2      NVARCHAR(5)   ,
   @cpa_LocationStateRestriction3      NVARCHAR(5)   ,
   @cpa_AllowFullPallets               NVARCHAR(5)   ,
   @cpa_AllowFullCases                 NVARCHAR(5)   ,
   @cpa_AllowPieces                    NVARCHAR(5)   ,
   @cpa_CheckEquipmentProfileKey       NVARCHAR(5)   ,
   @cpa_CheckRestrictions              NVARCHAR(5)
   DECLARE @c_Loc_Type NVARCHAR(10), @c_loc_zone NVARCHAR(10),
   @c_loc_category NVARCHAR(10), @c_loc_flag NVARCHAR(10),
   @c_loc_handling NVARCHAR(10),
   @n_Loc_Width float, @n_Loc_Length float, @n_Loc_Height float,
   @n_Loc_CubicCapacity float, @n_Loc_WeightCapacity float,
   @c_movableunittype NVARCHAR(10), -- 1=pallet,2=case,3=innerpack,4=other1,5=other2,6=piece
   @c_Loc_CommingleSku NVARCHAR(1),
   @c_loc_comminglelot NVARCHAR(1),
   @n_FromCube float,   -- the cube of the product/id being putaway
   @n_ToCube float,     -- the cube of existing product in the candidate location
   @n_FromWeight float, -- the weight of the product/id being putaway
   @n_ToWeight float,   -- the weight of existing product in the candidate location
   @n_PalletWoodWidth float, -- the width of the pallet wood being putaway
   @n_PalletWoodLength float, -- the length of the pallet wood being putaway
   @n_PalletWoodHeight float,  -- the height of the pallet wood being putaway
   @n_PalletHeight float,  -- the height of the pallet wood being putaway
   @n_CaseWidth float, -- the width of the cases on the  pallet being putaway
   @n_CaseLength float, -- the length of the cases on the  pallet being putaway
   @n_CaseHeight float,  -- the height of the cases on the pallet being putaway
   @n_ExistingHeight float, -- the height of any existing product in a candidate location
   @n_ExistingQuantity integer, -- the quantity of any existing product in a candidate location
   @n_QuantityCapacity integer, -- the quantity based on cube which could fit in candidate location
   @n_PackCaseCount integer,    -- the number of pieces in a case for the pack
   @n_UOMcapacity integer,      -- the number of a UOM cubic capacity which fits inside a cube
   @n_PutawayTI integer,        -- the number of cases on a pallet layer/tier
   @n_PutawayHI integer,        -- the number of layers/tiers on a pallet
   @n_ToQty integer,            -- Variable to hold quantity already in a location
   @n_ExistingLayers integer,   -- number of layers/tiers indicator
   @n_ExtraLayer integer,       -- a partial layer/tier indicator
   @n_CubeUOM1 float,           -- volumetric cube of UOM1
   @n_QtyUOM1 integer,          -- number of eaches in UOM1
   @n_CubeUOM3 float,           -- volumetric cube of UOM2
   @n_QtyUOM3 integer,          -- number of eaches in UOM2
   @n_CubeUOM4 float,           -- volumetric cube of UOM4
   @n_QtyUOM4 integer,          -- number of eaches in UOM4
   @c_searchzone NVARCHAR(10),
   @c_searchlogicalloc NVARCHAR(18),
   @n_CurrLocMultiSku int,      -- Current Location/Putaway Pallet is Commingled Sku
   @n_CurrLocMultiLot int       -- Current Location/Putaway Pallet is Commingled Lot
   -- For Checking Maximum Pallet
   -- Added by DLIM September 2001
   DECLARE @n_PendingPalletQty int, @n_TtlPalletQty int
   -- END Add by DLIM

   -- SOS#133381 Add new restriction on Location Level And Aisle
   DECLARE @npa_LocLevelInclude01   int
          ,@npa_LocLevelInclude02   int
          ,@npa_LocLevelInclude03   int
          ,@npa_LocLevelInclude04   int
          ,@npa_LocLevelInclude05   int
          ,@npa_LocLevelInclude06   int
          ,@npa_LocLevelExclude01   int
          ,@npa_LocLevelExclude02   int
          ,@npa_LocLevelExclude03   int
          ,@npa_LocLevelExclude04   int
          ,@npa_LocLevelExclude05   int
          ,@npa_LocLevelExclude06   int
          ,@cpa_LocAisleInclude01   NVARCHAR(10)
          ,@cpa_LocAisleInclude02   NVARCHAR(10)
          ,@cpa_LocAisleInclude03   NVARCHAR(10)
          ,@cpa_LocAisleInclude04   NVARCHAR(10)
          ,@cpa_LocAisleInclude05   NVARCHAR(10)
          ,@cpa_LocAisleInclude06   NVARCHAR(10)
          ,@cpa_LocAisleExclude01   NVARCHAR(10)
          ,@cpa_LocAisleExclude02   NVARCHAR(10)
          ,@cpa_LocAisleExclude03   NVARCHAR(10)
          ,@cpa_LocAisleExclude04   NVARCHAR(10)
          ,@cpa_LocAisleExclude05   NVARCHAR(10)
          ,@cpa_LocAisleExclude06   NVARCHAR(10)

   DECLARE @n_loc_level int,
           @c_loc_aisle NVARCHAR(10)

   SELECT @c_PutawayStrategyLineNumber = Space(5),
      @b_GotLoc = 0
   WHILE (1=1)
   BEGIN
      SET ROWCOUNT 1
      SELECT @c_PutawayStrategyLineNumber    =  putawaystrategylinenumber     ,
      @cpa_PAType                     =  PAType                        ,
      @cpa_FROMLOC                    =  FROMLOC                       ,
      @cPA_ToLoc                      =  TOLOC                         ,
      @cpa_AreaKey                    =  AreaKey                       ,
      @cpa_Zone                       =  Zone                          ,
      @cpa_LocType                    =  LocType                       ,
      @cpa_LocSearchType              =  LocSearchType                 ,
      @cpa_DimensionRestriction01     =  DimensionRestriction01        ,
      @cpa_DimensionRestriction02     =  DimensionRestriction02        ,
      @cpa_DimensionRestriction03     =  DimensionRestriction03        ,
      @cpa_DimensionRestriction04     =  DimensionRestriction04        ,
      @cpa_DimensionRestriction05     =  DimensionRestriction05        ,
      @cpa_DimensionRestriction06     =  DimensionRestriction06        ,
      @cpa_LocationTypeExclude01      =  LocationTypeExclude01         ,
      @cpa_LocationTypeExclude02      =  LocationTypeExclude02         ,
      @cpa_LocationTypeExclude03      =  LocationTypeExclude03         ,
      @cpa_LocationTypeExclude04      =  LocationTypeExclude04         ,
      @cpa_LocationTypeExclude05      =  LocationTypeExclude05         ,
      @cpa_LocationFlagExclude01      =  LocationFlagExclude01         ,
      @cpa_LocationFlagExclude02      =  LocationFlagExclude02         ,
      @cpa_LocationFlagExclude03      =  LocationFlagExclude03         ,
      @cpa_LocationCategoryExclude01  =  LocationCategoryExclude01     ,
      @cpa_LocationCategoryExclude02  =  LocationCategoryExclude02     ,
      @cpa_LocationCategoryExclude03  =  LocationCategoryExclude03     ,
      @cpa_LocationHandlingExclude01  =  LocationHandlingExclude01     ,
      @cpa_LocationHandlingExclude02  =  LocationHandlingExclude02     ,
      @cpa_LocationHandlingExclude03  =  LocationHandlingExclude03     ,
      @cpa_LocationFlagInclude01      =  LocationFlagInclude01         ,
      @cpa_LocationFlagInclude02      =  LocationFlagInclude02         ,
      @cpa_LocationFlagInclude03      =  LocationFlagInclude03 ,
      @cpa_LocationCategoryInclude01  =  LocationCategoryInclude01     ,
      @cpa_LocationCategoryInclude02  =  LocationCategoryInclude02     ,
      @cpa_LocationCategoryInclude03  =  LocationCategoryInclude03     ,
      @cpa_LocationHandlingInclude01  =  LocationHandlingInclude01     ,
      @cpa_LocationHandlingInclude02  =  LocationHandlingInclude02     ,
      @cpa_LocationHandlingInclude03  =  LocationHandlingInclude03     ,
      @cpa_AreaTypeExclude01          =  AreaTypeExclude01             ,
      @cpa_AreaTypeExclude02          =  AreaTypeExclude02             ,
      @cpa_AreaTypeExclude03          =  AreaTypeExclude03             ,
      @cpa_LocationTypeRestriction01  =  LocationTypeRestriction01     ,
      @cpa_LocationTypeRestriction02  =  LocationTypeRestriction02     ,
      @cpa_LocationTypeRestriction03  =  LocationTypeRestriction03     ,
      @cpa_FitFullReceipt             =  FitFullReceipt                ,
      @cpa_OrderType                  =  OrderType                     ,
      @npa_NumberofDaysOffSet         =  NumberofDaysOffSet            ,
      @cpa_LocationStateRestriction1  =  LocationStateRestriction01    ,
      @cpa_LocationStateRestriction2  =  LocationStateRestriction02    ,
      @cpa_LocationStateRestriction3  =  LocationStateRestriction03    ,
      @cpa_AllowFullPallets           =  AllowFullPallets              ,
      @cpa_AllowFullCases             =  AllowFullCases                ,
      @cpa_AllowPieces                =  AllowPieces                   ,
      @cpa_CheckEquipmentProfileKey   =  CheckEquipmentProfileKey      ,
      @cpa_CheckRestrictions          =  CheckRestrictions             ,
      @npa_LocLevelInclude01          =  LocLevelInclude01             ,
      @npa_LocLevelInclude02          =  LocLevelInclude02             ,
      @npa_LocLevelInclude03          =  LocLevelInclude03             ,
      @npa_LocLevelInclude04          =  LocLevelInclude04             ,
      @npa_LocLevelInclude05          =  LocLevelInclude05             ,
      @npa_LocLevelInclude06          =  LocLevelInclude06             ,
      @npa_LocLevelExclude01          =  LocLevelExclude01             ,
      @npa_LocLevelExclude02          =  LocLevelExclude02             ,
      @npa_LocLevelExclude03          =  LocLevelExclude03             ,
      @npa_LocLevelExclude04          =  LocLevelExclude04             ,
      @npa_LocLevelExclude05          =  LocLevelExclude05             ,
      @npa_LocLevelExclude06          =  LocLevelExclude06             ,
      @cpa_LocAisleInclude01          =  LocAisleInclude01             ,
      @cpa_LocAisleInclude02          =  LocAisleInclude02             ,
      @cpa_LocAisleInclude03          =  LocAisleInclude03             ,
      @cpa_LocAisleInclude04          =  LocAisleInclude04             ,
      @cpa_LocAisleInclude05          =  LocAisleInclude05             ,
      @cpa_LocAisleInclude06          =  LocAisleInclude06             ,
      @cpa_LocAisleExclude01          =  LocAisleExclude01             ,
      @cpa_LocAisleExclude02          =  LocAisleExclude02             ,
      @cpa_LocAisleExclude03          =  LocAisleExclude03             ,
      @cpa_LocAisleExclude04          =  LocAisleExclude04             ,
      @cpa_LocAisleExclude05          =  LocAisleExclude05             ,
      @cpa_LocAisleExclude06          =  LocAisleExclude06
      FROM PUTAWAYSTRATEGYDETAIL WITH (NOLOCK)
      WHERE PutAwayStrategyKey = @c_PutawayStrategyKey
      AND putawaystrategylinenumber > @c_PutawayStrategyLineNumber
      ORDER BY putawaystrategylinenumber
      IF @@ROWCOUNT = 0
      BEGIN
         SET ROWCOUNT 0
         BREAK
      END
      SET ROWCOUNT 0
      IF @b_debug = 1
      BEGIN
         -- Insert records into PTRACEDETAIL table
         SELECT @c_Reason = 'CHANGE of Putaway Type to ' + @cpa_PAType
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         '', @c_Reason
      END

      IF @b_debug = 2
      BEGIN
         SELECT 'putawaystrategykey is ' + @c_PutawayStrategyKey
      END

      IF @cpa_PAType = '01' -- If Source=FROMLOCATION, Putaway to TOLOCATION
      BEGIN
         IF @c_FromLoc = @cpa_fromloc
         BEGIN
            IF LTRIM(@cPA_ToLoc) IS NOT NULL AND LTRIM(@cPA_ToLoc) <> ''
            BEGIN
               SELECT @c_ToLoc = @cPA_ToLoc

               IF @cpa_checkrestrictions = 'Y'
               BEGIN
                  SELECT @b_RestrictionsPassed = 0
                  GOTO PA_CHECKRESTRICTIONS

                  PATYPE01:
                  IF @b_RestrictionsPassed = 1
                  BEGIN
                     SELECT @b_GotLoc = 1
                     IF @b_debug = 1
                     BEGIN
                        SELECT @c_Reason = 'FOUND PAType=01: from location ' + RTRIM(@c_FromLoc) + ' <> ' + RTRIM(@cpa_fromloc)
                        EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
                     END
                     BREAK
                  END
               END
               ELSE
               BEGIN
                  SELECT @b_GotLoc = 1
                  IF @b_debug = 1
                  BEGIN
                     SELECT @c_Reason = 'FOUND PAType=01: from location ' + RTRIM(@c_FromLoc) + ' <> ' + RTRIM(@cpa_fromloc)
                     EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                     @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                     @c_ToLoc, @c_Reason
                  END
                  BREAK
               END
            END
         END
         ELSE
         BEGIN
            IF @b_debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED PAType=01: from location ' + RTRIM(@c_FromLoc) + ' <> ' + RTRIM(@cpa_fromloc)
               EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
               @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
               @c_ToLoc, @c_Reason
            END
         END
         CONTINUE
      END -- PAType = '01'
      
--    Add new Strategy 03 - Put to Pick Loc If  
--    from Specified Location 

      IF @cpa_PAType = '03' -- If Source=FromLocATION, Putaway to Pick Location  
      BEGIN  
         IF @c_FromLoc = @cpa_FromLoc  
         BEGIN  
            SET @cpa_ToLoc = ''  
            SELECT TOP 1  
                   @cpa_ToLoc = LOC   
            FROM   SKUxLOC sl WITH (NOLOCK)  
            WHERE  sl.StorerKey = @c_StorerKey  
            AND    sl.Sku = @c_SKU  
            AND    sl.LocationType IN ('PICK','CASE')  
              
            IF ISNULL(RTRIM(@cpa_ToLoc),'') <> ''  
            BEGIN  
               SELECT @c_ToLoc = @cpa_ToLoc  
  
               IF @cpa_CheckRestrictions = 'Y'  
               BEGIN  
                  SELECT @b_RestrictionsPassed = 0  
                  GOTO PA_CHECKRESTRICTIONS  
  
                  PATYPE03:  
                  IF @b_RestrictionsPassed = 1  
                  BEGIN  
                     SELECT @b_GotLoc = 1  
                     IF @b_debug = 1  
                     BEGIN  
                        SELECT @c_Reason = 'FOUND PAType=03: from location ' + RTRIM(@c_FromLoc) + ' <> ' + RTRIM(@cpa_FromLoc)  
                        EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,  
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,  
                        @c_ToLoc, @c_Reason  
                     END  
                     BREAK  
                  END  
               END  
               ELSE  
               BEGIN  
                  SELECT @b_GotLoc = 1  
                  IF @b_debug = 1  
                  BEGIN  
                     SELECT @c_Reason = 'FOUND PAType=03: from location ' + RTRIM(@c_FromLoc) + ' <> ' + RTRIM(@cpa_FromLoc)  
                     EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,  
                     @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,  
                     @c_ToLoc, @c_Reason  
                  END  
                  BREAK  
               END  
            END -- LTRIM(RTRIM(@cpa_ToLoc),'') <> ''  
            ELSE  
            BEGIN  
               IF @b_debug = 1  
               BEGIN  
                  SELECT @c_Reason = 'FAILED PAType=03: from location ' + RTRIM(@c_FromLoc) + ', PICK Location Not Setup'  
                  EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,  
                  @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,  
                  @c_ToLoc, @c_Reason  
               END  
                 
            END  
         END  
         ELSE  
         BEGIN  
            IF @b_debug = 1  
            BEGIN  
               SELECT @c_Reason = 'FAILED PAType=03: from location ' + RTRIM(@c_FromLoc) + ' <> ' + RTRIM(@cpa_FromLoc)  
               EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,  
               @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,  
               @c_ToLoc, @c_Reason  
            END  
         END  
         CONTINUE  
      END -- PAType = '03'  
-----------------------------------------------------------  
      IF @cpa_PAType = '59' or -- SOS133180 UK Project - IF ID Held, PUT TO Specified ZONE
         @cpa_PAType = '60'    -- SOS133180 UK Project - IF ID Held, PUT TO Specified location
      BEGIN
         IF ISNULL(RTRIM(@c_ID), '') = '' OR
            EXISTS( SELECT 1 FROM ID WITH (NOLOCK) WHERE ID = @c_ID AND Status = 'OK' )
         BEGIN
            IF @b_debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED PAType=' + RTRIM(@cpa_PAType) + ': Pallet ID NOT On-Hold Or Blank '
               EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
               @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
               @c_ToLoc, @c_Reason
            END
            CONTINUE
         END
         IF @cpa_PAType = '60'  -- Search Specified Location When Pallet ID on Hold  
         BEGIN
            IF LTRIM(@cPA_ToLoc) IS NOT NULL AND LTRIM(@cPA_ToLoc) <> ''
            BEGIN
               SELECT @c_ToLoc = @cPA_ToLoc

               IF @cpa_checkrestrictions = 'Y'
               BEGIN
                  SELECT @b_RestrictionsPassed = 0
                  GOTO PA_CHECKRESTRICTIONS

                  PATYPE60:
                  IF @b_RestrictionsPassed = 1
                  BEGIN
                     SELECT @b_GotLoc = 1
                     IF @b_debug = 1
                     BEGIN
                        SELECT @c_Reason = 'FOUND PAType=60: Held ID ' + RTRIM(@c_ID) + ' Putaway to specified location ' + RTRIM(@cPA_ToLoc)
                        EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
                     END
                     BREAK
                  END
                  BEGIN
                     SELECT @b_GotLoc = 1
                     IF @b_debug = 1
                     BEGIN
                        SELECT @c_Reason = 'FOUND PAType=60: Held ID ' + RTRIM(@c_ID) + ' Putaway to specified location ' + RTRIM(@cPA_ToLoc)
                        EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
                     END
                     BREAK
                  END
               END
            END
            CONTINUE
         END
      END

      IF @cpa_PAType = '02' or -- IF source is FROMLOC then move to a location within the specified zone
         @cpa_PAType = '04' or -- Search ZONE specified on this strategy record
         @cpa_PAType = '12' or -- Search ZONE specified in sku table
         @cpa_PAType = '16' or -- IDSV5 - Leo - SOS# 3553 - Search Location With the same Sku Within Sku Zone
         @cpa_PAType = '17' or -- SOS36712 KCPI - Search Empty Location Within Sku Zone
         @cpa_PAType = '18' or -- SOS36712 KCPI - Search Location Within Specified Zone
         @cpa_PAType = '19' or -- SOS36712 KCPI - Search Empty Location Within Specified Zone
         @cpa_PAType = '22' or -- Search ZONE specified in sku table for Single Pallet and must be Empty Loc
         @cpa_PAType = '24' or -- Search ZONE specified in this strategy for Single Pallet and must be empty Loc
         @cpa_PAType = '32' or -- Search ZONE specified in sku table for Multi Pallet where unique sku = sku putaway
         @cpa_PAType = '34' or -- Search ZONE specified in this strategy for Multi Pallet where unique sku = sku putaway
         @cpa_PAType = '42' or -- Search ZONE specified in sku table for Empty Multi Pallet Location
         @cpa_PAType = '44' or -- Search ZONE specified in this strategy for empty Multi Pallet location
         @cpa_PAType = '52' or -- Search Zone specified in SKU table for matching Lottable02 and Lottable04
         @cpa_PAType = '54' or -- Search Specified Zone (Matching Lottable02 and Lottable04)  
         @cpa_PAType = '55' or -- SOS69388 KFP - Cross facility - search location within specified zone
                               --                with matching Lottable02 and Lottable04 (do not mix sku)
         @cpa_PAType = '56' or -- SOS69388 KFP - Cross facility - search Empty Location base on HostWhCode inventory = 0
         @cpa_PAType = '57' or -- SOS69388 KFP - Cross facility - search suitable location within specified zone (mix with diff sku)
         @cpa_PAType = '58' or -- SOS69388 KFP - Cross facility - search suitable location within specified zone (do not mix sku)
         @cpa_PAType = '59'    -- SOS133180 UK Project - IF ID Held, PUT TO Specified ZONE
      BEGIN
         IF @cpa_PAType = '02' or -- If Source=FromLocATION,Search Specified Zone For Suitable Location  
            @cpa_PAType = '55' or -- SOS69388 KFP - Cross facility - search location within specified zone
                                  --                with matching Lottable02 and Lottable04 (do not mix sku)
            @cpa_PAType = '56' or -- SOS69388 KFP - Cross facility - search Empty Location base on HostWhCode inventory = 0
            @cpa_PAType = '57' or -- SOS69388 KFP - Cross facility - search suitable location within specified zone (mix with diff sku)
            @cpa_PAType = '58'    -- SOS69388 KFP - Cross facility - search suitable location within specified zone (do not mix sku)
         BEGIN
            IF @c_FromLoc = @cpa_fromloc
            BEGIN
               SELECT @c_searchzone = @cpa_zone
            END
         END
         IF @cpa_PAType = '04' OR -- Search Specified Zone For Suitable Location  
            @cpa_PAType = '18' or -- SOS36712 KCPI - Search Location Within Specified Zone  
            @cpa_PAType = '19' or -- SOS36712 KCPI - Search Empty Location Within Specified Zone  
            @cpa_PAType = '24' OR -- Search Specified Zone (Single and Empty pallet Locations only)  
            @cpa_PAType = '34' OR -- Search Specified Zone (Multi Pallet locations with Unique SKU)  
            @cpa_PAType = '44' OR -- Search Specified Zone (Empty Multi pallet Locations Only)  
            @cpa_PAType = '54' OR -- Search Specified Zone (Matching Lottable02 and Lottable04)  
            @cpa_PAType = '59'    -- Search Specified Zone When Pallet ID on Hold  
         BEGIN  
            SELECT @c_searchzone = @cpa_zone
         END
         IF @cpa_PAType = '12' OR -- Search Zone specified in sku table For Suitable Location  
            @cpa_PAType = '16' or -- IDSV5 - Leo - SOS# 3553 - Search Location With the same Sku Within Sku Zone  
            @cpa_PAType = '17' or -- SOS36712 KCPI - Search Empty Location Within Sku Zone  
            @cpa_PAType = '22' OR -- Search Zone Specified in SKU table (Single and Empty pallet Locations only)  
            @cpa_PAType = '32' OR -- Search Zone specified in sku table For Suitable Location  
            @cpa_PAType = '42' OR -- Search Zone Specified in SKU table (Empty Multi pallet Locations Only)  
            @cpa_PAType = '52'    -- Search Zone Specified in SKU Table (Matching Lottable02 and Lottable04)  
         BEGIN  
            IF LTRIM(@c_SKU) IS NOT NULL AND LTRIM(@c_SKU) <> ''
               AND NOT (@b_MultiProductID = 1 or @b_MultiLotID = 1)
            BEGIN
               SELECT @c_searchzone = Putawayzone
               FROM SKU (NOLOCK)
               WHERE StorerKey = @c_StorerKey
               AND SKU = @c_SKU
            END
            ELSE
            BEGIN
               IF @b_debug = 1
               BEGIN
                  SELECT @c_Reason = 'FAILED PAType=' + RTRIM(@cpa_PAType) + ': Commodity and Storer combination not found'
                  EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                  @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                  @c_ToLoc, @c_Reason
               END
               CONTINUE -- This search does not apply because there is no sku
            END
         END

         -- Chekcing
         IF @b_debug = 2
         BEGIN
            SELECT 'PAType is ' + @cpa_PAType + ', SearchZone is ' + @c_searchzone
         END

         IF LTRIM(@c_searchzone) IS NOT NULL AND LTRIM(@c_searchzone) <> ''
         BEGIN
            IF @cpa_LocSearchType = '1' -- Search Zone By Location Code
            BEGIN
               IF @cpa_PAType = '02' or -- IF source is FROMLOC then move to a location within the specified zone
                  @cpa_PAType = '04' or -- Search ZONE specified on this strategy record
                  @cpa_PAType = '12'    -- Search Zone specified in sku table For Suitable Location  
               BEGIN
                  DECLARE @n_StdCube                float
                  DECLARE @c_SelectSQL              nvarchar(4000)
                  DECLARE @c_LocFlagRestriction     nvarchar(1000)
                  DECLARE @c_LocTypeRestriction     nvarchar(1000)
                  DECLARE @c_LocCategoryRestriction nvarchar(1000)
                  DECLARE @n_NoOfInclude            int
                  DECLARE @c_DimRestSQL             nvarchar(3000)
                  DECLARE @c_LocLevelRestriction    nvarchar(2000)
                  DECLARE @c_LocAisleRestriction    nvarchar(2000)

                  SELECT @n_StdCube =  Sku.StdCube,
                         @n_StdGrossWgt = Sku.StdGrossWgt
                  FROM SKU WITH (NOLOCK)
                  WHERE SKU.StorerKey = @c_StorerKey
                    AND SKU.SKU = @c_SKU

                  -- Build Location Flag Restriction SQL
                  SELECT @n_NoOfInclude = 0
                  SELECT @c_LocFlagRestriction = ''
                  IF LTRIM(@cpa_LocationFlagInclude01) IS NOT NULL AND LTRIM(@cpa_LocationFlagInclude01) <> ''
                  BEGIN
                     SELECT @n_NoOfInclude = @n_NoOfInclude + 1
                     SELECT @c_LocFlagRestriction = RTRIM(@c_LocFlagRestriction) + 'N''' + RTRIM(@cpa_LocationFlagInclude01) + ''''
                     SELECT @cpa_LocationFlagInclude01 = ''
                  END
                  IF LTRIM(@cpa_LocationFlagInclude02) IS NOT NULL AND LTRIM(@cpa_LocationFlagInclude02) <> ''
                  BEGIN
                     IF @n_NoOfInclude > 0
                     SELECT @c_LocFlagRestriction = RTRIM(@c_LocFlagRestriction) + ','
                     SELECT @n_NoOfInclude = @n_NoOfInclude + 1
                     SELECT @c_LocFlagRestriction = RTRIM(@c_LocFlagRestriction) + 'N''' + RTRIM(@cpa_LocationFlagInclude02) + ''''
                     SELECT @cpa_LocationFlagInclude02 = ''
                  END
                  IF LTRIM(@cpa_LocationFlagInclude03) IS NOT NULL AND LTRIM(@cpa_LocationFlagInclude03) <> ''
                  BEGIN
                     IF @n_NoOfInclude > 0
                     SELECT @c_LocFlagRestriction = RTRIM(@c_LocFlagRestriction) + ','

                     SELECT @n_NoOfInclude = @n_NoOfInclude + 1
                     SELECT @c_LocFlagRestriction = RTRIM(@c_LocFlagRestriction) + 'N''' + RTRIM(@cpa_LocationFlagInclude03) + ''''
                     SELECT @cpa_LocationFlagInclude03 = ''
                  END

                  IF @n_NoOfInclude = 1
                     SELECT @c_LocFlagRestriction = ' AND LOC.LocationFlag = ' + RTRIM(@c_LocFlagRestriction)
                  ELSE IF @n_NoOfInclude > 1
                     SELECT @c_LocFlagRestriction = ' AND LOC.LocationFlag IN (' + RTRIM(@c_LocFlagRestriction) + ') '
                  ELSE
                     SELECT @c_LocFlagRestriction = ''
                  -- END Build Location Flag


-- xxxxxxx
                  SET @c_LocLevelRestriction = ''
                  IF ISNULL(@npa_LocLevelInclude01,0) <> 0 OR
                     ISNULL(@npa_LocLevelInclude02,0) <> 0 OR
                     ISNULL(@npa_LocLevelInclude03,0) <> 0 OR
                     ISNULL(@npa_LocLevelInclude04,0) <> 0 OR
                     ISNULL(@npa_LocLevelInclude05,0) <> 0 OR
                     ISNULL(@npa_LocLevelInclude06,0) <> 0
                  BEGIN
                     SET @c_LocLevelRestriction = ' AND LOC.LocLevel IN ('

                     IF ISNULL(@npa_LocLevelInclude01,0) <> 0
                        SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction) + RTRIM(CAST(@npa_LocLevelInclude01 As NVARCHAR(10)))

                     IF ISNULL(@npa_LocLevelInclude02,0) <> 0
                     SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction)
                                                + CASE WHEN RIGHT(@c_LocLevelRestriction,1) = '(' THEN '' ELSE ',' END
                                                + RTRIM(CAST(@npa_LocLevelInclude02 As NVARCHAR(10)))
                     IF ISNULL(@npa_LocLevelInclude03,0) <> 0
                     SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction)
                                                + CASE WHEN RIGHT(@c_LocLevelRestriction,1) = '(' THEN '' ELSE ',' END
                                                + RTRIM(CAST(@npa_LocLevelInclude03 As NVARCHAR(10)))
                     IF ISNULL(@npa_LocLevelInclude04,0) <> 0
                     SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction)
                                                + CASE WHEN RIGHT(@c_LocLevelRestriction,1) = '(' THEN '' ELSE ',' END
                                                + RTRIM(CAST(@npa_LocLevelInclude04 As NVARCHAR(10)))
                     IF ISNULL(@npa_LocLevelInclude05,0) <> 0
                     SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction)
                                                + CASE WHEN RIGHT(@c_LocLevelRestriction,1) = '(' THEN '' ELSE ',' END
                                                + RTRIM(CAST(@npa_LocLevelInclude05 As NVARCHAR(10)))
                     IF ISNULL(@npa_LocLevelInclude06,0) <> 0
                     SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction)
                                                + CASE WHEN RIGHT(@c_LocLevelRestriction,1) = '(' THEN '' ELSE ',' END
                                                + RTRIM(CAST(@npa_LocLevelInclude06 As NVARCHAR(10)))

                     SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction) + ')' + master.dbo.fnc_GetCharASCII(13)
                  END

                  IF ISNULL(@npa_LocLevelExclude01,0) <> 0 OR
                     ISNULL(@npa_LocLevelExclude02,0) <> 0 OR
                     ISNULL(@npa_LocLevelExclude03,0) <> 0 OR
                     ISNULL(@npa_LocLevelExclude04,0) <> 0 OR
                     ISNULL(@npa_LocLevelExclude05,0) <> 0 OR
                     ISNULL(@npa_LocLevelExclude06,0) <> 0
                  BEGIN
                     SET @c_LocLevelRestriction = @c_LocLevelRestriction + ' AND LOC.LocLevel NOT IN ('

                     IF ISNULL(@npa_LocLevelExclude01,0) <> 0
                        SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction) + RTRIM(CAST(@npa_LocLevelExclude01 As NVARCHAR(10)))

                     IF ISNULL(@npa_LocLevelExclude02,0) <> 0
                     SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction)
                                                + CASE WHEN RIGHT(@c_LocLevelRestriction,1) = '(' THEN '' ELSE ',' END
                                                + RTRIM(CAST(@npa_LocLevelExclude02 As NVARCHAR(10)))
                     IF ISNULL(@npa_LocLevelExclude03,0) <> 0
                     SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction)
                                                + CASE WHEN RIGHT(@c_LocLevelRestriction,1) = '(' THEN '' ELSE ',' END
                                                + RTRIM(CAST(@npa_LocLevelExclude03 As NVARCHAR(10)))
                     IF ISNULL(@npa_LocLevelExclude04,0) <> 0
                     SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction)
                                                + CASE WHEN RIGHT(@c_LocLevelRestriction,1) = '(' THEN '' ELSE ',' END
                                                + RTRIM(CAST(@npa_LocLevelExclude04 As NVARCHAR(10)))
                     IF ISNULL(@npa_LocLevelExclude05,0) <> 0
                     SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction)
                                                + CASE WHEN RIGHT(@c_LocLevelRestriction,1) = '(' THEN '' ELSE ',' END
                                                + RTRIM(CAST(@npa_LocLevelExclude05 As NVARCHAR(10)))
                     IF ISNULL(@npa_LocLevelExclude06,0) <> 0
                     SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction)
                                                + CASE WHEN RIGHT(@c_LocLevelRestriction,1) = '(' THEN '' ELSE ',' END
                                                + RTRIM(CAST(@npa_LocLevelExclude06 As NVARCHAR(10)))

                     SET @c_LocLevelRestriction = RTRIM(@c_LocLevelRestriction) + ')'  + master.dbo.fnc_GetCharASCII(13)
                  END

                  SET @c_LocAisleRestriction = ''
                  IF ISNULL(RTRIM(@cpa_LocAisleInclude01),'') <> '' OR
                     ISNULL(RTRIM(@cpa_LocAisleInclude02),'') <> '' OR
                     ISNULL(RTRIM(@cpa_LocAisleInclude03),'') <> '' OR
                     ISNULL(RTRIM(@cpa_LocAisleInclude04),'') <> '' OR
                     ISNULL(RTRIM(@cpa_LocAisleInclude05),'') <> '' OR
                     ISNULL(RTRIM(@cpa_LocAisleInclude06),'') <> ''
                  BEGIN
                     SET @c_LocAisleRestriction = ' AND LOC.LocAisle IN ('

                     IF ISNULL(RTRIM(@cpa_LocAisleInclude01),'') <> ''
                        SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction) + 'N''' + ISNULL(RTRIM(@cpa_LocAisleInclude01), '')
                                                      + ''''

                     IF ISNULL(RTRIM(@cpa_LocAisleInclude02),'') <> ''
                     SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction)
                                                + CASE WHEN RIGHT(@c_LocAisleRestriction,1) = '(' THEN '''' ELSE ',''' END
                                                + ISNULL(RTRIM(@cpa_LocAisleInclude02), '') + ''''
                     IF ISNULL(RTRIM(@cpa_LocAisleInclude03),'') <> ''
                     SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction)
                                                + CASE WHEN RIGHT(@c_LocAisleRestriction,1) = '(' THEN '''' ELSE ',''' END
                                                + ISNULL(RTRIM(@cpa_LocAisleInclude03), '') + ''''
                     IF ISNULL(RTRIM(@cpa_LocAisleInclude04),'') <> ''
                     SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction)
                                                + CASE WHEN RIGHT(@c_LocAisleRestriction,1) = '(' THEN '''' ELSE ',''' END
                                                + ISNULL(RTRIM(@cpa_LocAisleInclude04), '') + ''''
                     IF ISNULL(RTRIM(@cpa_LocAisleInclude05),'') <> ''
                     SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction)
                                                + CASE WHEN RIGHT(@c_LocAisleRestriction,1) = '(' THEN '''' ELSE ',''' END
                                                + ISNULL(RTRIM(@cpa_LocAisleInclude05), '') + ''''
                     IF ISNULL(RTRIM(@cpa_LocAisleInclude06),'') <> ''
                     SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction)
                                                + CASE WHEN RIGHT(@c_LocAisleRestriction,1) = '(' THEN '''' ELSE ',''' END
                                                + ISNULL(RTRIM(@cpa_LocAisleInclude06), '') + ''''

                     SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction) + ')' + master.dbo.fnc_GetCharASCII(13)
                  END

                  IF ISNULL(RTRIM(@cpa_LocAisleExclude01),'') <> '' OR
                     ISNULL(RTRIM(@cpa_LocAisleExclude02),'') <> '' OR
                     ISNULL(RTRIM(@cpa_LocAisleExclude03),'') <> '' OR
                     ISNULL(RTRIM(@cpa_LocAisleExclude04),'') <> '' OR
                     ISNULL(RTRIM(@cpa_LocAisleExclude05),'') <> '' OR
                     ISNULL(RTRIM(@cpa_LocAisleExclude06),'') <> ''
                  BEGIN
                     SET @c_LocAisleRestriction = @c_LocAisleRestriction + ' AND LOC.LocAisle NOT IN ('

                     IF ISNULL(RTRIM(@cpa_LocAisleExclude01),'') <> ''
                        SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction) + 'N''' + ISNULL(RTRIM(@cpa_LocAisleExclude01), '')
                                                     + ''''

                     IF ISNULL(RTRIM(@cpa_LocAisleExclude02),'') <> ''
                     SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction)
                                                + CASE WHEN RIGHT(@c_LocAisleRestriction,1) = '(' THEN '''' ELSE ',''' END
                                                + ISNULL(RTRIM(@cpa_LocAisleExclude02), '') + ''''
                     IF ISNULL(RTRIM(@cpa_LocAisleExclude03),'') <> ''
                     SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction)
                                                + CASE WHEN RIGHT(@c_LocAisleRestriction,1) = '(' THEN '''' ELSE ',''' END
                                                + ISNULL(RTRIM(@cpa_LocAisleExclude03), '') + ''''
                     IF ISNULL(RTRIM(@cpa_LocAisleExclude04),'') <> ''
                     SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction)
                                                + CASE WHEN RIGHT(@c_LocAisleRestriction,1) = '(' THEN '''' ELSE ',''' END
                                                + ISNULL(RTRIM(@cpa_LocAisleExclude04), '') + ''''
                     IF ISNULL(RTRIM(@cpa_LocAisleExclude05),'') <> ''
                     SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction)
                                                + CASE WHEN RIGHT(@c_LocAisleRestriction,1) = '(' THEN '''' ELSE ',''' END
                                                + ISNULL(RTRIM(@cpa_LocAisleExclude05), '') + ''''
                     IF ISNULL(RTRIM(@cpa_LocAisleExclude06),'') <> ''
                     SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction)
                                                + CASE WHEN RIGHT(@c_LocAisleRestriction,1) = '(' THEN '''' ELSE ',''' END
                                                + ISNULL(RTRIM(@cpa_LocAisleExclude06), '') + ''''

                     SET @c_LocAisleRestriction = RTRIM(@c_LocAisleRestriction) + ')' + master.dbo.fnc_GetCharASCII(13)
                  END

-- xxxxxxx
---------------------
                 -- Build Location Category Restriction SQL
                  SELECT @n_NoOfInclude = 0
                  SELECT @c_LocCategoryRestriction = ''
                  IF LTRIM(@cpa_LocationCategoryInclude01) IS NOT NULL
                  BEGIN
                     SELECT @n_NoOfInclude = @n_NoOfInclude + 1
                     SELECT @c_LocCategoryRestriction = RTRIM(@c_LocCategoryRestriction) + 'N''' + RTRIM(@cpa_LocationCategoryInclude01) + ''''
                     SELECT @cpa_LocationCategoryInclude01 = ''
                  END
                  IF RTRIM(@cpa_LocationCategoryInclude02) IS NOT NULL AND RTRIM(@cpa_LocationCategoryInclude02) <> ''
                  BEGIN
                     IF @n_NoOfInclude > 0
                     SELECT @c_LocCategoryRestriction = RTRIM(@c_LocCategoryRestriction) + ','
                     SELECT @n_NoOfInclude = @n_NoOfInclude + 1
                     SELECT @c_LocCategoryRestriction = RTRIM(@c_LocCategoryRestriction) + 'N''' + RTRIM(@cpa_LocationCategoryInclude02) + ''''
                     SELECT @cpa_LocationCategoryInclude02 = ''
                  END
                  IF RTRIM(@cpa_LocationCategoryInclude03) IS NOT NULL AND RTRIM(@cpa_LocationCategoryInclude03) <> ''
                  BEGIN
                     IF @n_NoOfInclude > 0
                     SELECT @c_LocCategoryRestriction = RTRIM(@c_LocCategoryRestriction) + ','

                     SELECT @n_NoOfInclude = @n_NoOfInclude + 1
                     SELECT @c_LocCategoryRestriction = RTRIM(@c_LocCategoryRestriction) + 'N''' + RTRIM(@cpa_LocationCategoryInclude03) + ''''
                     SELECT @cpa_LocationCategoryInclude03 = ''
                  END

                  IF @n_NoOfInclude = 1
                     SELECT @c_LocCategoryRestriction = ' AND LOC.LocationCategory = ' + RTRIM(@c_LocCategoryRestriction)
                  ELSE IF @n_NoOfInclude > 1
                     SELECT @c_LocCategoryRestriction = ' AND LOC.LocationCategory IN (' + RTRIM(@c_LocCategoryRestriction) + ') '
                  ELSE
                     SELECT @c_LocCategoryRestriction = ''
                  -- END Build Location Category
---------------------
                  -- BEGIN Build Location Type Restriction
                  SELECT @n_NoOfInclude = 0
                  SELECT @c_LocTypeRestriction = ''
                  IF RTRIM(@cpa_LocationTypeExclude01) IS NOT NULL AND RTRIM(@cpa_LocationTypeExclude01) <> ''
                  BEGIN
                     SELECT @n_NoOfInclude = @n_NoOfInclude + 1
                     SELECT @c_LocTypeRestriction = RTRIM(@c_LocTypeRestriction) + 'N''' + RTRIM(@cpa_LocationTypeExclude01) + ''''
                     SELECT @cpa_LocationTypeExclude01 = ''
                  END
                  IF RTRIM(@cpa_LocationTypeExclude02) IS NOT NULL AND RTRIM(@cpa_LocationTypeExclude02) <> ''
                  BEGIN
                     IF @n_NoOfInclude > 0
                     SELECT @c_LocTypeRestriction = RTRIM(@c_LocTypeRestriction) + ','
                     SELECT @n_NoOfInclude = @n_NoOfInclude + 1
                     SELECT @c_LocTypeRestriction = RTRIM(@c_LocTypeRestriction) + 'N''' + RTRIM(@cpa_LocationTypeExclude02) + ''''
                     SELECT @cpa_LocationTypeExclude02 = ''
                  END
                  IF RTRIM(@cpa_LocationTypeExclude03) IS NOT NULL AND RTRIM(@cpa_LocationTypeExclude03) <> ''
                  BEGIN
                     IF @n_NoOfInclude > 0
                     SELECT @c_LocTypeRestriction = RTRIM(@c_LocTypeRestriction) + ','
                     SELECT @n_NoOfInclude = @n_NoOfInclude + 1
                     SELECT @c_LocTypeRestriction = RTRIM(@c_LocTypeRestriction) + 'N''' + RTRIM(@cpa_LocationTypeExclude03) + ''''
                     SELECT @cpa_LocationTypeExclude03 = ''
                  END
                  IF RTRIM(@cpa_LocationTypeExclude04) IS NOT NULL AND RTRIM(@cpa_LocationTypeExclude04) <> ''
                  BEGIN
                     IF @n_NoOfInclude > 0
                     SELECT @c_LocTypeRestriction = RTRIM(@c_LocTypeRestriction) + ','
                     SELECT @n_NoOfInclude = @n_NoOfInclude + 1
                  SELECT @c_LocTypeRestriction = RTRIM(@c_LocTypeRestriction) + 'N''' + RTRIM(@cpa_LocationTypeExclude04) + ''''
                     SELECT @cpa_LocationTypeExclude04 = ''
                  END
                  IF RTRIM(@cpa_LocationTypeExclude05) IS NOT NULL AND RTRIM(@cpa_LocationTypeExclude05) <> ''
                  BEGIN
                     IF @n_NoOfInclude > 0
                     SELECT @c_LocTypeRestriction = RTRIM(@c_LocTypeRestriction) + ','
                     SELECT @n_NoOfInclude = @n_NoOfInclude + 1
                     SELECT @c_LocTypeRestriction = RTRIM(@c_LocTypeRestriction) + 'N''' + RTRIM(@cpa_LocationTypeExclude05) + ''''
                     SELECT @cpa_LocationTypeExclude05 = ''
                  END

                  IF @n_NoOfInclude = 1
                     SELECT @c_LocTypeRestriction = ' AND LOC.LOCATIONTYPE <> ' + RTRIM(@c_LocTypeRestriction)
                  ELSE IF @n_NoOfInclude > 1
                     SELECT @c_LocTypeRestriction = ' AND LOC.LOCATIONTYPE NOT IN (' + RTRIM(@c_LocTypeRestriction) + ') '
                  ELSE
                     SELECT @c_LocTypeRestriction = ''

                  -- END Build Location Type

                  IF '1' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
                  BEGIN -- loc must be empty
                     SELECT @c_SelectSQL =
                     ' SELECT TOP 1 @c_Loc = LOC.LOC ' +
                     ' FROM  LOC (NOLOCK) LEFT OUTER JOIN LOTxLOCxID (NOLOCK) ON ( LOC.loc = LOTxLOCxID.LOC ) ' +
                     ' WHERE LOC.Putawayzone = N''' + RTRIM(@c_searchzone) + ''' ' +
                     ' AND   LOC.Facility = N''' + RTRIM(@c_Facility) + ''' ' +
                     ' AND   LOC.LOC > @c_LastLoc ' +
                     ISNULL( RTRIM(@c_LocFlagRestriction), '') +
                     ISNULL( RTRIM(@c_LocTypeRestriction), '') +
                     ISNULL( RTRIM(@c_LocLevelRestriction), '') +
                     ISNULL( RTRIM(@c_LocAisleRestriction), '') +
                     ' GROUP BY LOC.LOC ' +
                     --' HAVING (SUM(LOTxLOCxID.Qty) = 0 OR SUM(LOTxLOCxID.Qty) is null) ' +                  -- SOS# 181262
                     --' AND (SUM(LOTxLOCxID.PendingMoveIn) = 0 OR SUM(LOTxLOCxID.PendingMoveIn) is null) ' + -- SOS# 181262
                     ' HAVING SUM(ISNULL(LOTxLOCxID.Qty, 0)) = 0 ' +
                     ' AND SUM(ISNULL(LOTxLOCxID.PendingMoveIn, 0)) = 0 ' +
                     ' ORDER BY LOC.LOC '

                     -- modify by SHONG on 15-JAN-2004
                     -- to disable further checking of all locationstaterestriction = '1'
                     IF @cpa_LocationStateRestriction1 = '1'
                     BEGIN
                        select @cpa_LocationStateRestriction1 = '',
                        @cpa_LocationStateRestriction2 = '',
                        @cpa_LocationStateRestriction3 = ''
                     END
                  END -- loc must be empty
                  ELSE IF '3' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
                  BEGIN -- do not mix lot
                     SELECT @c_SelectSQL =
                     ' SELECT TOP 1 @c_Loc = LOC.LOC ' +
                     ' FROM LOC (NOLOCK) LEFT OUTER JOIN LOTxLOCxID (NOLOCK) ON ( LOC.loc = LOTxLOCxID.LOC ) ' +
                     ' WHERE LOC.Putawayzone = N''' + RTRIM(@c_searchzone) + ''' ' +
                     ' AND   LOC.LOC > @c_LastLoc ' +
                     ISNULL( RTRIM(@c_LocFlagRestriction), '') +
                     ISNULL( RTRIM(@c_LocTypeRestriction), '') +
                     ISNULL( RTRIM(@c_LocLevelRestriction), '') +
                     ISNULL( RTRIM(@c_LocAisleRestriction), '') +
                     ' AND  LOC.Facility = N''' + RTRIM(@c_Facility) + ''' ' +
                     ' AND (LOTxLOCxID.LOT = N''' + RTRIM(@c_LOT) + ''''  +
                     ' OR LOTxLOCxID.Lot IS NULL) ' +
                     ' GROUP BY LOC.LOC '

                     -- Fit by Cube
                     IF '1' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                     @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        IF RTRIM(@c_DimRestSQL) IS NULL OR RTRIM(@c_DimRestSQL) = ''
                           SELECT @c_DimRestSQL = ' HAVING '
                        ELSE
                           SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '

                        -- SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' MAX(LOC.Cube) - ' +
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' MAX(LOC.CubicCapacity) - ' +
                        '( ( SUM(ISNULL(LOTxLOCxID.Qty, 0)) - SUM(ISNULL(LOTxLOCxID.QtyPicked,0)) + SUM(ISNULL(LOTxLOCxID.PendingMoveIn,0))) ' +
                        '* ' + RTRIM(CAST(@n_StdCube as NVARCHAR(20))) + ') >= (' + RTRIM(CAST(@n_StdCube as NVARCHAR(20))) + ' * ' + RTRIM(CAST(@n_Qty as NVARCHAR(10))) + ')'
                     END

                     -- Fit by Weight
                     IF '3' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                     @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        IF RTRIM(@c_DimRestSQL) IS NULL OR RTRIM(@c_DimRestSQL) = ''
                        SELECT @c_DimRestSQL = ' HAVING '
                     ELSE
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '

                        -- SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' MAX(LOC.Cube) - ' +
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' MAX(LOC.WeightCapacity) - ' +
                        '( ( SUM(ISNULL(LOTxLOCxID.Qty, 0)) - SUM(ISNULL(LOTxLOCxID.QtyPicked,0)) + SUM(ISNULL(LOTxLOCxID.PendingMoveIn,0))) ' +
                        '* ' + RTRIM(CAST(@n_StdGrossWgt as NVARCHAR(20))) + ') >= (' + RTRIM(CAST(@n_StdGrossWgt as NVARCHAR(20))) + ' * ' + RTRIM(CAST(@n_Qty as NVARCHAR(10))) + ')'
                     END

                     SELECT @c_SelectSQL = RTRIM(@c_SelectSQL) + @c_DimRestSQL +
                     ' ORDER BY LOC.LOC '

                     -- to disable further checking of locationstaterestriction = '2'
                     IF @cpa_LocationStateRestriction1 = '2'
                        select @cpa_LocationStateRestriction1 = ''
                     ELSE IF @cpa_LocationStateRestriction2 = '2'
                        select @cpa_LocationStateRestriction2 = ''
                     ELSE select @cpa_LocationStateRestriction3 = ''

                     IF @cpa_DimensionRestriction01 IN ('1', '3')
                     SELECT @cpa_DimensionRestriction01 = '0'
                     IF @cpa_DimensionRestriction02 IN ('1', '3')
                     SELECT @cpa_DimensionRestriction02 = '0'
                     IF @cpa_DimensionRestriction03 IN ('1', '3')
                     SELECT @cpa_DimensionRestriction04 = '0'
                     IF @cpa_DimensionRestriction04 IN ('1', '3')
                     SELECT @cpa_DimensionRestriction04 = '0'
                     IF @cpa_DimensionRestriction05 IN ('1', '3')
                     SELECT @cpa_DimensionRestriction05 = '0'
                     IF @cpa_DimensionRestriction06 IN ('1', '3')
                     SELECT @cpa_DimensionRestriction06 = '0'

                  END -- do not mix Lot
                  ELSE IF '2' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
                  BEGIN -- do not mix skus
                     SELECT @c_SelectSQL =
                     ' SELECT TOP 1 @c_Loc = LOC.LOC ' +
                     ' FROM LOC (NOLOCK) LEFT OUTER JOIN LOTxLOCxID (NOLOCK) ON ( LOC.loc = LOTxLOCxID.LOC ) ' +
                     ' WHERE LOC.Putawayzone = N''' + RTRIM(@c_searchzone) + ''' ' +
                     ' AND   LOC.LOC > @c_LastLoc ' +
                     ISNULL( RTRIM(@c_LocFlagRestriction), '') +
                     ISNULL( RTRIM(@c_LocTypeRestriction), '') +
                     ISNULL( RTRIM(@c_LocLevelRestriction), '') +
                     ISNULL( RTRIM(@c_LocAisleRestriction), '') +
                     ' AND  LOC.Facility = N''' + RTRIM(@c_Facility) + ''' ' +
                     ' AND (LOTxLOCxID.StorerKey = N''' + RTRIM(@c_StorerKey) + '''  OR LOTxLOCxID.StorerKey IS NULL) ' +
                     ' AND (LOTxLOCxID.sku = N''' + RTRIM(@c_SKU) + ''' OR LOTxLOCxID.sku is null) ' +
                     ' GROUP BY LOC.LOC '

                     -- Fit by Cube
                     IF '1' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                     @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        IF RTRIM(@c_DimRestSQL) IS NULL OR RTRIM(@c_DimRestSQL) = ''
                           SELECT @c_DimRestSQL = ' HAVING '
                        ELSE
                           SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '

                        -- SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' MAX(LOC.Cube) - ' +
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' MAX(LOC.CubicCapacity) - ' +
                        '( ( SUM(ISNULL(LOTxLOCxID.Qty, 0)) - SUM(ISNULL(LOTxLOCxID.QtyPicked,0)) + SUM(ISNULL(LOTxLOCxID.PendingMoveIn,0))) ' +
                        '* ' + RTRIM(CAST(@n_StdCube as NVARCHAR(20))) + ') >= (' + RTRIM(CAST(@n_StdCube as NVARCHAR(20))) + ' * ' + RTRIM(CAST(@n_Qty as NVARCHAR(10))) + ')'
                     END

                     -- Fit by Weight
                     IF '3' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                     @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        IF RTRIM(@c_DimRestSQL) IS NULL OR RTRIM(@c_DimRestSQL) = ''
                        SELECT @c_DimRestSQL = ' HAVING '
                     ELSE
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '

                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' MAX(LOC.WeightCapacity) - ' +
                        '( ( SUM(ISNULL(LOTxLOCxID.Qty, 0)) - SUM(ISNULL(LOTxLOCxID.QtyPicked,0)) + SUM(ISNULL(LOTxLOCxID.PendingMoveIn,0))) ' +
                        '* ' + RTRIM(CAST(@n_StdGrossWgt as NVARCHAR(20))) + ') >= (' + RTRIM(CAST(@n_StdGrossWgt as NVARCHAR(20))) + ' * ' + RTRIM(CAST(@n_Qty as NVARCHAR(10))) + ')'
                     END

                     SELECT @c_SelectSQL = RTRIM(@c_SelectSQL) + @c_DimRestSQL +
                     ' ORDER BY LOC.LOC '

                     -- to disable further checking of locationstaterestriction = '2'
                     IF @cpa_LocationStateRestriction1 = '2'
                        select @cpa_LocationStateRestriction1 = ''
                     ELSE IF @cpa_LocationStateRestriction2 = '2'
                        select @cpa_LocationStateRestriction2 = ''
                     ELSE select @cpa_LocationStateRestriction3 = ''

                     IF @cpa_DimensionRestriction01 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction01 = '0'
                     IF @cpa_DimensionRestriction02 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction02 = '0'
                     IF @cpa_DimensionRestriction03 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction04 = '0'
                     IF @cpa_DimensionRestriction04 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction04 = '0'
                     IF @cpa_DimensionRestriction05 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction05 = '0'
                     IF @cpa_DimensionRestriction06 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction06 = '0'

                  END -- do not mix skus
                  ELSE -- no location state restrictions
                  BEGIN
                     SELECT @c_SelectSQL =
                     ' SELECT Top 1 @c_Loc = LOC.LOC ' +
                     ' FROM LOC (NOLOCK)  ' +
                     ' LEFT OUTER JOIN LOTxLOCxID (NOLOCK) ON ( LOC.loc = LOTxLOCxID.LOC ) ' +
                     ' LEFT OUTER JOIN SKU (NOLOCK) ON (SKU.StorerKey = LOTxLOCxID.StorerKey AND SKU.SKU = LOTxLOCxID.SKU) ' +
                     ' WHERE LOC.Putawayzone = N''' + RTRIM(@c_searchzone) + ''' ' +
                     ' AND   LOC.LOC > @c_LastLoc ' +
                     ISNULL( RTRIM(@c_LocFlagRestriction), '') +
                     ISNULL( RTRIM(@c_LocTypeRestriction), '') +
                     ISNULL( RTRIM(@c_LocLevelRestriction), '') +
                     ISNULL( RTRIM(@c_LocAisleRestriction), '') +
                     ' AND  LOC.Facility = N''' + RTRIM(@c_Facility) + ''' ' +
                     ' GROUP BY LOC.LOC '

                     -- Fit by Cube
                     IF '1' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                                @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        IF RTRIM(@c_DimRestSQL) IS NULL OR RTRIM(@c_DimRestSQL) = ''
                        SELECT @c_DimRestSQL = ' HAVING '
                     ELSE
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '

                        -- SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + 'MAX(LOC.Cube) - ' +
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' MAX(LOC.CubicCapacity) - ' +
                        '( SUM(( ISNULL(LOTxLOCxID.Qty, 0) - ISNULL(LOTxLOCxID.QtyPicked,0) + ISNULL(LOTxLOCxID.PendingMoveIn,0) ) ' +
                        ' * ISNULL(SKU.StdCube,0) )) >= (' + RTRIM(CAST(@n_StdCube as NVARCHAR(20))) + ' * ' + RTRIM(CAST(@n_Qty as NVARCHAR(10))) + ')'
                     END

                     -- Fit by Weight
                     IF '3' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                     @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        IF RTRIM(@c_DimRestSQL) IS NULL OR RTRIM(@c_DimRestSQL) = ''
                        SELECT @c_DimRestSQL = ' HAVING '
                     ELSE
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '

                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' MAX(LOC.WeightCapacity)  - ' +
                        ' ( SUM(( ISNULL(LOTxLOCxID.Qty, 0) - ISNULL(LOTxLOCxID.QtyPicked,0) + ISNULL(LOTxLOCxID.PendingMoveIn,0) ) ' +
                        ' * ISNULL(SKU.StdGrossWgt,0) )) >= (' + RTRIM(CAST(@n_StdGrossWgt as NVARCHAR(20))) + ' * ' + RTRIM(CAST(@n_Qty as NVARCHAR(10))) + ')'
                     END

                     SELECT @c_SelectSQL = RTRIM(@c_SelectSQL) + @c_DimRestSQL +
                           ' ORDER BY LOC.LOC '

                     -- to disable further checking of locationstaterestriction = '2'
                     IF @cpa_LocationStateRestriction1 = '2'
                        select @cpa_LocationStateRestriction1 = ''
                     ELSE IF @cpa_LocationStateRestriction2 = '2'
                        select @cpa_LocationStateRestriction2 = ''
                     ELSE select @cpa_LocationStateRestriction3 = ''

                     IF @cpa_DimensionRestriction01 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction01 = '0'
                     IF @cpa_DimensionRestriction02 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction02 = '0'
                     IF @cpa_DimensionRestriction03 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction04 = '0'
                     IF @cpa_DimensionRestriction04 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction04 = '0'
                     IF @cpa_DimensionRestriction05 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction05 = '0'
                     IF @cpa_DimensionRestriction06 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction06 = '0'
                  END -- Else

                  SELECT @c_ToLoc = SPACE(10)
                  SELECT @cPA_ToLoc = SPACE(10)

                  WHILE (1=1)
                  BEGIN
                     SELECT @c_ToLoc = ''

                     EXEC sp_executesql @c_SelectSQL, N'@c_LastLoc NVARCHAR(10), @c_Loc NVARCHAR(10) output', @cPA_ToLoc, @c_ToLoc output

                     if @b_debug = 2
                     begin
                        print @c_SelectSQL
                        select @cPA_ToLoc 'Last Loc', @c_ToLoc
                     end

                     IF RTRIM(@c_ToLoc) IS NULL OR RTRIM(@c_ToLoc) = ''
                        BREAK

                     IF @cPA_ToLoc = @c_ToLoc
                        BREAK

                     SELECT @cPA_ToLoc = @c_ToLoc
                     SELECT @n_locsreviewed = @n_locsreviewed + 1

                     IF @cpa_checkrestrictions = 'Y'
                     BEGIN
                        SELECT @b_RestrictionsPassed = 0
                        GOTO PA_CHECKRESTRICTIONS
                        PATYPE02_BYLOC_A:

                        IF @b_RestrictionsPassed = 1
                        BEGIN
                           SELECT @b_GotLoc = 1
                           BREAK
                        END
                     END
                     ELSE
                     BEGIN
                        SELECT @b_GotLoc = 1
                        BREAK
                     END
                  END -- WHILE (1=1)

                  IF @b_GotLoc = 1
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        SELECT @c_Reason = 'FOUND PAType=' + @cpa_PAType + ': Search Type by Location'
                        EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
                     END

                     BREAK
                  END
               END -- END of PAType = 02, 04 and 12
               ELSE IF @cpa_PAType IN ('16', '17', '18', '19', '22', '24', '32', '34', '42', '44', '52', '54',
                                       '55', '56', '57', '58')
               BEGIN
                  SELECT @cPA_ToLoc = SPACE(10)
                  WHILE (1=1)
                  BEGIN
                     SELECT @n_RowCount = 0
                     IF @cpa_PAType = '16' OR -- Search Location With the same Sku Within Sku Zone   
                        @cpa_PAType = '18'    -- Search Location Within Specified Zone  
                     BEGIN 

                        SELECT @c_SelectSQL = -- 'SET ROWCOUNT 1 ' +
                        ' SELECT @cPA_ToLoc = LOTxLOCxID.loc, ' +
                        ' @c_ToLoc = LOTxLOCxID.loc ' +
                        ' FROM LOTxLOCxID (NOLOCK) ' +
                        ' JOIN LOC (NOLOCK) on LOTxLOCxID.loc = loc.loc ' +
                        ' JOIN LotAttribute (NOLOCK) ON LotAttribute.LOT = LOTxLOCxID.LOT ' +
                        ' WHERE Qty > 0 ' +
                        ' AND LOTxLOCxID.loc > @cPA_ToLoc ' +
                        ' AND LOC.putawayzone = N''' + RTRIM(@c_searchzone) + ''' ' +
                        ' AND LOTxLOCxID.sku = N''' + RTRIM(@c_SKU) + ''' ' +
                        ' AND LOTxLOCxID.StorerKey = N''' + RTRIM(@c_StorerKey) + ''' ' +
                        ' AND loc.Facility = N''' + RTRIM(@c_Facility) + ''' ' +
                        CASE WHEN LEN(@cpa_LocationCategoryExclude01) > 0 OR
                                  LEN(@cpa_LocationCategoryExclude02) > 0 OR
                                  LEN(@cpa_LocationCategoryExclude03) > 0 THEN
                                  'AND LOC.LocationCategory NOT IN ('
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationCategoryexclude01) > 0 THEN
                                  'N''' + RTRIM(@cpa_LocationCategoryexclude01) + ''''
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationCategoryexclude02) > 0 THEN
                                  ',N''' + RTRIM(@cpa_LocationCategoryexclude02) + ''''
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationCategoryexclude03) > 0 THEN
                                  ',N''' + RTRIM(@cpa_LocationCategoryexclude03) + ''''
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationCategoryexclude01) > 0 OR
                                  LEN(@cpa_LocationCategoryexclude02) > 0 OR
                                  LEN(@cpa_LocationCategoryexclude03) > 0 THEN
                                  ')'
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationCategoryInclude01) > 0 OR
                                  LEN(@cpa_LocationCategoryInclude02) > 0 OR
                                  LEN(@cpa_LocationCategoryInclude03) > 0 THEN
                                  'AND LOC.LocationCategory IN ('
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationCategoryInclude01) > 0 THEN
                                  'N''' + RTRIM(@cpa_LocationCategoryInclude01) + ''''
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationCategoryInclude02) > 0 THEN
                                  ',N''' + RTRIM(@cpa_LocationCategoryInclude02) + ''''
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationCategoryInclude03) > 0 THEN
                                  ',N''' + RTRIM(@cpa_LocationCategoryInclude03) + ''''
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationCategoryInclude01) > 0 OR
                                  LEN(@cpa_LocationCategoryInclude02) > 0 OR
                                  LEN(@cpa_LocationCategoryInclude03) > 0 THEN
                                  ')'
                             ELSE ''
                        END +
                        -- @cpa_LocationFlagInclude01
                        CASE WHEN LEN(@cpa_LocationFlagInclude01) > 0 OR
                                  LEN(@cpa_LocationFlagInclude02) > 0 OR
                                  LEN(@cpa_LocationFlagInclude03) > 0 THEN
                                  'AND LOC.LocationFlag IN ('
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationFlagInclude01) > 0 THEN
                                  'N''' + RTRIM(@cpa_LocationFlagInclude01) + ''''
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationFlagInclude02) > 0 THEN
                                  ',N''' + RTRIM(@cpa_LocationFlagInclude02) + ''''
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationFlagInclude03) > 0 THEN
                                  ',N''' + RTRIM(@cpa_LocationFlagInclude03) + ''''
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationFlagInclude01) > 0 OR
                                  LEN(@cpa_LocationFlagInclude02) > 0 OR
                                  LEN(@cpa_LocationFlagInclude03) > 0 THEN
                                  ')'
                             ELSE ''
                        END +
                        -- @cpa_LocationFlagExclude01
                        CASE WHEN LEN(@cpa_LocationFlagExclude01) > 0 OR
                                  LEN(@cpa_LocationFlagExclude02) > 0 OR
                                  LEN(@cpa_LocationFlagExclude03) > 0 THEN
                                  'AND LOC.LocationFlag NOT IN ('
                             ELSE ''
                        END +

                        CASE WHEN LEN(@cpa_LocationFlagExclude01) > 0 THEN
                                  'N''' + RTRIM(@cpa_LocationFlagExclude01) + ''''
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationFlagExclude02) > 0 THEN
                           ',N''' + RTRIM(@cpa_LocationFlagExclude02) + ''''
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationFlagExclude03) > 0 THEN
                                  ',N''' + RTRIM(@cpa_LocationFlagExclude03) + ''''
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationFlagExclude01) > 0 OR
                                  LEN(@cpa_LocationFlagExclude02) > 0 OR
                                  LEN(@cpa_LocationFlagExclude03) > 0 THEN
                                  ')'
                             ELSE ''
                        END +
                        -- SHONG, Wayne, Manny, Vicky
                        CASE WHEN 'DRIVEIN' In (@cpa_LocationCategoryInclude01, @cpa_LocationCategoryInclude02,
                                                @cpa_LocationCategoryInclude03)
                                  AND @c_LOT <> '' AND @c_LOT IS NOT NULL
                                  THEN ' AND LotAttribute.Lottable02 = N''' + @c_Lottable02 + ''' AND ' +
                                       ' LotAttribute.Lottable01 = N''' + @c_Lottable01 + ''' '
                                  ELSE ''
                        END +
                        CASE WHEN 'DOUBLEDEEP' In (@cpa_LocationCategoryInclude01,
                                                   @cpa_LocationCategoryInclude02,
                                                   @cpa_LocationCategoryInclude03)
                                  AND @c_LOT <> '' AND @c_LOT IS NOT NULL
                                  THEN ' AND LotAttribute.Lottable02 = N''' + @c_Lottable02 + ''' AND ' +
                                       ' LotAttribute.Lottable04 = N''' + CONVERT(char(8), @d_Lottable04, 112) + ''' '
                                  ELSE ''
                        END +
                        ' GROUP BY LOTxLOCxID.LOC, LOC.MaxPallet ' +
                        CASE WHEN '4' IN (@cpa_LocationStateRestriction1,
                                          @cpa_LocationStateRestriction2,
                                          @cpa_LocationStateRestriction3)
                            THEN ' HAVING COUNT(DISTINCT LOTxLOCxID.ID) < LOC.MaxPallet '
                            ELSE ''
                        END +
                        ' ORDER BY LOTxLOCxID.LOC ' +
                        ' SELECT @n_RowCount = @@ROWCOUNT '

                        if @b_debug = 2
                           print @c_SelectSQL

                        EXEC sp_executesql @c_SelectSQL,
                             N'@cPA_ToLoc NVARCHAR(10) output, @c_ToLoc NVARCHAR(10) output, @n_RowCount int output',
                             @cPA_ToLoc output, @c_ToLoc output, @n_RowCount Output

                        -- Chekcing
                        IF @b_debug = 2
                        BEGIN
                           SELECT 'Storerkey is ' + @c_Storerkey + ', Sku is ' + @c_SKU + ', Facility is ' + @c_Facility
                           SELECT 'PAType is ' + @cpa_PAType + ', ToLoc is ' + @cPA_ToLoc
                        END

                     END -- End of @cpa_PAType = '16' or @cpa_PAType = '18'

                     -- Added by MaryVong on 16-Jun-2005 (SOS36712 KCPI) -Start(1)
                     -- Empty location
                     IF @cpa_PAType = '17' OR -- Search Empty Location Within Sku Zone  
                        @cpa_PAType = '19'    -- Search Empty Location Within Specified Zone   
                     BEGIN  
                        SET ROWCOUNT 1
                        SELECT @cPA_ToLoc = LOC.LOC,
                           @c_ToLoc = LOC.LOC
                        FROM LOC (NOLOCK)
                        LEFT OUTER JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.LOC = LOC.LOC)
                        WHERE LOC.LOC > @cPA_ToLoc
                        AND   LOC.Putawayzone = @c_searchzone
                        AND   LOC.Facility = @c_Facility
                        GROUP BY LOC.LOC
                        --HAVING SUM(SKUxLOC.Qty - SKUxLOC.QtyPicked) = 0 OR SUM(SKUxLOC.Qty - SKUxLOC.QtyPicked) IS NULL -- SOS# 181262
                        HAVING SUM(ISNULL(SKUxLOC.Qty, 0) - ISNULL(SKUxLOC.QtyPicked, 0)) = 0
                        ORDER BY LOC.LOC
                        SELECT @n_RowCount = @@ROWCOUNT

                        -- Chekcing
                        IF @b_debug = 2
                        BEGIN
                           SELECT 'SearchZone is ' + @c_searchzone + ', Facility is ' + @c_Facility
                           SELECT 'PAType is ' + @cpa_PAType + ', ToLoc is ' + @cPA_ToLoc
                        END
                     END -- End of @cpa_PAType = '17' or @cpa_PAType = '19'
                     -- Added by MaryVong on 16-Jun-2005 (SOS36712 KCPI) -End(1)  
                     IF @cpa_PAType = '22' OR -- Search Zone Specified in SKU table (Single and Empty pallet Locations only)   
                        @cpa_PAType = '24'    -- Search Specified Zone (Single and Empty pallet Locations only)  
                     BEGIN  
                        SELECT @cPA_ToLoc = LOC.LOC,
                           @c_ToLoc = LOC.LOC
                        FROM LOC (NOLOCK)
                        LEFT OUTER JOIN SKUxLOC WITH (NOLOCK) ON (LOC.LOC = SKUxLOC.LOC)
                        JOIN CODELKUP WITH (NOLOCK) ON ( LOC.LocationCategory = CODELKUP.CODE
                                                         AND CODELKUP.LISTNAME = 'LOCCATEGRY'
                                                         AND CODELKUP.SHORT = 'S')
                        WHERE LOC.LOC > @cPA_ToLoc
                        AND LOC.Putawayzone = @c_searchzone
                        AND LOC.Facility = @c_Facility -- CDC Migration
                        GROUP BY LOC.LOC
                        --HAVING SUM(SKUxLOC.Qty) = 0 OR SUM(SKUxLOC.Qty) IS NULL -- SOS# 181262
                        HAVING SUM(ISNULL(SKUxLOC.Qty, 0)) = 0
                        ORDER BY LOC.LOC
                        SELECT @n_RowCount = @@ROWCOUNT
                     END
                     IF @cpa_PAType = '32' or @cpa_PAType = '34'
                     BEGIN
                        SELECT @cPA_ToLoc = SKUxLOC.LOC,
                           @c_ToLoc = SKUxLOC.LOC
                        FROM SKUxLOC (NOLOCK)
                        JOIN (SELECT LOC.LOC FROM LOC (NOLOCK)
                              JOIN CODELKUP WITH (NOLOCK) ON (LOC.LocationCategory = CODELKUP.CODE
                                                               AND CODELKUP.LISTNAME = 'LOCCATEGRY'
                                                               AND CODELKUP.SHORT = 'M')
                              JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.LOC = LOC.LOC
                                                             AND SKUxLOC.Qty - SKUxLOC.QtyPicked  > 0)
                              WHERE SKUxLOC.StorerKey = @c_StorerKey
                              AND   SKUxLOC.SKU = @c_SKU
                              AND   SKUxLOC.LOC > @cPA_ToLoc
                              AND   LOC.Putawayzone = @c_searchzone
                              AND   LOC.Facility = @c_Facility -- CDC Migration
                              GROUP BY LOC.LOC
                              HAVING COUNT(LOC.LOC) = 1) AS SINGLE_SKU ON (SKUxLOC.LOC = SINGLE_SKU.LOC)
                        ORDER BY SKUxLOC.LOC
                        SELECT @n_RowCount = @@ROWCOUNT
                     END
                     IF @cpa_PAType = '42' or @cpa_PAType = '44'
                     BEGIN
                        SELECT @cPA_ToLoc = LOC.LOC,
                           @c_ToLoc = LOC.LOC
                        FROM LOC (NOLOCK)
                        LEFT OUTER JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.LOC = LOC.LOC)
                        JOIN CODELKUP WITH (NOLOCK) ON (LOC.LocationCategory = CODELKUP.CODE
                                                         AND CODELKUP.LISTNAME = 'LOCCATEGRY'
                                                         AND CODELKUP.SHORT = 'M')
                        WHERE LOC.LOC > @cPA_ToLoc
                        AND   LOC.Putawayzone = @c_searchzone
                        AND   LOC.Facility = @c_Facility -- CDC Migration
                        GROUP BY LOC.LOC
                        --HAVING SUM(SKUxLOC.Qty - SKUxLOC.QtyPicked) = 0 OR SUM(SKUxLOC.Qty - SKUxLOC.QtyPicked) IS NULL -- SOS# 181262
                        HAVING SUM(ISNULL(SKUxLOC.Qty,0) - ISNULL(SKUxLOC.QtyPicked,0)) = 0
                        ORDER BY LOC.LOC
                        SELECT @n_RowCount = @@ROWCOUNT
                     END -- @cpa_PAType = '42' or @cpa_PAType = '44'
                     IF @cpa_PAType = '52' or @cpa_PAType = '54'
                     BEGIN
                        SELECT @cPA_ToLoc = LOTxLOCxID.loc,
                           @c_ToLoc = LOTxLOCxID.loc
                        FROM LOTxLOCxID (NOLOCK)
                        JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.StorerKey = LOTxLOCxID.StorerKey
                                                      and SKUxLOC.sku = LOTxLOCxID. sku
                                                      and SKUxLOC.StorerKey = @c_StorerKey
                                                      and SKUxLOC.sku = @c_SKU
                                                      and SKUxLOC.loc = LOTxLOCxID.loc)
                        JOIN LotAttribute WITH (NOLOCK) ON (LOTxLOCxID.Lot = LotAttribute.lot)
                        JOIN (SELECT Lottable02, Lottable04 FROM LotAttribute (NOLOCK)
                        JOIN LOTxLOCxID (NOLOCK) ON (LOTxLOCxID.LOT = LotAttribute.LOT)
                              WHERE LOTxLOCxID.Qty > 0) AS L
                           ON (L.Lottable02 = LotAttribute.Lottable02 AND L.Lottable04 = LotAttribute.Lottable04)
                        JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = Loc.Loc
                        and LOC.PutawayZone = @c_searchzone
                        and LOC.Facility = @c_Facility )-- CDC Migration
                        WHERE LOTxLOCxID.LOC > @cPA_ToLoc
                        ORDER BY LOTxLOCxID.Loc
                        SELECT @n_Rowcount = @@ROWCOUNT
                     END
                     -- Added by MaryVong on 1-Apr-2007 (SOS69388 KFP) -Start(1)
                     -- Cross facility, search location within specified zone base on HostWhCode,
                     -- with matching Lottable02 and Lottable04 (do not mix sku)
                     IF @cpa_PAType = '55'
                     BEGIN
                        SET ROWCOUNT 1
                        SELECT @cPA_ToLoc = LOC.LOC,
                           @c_ToLoc = LOC.LOC,
                           @c_ToHostWhCode = LOC.HostWhCode
                        FROM LOC (NOLOCK)
                        JOIN LOTxLOCxID (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC)
                        JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.StorerKey = LOTxLOCxID.StorerKey
                                                  AND SKUxLOC.SKU = LOTxLOCxID.SKU
                                                  AND SKUxLOC.StorerKey = @c_storerkey
                                                  AND SKUxLOC.SKU = @c_SKU
                                                  AND SKUxLOC.LOC = LOTxLOCxID.LOC)
                        JOIN LotAttribute (NOLOCK) ON (LOTxLOCxID.LOT = LotAttribute.LOT
                                                       AND LOTxLOCxID.StorerKey = LotAttribute.StorerKey
                                                       AND LOTxLOCxID.SKU = LotAttribute.SKU)
                        JOIN (SELECT Lottable02, Lottable04
                              FROM LotAttribute (NOLOCK)
                              JOIN LOTxLOCxID (NOLOCK) ON (LOTxLOCxID.LOT = LotAttribute.LOT
                                                           AND LOTxLOCxID.StorerKey = LotAttribute.StorerKey
                                                           AND LOTxLOCxID.SKU = LotAttribute.SKU
                                                           AND LOTxLOCxID.StorerKey = @c_storerkey
                                                           AND LOTxLOCxID.SKU = @c_SKU
                                             AND LOTxLOCxID.LOT = @c_LOT)
                              WHERE LOTxLOCxID.Qty > 0) AS LA
                           ON (LA.Lottable02 = LotAttribute.Lottable02 AND
                              ISNULL(LA.Lottable04, '') = ISNULL(LotAttribute.Lottable04, '') )
                        WHERE LOC.LOC > @cPA_ToLoc
                        AND   LOC.PutawayZone = @c_searchzone
                        GROUP BY LOC.HostWhCode, LOC.LOC
                        ORDER BY LOC.HostWhCode, LOC.LOC
                        SELECT @n_Rowcount = @@ROWCOUNT
                     END -- End of @cpa_PAType = '55'

                     -- Cross facility, search Empty Location base on HostWhCode inventory = 0
                     IF @cpa_PAType = '56'
                     BEGIN
                        SET ROWCOUNT 1
                        SELECT @cPA_ToLoc = LOC.LOC,
                           @c_ToLoc = LOC.LOC,
                           @c_ToHostWhCode = LOC.HostWhCode
                        FROM LOC (NOLOCK)
                        JOIN (SELECT LOC.HostWhCode
                              FROM LOC (NOLOCK)
                              LEFT OUTER JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.LOC = LOC.LOC)
                              WHERE LOC.Putawayzone = @c_searchzone
                              GROUP BY LOC.HostWhCode
                              HAVING SUM(SKUxLOC.Qty - SKUxLOC.QtyAllocated - SKUxLOC.QtyPicked) = 0 OR
                                     SUM(SKUxLOC.Qty - SKUxLOC.QtyAllocated - SKUxLOC.QtyPicked) IS NULL) AS HWC
                           ON (HWC.HostWhCode = LOC.HostWhCode)
                        WHERE LOC.LOC > @cPA_ToLoc
                        AND   LOC.Putawayzone = @c_searchzone
                        ORDER BY LOC.HostWhCode, LOC.LOC
                        SELECT @n_RowCount = @@ROWCOUNT
                     END -- End of @cpa_PAType = '56'

                     -- Cross facility, search suitable location within specified zone (mix with diff sku)
                     IF @cpa_PAType = '57'
                     BEGIN
                        SET ROWCOUNT 1
                        SELECT @cPA_ToLoc = LOC.LOC,
                           @c_ToLoc = LOC.LOC,
                           @c_ToHostWhCode = MIXED_SKU.HostWhCode
                        FROM LOC (NOLOCK)
                        JOIN (SELECT LOC.HostWhCode FROM LOC (NOLOCK)
                              JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.LOC = LOC.LOC)
                              WHERE LOC.Putawayzone = @c_searchzone
                              GROUP BY LOC.HostWhCode
                              HAVING SUM(SKUxLOC.Qty - SKUxLOC.QtyAllocated - SKUxLOC.QtyPicked) > 0
                              ) AS MIXED_SKU
                           ON (LOC.HostWhCode = MIXED_SKU.HostWhCode)
                        WHERE LOC.LOC > @cPA_ToLoc
                        AND   LOC.Putawayzone = @c_searchzone
                        ORDER BY LOC.HostWhCode, LOC.LOC
                        SELECT @n_RowCount = @@ROWCOUNT

                     END -- End of @cpa_PAType = '57'

                     -- SOS69388 KFP - Cross facility, search suitable location within specified zone (do not mix sku)
                     IF @cpa_PAType = '58'
                     BEGIN
                        SET ROWCOUNT 1
                        SELECT @cPA_ToLoc = LOC.LOC,
                           @c_ToLoc = LOC.LOC,
                           @c_ToHostWhCode = SINGLE_SKU.HostWhCode
                        FROM LOC (NOLOCK)
                        JOIN (SELECT LOC.HostWhCode FROM LOC (NOLOCK)
                              JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.LOC = LOC.LOC)
                              WHERE SKUxLOC.StorerKey = @c_storerkey
                              AND   SKUxLOC.SKU = @c_SKU
                      AND   LOC.Putawayzone = @c_searchzone
                              GROUP BY LOC.HostWhCode
                              HAVING SUM(SKUxLOC.Qty - SKUxLOC.QtyAllocated - SKUxLOC.QtyPicked) > 0 ) AS SINGLE_SKU
                        ON (LOC.HostWhCode = SINGLE_SKU.HostWhCode)
                        WHERE LOC.LOC > @cPA_ToLoc
                        AND   LOC.Putawayzone = @c_searchzone
                        ORDER BY LOC.HostWhCode, LOC.LOC
                        SELECT @n_RowCount = @@ROWCOUNT

                     END -- End of @cpa_PAType = '58'
                     -- Added by MaryVong on 1-Apr-2007 (SOS69388) -End(1)

                     IF @b_debug = 2
                     BEGIN
                        SELECT 'PAType= ' + @cpa_PAType + ', SearchZone= ' + @c_searchzone +
                              ', ToHostWhCode= ' + @c_ToHostWhCode + ', ToLoc= ' + @cPA_ToLoc + ', @c_LOT= ' + @c_LOT
                     END

                     IF @n_RowCount = 0
                     BEGIN
                        BREAK
                     END
                     SELECT @n_locsreviewed = @n_locsreviewed + 1
                     SET ROWCOUNT 0
                     IF @cpa_checkrestrictions = 'Y'
                     BEGIN
                        SELECT @b_RestrictionsPassed = 0
                        GOTO PA_CHECKRESTRICTIONS
                        PATYPE02_BYLOC_B:
                        IF @b_RestrictionsPassed = 1
                        BEGIN
                           SELECT @b_GotLoc = 1
                           BREAK
                        END
                     END
                     ELSE
                     BEGIN
                        SELECT @b_GotLoc = 1
                        BREAK
                     END
                  END -- WHILE (1=1)

                  SET ROWCOUNT 0
                  IF @b_GotLoc = 1
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        SELECT @c_Reason = 'FOUND PAType=' + @cpa_PAType + ': Search Type by Location'
                        EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
                     END
                     BREAK
                  END -- @b_GotLoc = 1
               END -- IF PA_Type = '16','17','18','19','22','24','32','34','42','44','52','54','55','56','57','58'
            END -- IF @cpa_LocSearchType = '1'
            ELSE IF @cpa_LocSearchType = '2' -- Search Zone By Logical Location
            BEGIN
               SELECT @cPA_ToLoc = SPACE(10), @c_searchlogicalloc = SPACE(18)
               WHILE (1=1)
               BEGIN
                  SET ROWCOUNT 1
                  SELECT @cPA_ToLoc = LOC,
                  @c_ToLoc = LOC,
                  @c_searchlogicalloc = LogicalLocation
                  FROM LOC (NOLOCK)
                  WHERE LOGICALLOCATION > @c_searchlogicalloc
                  AND Putawayzone = @c_searchzone
                  AND Facility = @c_Facility -- CDC Migration
                  ORDER BY LOGICALLOCATION
                  IF @@ROWCOUNT = 0
                  BEGIN
                     BREAK
                  END
                  SET ROWCOUNT 0
                  SELECT @n_locsreviewed = @n_locsreviewed + 1
                  IF @cpa_checkrestrictions = 'Y'
                  BEGIN
                     SELECT @b_RestrictionsPassed = 0
                     GOTO PA_CHECKRESTRICTIONS
                     PATYPE02_BYLOGICALLOC:
                     IF @b_RestrictionsPassed = 1
                     BEGIN
                        SELECT @b_GotLoc = 1
                        BREAK
                     END
                  END
                  ELSE
                  BEGIN
                     SELECT @b_GotLoc = 1
                     BREAK
                  END
               END -- While 1=1
               SET ROWCOUNT 0
               IF @b_GotLoc = 1
               BEGIN
                  IF @b_debug = 1
                  BEGIN
                     SELECT @c_Reason = 'FOUND PAType=' + @cpa_PAType + ': Search Type by Route Sequence'
                     EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                     @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                     @c_ToLoc, @c_Reason
                  END
                  BREAK
               END
            END -- IF @cpa_LocSearchType = '2'
         END -- LTRIM(RTRIM(@c_searchzone)) IS NOT NULL
         CONTINUE
      END -- IF PARTYPE = '02'/'04'/'12'

      IF @cpa_PAType = '06' -- Use Absolute Location Specified in ToLoc
      BEGIN
         SELECT @c_ToLoc = @cPA_ToLoc
         IF RTRIM(@cPA_ToLoc) IS NOT NULL AND RTRIM(@cPA_ToLoc) <> ''
         BEGIN
            IF @cpa_checkrestrictions = 'Y'
            BEGIN
               SELECT @b_RestrictionsPassed = 0
               GOTO PA_CHECKRESTRICTIONS
               PATYPE06:
               IF @b_RestrictionsPassed = 1
               BEGIN
                  SELECT @b_GotLoc = 1
                  IF @b_debug = 1
                  BEGIN
                     SELECT @c_Reason = 'FOUND PAType=06: Putaway Into To Location'
                     EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                     @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                     @c_ToLoc, @c_Reason
                  END
                  BREAK
               END
            END
            ELSE
            BEGIN
               SELECT @b_GotLoc = 1
               IF @b_debug = 1
               BEGIN
                  SELECT @c_Reason = 'FOUND PAType=06: Putaway Into To Location'
                  EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                  @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                  @c_ToLoc, @c_Reason
               END
               BREAK
            END
         END
         CONTINUE
      END -- IF @cpa_PAType = '6'

      IF @cpa_PAType = '08' -- Use Pick Location Specified For Product
         OR @cpa_PAType = '07' -- Use Pick Location Specified For Product IF BOH = 0
         OR @cpa_PAType = '88' -- FOR IDSPH CDC Handling
      BEGIN
         IF @b_MultiProductID = 0
         BEGIN
            SELECT @c_ToLoc = ''
            WHILE (1=1)
            BEGIN
               SET ROWCOUNT 1
               --IF @cpa_PAType = '88'
                 IF @cpa_PAType = '08' -- SOS#121517 Use Piece Pick Location For Product      
               BEGIN
                  SELECT @c_ToLoc = SKUxLOC.LOC
                  FROM SKUxLOC (NOLOCK) Join Loc (NOLOCK)
                    ON SKUxLOC.Loc = Loc.Loc
                  WHERE StorerKey = @c_StorerKey
                  AND SKU = @c_SKU
                  AND Loc.Facility = @c_Facility -- CDC Migration
                  AND (SKUxLOC.LOCATIONTYPE = 'PICK' OR SKUxLOC.LOCATIONTYPE = 'CASE')
                  AND SKUxLOC.LOC > @c_ToLoc
                  ORDER BY SKUxLOC.LOC
               END
               ELSE
               BEGIN
                  SELECT @c_ToLoc = SKUxLOC.LOC
                  FROM SKUxLOC (NOLOCK) Join Loc (NOLOCK)
                  on SKUxLOC.Loc = Loc.Loc
                  WHERE StorerKey = @c_StorerKey
                  AND SKU = @c_SKU
                  AND Loc.Facility = @c_Facility -- CDC Migration
                  AND (SKUxLOC.LOCATIONTYPE = 'PICK' OR SKUxLOC.LOCATIONTYPE = 'CASE') --ang01    
                  AND SKUxLOC.LOC > @c_ToLoc
                  ORDER BY SKUxLOC.LOC
               END
               IF @@ROWCOUNT = 0
               BEGIN
                  SET ROWCOUNT 0
                  SELECT @c_ToLoc = ''
                  BREAK
               END
               SET ROWCOUNT 0
               IF @c_ToLoc IS NULL
               BEGIN
                  SELECT @c_ToLoc = ''
               END
               IF @cpa_PAType = '07'
               BEGIN
                  --    IF EXISTS(SELECT *
                  --    FROM SKUxLOC (NOLOCK)
                  --    WHERE SKUxLOC.StorerKey = @c_StorerKey
                  --    AND SKUxLOC.Sku = @c_SKU
                  --    AND (SKUxLOC.Qty - SKUxLOC.QtyPicked) > 0)
                  IF (SELECT SUM(Qty - QtyPicked)
                  FROM SKUxLOC (NOLOCK)
                  JOIN LOC (NOLOCK) on SKUxLOC.loc = LOC.LOC
                  WHERE SKU = @c_SKU
                  AND StorerKey = @c_StorerKey
                  AND Facility = @c_Facility -- CDC Migration
                  AND LocationFlag = 'NONE'
                  AND LocationCategory <> 'VIRTUAL'
                  AND (SKUxLOC.LOCATIONTYPE = 'PICK' OR SKUxLOC.LOCATIONTYPE = 'CASE')--ang01      
                  AND SKUxLOC.LOC <> @c_FromLoc) > 0 -- vicky
                  BEGIN
                     SELECT @c_ToLoc = ''
                     IF @b_debug = 1
                     BEGIN
                  SELECT @c_Reason = 'FAILED PAType=07: Commodity has balance-on-hand qty'
                        EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
                     END
                     BREAK
                  END
               END
               /* Added By Vicky 10 Apr 2003 - CDC Migration */
               IF @cpa_PAType = '88'
               BEGIN
                  IF (SELECT SUM(qty-qtypicked)
                  FROM SKUxLOC (NOLOCK)
                  JOIN LOC (NOLOCK) ON (SKUxLOC.loc = loc.loc)
                  WHERE sku = @c_SKU
                  AND StorerKey = @c_StorerKey
                  AND loc.Facility = @c_Facility      -- wally 23.oct.2002
                  AND LocationFlag = 'NONE') > 0
                  BEGIN
                     SELECT @c_ToLoc = ''
                     IF @b_debug = 1
                     BEGIN
                        SELECT @c_Reason = 'FAILED PAType=88: Commodity has balance-on-hand qty'
                        EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
                     END
                     BREAK
                  END
               END
               /* CDC Migration END*/

               IF RTRIM(@c_ToLoc) IS NOT NULL AND RTRIM(@c_ToLoc) <> ''
               BEGIN
                  IF @cpa_checkrestrictions = 'Y'
                  BEGIN
                     SELECT @b_RestrictionsPassed = 0
                     GOTO PA_CHECKRESTRICTIONS
                     PATYPE08:
                     IF @b_RestrictionsPassed = 1
                     BEGIN
                        SELECT @b_GotLoc = 1
                        BREAK
                     END
                  END
                  ELSE
                  BEGIN
                     SELECT @b_GotLoc = 1
                     BREAK
                  END
               END
            END -- While (1=1)
            SET ROWCOUNT 0
            IF @b_GotLoc = 1
            BEGIN
               IF @b_debug = 1
               BEGIN
                  SELECT @c_Reason = 'FOUND PAType=' + @cpa_PAType + ': Putaway to Assigned Piece Pick'
                  EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                  @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                  @c_ToLoc, @c_Reason
               END
               BREAK
            END
         END -- IF @b_MultiProductID = 0
         CONTINUE
      END -- IF @cpa_PAType = '08'

      IF @cpa_PAType = '09' -- Use Location Specified In Product/Sku Table
      BEGIN
         IF @b_MultiProductID = 0
         BEGIN
            SELECT @c_ToLoc = PUTAWAYLOC
            FROM SKU (NOLOCK)
            WHERE StorerKey = @c_StorerKey
            AND SKU = @c_SKU
            IF RTRIM(@c_ToLoc) IS NOT NULL AND RTRIM(@c_ToLoc) <> ''
            BEGIN
               IF @cpa_checkrestrictions = 'Y'
               BEGIN
                  SELECT @b_RestrictionsPassed = 0
                  GOTO PA_CHECKRESTRICTIONS
                  PATYPE09:
                  IF @b_RestrictionsPassed = 1
                  BEGIN
                     SELECT @b_GotLoc = 1
                     IF @b_debug = 1
                     BEGIN
                        SELECT @c_Reason = 'FOUND PAType=09: Putaway to location specified on Commodity'
                        EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
                     END
                     BREAK
                  END
               END
               ELSE
               BEGIN
                  SELECT @b_GotLoc = 1
                  IF @b_debug = 1
                  BEGIN
                     SELECT @c_Reason = 'FOUND PAType=09: Putaway to location specified on Commodity'
                     EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                     @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                     @c_ToLoc, @c_Reason
                  END
                  BREAK
               END
            END
            ELSE
            BEGIN
               IF @b_debug = 1
               BEGIN
                  SELECT @c_Reason = 'FAILED PAType=09: Commodity has no putaway location specified'
                  EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                  @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                  @c_ToLoc, @c_Reason
               END
            END
         END -- IF @b_MultiProductID = 0
         CONTINUE
      END -- IF @cpa_PAType = '09'

      /* Start Add by DLIM for FBR22 20010620 */
      IF @cpa_PAType = '20' -- Use SKU pickface Location
      BEGIN
         IF @b_MultiProductID = 0
         BEGIN
            SELECT @c_ToLoc = ''
            WHILE (1=1)
            BEGIN
               SET ROWCOUNT 1
               SELECT @c_ToLoc = SKUxLOC.Loc
               FROM SKUxLOC (NOLOCK) JOIN Loc (NOLOCK)
               on SKUxLOC.Loc = Loc.Loc
               WHERE StorerKey = @c_StorerKey
               AND SKU = @c_SKU
               AND SKUxLOC.LOCATIONTYPE = 'PICK'
               AND @cpa_FROMLOC = @c_FromLoc
               AND Loc.Facility = @c_Facility -- CDC Migration
               ORDER BY SKUxLOC.LOC
               IF @@ROWCOUNT = 0
               BEGIN
                  SET ROWCOUNT 0
                  SELECT @c_ToLoc = ''
                  BREAK
               END
               SET ROWCOUNT 0
               IF @c_ToLoc IS NULL
               BEGIN
                  SELECT @c_ToLoc = ''
               END
               IF RTRIM(@c_ToLoc) IS NOT NULL AND RTRIM(@c_ToLoc) <> ''
               BEGIN
                  IF @cpa_checkrestrictions = 'Y'
                  BEGIN
                     SELECT @b_RestrictionsPassed = 0
                     GOTO PA_CHECKRESTRICTIONS
                     PATYPE20:
                     IF @b_RestrictionsPassed = 1
                     BEGIN
                        SELECT @b_GotLoc = 1
                        BREAK
                     END
                  END
                  ELSE
                  BEGIN
                     SELECT @b_GotLoc = 1
                     BREAK
                  END
               END
            END -- WHILE (1=1)
            SET ROWCOUNT 0
            IF @b_GotLoc = 1
            BEGIN
               IF @b_debug = 1
               BEGIN
                  SELECT @c_Reason = 'FOUND PAType=20: Putaway to SKU pickface location'
                  EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                  @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                  @c_ToLoc, @c_Reason
               END
               BREAK
            END
         END -- IF @b_MultiProductID = 0
         CONTINUE
      END -- IF @cpa_PAType = '20'
      /* END Add by DLIM for FBR22 20010620 */

      IF @cpa_PAType = '15' -- Use Case Pick Location Specified For Product
      BEGIN
         IF @b_MultiProductID = 0
         BEGIN
            SELECT @c_ToLoc = ''
            WHILE (1=1)
            BEGIN
               SET ROWCOUNT 1

               SELECT @c_ToLoc = SKUxLOC.LOC
               FROM SKUxLOC (NOLOCK)
               Join Loc (NOLOCK) on SKUxLOC.Loc = Loc.Loc
               WHERE StorerKey = @c_StorerKey
               AND SKU = @c_SKU
               AND SKUxLOC.LOCATIONTYPE = 'CASE'
               AND Loc.Facility = @c_Facility -- SOS6421
               AND SKUxLOC.LOC > @c_ToLoc
               ORDER BY SKUxLOC.LOC

               IF @@ROWCOUNT = 0
           BEGIN
                  SET ROWCOUNT 0
                  SELECT @c_ToLoc = ''
                  BREAK
               END
               SET ROWCOUNT 0
               IF @c_ToLoc IS NULL
               BEGIN
                  SELECT @c_ToLoc = ''
               END
               IF RTRIM(@c_ToLoc) IS NOT NULL AND RTRIM(@c_ToLoc) <> ''
               BEGIN
                  IF @cpa_checkrestrictions = 'Y'
                  BEGIN
                     SELECT @b_RestrictionsPassed = 0
                     GOTO PA_CHECKRESTRICTIONS
                     PATYPE15:
                     IF @b_RestrictionsPassed = 1
                     BEGIN
                        SELECT @b_GotLoc = 1
                        BREAK
                     END
                  END
                  ELSE
                  BEGIN
                     SELECT @b_GotLoc = 1
                     BREAK
                  END
               END
            END -- WHILE (1=1)
            SET ROWCOUNT 0
            IF @b_GotLoc = 1
            BEGIN
               IF @b_debug = 1
               BEGIN
                  SELECT @c_Reason = 'FOUND PAType=15: Putaway to Assogned Case Pick'
                  EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                  @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                  @c_ToLoc, @c_Reason
               END
               BREAK
            END
         END -- IF @b_MultiProductID = 0
         CONTINUE
      END -- IF @cpa_PAType = '15'

   END -- WHILE (1=1)
   SET ROWCOUNT 0

   IF @b_GotLoc <> 1 -- No Luck
   BEGIN
      SELECT @c_ToLoc= ''
   END
   IF @b_debug = 1
   BEGIN
      UPDATE PTRACEHEAD SET ENDTime = getdate(), PA_locFound = @c_ToLoc, PA_LocsReviewed = @n_locsreviewed
      WHERE PTRACEHEADKey = @n_pTraceHeadKey
   END
   GOTO LOCATION_EXIT

PA_CHECKRESTRICTIONS:
SELECT @c_Loc_Type    = LOCATIONTYPE ,
      @c_loc_flag     = LocationFlag ,
      @c_loc_handling = LOCATIONHANDLING,
      @c_loc_category = LocationCategory,
      @c_loc_zone     = PUTAWAYZONE ,
      @c_Loc_CommingleSku = CASE WHEN LOC.comminglesku IN ('1','Y') THEN '1' ELSE '0' END,   --(Wan03) 
      @c_loc_comminglelot = comminglelot,
      @n_Loc_Width  = WIDTH ,
      @n_Loc_Length = LENGTH ,
      @n_Loc_Height = HEIGHT ,
      @n_Loc_CubicCapacity  = cubiccapacity ,
      @n_Loc_WeightCapacity = weightcapacity,
      @n_loc_level = LOC.LocLevel,
      @c_loc_aisle = LOC.LocAisle
   ,  @c_NoMixLottable01 = CASE WHEN LOC.NoMixLottable01 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan01) 
   ,  @c_NoMixLottable02 = CASE WHEN LOC.NoMixLottable02 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan01) 
   ,  @c_NoMixLottable03 = CASE WHEN LOC.NoMixLottable03 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan01) 
   ,  @c_NoMixLottable04 = CASE WHEN LOC.NoMixLottable04 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan01) 
   ,  @c_NoMixLottable06 = CASE WHEN LOC.NoMixLottable06 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan04)   
   ,  @c_NoMixLottable07 = CASE WHEN LOC.NoMixLottable07 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan04)   
   ,  @c_NoMixLottable08 = CASE WHEN LOC.NoMixLottable08 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan04)   
   ,  @c_NoMixLottable09 = CASE WHEN LOC.NoMixLottable09 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan04)   
   ,  @c_NoMixLottable10 = CASE WHEN LOC.NoMixLottable10 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan04)   
   ,  @c_NoMixLottable11 = CASE WHEN LOC.NoMixLottable11 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan04)   
   ,  @c_NoMixLottable12 = CASE WHEN LOC.NoMixLottable12 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan04)   
   ,  @c_NoMixLottable13 = CASE WHEN LOC.NoMixLottable13 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan04)   
   ,  @c_NoMixLottable14 = CASE WHEN LOC.NoMixLottable14 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan04)   
   ,  @c_NoMixLottable15 = CASE WHEN LOC.NoMixLottable15 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan04) 
FROM LOC WITH (NOLOCK)
WHERE LOC = @c_ToLoc
SELECT @c_movableunittype = @c_movableunittype
SELECT @b_RestrictionsPassed = 1
SELECT @c_Loc_Type = LTRIM(@c_Loc_Type)

IF @c_Loc_Type IS NOT NULL
BEGIN
   IF @c_Loc_Type IN (@cpa_LocationTypeExclude01,@cpa_LocationTypeExclude02,@cpa_LocationTypeExclude03,@cpa_LocationTypeExclude04,@cpa_LocationTypeExclude05)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED Location type ' + RTRIM(@c_Loc_Type) + ' was one of the excluded values'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
      SELECT @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'PASSED Location type ' + RTRIM(@c_Loc_Type) + ' was not one of the excluded values'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
   END
END
IF ISNULL(RTRIM(@cpa_LocationTypeRestriction01),'') <> ''
OR ISNULL(RTRIM(@cpa_LocationTypeRestriction02),'') <> ''
OR ISNULL(RTRIM(@cpa_LocationTypeRestriction03),'') <> ''
BEGIN
   IF @c_Loc_Type NOT IN (@cpa_LocationTypeRestriction01,@cpa_LocationTypeRestriction02,@cpa_LocationTypeRestriction03)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED Location type ' + RTRIM(@c_Loc_Type) + ' was not one of the specified values'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
      SELECT @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'PASSED Location type ' + RTRIM(@c_Loc_Type) + ' was one of the specified values'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
   END
END
SELECT @c_loc_flag = LTRIM(@c_loc_flag)
IF @c_loc_flag IS NOT NULL
BEGIN
   IF @c_loc_flag IN (@cpa_LocationFlagexclude01,@cpa_LocationFlagexclude02,@cpa_LocationFlagexclude03)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED Location flag ' + RTRIM(@c_loc_flag) + ' was one of the excluded values'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
      SELECT @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'PASSED Location flag ' + RTRIM(@c_loc_flag) + ' was not one of the excluded values'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
   END
END
IF ISNULL(RTRIM(@cpa_LocationFlagInclude01),'') <> ''
OR ISNULL(RTRIM(@cpa_LocationFlagInclude02),'') <> ''
OR ISNULL(RTRIM(@cpa_LocationFlagInclude03),'') <> ''
BEGIN
   IF @c_loc_flag NOT IN (@cpa_LocationFlagInclude01,@cpa_LocationFlagInclude02,@cpa_LocationFlagInclude03)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED Location flag ' + RTRIM(@c_loc_flag) + ' was not one of the specified values'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
      SELECT @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'PASSED Location flag ' + RTRIM(@c_loc_flag) + ' was one of the specified values'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
   END
END
SELECT @c_loc_category = LTRIM(@c_loc_category)
IF @c_loc_category IS NOT NULL
BEGIN
   IF @c_loc_category IN (@cpa_LocationCategoryexclude01,@cpa_LocationCategoryexclude02,@cpa_LocationCategoryexclude03)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED Location category ' + RTRIM(@c_loc_category) + ' was one of the excluded values'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
      SELECT @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'PASSED Location category ' + RTRIM(@c_loc_category) + ' was not one of the excluded values'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
   END
END
IF ISNULL(RTRIM(@cpa_LocationCategoryInclude01),'') <> ''
OR ISNULL(RTRIM(@cpa_LocationCategoryInclude02),'') <> ''
OR ISNULL(RTRIM(@cpa_LocationCategoryInclude03),'') <> ''
BEGIN
   IF @c_loc_category NOT IN (@cpa_LocationCategoryInclude01,@cpa_LocationCategoryInclude02,@cpa_LocationCategoryInclude03)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED Location category ' + RTRIM(@c_loc_category) + ' was not one of the specified values'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
      SELECT @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @cpa_LocationCategoryInclude01 = 'DRIVEIN'
      BEGIN
         IF not exists (SELECT 1 from LOTxLOCxID (NOLOCK)
                                 join LotAttribute (NOLOCK) on LOTxLOCxID.lot = LotAttribute.lot
                        where LotAttribute.Lottable01 = @c_Lottable01
                          and LotAttribute.Lottable02 = @c_Lottable02
                          and LotAttribute.sku = @c_SKU
                          and LotAttribute.StorerKey = @c_StorerKey
                          and LOTxLOCxID.loc = @c_ToLoc)
         BEGIN
            IF (select sum(qty) from SKUxLOC (NOLOCK) where loc = @c_ToLoc) > 0
            BEGIN
               IF @b_debug = 1
               BEGIN
                  SELECT @c_Reason = 'FAILED Location category DRIVEIN ' + RTRIM(@c_loc_category) + ' Contain Different LOT Attributes.'
                  EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                  @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                  @c_ToLoc, @c_Reason
               END
               SELECT @b_RestrictionsPassed = 0
               GOTO RESTRICTIONCHECKDONE
            END
         END
      END
      -- END : by Wally 18.jan.2002
      /* CDC Migration Start */
      -- Added By SHONG 22.Jul.2002
      IF @c_loc_category = 'DOUBLEDEEP'
      BEGIN
         IF not exists (select 1
                        from LOTxLOCxID (NOLOCK)
                        join LotAttribute (NOLOCK) on LOTxLOCxID.lot = LotAttribute.lot
                        where LotAttribute.Lottable04 = @d_Lottable04
                        and LotAttribute.Lottable02 = @c_Lottable02
                        and LotAttribute.sku = @c_SKU
                        and LotAttribute.StorerKey = @c_StorerKey
                        and LOTxLOCxID.loc = @c_ToLoc)
         BEGIN
            IF (select sum(qty) from SKUxLOC (NOLOCK) where loc = @c_ToLoc) > 0
            BEGIN
               IF @b_debug = 1
               BEGIN
                  SELECT @c_Reason = 'FAILED Location category DOUBLEDEEP ' + RTRIM(@c_loc_category) + ' Contain Different LOT Attributes.'
                  EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                  @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                  @c_ToLoc, @c_Reason
               END
               SELECT @b_RestrictionsPassed = 0
               GOTO RESTRICTIONCHECKDONE
            END
         END
      END
      -- END : by Shong 22.Jul.2002
      /* CDC Migration END */
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'PASSED Location category ' + RTRIM(@c_loc_category) + ' was one of the specified values'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
   END
END -- LocationCategory Checkign

-- SELECT @c_loc_handling = LTRIM(@c_loc_handling)

IF ISNULL(RTRIM(@c_loc_Handling),'') <> '' AND
  (ISNULL(RTRIM(@cpa_LocationHandlingExclude01),'') <> '' OR
   ISNULL(RTRIM(@cpa_LocationHandlingExclude02),'') <> '' OR
   ISNULL(RTRIM(@cpa_LocationHandlingExclude03),'') <> '' )
BEGIN
   IF @c_loc_handling IN (@cpa_LocationHandlingExclude01,@cpa_LocationHandlingExclude02,@cpa_LocationHandlingExclude03)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED Location handling ' + RTRIM(@c_loc_handling) + ' was one of the excluded values'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
      SELECT @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'PASSED Location handling ' + RTRIM(@c_loc_handling) + ' was not one of the excluded values'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
   END
END
IF ISNULL(RTRIM(@cpa_LocationHandlingInclude01),'') <> ''
OR ISNULL(RTRIM(@cpa_LocationHandlingInclude02),'') <> ''
OR ISNULL(RTRIM(@cpa_LocationHandlingInclude03),'') <> ''
BEGIN
   IF @c_loc_handling NOT IN (@cpa_LocationHandlingInclude01,@cpa_LocationHandlingInclude02,@cpa_LocationHandlingInclude03)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED Location handling ' + RTRIM(@c_loc_handling) + ' was not one of the specified values'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
      SELECT @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'PASSED Location handling ' + RTRIM(@c_loc_handling) + ' was one of the specified values'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
   END
END
IF @b_MultiProductID = 1
BEGIN
   SELECT @n_CurrLocMultiSku = 1
   IF @b_debug = 1
   BEGIN
      SELECT @c_Reason = 'INFO   Commingled Sku Putaway Pallet Situation'
      EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
      @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
      @c_ToLoc, @c_Reason
   END
END
ELSE
BEGIN
   IF EXISTS(SELECT 1 FROM LOTxLOCxID (NOLOCK) WHERE LOC = @c_ToLoc AND (QTY > 0 OR PendingMoveIN > 0)
             AND (StorerKey <> @c_StorerKey OR  SKU <> @c_SKU))
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'INFO   Commingled Sku Current Loc/Putaway Pallet Situation'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
      SELECT @n_CurrLocMultiSku = 1
   END
   ELSE
   BEGIN
      SELECT @n_CurrLocMultiSku = 0
   END
END
IF @b_MultiLotID = 1
BEGIN
   SELECT @n_CurrLocMultiLot = 1
   IF @b_debug = 1
   BEGIN
      SELECT @c_Reason = 'INFO   Commingled Lot Putaway Pallet Situation'
      EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
      @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
      @c_ToLoc, @c_Reason
   END
END
ELSE
BEGIN
   IF EXISTS(SELECT 1 FROM LOTxLOCxID (NOLOCK) WHERE LOC = @c_ToLoc AND (QTY > 0 OR PendingMoveIN > 0) AND LOT <> @c_LOT)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'INFO   Commingled Lot Current Loc/Putaway Pallet Situation'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
      SELECT @n_CurrLocMultiLot = 1
   END
   ELSE
   BEGIN
      SELECT @n_CurrLocMultiLot = 0
   END
END
IF '2' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
   OR @c_Loc_CommingleSku = '0'
BEGIN
   IF @n_CurrLocMultiSku = 1
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED Do not mix commodities but ptwy pallet is commingled. Location commingle flag = ' + RTRIM(@c_Loc_CommingleSku)
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
      SELECT @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'PASSED Do not mix commodities and ptwy pallet is not commingled.  Location commingle flag = ' + RTRIM(@c_Loc_CommingleSku)
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
   END
END
IF '3' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
   OR @c_loc_comminglelot = '0'
BEGIN
   IF @n_CurrLocMultiLot = 1
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED Do not mix lots and ptwy pallet is commingled. Location mix lots flag = ' + RTRIM(@c_loc_comminglelot)
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
      SELECT @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'PASSED Do not mix lots and ptwy pallet is not commingled. Location mix lots flag = ' + RTRIM(@c_loc_comminglelot)
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
   END
END

--(Wan03) - START
IF @c_ChkLocByCommingleSkuFlag = '0'
BEGIN
   IF @c_NoMixLottable01 = '1' OR @c_NoMixLottable02 = '1' OR @c_NoMixLottable03 = '1' OR @c_NoMixLottable04 = '1'
   OR @c_NoMixLottable06 = '1' OR @c_NoMixLottable07 = '1' OR @c_NoMixLottable08 = '1' OR @c_NoMixLottable09 = '1' OR @c_NoMixLottable10 = '1'--(Wan04)
   OR @c_NoMixLottable11 = '1' OR @c_NoMixLottable12 = '1' OR @c_NoMixLottable13 = '1' OR @c_NoMixLottable14 = '1' OR @c_NoMixLottable15 = '1'--(Wan04)
   BEGIN
      SET @c_Loc_CommingleSku = '0'
   END
   ELSE
   BEGIN
      SET @c_Loc_CommingleSku = '1'
   END 
END
--(Wan03) - END

--(Wan01) - START
IF @c_Loc_CommingleSku = '0'                                                                                         --(Wan03)    
--IF @c_NoMixLottable01 = '1' OR @c_NoMixLottable02 = '1' OR @c_NoMixLottable03 = '1' OR @c_NoMixLottable04 = '1'    --(Wan03)
BEGIN
   IF EXISTS (SELECT 1 FROM LOTxLOCxID LLI WITH (NOLOCK)  
              WHERE LLI.Loc = @c_ToLoc
              AND  (LLI.Storerkey <> @c_Storerkey OR  LLI.Sku <> @c_Sku)
              AND   LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIn > 0)   --(Wan02)
   BEGIN
      SET @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
END

IF @c_NoMixLottable01 = '1'
BEGIN
   IF @b_CurrIDMultiLot01 = 1
   BEGIN
      SET @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN

      IF EXISTS ( SELECT 1 
                  FROM LOTATTRIBUTE LA WITH (NOLOCK)
                  JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                  WHERE LLI.Loc = @c_ToLoc
                  AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable01 <> @c_Lottable01) --NJOW01
                  AND   LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIn > 0)   --(Wan02)
      BEGIN
         SET @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END   
   END
END

IF @c_NoMixLottable02 = '1'
BEGIN
   IF @b_CurrIDMultiLot02 = 1
   BEGIN
      SET @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF EXISTS ( SELECT 1 
                  FROM LOTATTRIBUTE LA WITH (NOLOCK)
                  JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                  WHERE LLI.Loc = @c_ToLoc
                  AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable02 <> @c_Lottable02) --NJOW01
                  AND   LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIn > 0)   --(Wan02)
      BEGIN
         SET @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END   
   END
END

IF @c_NoMixLottable03 = '1'
BEGIN
   IF @b_CurrIDMultiLot03 = 1
   BEGIN
      SET @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF EXISTS ( SELECT 1 
                  FROM LOTATTRIBUTE LA WITH (NOLOCK)
                  JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                  WHERE LLI.Loc = @c_ToLoc
                  AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable03 <> @c_Lottable03) --NJOW01
                  AND   LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIn > 0)   --(Wan02)
      BEGIN
         SET @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END   
   END
END

IF @c_NoMixLottable04 = '1'
BEGIN
   IF @b_CurrIDMultiLot04 = 1
   BEGIN
      SET @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF EXISTS ( SELECT 1 
                  FROM LOTATTRIBUTE LA WITH (NOLOCK)
                  JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                  WHERE LLI.Loc = @c_ToLoc
                  AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') --NJOW01
                  AND   ISNULL(LA.Lottable04, CONVERT(DATETIME,'19000101')) <> ISNULL(@d_Lottable04,CONVERT(DATETIME,'19000101')))
                  AND   LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIn > 0)   --(Wan02)
      BEGIN
         SET @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END   
   END
END
--(Wan01) - END
--(Wan04) - START
IF @c_NoMixLottable06 = '1'
BEGIN
   IF @b_CurrIDMultiLot06 = 1
   BEGIN
      SET @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF EXISTS ( SELECT 1 
                  FROM LOTATTRIBUTE LA WITH (NOLOCK)
                  JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                  WHERE LLI.Loc = @c_ToLoc
                  AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable06 <> @c_Lottable06)  --NJOW01
                  AND   LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIn > 0)   --(Wan02)
      BEGIN
         SET @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END   
   END
END

IF @c_NoMixLottable07 = '1'
BEGIN
   IF @b_CurrIDMultiLot07 = 1
   BEGIN
      SET @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF EXISTS ( SELECT 1 
                  FROM LOTATTRIBUTE LA WITH (NOLOCK)
                  JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                  WHERE LLI.Loc = @c_ToLoc
                  AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable07 <> @c_Lottable07) --NJOW01
                  AND   LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIn > 0)   --(Wan02)
      BEGIN
         SET @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END   
   END
END

IF @c_NoMixLottable08 = '1'
BEGIN
   IF @b_CurrIDMultiLot08 = 1
   BEGIN
      SET @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF EXISTS ( SELECT 1 
                  FROM LOTATTRIBUTE LA WITH (NOLOCK)
                  JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                  WHERE LLI.Loc = @c_ToLoc
                  AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable08 <> @c_Lottable08) --NJOW01
                  AND   LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIn > 0)   --(Wan02)
      BEGIN
         SET @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END   
   END
END

IF @c_NoMixLottable09 = '1'
BEGIN
   IF @b_CurrIDMultiLot09 = 1
   BEGIN
      SET @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF EXISTS ( SELECT 1 
                  FROM LOTATTRIBUTE LA WITH (NOLOCK)
                  JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                  WHERE LLI.Loc = @c_ToLoc
                  AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable09 <> @c_Lottable09) --NJOW01
                  AND   LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIn > 0)   --(Wan02)
      BEGIN
         SET @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END   
   END
END

IF @c_NoMixLottable10 = '1'
BEGIN
   IF @b_CurrIDMultiLot10 = 1
   BEGIN
      SET @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF EXISTS ( SELECT 1 
                  FROM LOTATTRIBUTE LA WITH (NOLOCK)
                  JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                  WHERE LLI.Loc = @c_ToLoc
                  AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable10 <> @c_Lottable10) --NJOW01
                  AND   LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIn > 0)   --(Wan02)
      BEGIN
         SET @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END   
   END
END

IF @c_NoMixLottable11 = '1'
BEGIN
   IF @b_CurrIDMultiLot11 = 1
   BEGIN
      SET @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF EXISTS ( SELECT 1 
                  FROM LOTATTRIBUTE LA WITH (NOLOCK)
                  JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                  WHERE LLI.Loc = @c_ToLoc
                  AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable11 <> @c_Lottable11) --NJOW01
                  AND   LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIn > 0)   --(Wan02)
      BEGIN
         SET @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END   
   END
END

IF @c_NoMixLottable12 = '1'
BEGIN
   IF @b_CurrIDMultiLot12 = 1
   BEGIN
      SET @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF EXISTS ( SELECT 1 
                  FROM LOTATTRIBUTE LA WITH (NOLOCK)
                  JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                  WHERE LLI.Loc = @c_ToLoc
                  AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable12 <> @c_Lottable12) --NJOW01
                  AND   LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIn > 0)   --(Wan02)
      BEGIN
         SET @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END   
   END
END

IF @c_NoMixLottable13 = '1'
BEGIN
   IF @b_CurrIDMultiLot13 = 1
   BEGIN
      SET @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF EXISTS ( SELECT 1 
                  FROM LOTATTRIBUTE LA WITH (NOLOCK)
                  JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                  WHERE LLI.Loc = @c_ToLoc
                  AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') --NJOW01
                  AND   ISNULL(LA.Lottable13, CONVERT(DATETIME,'19000101')) <> ISNULL(@d_Lottable13,CONVERT(DATETIME,'19000101')))
                  AND   LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIn > 0)   --(Wan02)
      BEGIN
         SET @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END   
   END
END

IF @c_NoMixLottable14 = '1'
BEGIN
   IF @b_CurrIDMultiLot14 = 1
   BEGIN
      SET @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF EXISTS ( SELECT 1 
                  FROM LOTATTRIBUTE LA WITH (NOLOCK)
                  JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                  WHERE LLI.Loc = @c_ToLoc
                  AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') --NJOW01
                  AND   ISNULL(LA.Lottable14, CONVERT(DATETIME,'19000101')) <> ISNULL(@d_Lottable14,CONVERT(DATETIME,'19000101')))
                  AND   LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIn > 0)   --(Wan02)
      BEGIN
         SET @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END   
   END
END

IF @c_NoMixLottable15 = '1'
BEGIN
   IF @b_CurrIDMultiLot15 = 1
   BEGIN
      SET @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF EXISTS ( SELECT 1 
                  FROM LOTATTRIBUTE LA WITH (NOLOCK)
                  JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                  WHERE LLI.Loc = @c_ToLoc
                  AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') --NJOW01
                  AND   ISNULL(LA.Lottable15, CONVERT(DATETIME,'19000101')) <> ISNULL(@d_Lottable15,CONVERT(DATETIME,'19000101')))
                  AND   LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIn > 0)   --(Wan02)
      BEGIN
         SET @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END   
   END
END
--(Wan04) - END

-- Added By SHONG - Check Max Pallet
-- END Check Pallet
SELECT @cpa_AreaTypeExclude01 = LTRIM(@cpa_AreaTypeExclude01)
IF @cpa_AreaTypeExclude01 IS NOT NULL
BEGIN
   IF EXISTS(SELECT * FROM AREADETAIL (NOLOCK) WHERE PUTAWAYZONE = @c_loc_zone AND AREAKEY = @cpa_AreaTypeExclude01)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED Zone: ' + RTRIM(@c_loc_zone) + ' falls in excluded Area1: ' +  RTRIM(@cpa_AreaTypeExclude01)
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
      SELECT @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'PASSED Zone1 ' + RTRIM(@c_loc_zone) + ' is not excluded'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
   END
END
SELECT @cpa_AreaTypeExclude02 = LTRIM(@cpa_AreaTypeExclude02)
IF @cpa_AreaTypeExclude02 IS NOT NULL
BEGIN
   IF EXISTS(SELECT 1 FROM AREADETAIL (NOLOCK) WHERE PUTAWAYZONE = @c_loc_zone AND AREAKEY = @cpa_AreaTypeExclude02)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED Zone: ' + RTRIM(@c_loc_zone) + ' falls in excluded Area2: ' +  RTRIM(@cpa_AreaTypeExclude02)
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
      SELECT @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'PASSED Zone2 ' + RTRIM(@c_loc_zone) + ' is not excluded'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
   END
END
SELECT @cpa_AreaTypeExclude03 = LTRIM(@cpa_AreaTypeExclude03)
IF @cpa_AreaTypeExclude03 IS NOT NULL
BEGIN
   IF EXISTS(SELECT 1 FROM AREADETAIL (NOLOCK) WHERE PUTAWAYZONE = @c_loc_zone AND AREAKEY = @cpa_AreaTypeExclude03)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED Zone: ' + RTRIM(@c_loc_zone) + ' falls in excluded Area3:' +  RTRIM(@cpa_AreaTypeExclude03)
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
      SELECT @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'PASSED Zone3 ' + RTRIM(@c_loc_zone) + ' is not excluded'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
   END
END
IF '1' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
BEGIN
   IF EXISTS(SELECT 1 FROM LOTxLOCxID (NOLOCK) WHERE LOC = @c_ToLoc AND (QTY > 0 or PendingMoveIN > 0))
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED Location state says Location must be empty, but its not'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
      SELECT @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'PASSED Location state says Location must be empty, and it is'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
   END
END
IF '2' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
OR @c_Loc_CommingleSku = '0'
BEGIN
   IF @n_CurrLocMultiSku = 1
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED Do not mix commodities'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
      SELECT @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'PASSED do not mix commodities'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
   END
END
IF '3' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
OR @c_loc_comminglelot = '0'
BEGIN
   IF @n_CurrLocMultiLot = 1
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED Do not mix lots'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
      SELECT @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'PASSED Do not mix lots'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
   END
END
IF '4' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
BEGIN
   -- get the pallet setup
   SELECT @n_MaxPallet = (CASE MaxPallet WHEN NULL THEN 0 ELSE MaxPallet END) FROM LOC (NOLOCK) WHERE LOC = @c_ToLoc

   IF @n_MaxPallet > 0
   BEGIN
      SELECT @n_PalletQty = 0

      SELECT @n_PalletQty = ISNULL( COUNT(DISTINCT ID), 0)
      FROM   LOTxLOCxID (NOLOCK)
      WHERE  LOC = @c_ToLoc
      --AND  (Qty > 0 OR PendingMoveIn > 0 )  -- SOS#122545
      AND  ( (Qty - QtyPicked) > 0 OR PendingMoveIn > 0 ) -- SOS#122545

      IF @n_PalletQty >= @n_MaxPallet
      BEGIN
         -- error
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED - Fit By Max Pallet, Max Pallet: ' + RTRIM(CAST(@n_MaxPallet as NVARCHAR(10))) +
                               ' Pallet Required: ' +  RTRIM( CAST((@n_PalletQty + 1) as NVARCHAR(10)))

            EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
            @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
            @c_ToLoc, @c_Reason
         END
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED - Fit By Max Pallet, Max Pallet: ' + RTRIM(CAST(@n_MaxPallet as NVARCHAR(10))) +
                               ' Pallet Required: ' +  RTRIM( CAST((@n_PalletQty + 1) as NVARCHAR(10)))

            EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
            @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
            @c_ToLoc, @c_Reason
         END
      END
   END
END
-- Added by MaryVong on 20-Jul-2005 (SOS36712 KCPI) -Start(2)
IF '5' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
BEGIN
   -- get the pallet setup
   SELECT @n_MaxPallet = (CASE MaxPallet WHEN NULL THEN 0 ELSE MaxPallet END) FROM  LOC (NOLOCK) WHERE LOC = @c_ToLoc
   SELECT @n_StackFactor = (CASE StackFactor WHEN NULL THEN 0 ELSE StackFactor END) FROM SKU (NOLOCK) WHERE Storerkey = @c_StorerKey AND Sku = @c_SKU
   SELECT @n_MaxPalletStackFactor = @n_MaxPallet * @n_StackFactor

   IF @b_debug = 2
   BEGIN
      SELECT 'MaxPallet is ' + CONVERT(CHAR(3),@n_MaxPallet) + 'StackFactor is ' + CONVERT(CHAR(3),@n_StackFactor)
      SELECT 'MaxPallet * StackFactor is ' + CONVERT(CHAR(3),@n_MaxPalletStackFactor)
   END

   IF @n_MaxPalletStackFactor > 0
   BEGIN
      SELECT @n_PalletQty = 0

      SELECT @n_PalletQty = ISNULL( COUNT(DISTINCT ID), 0)
      FROM   LOTxLOCxID (NOLOCK)
      WHERE  LOC = @c_ToLoc
      AND    (Qty > 0 OR PendingMoveIn > 0 )

      IF @n_PalletQty >= @n_MaxPalletStackFactor
      BEGIN
         -- error
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED - Fit By Max Pallet (Stack Factor), Max Pallet: ' + RTRIM(CAST(@n_MaxPallet as NVARCHAR(10))) +
                               ' Pallet Required: ' +  RTRIM( CAST((@n_PalletQty + 1) as NVARCHAR(10)))

            EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
            @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
            @c_ToLoc, @c_Reason
         END
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED - Fit By Max Pallet (Stack Factor), Max Pallet: ' + RTRIM(CAST(@n_MaxPallet as NVARCHAR(10))) +
                               ' Pallet Required: ' +  RTRIM( CAST((@n_PalletQty + 1) as NVARCHAR(10)))

            EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                 @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                 @c_ToLoc, @c_Reason
         END
      END
   END
END
-- Added by MaryVong on 20-Jul-2005 (SOS36712 KCPI) -End(2)

-- Added by MaryVong on 31-Mar-2007 (SOS69388 KFP) -Start(2)
-- '6' & '7' - Check with MaxPallet for HostWhCode instead of Loc
-- KFP LOC Setup: Facility    Loc    HostWhCode
--                Good        LOC1   LOC1
--                Good        LOC2   LOC2
--                Quarantine  LOC1Q  LOC1
--                Quarantine  LOC2Q  LOC2
IF '6' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
BEGIN
   -- Get the pallet setup
   SELECT @n_MaxPallet = (CASE MaxPallet WHEN NULL THEN 0 ELSE MaxPallet END) FROM LOC (NOLOCK) WHERE LOC = @c_ToLoc

   IF @n_MaxPallet > 0
   BEGIN
      SELECT @n_PalletQty = 0

      SELECT @n_PalletQty = ISNULL( COUNT(DISTINCT ID), 0)
      FROM   LOTxLOCxID (NOLOCK)
      WHERE  LOC IN (SELECT LOC FROM LOC (NOLOCK) WHERE HostWhCode = @c_ToHostWhCode)
      AND    (Qty > 0 OR PendingMoveIn > 0 )

      IF @n_PalletQty >= @n_MaxPallet
      BEGIN
         -- error
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED - 6 - Fit By Max Pallet, Max Pallet: ' + RTRIM(CAST(@n_MaxPallet as NVARCHAR(10))) +
                               ' Pallet Required: ' +  RTRIM( CAST((@n_PalletQty + 1) as NVARCHAR(10)))

            EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
            @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
            @c_ToLoc, @c_Reason
         END
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED - 6 - Fit By Max Pallet, Max Pallet: ' + RTRIM(CAST(@n_MaxPallet as NVARCHAR(10))) +
                               ' Pallet Required: ' +  RTRIM( CAST((@n_PalletQty + 1) as NVARCHAR(10)))

            EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
            @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
            @c_ToLoc, @c_Reason
         END
      END
   END
END

IF '7' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
BEGIN
   -- get the pallet setup
   SELECT @n_MaxPallet = (CASE MaxPallet WHEN NULL THEN 0 ELSE MaxPallet END) FROM  LOC (NOLOCK) WHERE LOC = @c_ToLoc
   SELECT @n_StackFactor = (CASE StackFactor WHEN NULL THEN 0 ELSE StackFactor END) FROM SKU (NOLOCK) WHERE Storerkey = @c_StorerKey AND Sku = @c_SKU
   SELECT @n_MaxPalletStackFactor = @n_MaxPallet * @n_StackFactor

   IF @b_debug = 2
   BEGIN
      SELECT '7 - MaxPallet is ' + CONVERT(CHAR(3),@n_MaxPallet) + 'StackFactor is ' + CONVERT(CHAR(3),@n_StackFactor)
      SELECT '7 - MaxPallet * StackFactor is ' + CONVERT(CHAR(3),@n_MaxPalletStackFactor)
   END

   IF @n_MaxPalletStackFactor > 0
   BEGIN
      SELECT @n_PalletQty = 0

      SELECT @n_PalletQty = ISNULL( COUNT(DISTINCT ID), 0)
      FROM   LOTxLOCxID (NOLOCK)
      -- WHERE  LOC = @c_ToLoc
      WHERE  LOC IN (SELECT LOC FROM LOC (NOLOCK) WHERE HostWhCode = @c_ToHostWhCode)
      AND    (Qty > 0 OR PendingMoveIn > 0 )

      IF @n_PalletQty >= @n_MaxPalletStackFactor
      BEGIN
         -- error
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED - 7 - Fit By Max Pallet (Stack Factor), Max Pallet: ' + RTRIM(CAST(@n_MaxPallet as NVARCHAR(10))) +
                               ' Pallet Required: ' +  RTRIM( CAST((@n_PalletQty + 1) as NVARCHAR(10)))

            EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
            @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
            @c_ToLoc, @c_Reason
         END
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED - 7 - Fit By Max Pallet (Stack Factor), Max Pallet: ' + RTRIM(CAST(@n_MaxPallet as NVARCHAR(10))) +
                               ' Pallet Required: ' +  RTRIM( CAST((@n_PalletQty + 1) as NVARCHAR(10)))

            EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
            @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
            @c_ToLoc, @c_Reason
         END
      END
   END
END
-- Added by MaryVong on 31-Mar-2007 (SOS69388 KFP) -End(2)
-- SOS#140197
IF '10' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
BEGIN
   SET @d_CurrentLottable05 = NULL
   SELECT TOP 1
          @d_CurrentLottable05 = Lottable05
   FROM   LOTxLOCxID LLL WITH (NOLOCK)
   JOIN   LotAttribute LA WITH (NOLOCK) ON LLL.LOT = LA.LOT
   WHERE  LLL.LOC = @c_ToLoc
   AND    LLL.Qty - QtyPicked > 0

   IF @d_CurrentLottable05 IS NOT NULL AND @d_CurrentLottable05 <> @d_Lottable05
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED Do Not Mix Lottable05, Location Already Contain Lottable05 = ' + CONVERT(varchar(20), @d_CurrentLottable05)
         EXEC nspPTD 'nspASNPASTD', @n_ptraceheadkey, @c_PutawayStrategyKey,
         @c_putawaystrategylinenumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
      END
      SELECT @b_restrictionspassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'PASSED Do Not Mix Lottable05'
         EXEC nspPTD 'nspASNPASTD', @n_ptraceheadkey, @c_PutawayStrategyKey, @c_putawaystrategylinenumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
   END
END
-- END SOS#140197

-- SOS#133381 Location Alsie Restriction
IF ISNULL(RTRIM(@cpa_LocAisleInclude01),'') <> '' OR
   ISNULL(RTRIM(@cpa_LocAisleInclude02),'') <> '' OR
   ISNULL(RTRIM(@cpa_LocAisleInclude03),'') <> '' OR
   ISNULL(RTRIM(@cpa_LocAisleInclude04),'') <> '' OR
   ISNULL(RTRIM(@cpa_LocAisleInclude05),'') <> '' OR
   ISNULL(RTRIM(@cpa_LocAisleInclude06),'') <> ''
BEGIN
   IF @c_Loc_Aisle NOT IN (@cpa_LocAisleInclude01,@cpa_LocAisleInclude02,@cpa_LocAisleInclude03,
                           @cpa_LocAisleInclude04,@cpa_LocAisleInclude05,@cpa_LocAisleInclude06)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED Location Aisle ' + RTRIM(@c_Loc_Aisle) + ' was not one of the specified values'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
      SELECT @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'PASSED Location Aisle ' + RTRIM(@c_Loc_Aisle) + ' was one of the specified values'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
   END
END

IF ISNULL(RTRIM(@cpa_LocAisleExclude01),'') <> '' OR
   ISNULL(RTRIM(@cpa_LocAisleExclude02),'') <> '' OR
   ISNULL(RTRIM(@cpa_LocAisleExclude03),'') <> '' OR
   ISNULL(RTRIM(@cpa_LocAisleExclude04),'') <> '' OR
   ISNULL(RTRIM(@cpa_LocAisleExclude05),'') <> '' OR
   ISNULL(RTRIM(@cpa_LocAisleExclude06),'') <> ''
BEGIN
   IF @c_Loc_Aisle IN (@cpa_LocAisleExclude01,@cpa_LocAisleExclude02,@cpa_LocAisleExclude03,
                           @cpa_LocAisleExclude04,@cpa_LocAisleExclude05,@cpa_LocAisleExclude06)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED Location Aisle ' + RTRIM(@c_Loc_Aisle) + ' was one of the excluded values'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
      SELECT @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'PASSED Location Aisle ' + RTRIM(@c_Loc_Aisle) + ' was not one of the excluded values'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
   END
END

IF ISNULL(@npa_LocLevelInclude01,0) <> 0 OR
   ISNULL(@npa_LocLevelInclude02,0) <> 0 OR
   ISNULL(@npa_LocLevelInclude03,0) <> 0 OR
   ISNULL(@npa_LocLevelInclude04,0) <> 0 OR
   ISNULL(@npa_LocLevelInclude05,0) <> 0 OR
   ISNULL(@npa_LocLevelInclude06,0) <> 0
BEGIN
   IF @n_Loc_Level NOT IN (@npa_LocLevelInclude01,@npa_LocLevelInclude02,@npa_LocLevelInclude03,
                           @npa_LocLevelInclude04,@npa_LocLevelInclude05,@npa_LocLevelInclude06)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED Location Level ' + RTRIM(CAST(@n_Loc_Level as NVARCHAR(10))) + ' was not one of the specified values'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
      SELECT @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'PASSED Location Level ' + RTRIM(CAST(@n_Loc_Level as NVARCHAR(10))) + ' was one of the specified values'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
   END
END
IF (ISNULL(@npa_LocLevelExclude01,0) <> 0 OR
    ISNULL(@npa_LocLevelExclude02,0) <> 0 OR
    ISNULL(@npa_LocLevelExclude03,0) <> 0 OR
    ISNULL(@npa_LocLevelExclude04,0) <> 0 OR
    ISNULL(@npa_LocLevelExclude05,0) <> 0 OR
    ISNULL(@npa_LocLevelExclude06,0) <> 0 ) AND
   @n_Loc_Level > 0
BEGIN
   IF @n_Loc_Level IN (@npa_LocLevelExclude01,@npa_LocLevelExclude02,@npa_LocLevelExclude03,
                       @npa_LocLevelExclude04,@npa_LocLevelExclude05,@npa_LocLevelExclude06)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED Location Level ' + RTRIM(CAST(@n_Loc_Level as NVARCHAR(10))) + ' was not one of the excluded values'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
      SELECT @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'PASSED Location Level ' + RTRIM(CAST(@n_Loc_Level as NVARCHAR(10))) + ' was not one of the exclude values'
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
   END
END

SELECT @n_PalletWoodWidth  = PACK.PalletWoodWidth,
       @n_PalletWoodLength = PACK.PalletWoodLength,
       @n_PalletWoodHeight = PACK.PalletWoodHeight,
       @n_CaseLength       = PACK.LengthUOM1,
       @n_CaseWidth        = PACK.WidthUOM1,
       @n_CaseHeight       = PACK.HeightUOM1,
       @n_PutawayTI        = PACK.PalletTI,
       @n_PutawayHI        = PACK.PalletHI,
       @n_PackCaseCount    = PACK.CaseCnt,
       @n_CubeUOM1         = PACK.CubeUOM1,
       @n_QtyUOM1          = PACK.CaseCnt,
       @n_CubeUOM3         = PACK.CubeUOM3,
       @n_QtyUOM3          = PACK.Qty,
       @n_CubeUOM4         = PACK.CubeUOM4,
       @n_QtyUOM4          = PACK.Pallet
FROM PACK (NOLOCK)
WHERE PACK.Packkey = @c_PackKey

IF '1' IN (@cpa_DimensionRestriction01,
           @cpa_DimensionRestriction02,
           @cpa_DimensionRestriction03,
           @cpa_DimensionRestriction04,
           @cpa_DimensionRestriction05,
           @cpa_DimensionRestriction06)
BEGIN
   IF @n_CurrLocMultiLot = 0
   BEGIN
      SELECT @n_QuantityCapacity = 0
      IF @n_CubeUOM3 = 0 OR @n_CubeUOM3 IS NULL
      BEGIN
         SELECT @n_CubeUOM3 = Sku.StdCube
         FROM   SKU (NOLOCK)
         WHERE  SKu.SKU = @c_SKU
         IF @n_CubeUOM3 IS NULL
         SELECT @n_CubeUOM3 = 0
      END
      SELECT @n_UOMcapacity = (@n_Loc_CubicCapacity / @n_CubeUOM3)
      SELECT @n_QuantityCapacity = @n_UOMcapacity
      -- IF @c_Loc_Type = 'OTHER'
      -- BEGIN
      -- SELECT @n_Loc_CubicCapacity = @n_Loc_CubicCapacity - (@n_PalletWoodWidth * @n_PalletWoodLength * @n_PalletWoodHeight)
      -- SELECT @n_UOMcapacity = (@n_Loc_CubicCapacity / @n_CubeUOM4)
      -- SELECT @n_QuantityCapacity = @n_QuantityCapacity + (@n_UOMcapacity * @n_QtyUOM4)
      -- SELECT @n_Loc_CubicCapacity = @n_Loc_CubicCapacity - (@n_UOMcapacity * @n_CubeUOM4)
      -- END
      -- SELECT @n_UOMcapacity = (@n_Loc_CubicCapacity / @n_CubeUOM1)
      -- SELECT @n_QuantityCapacity = @n_QuantityCapacity + (@n_UOMcapacity * @n_QtyUOM1)
      -- SELECT @n_Loc_CubicCapacity = @n_Loc_CubicCapacity - (@n_UOMcapacity * @n_CubeUOM1)
      -- IF @c_Loc_Type = 'PICK'
      -- BEGIN
      -- SELECT @n_UOMcapacity = (@n_Loc_CubicCapacity / @n_CubeUOM3)
      -- SELECT @n_QuantityCapacity = @n_QuantityCapacity + (@n_UOMcapacity * @n_QtyUOM3)
      -- END
      SELECT @n_ToQty = SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked + LOTxLOCxID.PendingMoveIn)
      FROM LOTxLOCxID (NOLOCK)
      WHERE LOTxLOCxID.StorerKey = @c_StorerKey
      AND LOTxLOCxID.Sku = @c_SKU
      AND LOTxLOCxID.Loc = @c_ToLoc
      AND (LOTxLOCxID.Qty > 0 OR LOTxLOCxID.PendingMoveIn > 0)
      IF @n_ToQty IS NULL
      BEGIN
         SELECT @n_ToQty = 0
      END
      IF (@n_ToQty + @n_Qty ) > @n_QuantityCapacity
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED Qty Fit: QtyCapacity = ' + RTRIM(CONVERT(char(10),@n_QuantityCapacity)) + '  QtyRequired = ' + RTRIM(Convert(char(10),(@n_ToQty + @n_Qty)))
            EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
            @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
            @c_ToLoc, @c_Reason
         END
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Qty Fit: QtyCapacity = ' + RTRIM(CONVERT(char(10),@n_QuantityCapacity)) + '  QtyRequired = ' + RTRIM(Convert(char(10),(@n_ToQty + @n_Qty)))
            EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
            @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
            @c_ToLoc, @c_Reason
         END
      END
   END  -- End of IF @n_CurrLocMultiLot = 0
   ELSE
   BEGIN
      SELECT @n_ToCube = SUM((LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked + LOTxLOCxID.PendingMoveIn) * Sku.StdCube)
      FROM LOTxLOCxID (NOLOCK) ,Sku (NOLOCK)
      WHERE LOTxLOCxID.StorerKey = @c_StorerKey
      AND LOTxLOCxID.Sku = @c_SKU
      AND LOTxLOCxID.Loc = @c_ToLoc
      AND LOTxLOCxID.StorerKey = sku.StorerKey
      and LOTxLOCxID.sku = sku.sku
      AND (LOTxLOCxID.Qty > 0 OR LOTxLOCxID.PendingMoveIn > 0)
      IF RTRIM(@c_ID) IS NOT NULL AND RTRIM(@c_ID) <> ''
      BEGIN
         SELECT @n_FromCube = SUM((LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked) * Sku.StdCube)
         FROM LOTxLOCxID (NOLOCK), Sku (NOLOCK)
         WHERE LOTxLOCxID.StorerKey = @c_StorerKey
         AND LOTxLOCxID.Sku = @c_SKU
         AND LOTxLOCxID.Loc = @c_FromLoc
         AND LOTxLOCxID.Id = @c_ID
         AND LOTxLOCxID.StorerKey = sku.StorerKey
         and LOTxLOCxID.sku = sku.sku
         AND LOTxLOCxID.Qty > 0
      END
      ELSE
      BEGIN
         SELECT @n_FromCube = SUM((LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked) * Sku.StdCube)
         FROM LOTxLOCxID (NOLOCK), Sku (NOLOCK)
         WHERE LOTxLOCxID.StorerKey = @c_StorerKey
         AND LOTxLOCxID.Sku = @c_SKU  --vicky
         AND LOTxLOCxID.Loc = @c_FromLoc
         AND LOTxLOCxID.Lot = @c_LOT
         AND LOTxLOCxID.StorerKey = sku.StorerKey
         and LOTxLOCxID.sku = sku.sku
         AND LOTxLOCxID.Qty > 0
      END
      IF @n_Loc_CubicCapacity < (@n_ToCube + @n_FromCube)
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED Cube Fit: CubeCapacity = ' + RTRIM(CONVERT(char(10),@n_Loc_CubicCapacity)) + '  CubeRequired = ' + RTRIM(Convert(char(10),(@n_ToCube + @n_FromCube)))
            EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
            @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
            @c_ToLoc, @c_Reason
         END
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Cube Fit: CubeCapacity = ' + RTRIM(CONVERT(char(10),@n_Loc_CubicCapacity)) + '  CubeRequired = ' + RTRIM(Convert(char(10),(@n_ToCube + @n_FromCube)))
            EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
            @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
            @c_ToLoc, @c_Reason
         END
      END
   END
END
IF '2' IN (@cpa_DimensionRestriction01,
         @cpa_DimensionRestriction02,
         @cpa_DimensionRestriction03,
         @cpa_DimensionRestriction04,
         @cpa_DimensionRestriction05,
         @cpa_DimensionRestriction06)
AND @c_Loc_Type NOT IN ('PICK','CASE')
AND @n_CurrLocMultiLot = 0
BEGIN
   IF @n_PutawayTI IS NULL OR @n_PutawayTI = 0
   BEGIN
      SELECT @c_Reason = 'FAILED LxWxH Fit: Commodity PutawayTi = 0 or is NULL'
      EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
      @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
      @c_ToLoc, @c_Reason

      SELECT @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   IF (@n_PalletWoodWidth > @n_Loc_Width OR @n_PalletWoodLength > @n_Loc_Length) AND
      (@n_PalletWoodWidth > @n_Loc_Length OR @n_PalletWoodLength > @n_Loc_Width)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED LxWxH Fit: Wood/LocWidth=' + CONVERT(char(4),@n_PalletWoodWidth) + ' / ' + CONVERT(char(4),@n_Loc_Width) + '  Wood/locLength=' + CONVERT(char(4),@n_PalletWoodLength) + ' / ' + CONVERT(char(4),@n_Loc_Length)
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
      SELECT @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
   BEGIN
         SELECT @c_Reason = 'PASSED LxWxH Fit: Wood/LocWidth=' + CONVERT(char(4),@n_PalletWoodWidth) + ' / ' + CONVERT(char(4),@n_Loc_Width) + '  Wood/locLength=' + CONVERT(char(4),@n_PalletWoodLength) + ' / ' + CONVERT(char(4),@n_Loc_Length)
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
   END
   SELECT @n_ExistingQuantity = SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked + LOTxLOCxID.PendingMoveIn)
   FROM LOTxLOCxID (NOLOCK)
   WHERE LOTxLOCxID.StorerKey = @c_StorerKey
   AND LOTxLOCxID.Sku = @c_SKU
   AND LOTxLOCxID.Loc = @c_ToLoc
   AND (LOTxLOCxID.Qty > 0 OR LOTxLOCxID.PendingMoveIn > 0)
   IF @n_ExistingQuantity IS NULL
   BEGIN
      SELECT @n_ExistingQuantity = 0
      SELECT @n_ExistingHeight = @n_PalletWoodHeight
   END
   ELSE
   BEGIN
      SELECT @n_ExistingLayers = @n_ExistingQuantity / (@n_PutawayTI * @n_PackCaseCount)
      SELECT @n_ExtraLayer = @n_ExistingQuantity % (@n_PutawayTI * @n_PackCaseCount)
      IF @n_ExtraLayer > 0
      BEGIN
         SELECT @n_ExistingLayers = @n_ExistingLayers + 1
      END
      SELECT @n_ExistingHeight = (@n_ExistingLayers * @n_CaseHeight) + @n_PalletWoodHeight
   END
   SELECT @n_ExistingLayers = @n_Qty / (@n_PutawayTI * @n_PackCaseCount)
   SELECT @n_ExtraLayer = @n_Qty % (@n_PutawayTI * @n_PackCaseCount)
   IF @n_ExtraLayer > 0
   BEGIN
      SELECT @n_ExistingLayers = @n_ExistingLayers + 1
   END
   SELECT @n_PalletHeight = @n_CaseHeight * @n_ExistingLayers
   IF @n_ExistingHeight + @n_PalletHeight > @n_Loc_Height
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED LxWxH Fit: LocHeight = ' + RTRIM(CONVERT(char(20),@n_Loc_Height)) + '  ExistingHeight = ' + RTRIM(CONVERT(char(20),@n_ExistingHeight)) + '  AdditionalHeight = ' + RTRIM(CONVERT(char(20),(@n_PalletHeight)))
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
      SELECT @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'PASSED LxWxH Fit: LocHeight = ' + RTRIM(CONVERT(char(20),@n_Loc_Height)) + '  ExistingHeight = ' + RTRIM(CONVERT(char(20),@n_ExistingHeight)) + '  AdditionalHeight = ' + RTRIM(CONVERT(char(20),(@n_PalletHeight)))
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
   END
END
IF '3' IN (@cpa_DimensionRestriction01,
@cpa_DimensionRestriction02,
@cpa_DimensionRestriction03,
@cpa_DimensionRestriction04,
@cpa_DimensionRestriction05,
@cpa_DimensionRestriction06)
BEGIN
   SELECT @n_ToWeight = SUM((LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked + LOTxLOCxID.PendingMoveIn) * Sku.StdGrossWgt)
   FROM LOTxLOCxID (NOLOCK), Sku (NOLOCK)
   WHERE LOTxLOCxID.StorerKey = Sku.StorerKey
   AND LOTxLOCxID.Sku = Sku.sku
   AND LOTxLOCxID.Loc = @c_ToLoc
   AND LOTxLOCxID.Qty > 0
   IF @n_ToWeight IS NULL
   BEGIN
      SELECT @n_ToWeight = 0
   END
   IF @b_MultiProductID = 0
   BEGIN
      SELECT @n_FromWeight = @n_Qty * @n_StdGrossWgt
   END
   ELSE
   BEGIN
      SELECT @n_FromWeight = SUM((LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked) * Sku.StdGrossWgt)
      FROM LOTxLOCxID (NOLOCK), Sku (NOLOCK)
      WHERE LOTxLOCxID.StorerKey = Sku.StorerKey
      AND LOTxLOCxID.Sku = Sku.sku
      AND LOTxLOCxID.Id = @c_ID
      IF @n_FromWeight IS NULL
      BEGIN
         SELECT @n_FromWeight = 0
      END
   END
   IF @n_Loc_WeightCapacity < ( @n_ToWeight + @n_FromWeight )
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED Weight Fit: LocWeight = ' + RTRIM(CONVERT(char(20),@n_Loc_WeightCapacity)) + '  ExistingWeight = ' + RTRIM(CONVERT(char(20),@n_ToWeight)) + '  AdditionalWeight = ' + RTRIM(CONVERT(char(20),(@n_FromWeight)))
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
      SELECT @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'PASSED Weight Fit: LocWeight = ' + RTRIM(CONVERT(char(20),@n_Loc_WeightCapacity)) + '  ExistingWeight = ' + RTRIM(CONVERT(char(20),@n_ToWeight)) + '  AdditionalWeight = ' + RTRIM(CONVERT(char(20),(@n_FromWeight)))
         EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
         @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
         @c_ToLoc, @c_Reason
      END
   END
END
IF '4' IN (@cpa_DimensionRestriction01,
@cpa_DimensionRestriction02,
@cpa_DimensionRestriction03,
@cpa_DimensionRestriction04,
@cpa_DimensionRestriction05,
@cpa_DimensionRestriction06)
BEGIN
   SELECT @n_QtylocationLimit = QtyLocationLimit
   FROM SKUxLOC (NOLOCK)
   WHERE StorerKey = @c_StorerKey
   AND SKU = @c_SKU
   AND Locationtype IN ('PICK', 'CASE')
   AND loc = @c_ToLoc
   IF @n_QtylocationLimit IS NOT NULL
   BEGIN
      SELECT @n_ExistingQuantity = SUM((Qty - QtyPicked) + PendingMoveIN)
      FROM LOTxLOCxID (NOLOCK)
      WHERE StorerKey = @c_StorerKey
      AND SKU = @c_SKU
      AND loc = @c_ToLoc
      AND (Qty > 0
      OR  PendingMoveIn > 0)
      IF @n_ExistingQuantity IS NULL
      BEGIN
         SELECT @n_ExistingQuantity = 0
      END
      IF @n_QtylocationLimit < (@n_Qty + @n_ExistingQuantity)
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED Qty Capacity: LocCapacity = ' + RTRIM(CONVERT(char(20),@n_QtylocationLimit)) + '  Required = ' + RTRIM(CONVERT(char(20),(@n_Qty + @n_ExistingQuantity)))
            EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
            @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
            @c_ToLoc, @c_Reason
         END
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Qty Capacity: LocCapacity = ' + RTRIM(CONVERT(char(20),@n_QtylocationLimit)) + '  Required = ' + RTRIM(CONVERT(char(20),(@n_Qty + @n_ExistingQuantity)))
            EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
            @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
            @c_ToLoc, @c_Reason
         END
      END
   END
END
/********************************************************************
Begin - Modified by Teoh To Cater for Height Restriction 30/3/2000
*********************************************************************/
IF '5' IN (@cpa_DimensionRestriction01,
@cpa_DimensionRestriction02,
@cpa_DimensionRestriction03,
@cpa_DimensionRestriction04,
@cpa_DimensionRestriction05,
@cpa_DimensionRestriction06)
BEGIN
   IF ((@n_CaseHeight * @n_PutawayHI) + @n_PalletWoodHeight) > @n_Loc_Height
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED Height Restriction: Loc Height = ' + RTRIM(CONVERT(char(20), @n_Loc_Height)) + '. Pallet Build Height = ' +
         RTRIM(CONVERT(char(20), ((@n_CaseHeight * @n_PutawayHI) + @n_PalletWoodHeight)))
         EXEC nspPTD 'nspASNPASTD'-- SOS# 143046
         , @n_pTraceHeadKey, @c_PutawayStrategyKey,
           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
           @c_ToLoc, @c_Reason
      END
      SELECT @b_RestrictionsPassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'PASSED Height Restriction: Loc Height = ' + RTRIM(CONVERT(char(20), @n_Loc_Height)) + '. Pallet Build Height = ' +
         RTRIM(CONVERT(char(20), ((@n_CaseHeight * @n_PutawayHI) + @n_PalletWoodHeight)))
         EXEC nspPTD 'nspASNPASTD' -- SOS# 143046
         , @n_pTraceHeadKey, @c_PutawayStrategyKey,
           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
           @c_ToLoc, @c_Reason
      END
   END
END
/********************************************************************
End - Modified by Teoh To Cater for Height Restriction 30/3/2000
*********************************************************************/
RESTRICTIONCHECKDONE:
IF @cpa_PAType = '01'
BEGIN
   GOTO PATYPE01
END
IF @cpa_PAType = '03'  
BEGIN  
   GOTO PATYPE03  
END 
IF @cpa_PAType = '02' OR @cpa_PAType = '04' OR @cpa_PAType = '12'
BEGIN
   IF @cpa_LocSearchType = '1'
   BEGIN
      GOTO PATYPE02_BYLOC_A
   END
   ELSE IF @cpa_LocSearchType = '2'
   BEGIN
      GOTO PATYPE02_BYLOGICALLOC
   END
END
IF @cpa_PAType = '04' or
   @cpa_PAType = '16' or -- IDSV5 - Leo - SOS# 3553 - Search Location With the same Sku Within Sku Zone
   @cpa_PAType = '17' or -- SOS36712 KCPI - Search Empty Location Within Sku Zone
   @cpa_PAType = '18' or -- SOS36712 KCPI - Search Location Within Specified Zone
   @cpa_PAType = '19' or -- SOS36712 KCPI - Search Empty Location Within Specified Zone
   @cpa_PAType = '22' or -- Search ZONE specified in sku table for Single Pallet and must be Empty Loc
   @cpa_PAType = '24' or -- Search ZONE specified in this strategy for Single Pallet and must be empty Loc
   @cpa_PAType = '32' or -- Search ZONE specified in sku table for Multi Pallet where unique sku = sku putaway
   @cpa_PAType = '34' or -- Search ZONE specified in this strategy for Multi Pallet where unique sku = sku putaway
   @cpa_PAType = '42' or -- Search ZONE specified in sku table for Empty Multi Pallet Location
   @cpa_PAType = '44' or -- Search ZONE specified in this strategy for empty Multi Pallet location
   -- added for China - Putaaway to location with matching Lottable02 and Lottable04
   @cpa_PAType = '52' or -- Search Zone specified in SKU table for matching Lottable02 and Lottable04
   @cpa_PAType = '54' or
   @cpa_PAType = '55' or -- SOS69388 KFP - Cross facility - search location within specified zone
                         --                with matching Lottable02 and Lottable04 (do not mix sku)
   @cpa_PAType = '56' or -- SOS69388 KFP - Cross facility - search Empty Location base on HostWhCode inventory = 0
   @cpa_PAType = '57' or -- SOS69388 KFP - Cross facility - search suitable location within specified zone (mix with diff sku)
   @cpa_PAType = '58' or -- SOS69388 KFP - Cross facility - search suitable location within specified zone (do not mix sku)
   @cpa_PAType = '59'    -- SOS133180
BEGIN
   IF @cpa_LocSearchType = '1'
   BEGIN
      GOTO PATYPE02_BYLOC_B
   END
   IF @cpa_LocSearchType = '2'
   BEGIN
      GOTO PATYPE02_BYLOGICALLOC
   END
END
IF @cpa_PAType = '06'
BEGIN
   GOTO PATYPE06
END
IF @cpa_PAType = '08'
OR @cpa_PAType = '07'
OR @cpa_PAType = '88' -- CDC Migration
BEGIN
   GOTO PATYPE08
END
IF @cpa_PAType = '09'
BEGIN
   GOTO PATYPE09
END
IF @cpa_PAType = '15'
BEGIN
   GOTO PATYPE15
END
/* Start Add by DLIM for FBR22 20010620 */
IF @cpa_PAType = '20'
BEGIN
   GOTO PATYPE20
END
/* END Add by DLIM for FBR22 20010620 */
IF @cpa_PAType = '60' -- SOS133180
BEGIN
   GOTO PATYPE60
END

LOCATION_EXIT:
   IF @b_GotLoc = 1
   BEGIN
      SELECT @c_Final_ToLoc = @c_ToLoc
      IF @b_debug = 2
      BEGIN
         SELECT 'Final Location is ' + @c_Final_ToLoc
      END
   END
   GOTO LOCATION_DONE

LOCATION_ERROR:
   SELECT @n_err = 99701
   SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': No Location. (nspASNPASTD)'
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012

LOCATION_DONE:
END

GO