SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  nspPASTD                                             */
/* Creation Date: 05-Aug-2002                                             */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  Stored Procedure for RF PUTAWAY                            */
/*                                                                      */
/* Input Parameters:  @c_userid,          - User Id                     */
/*                    @c_storerkey,       - Storerkey                   */
/*                    @c_lot,             - Lot                         */
/*                    @c_sku,             - Sku                         */
/*                    @c_id,              - Id                          */
/*                    @c_fromloc,         - From Location               */
/*                    @n_qty,             - Putaway Qty                 */
/*                    @c_uom,             - UOM unit                    */
/*                    @c_packkey,         - Packkey for sku             */
/*                    @n_putawaycapacity  - Putaway Capacity            */
/*                                                                      */
/* Output Parameters: @c_final_toloc      - Final ToLocation            */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                            */
/*                                                                      */
/* PVCS Version: 1.6                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 05-Jun-2003  Ricky         Branch From 1.0.1.1 - Version 5.1 include */
/*                            the putaway by facility based from the    */
/*                            fromloc or toid                           */
/* 04-Dec-2003  Ricky         Remove an additional EN                   */
/* 09-Jan-2004  Shong         SOS#19030 System suggest to putaway to    */
/*                            Location the On-Hold                      */
/* 18-Aug-2004  Shong         Change RF Putaway same logic as Work      */
/*                            station (ASN) Putaway.                    */
/* 20-Jul-2005  MaryVong      Change RF Putaway same logic as Work      */
/*                            station (ASN) Putaway:                    */
/*                            SOS36712 KCPI PutawayStrategy - Add in    */
/*                            new patype '17','18' and '19'             */
/*                            Note: Changes applied to nspASNPASTD      */
/* 31-Mar-2007  MaryVong      SOS69388 KFP PutawayStrategy - Add in     */
/*                              '55','56','57' and '58'                 */
/*                            Add LocationStateRestriction '6' and '7'  */
/*                            Note: Changes applied to nspASNPASTD      */
/* 31-May-2024  NLT013        UWP-20191 Skip PAType02 if fromLocation <>*/
/*                            pa_FromLoc                                */
/************************************************************************/

CREATE PROCEDURE   nspPASTD
@c_userid           NVARCHAR(18)
,              @c_storerkey        NVARCHAR(15)
,              @c_lot              NVARCHAR(10)
,              @c_sku              NVARCHAR(20)
,              @c_id               NVARCHAR(18)
,              @c_fromloc          NVARCHAR(10)
,              @n_qty              int
,              @c_uom              NVARCHAR(10)
,              @c_packkey          NVARCHAR(10)
,              @n_putawaycapacity  int
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
   DECLARE @c_toloc NVARCHAR(10),
   @c_orderkey NVARCHAR(10),
   @n_idcnt int,
   @b_MultiProductID int,
   @b_MultiLotID int ,
   @c_putawaystrategykey NVARCHAR(10),
   @c_userequipmentprofilekey NVARCHAR(10),
   @b_success int, @n_stdgrosswgt float(8),
   @n_ptraceheadkey NVARCHAR(10),   -- Unique key value for the putaway trace header
   @n_ptracedetailkey NVARCHAR(10), -- part of key value for the putaway trace detail
   @n_locsreviewed int,         -- counter for the number of location reviewed
   @c_reason NVARCHAR(80),          -- putaway trace rejection reason text for putaway trace detail
   @d_startdtim datetime,       -- Start time of this stored procedure
   @n_qtylocationlimit int,      -- Location Qty Capacity for Case/Piece Pick Locations
   @c_Facility NVARCHAR(5), -- CDC Migration
   @n_MaxPallet int,
   @n_PalletQty int,
   @n_StackFactor int,           -- SOS36712 KCPI
   @n_MaxPalletStackFactor int,  -- SOS36712 KCPI
   @c_ToHostWhCode NVARCHAR(10)      -- SOS69388 KFP
      
   SELECT @c_toloc = SPACE(10),
   @n_idcnt = 0,
   @b_MultiProductID = 0,
   @b_MultiLotID = 0,
   @n_locsreviewed = 0,
   @d_startdtim = getdate()
   SET NOCOUNT ON

   /* Added By Vicky 10 Apr 2003 - CDC Migration */
   SELECT  @c_Facility = Facility
   FROM   LOC (NOLOCK)
   WHERE  Loc =  @c_fromloc
   /* END Add */
   
   DECLARE @c_PTraceType NVARCHAR(30)
   SELECT @c_PTraceType = 'nspPASTD'  

   IF @c_sku IS NULL
   BEGIN
      IF @c_lot IS NOT NULL
      BEGIN
         SELECT @c_StorerKey = StorerKey , @c_SKU = SKU FROM LOT (NOLOCK) WHERE LOT = @c_lot
      END
   END
   IF dbo.fnc_LTrim(@c_id) IS NOT NULL
   BEGIN
      SELECT @n_idcnt = COUNT(DISTINCT SKU)
      FROM LOTxLOCxID (NOLOCK)
      WHERE ID = @c_id
      AND LOC = @c_fromloc
      AND QTY > 0
      IF @n_idcnt = 1
      BEGIN
         SELECT @c_StorerKey = StorerKey , @c_SKU = SKU, @n_qty = QTY, @c_lot = LOT
         FROM LOTxLOCxID (NOLOCK)
         WHERE ID = @c_id
         AND LOC = @c_fromloc
         AND QTY > 0
      END
      ELSE
      BEGIN
         IF @n_idcnt > 1
         BEGIN
            SELECT @b_MultiProductID = 1,
            @b_MultiLotID = 1  -- Multiproduct is multilot by definition of lot
         END
      END
      IF @b_MultiLotID = 0
      BEGIN
         SELECT @n_idcnt = COUNT(DISTINCT LOT)
         FROM LOTxLOCxID (NOLOCK)
         WHERE ID = @c_id
         AND LOC = @c_fromloc
         AND QTY > 0
         IF @n_idcnt > 1
         BEGIN
            SELECT @b_MultiLotID = 1
         END
      END
      IF  @b_MultiLotID = 0 AND @c_lot IS NULL
      BEGIN
         SELECT @c_lot = LOT
         FROM LOTxLOCxID (NOLOCK)
         WHERE ID = @c_id
         AND LOC = @c_fromloc
         AND QTY > 0
      END
   END
   
   EXEC nspGetPack @c_StorerKey,
   @c_sku,
   @c_lot,
   @c_fromloc,
   @c_id,
   @c_packkey OUTPUT,
   @b_success OUTPUT,
   @n_err OUTPUT,
   @c_errmsg OUTPUT
   IF @b_success = 0
   BEGIN
      SELECT @c_toloc = ''
      GOTO LOCATION_ERROR
   END
   
   IF @b_MultiProductID = 0
   BEGIN
      SELECT @c_putawaystrategykey = STRATEGY.PutAwayStrategyKey,
      @n_stdgrosswgt = SKU.StdGrossWgt
      FROM STRATEGY (NOLOCK), SKU (NOLOCK)
      WHERE SKU.StorerKey = @c_StorerKey
      AND SKU.SKU = @c_sku
      AND SKU.STRATEGYKEY = STRATEGY.Strategykey
   END
   ELSE
   BEGIN
      SELECT @c_putawaystrategykey = Strategy.Putawaystrategykey
      FROM STRATEGY (NOLOCK)
      WHERE STRATEGYKEY = 'SYSTEM'
   END
   IF dbo.fnc_LTrim(@c_id) IS NOT NULL
      AND @n_qty = 0
      AND @b_MultiProductID = 0
   BEGIN
      SELECT @n_qty = qty
      FROM ID (NOLOCK)
      WHERE ID = @c_id
   END     
   
   SELECT @b_debug = CONVERT(int,NSQLValue)
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
      @c_sku, @c_lot, @c_id, @c_packkey, @n_qty,
      @b_MultiProductID, @b_MultiLotID,

      @d_startdtim, NULL, 0, NULL, @n_ptraceheadkey OUTPUT
   END
   DECLARE
   @c_putawaystrategylinenumber        NVARCHAR(5)   ,
   @b_restrictionspassed               int ,
   @b_gotloc                           int ,
   @cpa_PAType                         NVARCHAR(5)   ,
   @cpa_FROMLOC                        NVARCHAR(10)  ,
   @cpa_TOLOC                          NVARCHAR(10)  ,
   @cpa_AreaKey                        NVARCHAR(10)  ,
   @cpa_Zone                           NVARCHAR(10)  ,
   @cpa_LocType                        NVARCHAR(10)  ,
   @cpa_LocSearchType   NVARCHAR(10)  ,
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
   @cpa_FitFullReceipt                 NVARCHAR(5)   ,
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
   DECLARE @c_loc_type NVARCHAR(10), @c_loc_zone NVARCHAR(10),
   @c_loc_category NVARCHAR(10), @c_loc_flag NVARCHAR(10),
   @c_loc_handling NVARCHAR(10),
   @n_loc_width float, @n_loc_length float, @n_loc_height float,
   @n_loc_cubiccapacity float, @n_loc_weightcapacity float,
   @c_movableunittype NVARCHAR(10), -- 1=pallet,2=case,3=innerpack,4=other1,5=other2,6=piece
   @c_loc_comminglesku NVARCHAR(1),
   @c_loc_comminglelot NVARCHAR(1),
   @n_fromcube float,   -- the cube of the product/id being putaway
   @n_tocube float,     -- the cube of existing product in the candidate location
   @n_fromweight float, -- the weight of the product/id being putaway
   @n_toweight float,   -- the weight of existing product in the candidate location
   @n_palletwoodwidth float, -- the width of the pallet wood being putaway
   @n_palletwoodlength float, -- the length of the pallet wood being putaway
   @n_palletwoodheight float,  -- the height of the pallet wood being putaway
   @n_palletheight float,  -- the height of the pallet wood being putaway
   @n_casewidth float, -- the width of the cases on the  pallet being putaway
   @n_caselength float, -- the length of the cases on the  pallet being putaway
   @n_caseheight float,  -- the height of the cases on the pallet being putaway
   @n_existingheight float, -- the height of any existing product in a candidate location
   @n_existingquantity integer, -- the quantity of any existing product in a candidate location
   @n_QuantityCapacity integer, -- the quantity based on cube which could fit in candidate location
   @n_packcasecount integer,    -- the number of pieces in a case for the pack
   @n_UOMcapacity integer,      -- the number of a UOM cubic capacity which fits inside a cube
   @n_putawayti integer,        -- the number of cases on a pallet layer/tier
   @n_putawayhi integer,        -- the number of layers/tiers on a pallet
   @n_toqty integer,            -- Variable to hold quantity already in a location
   @n_existinglayers integer,   -- number of layers/tiers indicator
   @n_extralayer integer,       -- a partial layer/tier indicator
   @n_CubeUOM1 float,           -- volumetric cube of UOM1
   @n_QtyUOM1 integer,          -- number of eaches in UOM1
   @n_CubeUOM3 float,           -- volumetric cube of UOM2
   @n_QtyUOM3 integer,          -- number of eaches in UOM2
   @n_CubeUOM4 float,           -- volumetric cube of UOM4
   @n_QtyUOM4 integer,          -- number of eaches in UOM4
   @c_searchzone NVARCHAR(10),
   @c_searchlogicalloc NVARCHAR(18),
   @n_currlocmultisku int,      -- Current Location/Putaway Pallet is Commingled Sku
   @n_currlocmultilot int       -- Current Location/Putaway Pallet is Commingled Lot
   -- For Checking Maximum Pallet
   -- Added by DLIM September 2001
   DECLARE @n_PendingPalletQty int, @n_TtlPalletQty int
   -- END Add by DLIM

   SELECT @c_putawaystrategylinenumber = Space(5),
      @b_gotloc = 0
   WHILE (1=1)
   BEGIN
      SET ROWCOUNT 1
      SELECT @c_putawaystrategylinenumber    =  putawaystrategylinenumber     ,
      @cpa_PAType                     =  PAType                        ,
      @cpa_FROMLOC                    =  FROMLOC                       ,
      @cpa_TOLOC                      =  TOLOC                         ,
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
      @cpa_CheckRestrictions          =  CheckRestrictions
      FROM PUTAWAYSTRATEGYDETAIL (NOLOCK)
      WHERE PutAwayStrategyKey=@c_putawaystrategykey
      AND putawaystrategylinenumber>@c_putawaystrategylinenumber
      ORDER BY putawaystrategylinenumber
      IF @@ROWCOUNT = 0
      BEGIN
         SET ROWCOUNT 0
         BREAK
      END

      SET @c_searchzone = ''
      SET ROWCOUNT 0
      IF @b_debug = 1
      BEGIN
         -- Insert records into PTRACEDETAIL table
         SELECT @c_reason = 'CHANGE of Putaway Type to ' + @cpa_PAType
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         '', @c_reason
      END

      IF @b_debug = 2
      BEGIN
         SELECT 'putawaystrategykey is ' + @c_putawaystrategykey
      END

      IF @cpa_PAType = '01'
      BEGIN
         IF @c_fromloc = @cpa_fromloc
         BEGIN
            IF dbo.fnc_LTrim(@cpa_toloc) IS NOT NULL
            BEGIN
               SELECT @c_toloc = @cpa_toloc

               IF @cpa_checkrestrictions = 'Y'
               BEGIN
                  SELECT @b_restrictionspassed = 0
                  GOTO PA_CHECKRESTRICTIONS

                  PATYPE01:
                  IF @b_restrictionspassed = 1
                  BEGIN
                     SELECT @b_gotloc = 1
                     IF @b_debug = 1
                     BEGIN
                        SELECT @c_reason = 'FOUND PAType=01: from location ' + dbo.fnc_RTrim(@c_fromloc) + ' <> ' + dbo.fnc_RTrim(@cpa_fromloc)
                        EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
                        @c_putawaystrategylinenumber, @n_ptracedetailkey,
                        @c_toloc, @c_reason
                     END
                     BREAK
                  END
               END
               ELSE
               BEGIN
                  SELECT @b_gotloc = 1
                  IF @b_debug = 1
                  BEGIN
                     SELECT @c_reason = 'FOUND PAType=01: from location ' + dbo.fnc_RTrim(@c_fromloc) + ' <> ' + dbo.fnc_RTrim(@cpa_fromloc)
                     EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
                     @c_putawaystrategylinenumber, @n_ptracedetailkey,
                     @c_toloc, @c_reason
                  END
                  BREAK
               END
            END
         END
         ELSE
         BEGIN
            IF @b_debug = 1
            BEGIN
               SELECT @c_reason = 'FAILED PAType=01: from location ' + dbo.fnc_RTrim(@c_fromloc) + ' <> ' + dbo.fnc_RTrim(@cpa_fromloc)
               EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
               @c_putawaystrategylinenumber, @n_ptracedetailkey,
               @c_toloc, @c_reason
            END
         END
         CONTINUE
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
         @cpa_PAType = '54' or
         @cpa_PAType = '55' or -- SOS69388 KFP - Cross facility - search location within specified zone 
                                --                  with matching Lottable02 and Lottable04 (do not mix sku)
         @cpa_PAType = '56' or -- SOS69388 KFP - Cross facility - search Empty Location base on HostWhCode inventory = 0
         @cpa_PAType = '57' or -- SOS69388 KFP - Cross facility - search suitable location within specified zone (mix with diff sku)
         @cpa_PAType = '58'    -- SOS69388 KFP - Cross facility - search suitable location within specified zone (do not mix sku)
      BEGIN
         IF @cpa_PAType = '02' or
            @cpa_PAType = '55' or -- SOS69388 KFP - Cross facility - search location within specified zone 
                                   --                  with matching Lottable02 and Lottable04 (do not mix sku)
            @cpa_PAType = '56' or -- SOS69388 KFP - Cross facility - search Empty Location base on HostWhCode inventory = 0
            @cpa_PAType = '57' or -- SOS69388 KFP - Cross facility - search suitable location within specified zone (mix with diff sku)
            @cpa_PAType = '58'    -- SOS69388 KFP - Cross facility - search suitable location within specified zone (do not mix sku)
         BEGIN
            IF @cpa_PAType = '02' --If PA_FromLoc does not equal to current location, need go to next strategy
            BEGIN
               IF ISNULL(@cpa_fromloc, '') <> @c_fromloc
               BEGIN
                  IF @b_Debug = 1
                  BEGIN
                     SELECT @c_reason = 'FAILED PAType=' + dbo.fnc_RTrim(@cpa_PAType) + ': ' 
                                    + 'FROM location '
                                    + RTRIM(@c_FromLoc) + ' <> ' + RTRIM(@cpa_FromLoc)
                     EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
                     @c_putawaystrategylinenumber, @n_ptracedetailkey,
                     @c_toloc, @c_reason
                  END
                  CONTINUE;
               END
            END

            IF @c_fromloc = @cpa_fromloc
            BEGIN
               SELECT @c_searchzone = @cpa_zone
            END
         END
         IF @cpa_PAType = '04' or
            @cpa_PAType = '18' or -- SOS36712 KCPI - Search Location Within Specified Zone
            @cpa_PAType = '19' or -- SOS36712 KCPI - Search Empty Location Within Specified Zone
            @cpa_PAType = '24' or
            @cpa_PAType = '34' or
            @cpa_PAType = '44' or
            @cpa_PAType = '54'
         BEGIN
            SELECT @c_searchzone = @cpa_zone
         END
         IF @cpa_PAType = '12' or
            @cpa_PAType = '16' or -- IDSV5 - Leo - SOS# 3553 - Search Location With the same Sku Within Sku Zone
            @cpa_PAType = '17' or -- SOS36712 KCPI - Search Empty Location Within Sku Zone
            @cpa_PAType = '22' or
            @cpa_PAType = '32' or
            @cpa_PAType = '42' or
            @cpa_PAType = '52'
         BEGIN
            IF dbo.fnc_LTrim(@c_sku) IS NOT NULL
               AND NOT (@b_MultiProductID = 1 or @b_MultiLotID = 1)
            BEGIN
               SELECT @c_searchzone = Putawayzone
               FROM SKU (NOLOCK)
               WHERE StorerKey = @c_StorerKey
               AND SKU = @c_sku
            END
            ELSE
            BEGIN
               IF @b_debug = 1
               BEGIN
                  SELECT @c_reason = 'FAILED PAType=' + dbo.fnc_RTrim(@cpa_PAType) + ': Commodity and Storer combination not found'
                  EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
                  @c_putawaystrategylinenumber, @n_ptracedetailkey,
                  @c_toloc, @c_reason
               END
               CONTINUE -- This search does not apply because there is no sku
            END
         END

         -- Chekcing
         IF @b_debug = 2
         BEGIN
            SELECT 'PAType is ' + @cpa_PAType + ', SearchZone is ' + @c_searchzone
         END

         IF dbo.fnc_LTrim(@c_searchzone) IS NOT NULL
         BEGIN
            IF @cpa_LocSearchType = '1' -- Search Zone By Location Code
            BEGIN
               IF @cpa_PAType = '02' or -- IF source is FROMLOC then move to a location within the specified zone
                  @cpa_PAType = '04' or -- Search ZONE specified on this strategy record
                  @cpa_PAType = '12'
               BEGIN
                  DECLARE @n_StdCube float
                  DECLARE @c_SelectSQL nvarchar(4000)
                  DECLARE @c_LocFlagRestriction nvarchar(1000)
                  DECLARE @c_LocTypeRestriction nvarchar(1000)
                  DECLARE @n_NoOfInclude int
                  DECLARE @c_DimRestSQL nvarchar(3000)

                  SELECT @n_StdCube =  Sku.StdCube, @n_StdGrossWgt = Sku.StdGrossWgt
                  FROM SKU (NOLOCK)
                  WHERE SKU.StorerKey = @c_StorerKey
                  AND SKU.SKU = @c_SKU

                  -- Build Location Flag Restriction SQL
                  SELECT @n_NoOfInclude = 0
                  SELECT @c_LocFlagRestriction = ''
                  IF dbo.fnc_LTrim(@cpa_LocationFlagInclude01) IS NOT NULL
                  BEGIN
                     SELECT @n_NoOfInclude = @n_NoOfInclude + 1
                     SELECT @c_LocFlagRestriction = dbo.fnc_RTrim(@c_LocFlagRestriction) + 'N''' + dbo.fnc_RTrim(@cpa_LocationFlagInclude01) + ''''
                     SELECT @cpa_LocationFlagInclude01 = ''
                  END
                  IF dbo.fnc_LTrim(@cpa_LocationFlagInclude02) IS NOT NULL
                  BEGIN
                     IF @n_NoOfInclude > 0
                     SELECT @c_LocFlagRestriction = dbo.fnc_RTrim(@c_LocFlagRestriction) + ','
                     SELECT @n_NoOfInclude = @n_NoOfInclude + 1
                     SELECT @c_LocFlagRestriction = dbo.fnc_RTrim(@c_LocFlagRestriction) + 'N''' + dbo.fnc_RTrim(@cpa_LocationFlagInclude02) + ''''
                     SELECT @cpa_LocationFlagInclude02 = ''
                  END
                  IF dbo.fnc_LTrim(@cpa_LocationFlagInclude03) IS NOT NULL
                  BEGIN
                     IF @n_NoOfInclude > 0
                     SELECT @c_LocFlagRestriction = dbo.fnc_RTrim(@c_LocFlagRestriction) + ','

                     SELECT @n_NoOfInclude = @n_NoOfInclude + 1
                     SELECT @c_LocFlagRestriction = dbo.fnc_RTrim(@c_LocFlagRestriction) + 'N''' + dbo.fnc_RTrim(@cpa_LocationFlagInclude03) + ''''
                     SELECT @cpa_LocationFlagInclude03 = ''
                  END

                  IF @n_NoOfInclude = 1
                     SELECT @c_LocFlagRestriction = 'AND LOC.LocationFlag = ' + dbo.fnc_RTrim(@c_LocFlagRestriction)
                  ELSE IF @n_NoOfInclude > 1
                     SELECT @c_LocFlagRestriction = 'AND LOC.LocationFlag IN (' + dbo.fnc_RTrim(@c_LocFlagRestriction) + ') '
                  ELSE
                     SELECT @c_LocFlagRestriction = ''
                  -- END Build Location Flag

                  -- BEGIN Build Location Type Restriction
                  SELECT @n_NoOfInclude = 0
                  SELECT @c_LocTypeRestriction = ''
                  IF dbo.fnc_LTrim(@cpa_LocationTypeExclude01) IS NOT NULL
                  BEGIN
                     SELECT @n_NoOfInclude = @n_NoOfInclude + 1
                     SELECT @c_LocTypeRestriction = dbo.fnc_RTrim(@c_LocTypeRestriction) + 'N''' + dbo.fnc_RTrim(@cpa_LocationTypeExclude01) + ''''
                     SELECT @cpa_LocationTypeExclude01 = ''
                  END
                  IF dbo.fnc_LTrim(@cpa_LocationTypeExclude02) IS NOT NULL
                  BEGIN
                     IF @n_NoOfInclude > 0
                     SELECT @c_LocTypeRestriction = dbo.fnc_RTrim(@c_LocTypeRestriction) + ','
                     SELECT @n_NoOfInclude = @n_NoOfInclude + 1
                     SELECT @c_LocTypeRestriction = dbo.fnc_RTrim(@c_LocTypeRestriction) + 'N''' + dbo.fnc_RTrim(@cpa_LocationTypeExclude02) + ''''
                     SELECT @cpa_LocationTypeExclude02 = ''
                  END
                  IF dbo.fnc_LTrim(@cpa_LocationTypeExclude03) IS NOT NULL
                  BEGIN
                     IF @n_NoOfInclude > 0
                     SELECT @c_LocTypeRestriction = dbo.fnc_RTrim(@c_LocTypeRestriction) + ','
                     SELECT @n_NoOfInclude = @n_NoOfInclude + 1
                     SELECT @c_LocTypeRestriction = dbo.fnc_RTrim(@c_LocTypeRestriction) + 'N''' + dbo.fnc_RTrim(@cpa_LocationTypeExclude03) + ''''
                     SELECT @cpa_LocationTypeExclude03 = ''
                  END
                  IF dbo.fnc_LTrim(@cpa_LocationTypeExclude04) IS NOT NULL
                  BEGIN
                     IF @n_NoOfInclude > 0
                     SELECT @c_LocTypeRestriction = dbo.fnc_RTrim(@c_LocTypeRestriction) + ','
                     SELECT @n_NoOfInclude = @n_NoOfInclude + 1
                  SELECT @c_LocTypeRestriction = dbo.fnc_RTrim(@c_LocTypeRestriction) + 'N''' + dbo.fnc_RTrim(@cpa_LocationTypeExclude04) + ''''
                     SELECT @cpa_LocationTypeExclude04 = ''
                  END
                  IF dbo.fnc_LTrim(@cpa_LocationTypeExclude05) IS NOT NULL
                  BEGIN
                     IF @n_NoOfInclude > 0
                     SELECT @c_LocTypeRestriction = dbo.fnc_RTrim(@c_LocTypeRestriction) + ','
                     SELECT @n_NoOfInclude = @n_NoOfInclude + 1
                     SELECT @c_LocTypeRestriction = dbo.fnc_RTrim(@c_LocTypeRestriction) + 'N''' + dbo.fnc_RTrim(@cpa_LocationTypeExclude05) + ''''
                     SELECT @cpa_LocationTypeExclude05 = ''
                  END

                  IF @n_NoOfInclude = 1
                     SELECT @c_LocTypeRestriction = 'AND LOC.LOCATIONTYPE <> ' + dbo.fnc_RTrim(@c_LocTypeRestriction)
                  ELSE IF @n_NoOfInclude > 1
                     SELECT @c_LocTypeRestriction = 'AND LOC.LOCATIONTYPE NOT IN (' + dbo.fnc_RTrim(@c_LocTypeRestriction) + ') '
                  ELSE
                     SELECT @c_LocTypeRestriction = ''

                  -- END Build Location Type

                  IF '1' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
                  BEGIN -- loc must be empty
                     SELECT @c_SelectSQL =
                     ' SET ROWCOUNT 1 ' + master.dbo.fnc_GetCharASCII(13) + 
                     ' SELECT @c_Loc = LOC.LOC ' +
                     ' FROM  LOC (NOLOCK) LEFT OUTER JOIN LOTxLOCxID (NOLOCK) ON ( LOC.loc = LOTxLOCxID.LOC ) ' +
                     ' WHERE LOC.Putawayzone = N''' + dbo.fnc_RTrim(@c_searchzone) + ''' ' + 
                     ' AND   LOC.Facility = N''' + dbo.fnc_RTrim(@c_Facility) + ''' ' + 
                     ' AND   LOC.LOC > @c_LastLoc ' +
                     dbo.fnc_RTrim(@c_LocFlagRestriction) +
                     dbo.fnc_RTrim(@c_LocTypeRestriction) +
                     ' GROUP BY LOC.LOC ' +
                     ' HAVING (SUM(LOTxLOCxID.Qty) = 0 OR SUM(LOTxLOCxID.Qty) is null) ' +
                     ' AND (SUM(LOTxLOCxID.PendingMoveIn) = 0 OR SUM(LOTxLOCxID.PendingMoveIn) is null) ' +
                     ' ORDER BY LOC.LOC ' + ' SET ROWCOUNT 0 '
      
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
                     ' SET ROWCOUNT 1 ' + master.dbo.fnc_GetCharASCII(13) + 
                     ' SELECT @c_Loc = LOC.LOC ' +
                     ' FROM LOC (NOLOCK) LEFT OUTER JOIN LOTxLOCxID (NOLOCK) ON ( LOC.loc = LOTxLOCxID.LOC ) ' +
                     ' WHERE LOC.Putawayzone = N''' + dbo.fnc_RTrim(@c_searchzone) + ''' ' + 
                     ' AND   LOC.LOC > @c_LastLoc ' +
                     dbo.fnc_RTrim(@c_LocFlagRestriction) +
                     ' AND  LOC.Facility = N''' + dbo.fnc_RTrim(@c_Facility) + ''' ' + 
                     ' AND (LOTxLOCxID.LOT = N''' + dbo.fnc_RTrim(@c_lot) + ''''  + 
                     ' OR LOTxLOCxID.Lot IS NULL) ' + 
                     ' GROUP BY LOC.LOC ' 
         
                     -- Fit by Cube
                     IF '1' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                     @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        IF dbo.fnc_RTrim(@c_DimRestSQL) IS NULL OR dbo.fnc_RTrim(@c_DimRestSQL) = ''
                        SELECT @c_DimRestSQL = ' HAVING '
                     ELSE
                        SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' AND '
         
                        -- SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' MAX(LOC.Cube) - ' +
                        SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' MAX(LOC.CubicCapacity) - ' +
                        '( ( SUM(ISNULL(LOTxLOCxID.Qty, 0)) - SUM(ISNULL(LOTxLOCxID.QtyPicked,0)) + SUM(ISNULL(LOTxLOCxID.PendingMoveIn,0))) ' +
                        '* ' + dbo.fnc_RTrim(CAST(@n_StdCube as NVARCHAR(20))) + ') >= (' + dbo.fnc_RTrim(CAST(@n_StdCube as NVARCHAR(20))) + ' * ' + dbo.fnc_RTrim(CAST(@n_Qty as NVARCHAR(10))) + ')'
                     END
         
                     -- Fit by Weight
                     IF '3' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                     @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        IF dbo.fnc_RTrim(@c_DimRestSQL) IS NULL OR dbo.fnc_RTrim(@c_DimRestSQL) = ''
                        SELECT @c_DimRestSQL = ' HAVING '
                     ELSE
                        SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' AND '
         
                        -- SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' MAX(LOC.Cube) - ' +
                        SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' MAX(LOC.WeightCapacity) - ' +
                        '( ( SUM(ISNULL(LOTxLOCxID.Qty, 0)) - SUM(ISNULL(LOTxLOCxID.QtyPicked,0)) + SUM(ISNULL(LOTxLOCxID.PendingMoveIn,0))) ' +
                        '* ' + dbo.fnc_RTrim(CAST(@n_StdGrossWgt as NVARCHAR(20))) + ') >= (' + dbo.fnc_RTrim(CAST(@n_StdGrossWgt as NVARCHAR(20))) + ' * ' + dbo.fnc_RTrim(CAST(@n_Qty as NVARCHAR(10))) + ')'
                     END
         
                     SELECT @c_SelectSQL = dbo.fnc_RTrim(@c_SelectSQL) + @c_DimRestSQL + 
                     ' ORDER BY LOC.LOC ' + ' SET ROWCOUNT 0 '

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
                     ' SET ROWCOUNT 1 ' + master.dbo.fnc_GetCharASCII(13) + 
                     ' SELECT @c_Loc = LOC.LOC ' +
                     ' FROM LOC (NOLOCK) LEFT OUTER JOIN LOTxLOCxID (NOLOCK) ON ( LOC.loc = LOTxLOCxID.LOC ) ' +
                     ' WHERE LOC.Putawayzone = N''' + dbo.fnc_RTrim(@c_searchzone) + ''' ' + 
                     ' AND   LOC.LOC > @c_LastLoc ' +
                     dbo.fnc_RTrim(@c_LocFlagRestriction) +
                     dbo.fnc_RTrim(@c_LocTypeRestriction) +
                     ' AND  LOC.Facility = N''' + dbo.fnc_RTrim(@c_Facility) + ''' ' + 
                     ' AND (LOTxLOCxID.StorerKey = N''' + dbo.fnc_RTrim(@c_StorerKey) + '''  OR LOTxLOCxID.StorerKey IS NULL) ' + 
                     ' AND (LOTxLOCxID.sku = N''' + dbo.fnc_RTrim(@c_sku) + ''' OR LOTxLOCxID.sku is null) ' + 
                     ' GROUP BY LOC.LOC ' 
                  
                     -- Fit by Cube
                     IF '1' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                     @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        IF dbo.fnc_RTrim(@c_DimRestSQL) IS NULL OR dbo.fnc_RTrim(@c_DimRestSQL) = ''
                        SELECT @c_DimRestSQL = ' HAVING '
                     ELSE
                        SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' AND '
                  
                        -- SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' MAX(LOC.Cube) - ' +
                        SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' MAX(LOC.CubicCapacity) - ' +
                        '( ( SUM(ISNULL(LOTxLOCxID.Qty, 0)) - SUM(ISNULL(LOTxLOCxID.QtyPicked,0)) + SUM(ISNULL(LOTxLOCxID.PendingMoveIn,0))) ' +
                        '* ' + dbo.fnc_RTrim(CAST(@n_StdCube as NVARCHAR(20))) + ') >= (' + dbo.fnc_RTrim(CAST(@n_StdCube as NVARCHAR(20))) + ' * ' + dbo.fnc_RTrim(CAST(@n_Qty as NVARCHAR(10))) + ')'
                     END
                  
                     -- Fit by Weight
                     IF '3' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                     @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        IF dbo.fnc_RTrim(@c_DimRestSQL) IS NULL OR dbo.fnc_RTrim(@c_DimRestSQL) = ''
                        SELECT @c_DimRestSQL = ' HAVING '
                     ELSE
                        SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' AND '
                  
                        SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' MAX(LOC.WeightCapacity) - ' +
                        '( ( SUM(ISNULL(LOTxLOCxID.Qty, 0)) - SUM(ISNULL(LOTxLOCxID.QtyPicked,0)) + SUM(ISNULL(LOTxLOCxID.PendingMoveIn,0))) ' +
                        '* ' + dbo.fnc_RTrim(CAST(@n_StdGrossWgt as NVARCHAR(20))) + ') >= (' + dbo.fnc_RTrim(CAST(@n_StdGrossWgt as NVARCHAR(20))) + ' * ' + dbo.fnc_RTrim(CAST(@n_Qty as NVARCHAR(10))) + ')'
                     END
                  
                     SELECT @c_SelectSQL = dbo.fnc_RTrim(@c_SelectSQL) + @c_DimRestSQL +
                     ' ORDER BY LOC.LOC ' + ' SET ROWCOUNT 0 ' 

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
                     ' SET ROWCOUNT 1 ' + master.dbo.fnc_GetCharASCII(13) + 
                     ' SELECT @c_Loc = LOC.LOC ' +
                     ' FROM LOC (NOLOCK)  ' +
                     ' LEFT OUTER JOIN LOTxLOCxID (NOLOCK) ON ( LOC.loc = LOTxLOCxID.LOC ) ' +
                     ' LEFT OUTER JOIN SKU (NOLOCK) ON (SKU.StorerKey = LOTxLOCxID.StorerKey AND SKU.SKU = LOTxLOCxID.SKU) ' +
                     ' WHERE LOC.Putawayzone = N''' + dbo.fnc_RTrim(@c_searchzone) + ''' ' + 
                     ' AND   LOC.LOC > @c_LastLoc ' +
                     dbo.fnc_RTrim(@c_LocFlagRestriction) +
                     dbo.fnc_RTrim(@c_LocTypeRestriction) +
                     ' AND  LOC.Facility = N''' + dbo.fnc_RTrim(@c_Facility) + ''' ' + 
                     ' GROUP BY LOC.LOC '

                     -- Fit by Cube
                     IF '1' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                                @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        IF dbo.fnc_RTrim(@c_DimRestSQL) IS NULL OR dbo.fnc_RTrim(@c_DimRestSQL) = ''
                        SELECT @c_DimRestSQL = ' HAVING '
                     ELSE
                        SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' AND '
               
                        -- SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + 'MAX(LOC.Cube) - ' +
                        SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' MAX(LOC.CubicCapacity) - ' +
                        '( SUM(( ISNULL(LOTxLOCxID.Qty, 0) - ISNULL(LOTxLOCxID.QtyPicked,0) + ISNULL(LOTxLOCxID.PendingMoveIn,0) ) ' +
                        ' * ISNULL(SKU.StdCube,0) )) >= (' + dbo.fnc_RTrim(CAST(@n_StdCube as NVARCHAR(20))) + ' * ' + dbo.fnc_RTrim(CAST(@n_Qty as NVARCHAR(10))) + ')'
                     END
                  
                     -- Fit by Weight
                     IF '3' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                     @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        IF dbo.fnc_RTrim(@c_DimRestSQL) IS NULL OR dbo.fnc_RTrim(@c_DimRestSQL) = ''
                        SELECT @c_DimRestSQL = ' HAVING '
                     ELSE
                        SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' AND '
               
                        SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' MAX(LOC.WeightCapacity)  - ' +
                        ' ( SUM(( ISNULL(LOTxLOCxID.Qty, 0) - ISNULL(LOTxLOCxID.QtyPicked,0) + ISNULL(LOTxLOCxID.PendingMoveIn,0) ) ' +
                        ' * ISNULL(SKU.StdGrossWgt,0) )) >= (' + dbo.fnc_RTrim(CAST(@n_StdGrossWgt as NVARCHAR(20))) + ' * ' + dbo.fnc_RTrim(CAST(@n_Qty as NVARCHAR(10))) + ')'
                     END
                  
                     SELECT @c_SelectSQL = dbo.fnc_RTrim(@c_SelectSQL) + @c_DimRestSQL +
                           ' ORDER BY LOC.LOC ' + ' SET ROWCOUNT 0 ' 

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

                  SELECT @c_toloc = SPACE(10)
                  SELECT @cpa_toloc = SPACE(10)
                  
                  WHILE (1=1)
                  BEGIN
                     SELECT @c_toloc = '' 

                     EXEC sp_executesql @c_SelectSQL, N'@c_LastLoc NVARCHAR(10), @c_Loc NVARCHAR(10) output', @cpa_toloc, @c_toloc output

                     if @b_debug = 2 
                     begin
                        print @c_SelectSQL
                        select @cpa_toloc 'Last Loc', @c_toloc
                     end 

                     IF dbo.fnc_RTrim(@c_toloc) IS NULL OR dbo.fnc_RTrim(@c_toloc) = ''
                        BREAK

                     IF @cpa_toloc = @c_toloc 
                        BREAK

                     SELECT @cpa_toloc = @c_toloc                      
                     SELECT @n_locsreviewed = @n_locsreviewed + 1
                  
                     IF @cpa_checkrestrictions = 'Y'
                     BEGIN
                        SELECT @b_restrictionspassed = 0
                        GOTO PA_CHECKRESTRICTIONS
                        PATYPE02_BYLOC_A:

                        IF @b_restrictionspassed = 1
                        BEGIN
                           SELECT @b_gotloc = 1
                           BREAK
                        END
                     END
                     ELSE
                     BEGIN
                        SELECT @b_gotloc = 1
                        BREAK
                     END
                    END -- WHILE (1=1)

                  IF @b_gotloc = 1
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        SELECT @c_reason = 'FOUND PAType=' + @cpa_PAType + ': Search Type by Location'
                        EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
                        @c_putawaystrategylinenumber, @n_ptracedetailkey,
                        @c_toloc, @c_reason
                     END
                  
                     BREAK 
                  END
               END -- END of PAType = 02, 04 and 12
               ELSE IF @cpa_PAType IN ('16', '17', '18', '19', '22', '24', '32', '34', '42', '44', '52', '54',
                                       '55', '56', '57', '58')
               BEGIN
                  SELECT @cpa_toloc = SPACE(10)
                  WHILE (1=1)
                  BEGIN
                     SELECT @n_RowCount = 0
                     IF @cpa_PAType = '16' or @cpa_PAType = '18'
                     BEGIN
                        SELECT @c_SelectSQL = 'SET ROWCOUNT 1 ' + 
                        ' SELECT @cpa_toloc = LOTxLOCxID.loc, ' +
                        ' @c_toloc = LOTxLOCxID.loc ' +
                        ' FROM LOTxLOCxID (NOLOCK) ' +
                        ' JOIN LOC (NOLOCK) on LOTxLOCxID.loc = loc.loc ' +
                        ' WHERE Qty > 0 ' +
                        ' AND LOTxLOCxID.loc > @cpa_toloc ' +
                        ' AND putawayzone = N''' + dbo.fnc_RTrim(@c_searchzone) + ''' ' + 
                        ' AND sku = N''' + dbo.fnc_RTrim(@c_sku) + ''' ' + 
                        ' AND StorerKey = N''' + dbo.fnc_RTrim(@c_StorerKey) + ''' ' + 
                        ' AND loc.Facility = N''' + dbo.fnc_RTrim(@c_Facility) + ''' ' +
                        CASE WHEN LEN(@cpa_LocationCategoryExclude01) > 0 OR 
                                  LEN(@cpa_LocationCategoryExclude02) > 0 OR
                                  LEN(@cpa_LocationCategoryExclude03) > 0 THEN 
                                  'AND LOC.LocationCategory NOT IN (' 
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationCategoryexclude01) > 0 THEN
                                  'N''' + dbo.fnc_RTrim(@cpa_LocationCategoryexclude01) + '''' 
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationCategoryexclude02) > 0 THEN
                                  ',N''' + dbo.fnc_RTrim(@cpa_LocationCategoryexclude02) + '''' 
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationCategoryexclude03) > 0 THEN
                                  ',N''' + dbo.fnc_RTrim(@cpa_LocationCategoryexclude03) + '''' 
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
                                  'N''' + dbo.fnc_RTrim(@cpa_LocationCategoryInclude01) + '''' 
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationCategoryInclude02) > 0 THEN
                                  ',N''' + dbo.fnc_RTrim(@cpa_LocationCategoryInclude02) + '''' 
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationCategoryInclude03) > 0 THEN
                                  ',N''' + dbo.fnc_RTrim(@cpa_LocationCategoryInclude03) + '''' 
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
                                  'N''' + dbo.fnc_RTrim(@cpa_LocationFlagInclude01) + '''' 
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationFlagInclude02) > 0 THEN
                                  ',N''' + dbo.fnc_RTrim(@cpa_LocationFlagInclude02) + '''' 
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationFlagInclude03) > 0 THEN
                                  ',N''' + dbo.fnc_RTrim(@cpa_LocationFlagInclude03) + '''' 
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
                                  'N''' + dbo.fnc_RTrim(@cpa_LocationFlagExclude01) + '''' 
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationFlagExclude02) > 0 THEN
                                  ',N''' + dbo.fnc_RTrim(@cpa_LocationFlagExclude02) + '''' 
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationFlagExclude03) > 0 THEN
                                  ',N''' + dbo.fnc_RTrim(@cpa_LocationFlagExclude03) + '''' 
                             ELSE ''
                        END +
                        CASE WHEN LEN(@cpa_LocationFlagExclude01) > 0 OR 
                                  LEN(@cpa_LocationFlagExclude02) > 0 OR
                                  LEN(@cpa_LocationFlagExclude03) > 0 THEN 
                                  ')' 
                             ELSE ''
                        END + 
                        ' ORDER BY LOTxLOCxID.LOC ' + 
                        ' SELECT @n_RowCount = @@ROWCOUNT '

                        if @b_debug = 2
                           print @c_SelectSQL

                        EXEC sp_executesql @c_SelectSQL, 
                             N'@cpa_toloc NVARCHAR(10) output, @c_toloc NVARCHAR(10) output, @n_RowCount int output', 
                             @cpa_toloc output, @c_toloc output, @n_RowCount Output 

                        -- Chekcing
                        IF @b_debug = 2
                        BEGIN
                           SELECT 'Storerkey is ' + @c_Storerkey + ', Sku is ' + @c_Sku + ', Facility is ' + @c_Facility
                           SELECT 'PAType is ' + @cpa_PAType + ', ToLoc is ' + @cpa_toloc
                        END

                     END -- End of @cpa_PAType = '16' or @cpa_PAType = '18'

                     -- Added by MaryVong on 16-Jun-2005 (SOS36712 KCPI) -Start(1)
                     -- Empty location
                     IF @cpa_PAType = '17' or @cpa_PAType = '19'
                     BEGIN
                        SET ROWCOUNT 1
                        SELECT @cpa_toloc = LOC.LOC,
                           @c_toloc = LOC.LOC
                        FROM LOC (NOLOCK)
                        LEFT OUTER JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.LOC = LOC.LOC)
                        WHERE LOC.LOC > @cpa_toloc
                        AND   LOC.Putawayzone = @c_searchzone
                        AND   LOC.Facility = @c_Facility
                        GROUP BY LOC.LOC
                        HAVING SUM(SKUxLOC.Qty - SKUxLOC.QtyPicked) = 0 OR SUM(SKUxLOC.Qty - SKUxLOC.QtyPicked) IS NULL
                        ORDER BY LOC.LOC
                        SELECT @n_RowCount = @@ROWCOUNT

                        -- Chekcing
                        IF @b_debug = 2
                        BEGIN
                           SELECT 'SearchZone is ' + @c_searchzone + ', Facility is ' + @c_Facility
                           SELECT 'PAType is ' + @cpa_PAType + ', ToLoc is ' + @cpa_toloc
                        END
                     END -- End of @cpa_PAType = '17' or @cpa_PAType = '19' 
                     -- Added by MaryVong on 16-Jun-2005 (SOS36712 KCPI) -End(1)                                       
                     
                     IF @cpa_PAType = '22' or @cpa_PAType = '24'
                     BEGIN
                        SELECT @cpa_toloc = LOC.LOC,
                           @c_toloc = LOC.LOC
                          FROM LOC (NOLOCK)
                        LEFT OUTER JOIN SKUxLOC WITH (NOLOCK) ON (LOC.LOC = SKUxLOC.LOC)
                        JOIN CODELKUP WITH (NOLOCK) ON ( LOC.LocationCategory = CODELKUP.CODE
                                                         AND CODELKUP.LISTNAME = 'LOCCATEGRY'
                                                         AND CODELKUP.SHORT = 'S')
                        WHERE LOC.LOC > @cpa_toloc
                        AND LOC.Putawayzone = @c_searchzone
                        AND LOC.Facility = @c_Facility -- CDC Migration
                        GROUP BY LOC.LOC
                        HAVING SUM(SKUxLOC.Qty) = 0 OR SUM(SKUxLOC.Qty) IS NULL
                        ORDER BY LOC.LOC
                        SELECT @n_RowCount = @@ROWCOUNT
                     END
                     IF @cpa_PAType = '32' or @cpa_PAType = '34'
                     BEGIN
                        SELECT @cpa_toloc = SKUxLOC.LOC,
                           @c_toloc = SKUxLOC.LOC
                        FROM SKUxLOC (NOLOCK)
                        JOIN (SELECT LOC.LOC FROM LOC (NOLOCK)
                              JOIN CODELKUP WITH (NOLOCK) ON (LOC.LocationCategory = CODELKUP.CODE
                                                               AND CODELKUP.LISTNAME = 'LOCCATEGRY'
                                                               AND CODELKUP.SHORT = 'M')
                              JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.LOC = LOC.LOC
                                                             AND SKUxLOC.Qty - SKUxLOC.QtyPicked  > 0)
                              WHERE SKUxLOC.StorerKey = @c_StorerKey
                              AND   SKUxLOC.SKU = @c_sku
                              AND   SKUxLOC.LOC > @cpa_toloc
                              AND   LOC.Putawayzone = @c_searchzone
                              AND   LOC.Facility = @c_Facility -- CDC Migration
                              GROUP BY LOC.LOC
                              HAVING COUNT(LOC.LOC) = 1) AS SINGLE_SKU ON (SKUxLOC.LOC = SINGLE_SKU.LOC)
                        ORDER BY SKUxLOC.LOC
                        SELECT @n_RowCount = @@ROWCOUNT
                     END
                     IF @cpa_PAType = '42' or @cpa_PAType = '44'
                     BEGIN
                        SELECT @cpa_toloc = LOC.LOC,
                           @c_toloc = LOC.LOC
                        FROM LOC (NOLOCK)
                        LEFT OUTER JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.LOC = LOC.LOC)
                        JOIN CODELKUP WITH (NOLOCK) ON (LOC.LocationCategory = CODELKUP.CODE
                                                         AND CODELKUP.LISTNAME = 'LOCCATEGRY'
                                                         AND CODELKUP.SHORT = 'M')
                        WHERE LOC.LOC > @cpa_toloc
                        AND   LOC.Putawayzone = @c_searchzone
                        AND   LOC.Facility = @c_Facility -- CDC Migration
                        GROUP BY LOC.LOC
                        HAVING SUM(SKUxLOC.Qty - SKUxLOC.QtyPicked) = 0 OR SUM(SKUxLOC.Qty - SKUxLOC.QtyPicked) IS NULL
                        ORDER BY LOC.LOC
                        SELECT @n_RowCount = @@ROWCOUNT
                     END -- @cpa_PAType = '42' or @cpa_PAType = '44'
                     IF @cpa_PAType = '52' or @cpa_PAType = '54'
                     BEGIN
                        SELECT @cpa_toloc = LOTxLOCxID.loc,
                           @c_toloc = LOTxLOCxID.loc
                        FROM LOTxLOCxID (NOLOCK)
                        JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.StorerKey = LOTxLOCxID.StorerKey
                                                      and SKUxLOC.sku = LOTxLOCxID. sku
                                                      and SKUxLOC.StorerKey = @c_StorerKey
                                                      and SKUxLOC.sku = @c_sku
                                                      and SKUxLOC.loc = LOTxLOCxID.loc)
                        JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOTxLOCxID.Lot = Lotattribute.lot)
                        JOIN (SELECT Lottable02, Lottable04 FROM LOTAttribute (NOLOCK)
                        JOIN LOTxLOCxID (NOLOCK) ON (LOTxLOCxID.LOT = Lotattribute.LOT)
                              WHERE LOTxLOCxID.Qty > 0) AS L
                           ON (L.Lottable02 = LotAttribute.Lottable02 AND L.Lottable04 = LotAttribute.Lottable04)
                        JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = Loc.Loc
                        and LOC.PutawayZone = @c_searchzone
                        and LOC.Facility = @c_Facility )-- CDC Migration
                        WHERE LOTxLOCxID.LOC > @cpa_toloc
                        ORDER BY LOTxLOCxID.Loc
                        SELECT @n_Rowcount = @@ROWCOUNT
                     END
                     -- Added by MaryVong on 1-Apr-2007 (SOS69388 KFP) -Start(1)               
                     -- Cross facility, search location within specified zone base on HostWhCode,
                     -- with matching Lottable02 and Lottable04 (do not mix sku)
                     IF @cpa_PAType = '55'
                     BEGIN               
                        SET ROWCOUNT 1
                        SELECT @cpa_toloc = LOC.LOC,
                           @c_toloc = LOC.LOC,
                           @c_ToHostWhCode = LOC.HostWhCode
                        FROM LOC (NOLOCK)
                        JOIN LOTxLOCxID (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC)
                        JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.StorerKey = LOTxLOCxID.StorerKey
                                                  AND SKUxLOC.SKU = LOTxLOCxID.SKU
                                                  AND SKUxLOC.StorerKey = @c_storerkey
                                                  AND SKUxLOC.SKU = @c_sku
                                                  AND SKUxLOC.LOC = LOTxLOCxID.LOC)
                        JOIN LOTATTRIBUTE (NOLOCK) ON (LOTxLOCxID.LOT = Lotattribute.LOT
                                                       AND LOTxLOCxID.StorerKey = Lotattribute.StorerKey
                                                       AND LOTxLOCxID.SKU = Lotattribute.SKU)
                        JOIN (SELECT Lottable02, Lottable04
                              FROM LotAttribute (NOLOCK)
                              JOIN LOTxLOCxID (NOLOCK) ON (LOTxLOCxID.LOT = Lotattribute.LOT
                                                           AND LOTxLOCxID.StorerKey = Lotattribute.StorerKey
                                                           AND LOTxLOCxID.SKU = Lotattribute.SKU
                                                           AND LOTxLOCxID.StorerKey = @c_storerkey
                                                           AND LOTxLOCxID.SKU = @c_sku
                                                           AND LOTxLOCxID.LOT = @c_lot)
                              WHERE LOTxLOCxID.Qty > 0) AS LA
                           ON (LA.Lottable02 = LotAttribute.Lottable02 AND 
                              ISNULL(LA.Lottable04, '') = ISNULL(LotAttribute.Lottable04, '') )
                        WHERE LOC.LOC > @cpa_toloc
                        AND   LOC.PutawayZone = @c_searchzone
                        GROUP BY LOC.HostWhCode, LOC.LOC
                        ORDER BY LOC.HostWhCode, LOC.LOC
                        SELECT @n_Rowcount = @@ROWCOUNT
                     END -- End of @cpa_PAType = '55'
                     
                     -- Cross facility, search Empty Location base on HostWhCode inventory = 0             
                     IF @cpa_PAType = '56'
                     BEGIN
                        SET ROWCOUNT 1
                        SELECT @cpa_toloc = LOC.LOC,
                           @c_toloc = LOC.LOC,
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
                        WHERE LOC.LOC > @cpa_toloc
                        AND   LOC.Putawayzone = @c_searchzone
                        ORDER BY LOC.HostWhCode, LOC.LOC
                        SELECT @n_RowCount = @@ROWCOUNT
                     END -- End of @cpa_PAType = '56'                
                    
                     -- Cross facility, search suitable location within specified zone (mix with diff sku)
                     IF @cpa_PAType = '57'
                     BEGIN
                        SET ROWCOUNT 1
                        SELECT @cpa_toloc = LOC.LOC,
                           @c_toloc = LOC.LOC,
                           @c_ToHostWhCode = MIXED_SKU.HostWhCode
                        FROM LOC (NOLOCK)
                        JOIN (SELECT LOC.HostWhCode FROM LOC (NOLOCK)
                              JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.LOC = LOC.LOC)
                              WHERE LOC.Putawayzone = @c_searchzone
                              GROUP BY LOC.HostWhCode
                              HAVING SUM(SKUxLOC.Qty - SKUxLOC.QtyAllocated - SKUxLOC.QtyPicked) > 0 ) AS MIXED_SKU
                           ON (LOC.HostWhCode = MIXED_SKU.HostWhCode)
                        WHERE LOC.LOC > @cpa_toloc
                        AND   LOC.Putawayzone = @c_searchzone
                        ORDER BY LOC.HostWhCode, LOC.LOC
                        SELECT @n_RowCount = @@ROWCOUNT
                     END -- End of @cpa_PAType = '57'
                     
                      -- SOS69388 KFP - Cross facility, search suitable location within specified zone (do not mix sku)         
                     IF @cpa_PAType = '58'
                     BEGIN
                        SET ROWCOUNT 1
                        SELECT @cpa_toloc = LOC.LOC,
                           @c_toloc = LOC.LOC,
                           @c_ToHostWhCode = SINGLE_SKU.HostWhCode
                        FROM LOC (NOLOCK)
                        JOIN (SELECT LOC.HostWhCode FROM LOC (NOLOCK)
                              JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.LOC = LOC.LOC)
                              WHERE SKUxLOC.StorerKey = @c_storerkey
                              AND   SKUxLOC.SKU = @c_sku
                              AND   LOC.Putawayzone = @c_searchzone
                              GROUP BY LOC.HostWhCode
                              HAVING SUM(SKUxLOC.Qty - SKUxLOC.QtyAllocated - SKUxLOC.QtyPicked) > 0 ) AS SINGLE_SKU
                        ON (LOC.HostWhCode = SINGLE_SKU.HostWhCode)
                        WHERE LOC.LOC > @cpa_toloc
                        AND   LOC.Putawayzone = @c_searchzone
                        ORDER BY LOC.HostWhCode, LOC.LOC
                        SELECT @n_RowCount = @@ROWCOUNT                        
                     END -- End of @cpa_PAType = '58'                     
                     -- Added by MaryVong on 1-Apr-2007 (SOS69388) -End(1)

                     IF @b_debug = 2
                     BEGIN
                        SELECT 'PAType= ' + @cpa_PAType + ', SearchZone= ' + @c_searchzone + 
                              ', ToHostWhCode= ' + @c_ToHostWhCode + ', ToLoc= ' + @cpa_toloc + ', @c_lot= ' + @c_lot
                     END 

                     IF @n_RowCount = 0
                     BEGIN
                        BREAK
                     END
                     SELECT @n_locsreviewed = @n_locsreviewed + 1
                     SET ROWCOUNT 0
                     IF @cpa_checkrestrictions = 'Y'
                     BEGIN
                        SELECT @b_restrictionspassed = 0
                        GOTO PA_CHECKRESTRICTIONS
                        PATYPE02_BYLOC_B:
                        IF @b_restrictionspassed = 1
                        BEGIN
                           SELECT @b_gotloc = 1
                           BREAK
                        END
                     END
                     ELSE
                     BEGIN
                        SELECT @b_gotloc = 1
                        BREAK
                     END
                  END -- WHILE (1=1)

                  SET ROWCOUNT 0
                  IF @b_gotloc = 1
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        SELECT @c_reason = 'FOUND PAType=' + @cpa_PAType + ': Search Type by Location'
                        EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
                        @c_putawaystrategylinenumber, @n_ptracedetailkey,
                        @c_toloc, @c_reason
                     END
                     BREAK
                  END -- @b_gotloc = 1
               END -- IF PA_Type = '16','17','18','19','22','24','32','34','42','44','52','54','55','56','57','58'
            END -- IF @cpa_LocSearchType = '1'
            ELSE IF @cpa_LocSearchType = '2' -- Search Zone By Logical Location
            BEGIN
               SELECT @cpa_toloc = SPACE(10), @c_searchlogicalloc = SPACE(18)
               WHILE (1=1)
               BEGIN
                  SET ROWCOUNT 1
                  SELECT @cpa_toloc = LOC,
                  @c_toloc = LOC,
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
                     SELECT @b_restrictionspassed = 0
                     GOTO PA_CHECKRESTRICTIONS
                     PATYPE02_BYLOGICALLOC:
                     IF @b_restrictionspassed = 1
                     BEGIN
                        SELECT @b_gotloc = 1
                        BREAK
                     END
                  END
                  ELSE
                  BEGIN
                     SELECT @b_gotloc = 1
                     BREAK
                  END
               END -- While 1=1
               SET ROWCOUNT 0
               IF @b_gotloc = 1
               BEGIN
                  IF @b_debug = 1
                  BEGIN
                     SELECT @c_reason = 'FOUND PAType=' + @cpa_PAType + ': Search Type by Route Sequence'
                     EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
                     @c_putawaystrategylinenumber, @n_ptracedetailkey,
                     @c_toloc, @c_reason
                  END
                  BREAK
               END
            END -- IF @cpa_LocSearchType = '2'
         END -- dbo.fnc_LTrim(dbo.fnc_RTrim(@c_searchzone)) IS NOT NULL
         CONTINUE
      END -- IF PARTYPE = '02'/'04'/'12'
      IF @cpa_PAType = '06' -- Use Absolute Location Specified in ToLoc
      BEGIN
         SELECT @c_toloc = @cpa_toloc
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@cpa_toloc)) IS NOT NULL
         BEGIN
            IF @cpa_checkrestrictions = 'Y'
            BEGIN
               SELECT @b_restrictionspassed = 0
               GOTO PA_CHECKRESTRICTIONS
               PATYPE06:
               IF @b_restrictionspassed = 1
               BEGIN
                  SELECT @b_gotloc = 1
                  IF @b_debug = 1
                  BEGIN
                     SELECT @c_reason = 'FOUND PAType=06: Putaway Into To Location'
                     EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
                     @c_putawaystrategylinenumber, @n_ptracedetailkey,
                     @c_toloc, @c_reason
                  END
                  BREAK
               END
            END
            ELSE
            BEGIN
               SELECT @b_gotloc = 1
               IF @b_debug = 1
               BEGIN
                  SELECT @c_reason = 'FOUND PAType=06: Putaway Into To Location'
                  EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
                  @c_putawaystrategylinenumber, @n_ptracedetailkey,
                  @c_toloc, @c_reason
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
            SELECT @c_toloc = ''
            WHILE (1=1)
            BEGIN
               SET ROWCOUNT 1
               IF @cpa_PAType = '88'
               BEGIN
                  SELECT @c_toloc = SKUxLOC.LOC
                  FROM SKUxLOC (NOLOCK) Join Loc (NOLOCK)
                    ON SKUxLOC.Loc = Loc.Loc
                  WHERE StorerKey = @c_StorerKey
                  AND SKU = @c_sku
                  AND Loc.Facility = @c_Facility -- CDC Migration
                  AND (SKUxLOC.LOCATIONTYPE = 'PICK' OR SKUxLOC.LOCATIONTYPE = 'CASE')
                  AND SKUxLOC.LOC > @c_toloc
                  ORDER BY SKUxLOC.LOC
               END
               ELSE
               BEGIN
                  SELECT @c_toloc = SKUxLOC.LOC
                  FROM SKUxLOC (NOLOCK) Join Loc (NOLOCK)
                  on SKUxLOC.Loc = Loc.Loc
                  WHERE StorerKey = @c_StorerKey
                  AND SKU = @c_sku
                  AND Loc.Facility = @c_Facility -- CDC Migration
                  AND SKUxLOC.LOCATIONTYPE = 'PICK'
                  AND SKUxLOC.LOC > @c_toloc
                  ORDER BY SKUxLOC.LOC
               END
               IF @@ROWCOUNT = 0
               BEGIN
                  SET ROWCOUNT 0
                  SELECT @c_toloc = ''
                  BREAK
               END
               SET ROWCOUNT 0
               IF @c_toloc IS NULL
               BEGIN
                  SELECT @c_toloc = ''
               END
               IF @cpa_PAType = '07'
               BEGIN
                  --    IF EXISTS(SELECT *
                  --    FROM SKUxLOC (NOLOCK)
                  --    WHERE SKUxLOC.StorerKey = @c_StorerKey
                  --    AND SKUxLOC.Sku = @c_sku
                  --    AND (SKUxLOC.Qty - SKUxLOC.QtyPicked) > 0)
                  IF (SELECT SUM(Qty - QtyPicked)
                  FROM SKUxLOC (NOLOCK)
                  JOIN LOC (NOLOCK) on SKUxLOC.loc = LOC.LOC
                  WHERE SKU = @c_sku
                  AND StorerKey = @c_StorerKey
                  AND Facility = @c_Facility -- CDC Migration
                  AND LocationFlag = 'NONE'
                  AND LocationCategory <> 'VIRTUAL'
                  AND SKUxLOC.LOC <> @c_FromLoc) > 0 -- vicky
                  BEGIN
                     SELECT @c_toloc = ''
                     IF @b_debug = 1
                     BEGIN
                        SELECT @c_reason = 'FAILED PAType=07: Commodity has balance-on-hand qty'
                        EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
                        @c_putawaystrategylinenumber, @n_ptracedetailkey,
                        @c_toloc, @c_reason
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
                  WHERE sku = @c_sku
                  AND StorerKey = @c_StorerKey
                  AND loc.Facility = @c_Facility      -- wally 23.oct.2002
                  AND LocationFlag = 'NONE') > 0
                  BEGIN
                     SELECT @c_toloc = ''
                     IF @b_debug = 1
                     BEGIN
                        SELECT @c_reason = 'FAILED PAType=88: Commodity has balance-on-hand qty'
                        EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
                        @c_putawaystrategylinenumber, @n_ptracedetailkey,
                        @c_toloc, @c_reason
                     END
                     BREAK
                  END
               END
               /* CDC Migration END*/

               IF dbo.fnc_LTrim(@c_toloc) IS NOT NULL
               BEGIN
                  IF @cpa_checkrestrictions = 'Y'
                  BEGIN
                     SELECT @b_restrictionspassed = 0
                     GOTO PA_CHECKRESTRICTIONS
                     PATYPE08:
                     IF @b_restrictionspassed = 1
                     BEGIN
                        SELECT @b_gotloc = 1
                        BREAK
                     END
                  END
                  ELSE
                  BEGIN
                     SELECT @b_gotloc = 1
                     BREAK
                  END
               END
            END -- While (1=1)
            SET ROWCOUNT 0
            IF @b_gotloc = 1
            BEGIN
               IF @b_debug = 1
               BEGIN
                  SELECT @c_reason = 'FOUND PAType=' + @cpa_PAType + ': Putaway to Assigned Piece Pick'
                  EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
                  @c_putawaystrategylinenumber, @n_ptracedetailkey,
                  @c_toloc, @c_reason
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
            SELECT @c_toloc = PUTAWAYLOC
            FROM SKU (NOLOCK)
            WHERE StorerKey = @c_StorerKey
            AND SKU = @c_sku
            IF dbo.fnc_LTrim(@c_toloc) IS NOT NULL
            BEGIN
               IF @cpa_checkrestrictions = 'Y'
               BEGIN
                  SELECT @b_restrictionspassed = 0
                  GOTO PA_CHECKRESTRICTIONS
                  PATYPE09:
                  IF @b_restrictionspassed = 1
                  BEGIN
                     SELECT @b_gotloc = 1
                     IF @b_debug = 1
                     BEGIN
                        SELECT @c_reason = 'FOUND PAType=09: Putaway to location specified on Commodity'
                        EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
                        @c_putawaystrategylinenumber, @n_ptracedetailkey,
                        @c_toloc, @c_reason
                     END
                     BREAK
                  END
               END
               ELSE
               BEGIN
                  SELECT @b_gotloc = 1
                  IF @b_debug = 1
                  BEGIN
                     SELECT @c_reason = 'FOUND PAType=09: Putaway to location specified on Commodity'
                     EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
                     @c_putawaystrategylinenumber, @n_ptracedetailkey,
                     @c_toloc, @c_reason
                  END
                  BREAK
               END
            END
            ELSE
            BEGIN
               IF @b_debug = 1
               BEGIN
                  SELECT @c_reason = 'FAILED PAType=09: Commodity has no putaway location specified'
                  EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
                  @c_putawaystrategylinenumber, @n_ptracedetailkey,
                  @c_toloc, @c_reason
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
            SELECT @c_toloc = ''
            WHILE (1=1)
            BEGIN
               SET ROWCOUNT 1
               SELECT @c_toloc = SKUxLOC.Loc
               FROM SKUxLOC (NOLOCK) JOIN Loc (NOLOCK)
               on SKUxLOC.Loc = Loc.Loc
               WHERE StorerKey = @c_StorerKey
               AND SKU = @c_sku
               AND SKUxLOC.LOCATIONTYPE = 'PICK'
               AND @cpa_FROMLOC = @c_fromloc
               AND Loc.Facility = @c_Facility -- CDC Migration
               ORDER BY SKUxLOC.LOC
               IF @@ROWCOUNT = 0
               BEGIN
                  SET ROWCOUNT 0
                  SELECT @c_toloc = ''
                  BREAK
               END
               SET ROWCOUNT 0
               IF @c_toloc IS NULL
               BEGIN
                  SELECT @c_toloc = ''
               END
               IF dbo.fnc_LTrim(@c_toloc) IS NOT NULL
               BEGIN
                  IF @cpa_checkrestrictions = 'Y'
                  BEGIN
                     SELECT @b_restrictionspassed = 0
                     GOTO PA_CHECKRESTRICTIONS
                     PATYPE20:
                     IF @b_restrictionspassed = 1
                     BEGIN
                        SELECT @b_gotloc = 1
                        BREAK
                     END
                  END
                  ELSE
                  BEGIN
                     SELECT @b_gotloc = 1
                     BREAK
                  END
               END
            END -- WHILE (1=1)
            SET ROWCOUNT 0
            IF @b_gotloc = 1
            BEGIN
               IF @b_debug = 1
               BEGIN
                  SELECT @c_reason = 'FOUND PAType=20: Putaway to SKU pickface location'
                  EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
                  @c_putawaystrategylinenumber, @n_ptracedetailkey,
                  @c_toloc, @c_reason
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
            SELECT @c_toloc = ''
            WHILE (1=1)
            BEGIN
               SET ROWCOUNT 1
               
               SELECT @c_toloc = SKUxLOC.LOC
               FROM SKUxLOC (NOLOCK)
               Join Loc (NOLOCK) on SKUxLOC.Loc = Loc.Loc
               WHERE StorerKey = @c_StorerKey
               AND SKU = @c_sku
               AND SKUxLOC.LOCATIONTYPE = 'CASE'
               AND Loc.Facility = @c_Facility -- SOS6421
               AND SKUxLOC.LOC > @c_toloc
               ORDER BY SKUxLOC.LOC
      
               IF @@ROWCOUNT = 0
               BEGIN
                  SET ROWCOUNT 0
                  SELECT @c_toloc = ''
                  BREAK
               END
               SET ROWCOUNT 0
               IF @c_toloc IS NULL
               BEGIN
                  SELECT @c_toloc = ''
               END
               IF dbo.fnc_LTrim(@c_toloc) IS NOT NULL
               BEGIN
                  IF @cpa_checkrestrictions = 'Y'
                  BEGIN
                     SELECT @b_restrictionspassed = 0
                     GOTO PA_CHECKRESTRICTIONS
                     PATYPE15:
                     IF @b_restrictionspassed = 1
                     BEGIN
                        SELECT @b_gotloc = 1
                        BREAK
                     END
                  END
                  ELSE
                  BEGIN
                     SELECT @b_gotloc = 1
                     BREAK
                  END
               END
            END -- WHILE (1=1)
            SET ROWCOUNT 0
            IF @b_gotloc = 1
            BEGIN
               IF @b_debug = 1
               BEGIN
                  SELECT @c_reason = 'FOUND PAType=15: Putaway to Assogned Case Pick'
                  EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
                  @c_putawaystrategylinenumber, @n_ptracedetailkey,
                  @c_toloc, @c_reason
               END
               BREAK
            END
         END -- IF @b_MultiProductID = 0
         CONTINUE
      END -- IF @cpa_PAType = '15'

   END -- WHILE (1=1)
   SET ROWCOUNT 0

   IF @b_gotloc <> 1 -- No Luck
   BEGIN
      SELECT @c_toloc= ''
   END
   IF @b_debug = 1
   BEGIN
      UPDATE PTRACEHEAD SET ENDTime = getdate(), PA_locFound = @c_toloc, PA_LocsReviewed = @n_locsreviewed
      WHERE PTRACEHEADKey = @n_ptraceheadkey
   END
   GOTO LOCATION_EXIT
   
PA_CHECKRESTRICTIONS:
SELECT @c_loc_type = LOCATIONTYPE ,
      @c_loc_flag = LocationFlag ,
      @c_loc_handling = LOCATIONHANDLING,
      @c_loc_category = LocationCategory,
      @c_loc_zone = PUTAWAYZONE ,
      @c_loc_comminglesku = comminglesku,
      @c_loc_comminglelot = comminglelot,
      @n_loc_width = WIDTH ,
      @n_loc_length = LENGTH ,
      @n_loc_height = HEIGHT ,
      @n_loc_cubiccapacity = cubiccapacity ,
      @n_loc_weightcapacity = weightcapacity
FROM LOC (NOLOCK)
WHERE LOC = @c_toloc
SELECT @c_movableunittype = @c_movableunittype
select @b_restrictionspassed = 1
SELECT @c_loc_type = dbo.fnc_LTrim(@c_loc_type)

IF @c_loc_type IS NOT NULL
BEGIN
   IF @c_loc_type IN (@cpa_locationtypeexclude01,@cpa_locationtypeexclude02,@cpa_locationtypeexclude03,@cpa_locationtypeexclude04,@cpa_locationtypeexclude05)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'FAILED Location type ' + dbo.fnc_RTrim(@c_loc_type) + ' was one of the excluded values'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
      SELECT @b_restrictionspassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'PASSED Location type ' + dbo.fnc_RTrim(@c_loc_type) + ' was not one of the excluded values'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
   END
END
IF dbo.fnc_LTrim(@cpa_LocationTypeRestriction01) IS NOT NULL
OR dbo.fnc_LTrim(@cpa_LocationTypeRestriction02) IS NOT NULL
OR dbo.fnc_LTrim(@cpa_LocationTypeRestriction03) IS NOT NULL
BEGIN
   IF @c_loc_type NOT IN (@cpa_LocationTypeRestriction01,@cpa_LocationTypeRestriction02,@cpa_LocationTypeRestriction03)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'FAILED Location type ' + dbo.fnc_RTrim(@c_loc_type) + ' was not one of the specified values'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
      SELECT @b_restrictionspassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'PASSED Location type ' + dbo.fnc_RTrim(@c_loc_type) + ' was one of the specified values'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
   END
END
SELECT @c_loc_flag = dbo.fnc_LTrim(@c_loc_flag)
IF @c_loc_flag IS NOT NULL
BEGIN
   IF @c_loc_flag IN (@cpa_LocationFlagexclude01,@cpa_LocationFlagexclude02,@cpa_LocationFlagexclude03)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'FAILED Location flag ' + dbo.fnc_RTrim(@c_loc_flag) + ' was one of the excluded values'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
      SELECT @b_restrictionspassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'PASSED Location flag ' + dbo.fnc_RTrim(@c_loc_flag) + ' was not one of the excluded values'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
   END
END
IF dbo.fnc_LTrim(@cpa_LocationFlagInclude01) IS NOT NULL
OR dbo.fnc_LTrim(@cpa_LocationFlagInclude02) IS NOT NULL
OR dbo.fnc_LTrim(@cpa_LocationFlagInclude03) IS NOT NULL
BEGIN
   IF @c_loc_flag NOT IN (@cpa_LocationFlagInclude01,@cpa_LocationFlagInclude02,@cpa_LocationFlagInclude03)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'FAILED Location flag ' + dbo.fnc_RTrim(@c_loc_flag) + ' was not one of the specified values'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
      SELECT @b_restrictionspassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'PASSED Location flag ' + dbo.fnc_RTrim(@c_loc_flag) + ' was one of the specified values'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
   END
END
SELECT @c_loc_category = dbo.fnc_LTrim(@c_loc_category)
IF @c_loc_category IS NOT NULL
BEGIN
   IF @c_loc_category IN (@cpa_LocationCategoryexclude01,@cpa_LocationCategoryexclude02,@cpa_LocationCategoryexclude03)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'FAILED Location category ' + dbo.fnc_RTrim(@c_loc_category) + ' was one of the excluded values'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
      SELECT @b_restrictionspassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'PASSED Location category ' + dbo.fnc_RTrim(@c_loc_category) + ' was not one of the excluded values'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
   END
END
IF dbo.fnc_LTrim(@cpa_LocationCategoryInclude01) IS NOT NULL
OR dbo.fnc_LTrim(@cpa_LocationCategoryInclude02) IS NOT NULL
OR dbo.fnc_LTrim(@cpa_LocationCategoryInclude03) IS NOT NULL
BEGIN
   IF @c_loc_category NOT IN (@cpa_LocationCategoryInclude01,@cpa_LocationCategoryInclude02,@cpa_LocationCategoryInclude03)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'FAILED Location category ' + dbo.fnc_RTrim(@c_loc_category) + ' was not one of the specified values'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
      SELECT @b_restrictionspassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      -- Modification for Unilever Philippines
      -- SOS 3265
      -- start : by Wally 18.jan.2002
      DECLARE @c_lottable01 NVARCHAR(18),
      @c_lottable02 NVARCHAR(18),
      @d_lottable04 datetime

      IF @cpa_LocationCategoryInclude01 = 'DRIVEIN'
      BEGIN
         SELECT @c_lottable01 = lottable01, @c_lottable02 = lottable02
         FROM lotattribute (NOLOCK)
         WHERE lot = @c_lot

         IF not exists (select 1 from LOTxLOCxID (NOLOCK) 
                                 join lotattribute (NOLOCK) on LOTxLOCxID.lot = lotattribute.lot
                        where lotattribute.lottable01 = @c_lottable01
                          and lotattribute.lottable02 = @c_lottable02
                          and lotattribute.sku = @c_sku
                          and lotattribute.StorerKey = @c_StorerKey
                          and LOTxLOCxID.loc = @c_toloc)
         BEGIN
            IF (select sum(qty) from SKUxLOC (NOLOCK) where loc = @c_toloc) > 0
            BEGIN
               IF @b_debug = 1
               BEGIN
                  SELECT @c_reason = 'FAILED Location category DRIVEIN ' + dbo.fnc_RTrim(@c_loc_category) + ' Contain Different LOT Attributes.'
                  EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
                  @c_putawaystrategylinenumber, @n_ptracedetailkey,
                  @c_toloc, @c_reason
               END
               SELECT @b_restrictionspassed = 0
               GOTO RESTRICTIONCHECKDONE
            END
         END
      END
      -- END : by Wally 18.jan.2002
      /* CDC Migration Start */
      -- Added By SHONG 22.Jul.2002
      IF @c_loc_category = 'DOUBLEDEEP'
      BEGIN
         SELECT @d_lottable04 = lottable04, @c_lottable02 = lottable02
         FROM lotattribute (NOLOCK)
         WHERE lot = @c_lot

         IF not exists (select 1
         from LOTxLOCxID (NOLOCK)
         join lotattribute (NOLOCK) on LOTxLOCxID.lot = lotattribute.lot
         where lotattribute.lottable04 = @d_lottable04
         and lotattribute.lottable02 = @c_lottable02
         and lotattribute.sku = @c_sku
         and lotattribute.StorerKey = @c_StorerKey
         and LOTxLOCxID.loc = @c_toloc)
         BEGIN
            IF (select sum(qty) from SKUxLOC (NOLOCK) where loc = @c_toloc) > 0
            BEGIN
               IF @b_debug = 1
               BEGIN
                  SELECT @c_reason = 'FAILED Location category DOUBLEDEEP ' + dbo.fnc_RTrim(@c_loc_category) + ' Contain Different LOT Attributes.'
                  EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
                  @c_putawaystrategylinenumber, @n_ptracedetailkey,
                  @c_toloc, @c_reason
               END
               SELECT @b_restrictionspassed = 0
               GOTO RESTRICTIONCHECKDONE
            END
         END
      END
      -- END : by Shong 22.Jul.2002
      /* CDC Migration END */
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'PASSED Location category ' + dbo.fnc_RTrim(@c_loc_category) + ' was one of the specified values'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
   END
END
SELECT @c_loc_handling = dbo.fnc_LTrim(@c_loc_handling)
IF @c_loc_handling IS NOT NULL
BEGIN
   IF @c_loc_handling IN (@cpa_locationhandlingexclude01,@cpa_locationhandlingexclude02,@cpa_locationhandlingexclude03)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'FAILED Location handling ' + dbo.fnc_RTrim(@c_loc_handling) + ' was one of the excluded values'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
      SELECT @b_restrictionspassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'PASSED Location handling ' + dbo.fnc_RTrim(@c_loc_handling) + ' was not one of the excluded values'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
   END
END
IF dbo.fnc_LTrim(@cpa_LocationHandlingInclude01) IS NOT NULL
OR dbo.fnc_LTrim(@cpa_LocationHandlingInclude02) IS NOT NULL
OR dbo.fnc_LTrim(@cpa_LocationHandlingInclude03) IS NOT NULL
BEGIN
   IF @c_loc_handling NOT IN (@cpa_LocationHandlingInclude01,@cpa_LocationHandlingInclude02,@cpa_LocationHandlingInclude03)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'FAILED Location handling ' + dbo.fnc_RTrim(@c_loc_handling) + ' was not one of the specified values'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
      SELECT @b_restrictionspassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'PASSED Location handling ' + dbo.fnc_RTrim(@c_loc_handling) + ' was one of the specified values'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
   END
END
IF @b_MultiProductID = 1
BEGIN
   SELECT @n_currlocmultisku = 1
   IF @b_debug = 1
   BEGIN
      SELECT @c_reason = 'INFO   Commingled Sku Putaway Pallet Situation'
      EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
      @c_putawaystrategylinenumber, @n_ptracedetailkey,
      @c_toloc, @c_reason
   END
END
ELSE
BEGIN
   IF EXISTS(SELECT * FROM LOTxLOCxID (NOLOCK) WHERE LOC = @c_toloc AND (QTY > 0 OR PendingMoveIN > 0) AND (StorerKey <> @c_StorerKey OR  SKU <> @c_sku))
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'INFO   Commingled Sku Current Loc/Putaway Pallet Situation'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
      SELECT @n_currlocmultisku = 1
   END
   ELSE
   BEGIN
      SELECT @n_currlocmultisku = 0
   END
END
IF @b_MultiLotID = 1
BEGIN
   SELECT @n_currlocmultilot = 1
   IF @b_debug = 1
   BEGIN
      SELECT @c_reason = 'INFO   Commingled Lot Putaway Pallet Situation'
      EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
      @c_putawaystrategylinenumber, @n_ptracedetailkey,
      @c_toloc, @c_reason
   END
END
ELSE
BEGIN
   IF EXISTS(SELECT * FROM LOTxLOCxID (NOLOCK) WHERE LOC = @c_toloc AND (QTY > 0 OR PendingMoveIN > 0) AND LOT <> @c_lot)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'INFO   Commingled Lot Current Loc/Putaway Pallet Situation'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
      SELECT @n_currlocmultilot = 1
   END
   ELSE
   BEGIN
      SELECT @n_currlocmultilot = 0
   END
END
IF '2' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
   OR @c_loc_comminglesku = '0'
BEGIN
   IF @n_currlocmultisku = 1
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'FAILED Do not mix commodities but ptwy pallet is commingled. Location commingle flag = ' + dbo.fnc_RTrim(@c_loc_comminglesku)
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
      SELECT @b_restrictionspassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'PASSED Do not mix commodities and ptwy pallet is not commingled.  Location commingle flag = ' + dbo.fnc_RTrim(@c_loc_comminglesku)
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
   END
END
IF '3' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
   OR @c_loc_comminglelot = '0'
BEGIN
   IF @n_currlocmultilot = 1
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'FAILED Do not mix lots and ptwy pallet is commingled. Location mix lots flag = ' + dbo.fnc_RTrim(@c_loc_comminglelot)
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
      SELECT @b_restrictionspassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'PASSED Do not mix lots and ptwy pallet is not commingled. Location mix lots flag = ' + dbo.fnc_RTrim(@c_loc_comminglelot)
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
   END
END
-- Added By SHONG - Check Max Pallet
-- END Check Pallet
SELECT @cpa_areatypeexclude01 = dbo.fnc_LTrim(@cpa_areatypeexclude01)
IF @cpa_areatypeexclude01 IS NOT NULL
BEGIN
   IF EXISTS(SELECT * FROM AREADETAIL (NOLOCK) WHERE PUTAWAYZONE = @c_loc_zone AND AREAKEY = @cpa_areatypeexclude01)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'FAILED Zone: ' + dbo.fnc_RTrim(@c_loc_zone) + ' falls in excluded Area1: ' +  dbo.fnc_RTrim(@cpa_areatypeexclude01)
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
      SELECT @b_restrictionspassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'PASSED Zone1 ' + dbo.fnc_RTrim(@c_loc_zone) + ' is not excluded'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
   END
END
SELECT @cpa_areatypeexclude02 = dbo.fnc_LTrim(@cpa_areatypeexclude02)
IF @cpa_areatypeexclude02 IS NOT NULL
BEGIN
   IF EXISTS(SELECT * FROM AREADETAIL (NOLOCK) WHERE PUTAWAYZONE = @c_loc_zone AND AREAKEY = @cpa_areatypeexclude02)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'FAILED Zone: ' + dbo.fnc_RTrim(@c_loc_zone) + ' falls in excluded Area2: ' +  dbo.fnc_RTrim(@cpa_areatypeexclude02)
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
      SELECT @b_restrictionspassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'PASSED Zone2 ' + dbo.fnc_RTrim(@c_loc_zone) + ' is not excluded'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
   END
END
SELECT @cpa_areatypeexclude03 = dbo.fnc_LTrim(@cpa_areatypeexclude03)
IF @cpa_areatypeexclude03 IS NOT NULL
BEGIN
   IF EXISTS(SELECT * FROM AREADETAIL (NOLOCK) WHERE PUTAWAYZONE = @c_loc_zone AND AREAKEY = @cpa_areatypeexclude03)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'FAILED Zone: ' + dbo.fnc_RTrim(@c_loc_zone) + ' falls in excluded Area3:' +  dbo.fnc_RTrim(@cpa_areatypeexclude03)
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
      SELECT @b_restrictionspassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'PASSED Zone3 ' + dbo.fnc_RTrim(@c_loc_zone) + ' is not excluded'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
   END
END
IF '1' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
BEGIN
   IF EXISTS(SELECT * FROM LOTxLOCxID (NOLOCK) WHERE LOC = @c_toloc AND (QTY > 0 or PendingMoveIN > 0))
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'FAILED Location state says Location must be empty, but its not'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
      SELECT @b_restrictionspassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'PASSED Location state says Location must be empty, and it is'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
   END
END
IF '2' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
OR @c_loc_comminglesku = '0'
BEGIN
   IF @n_currlocmultisku = 1
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'FAILED Do not mix commodities'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
      SELECT @b_restrictionspassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'PASSED do not mix commodities'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
   END
END
IF '3' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
OR @c_loc_comminglelot = '0'
BEGIN
   IF @n_currlocmultilot = 1
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'FAILED Do not mix lots'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
      SELECT @b_restrictionspassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'PASSED Do not mix lots'
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
   END
END
IF '4' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
BEGIN
   -- get the pallet setup
   SELECT @n_MaxPallet = (CASE MaxPallet WHEN NULL THEN 0 ELSE MaxPallet END) FROM LOC (NOLOCK) WHERE LOC = @c_toloc

   IF @n_MaxPallet > 0 
   BEGIN
      SELECT @n_PalletQty = 0

      SELECT @n_PalletQty = ISNULL( COUNT(DISTINCT ID), 0) 
      FROM   LOTxLOCxID (NOLOCK)
      WHERE  LOC = @c_toloc
      AND    (Qty > 0 OR PendingMoveIn > 0 )

      IF @n_PalletQty >= @n_MaxPallet
      BEGIN
         -- error
         IF @b_debug = 1
         BEGIN
            SELECT @c_reason = 'FAILED - Fit By Max Pallet, Max Pallet: ' + dbo.fnc_RTrim(CAST(@n_MaxPallet as NVARCHAR(10))) +
                               ' Pallet Required: ' +  dbo.fnc_RTrim( CAST((@n_PalletQty + 1) as NVARCHAR(10)))
                               
            EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
            @c_putawaystrategylinenumber, @n_ptracedetailkey,
            @c_toloc, @c_reason
         END
         SELECT @b_restrictionspassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_reason = 'PASSED - Fit By Max Pallet, Max Pallet: ' + dbo.fnc_RTrim(CAST(@n_MaxPallet as NVARCHAR(10))) +
                               ' Pallet Required: ' +  dbo.fnc_RTrim( CAST((@n_PalletQty + 1) as NVARCHAR(10)))

            EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
            @c_putawaystrategylinenumber, @n_ptracedetailkey,
            @c_toloc, @c_reason
         END
      END

   END
END
-- Added by MaryVong on 20-Jul-2005 (SOS36712 KCPI) -Start(2)
IF '5' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
BEGIN
   -- get the pallet setup
   SELECT @n_MaxPallet = (CASE MaxPallet WHEN NULL THEN 0 ELSE MaxPallet END) FROM  LOC (NOLOCK) WHERE LOC = @c_toloc
   SELECT @n_StackFactor = (CASE StackFactor WHEN NULL THEN 0 ELSE StackFactor END) FROM SKU (NOLOCK) WHERE Storerkey = @c_StorerKey AND Sku = @c_Sku
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
      WHERE  LOC = @c_toloc
      AND    (Qty > 0 OR PendingMoveIn > 0 )

      IF @n_PalletQty >= @n_MaxPalletStackFactor
      BEGIN
         -- error
         IF @b_debug = 1
         BEGIN
            SELECT @c_reason = 'FAILED - Fit By Max Pallet (Stack Factor), Max Pallet: ' + dbo.fnc_RTrim(CAST(@n_MaxPallet as NVARCHAR(10))) +
                               ' Pallet Required: ' +  dbo.fnc_RTrim( CAST((@n_PalletQty + 1) as NVARCHAR(10)))
                               
            EXEC nspPTD 'nspASNPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
            @c_putawaystrategylinenumber, @n_ptracedetailkey,
            @c_toloc, @c_reason
         END
         SELECT @b_restrictionspassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_reason = 'PASSED - Fit By Max Pallet (Stack Factor), Max Pallet: ' + dbo.fnc_RTrim(CAST(@n_MaxPallet as NVARCHAR(10))) +
                               ' Pallet Required: ' +  dbo.fnc_RTrim( CAST((@n_PalletQty + 1) as NVARCHAR(10)))

            EXEC nspPTD 'nspASNPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
            @c_putawaystrategylinenumber, @n_ptracedetailkey,
            @c_toloc, @c_reason
         END
      END
   END
END
-- Added by MaryVong on 20-Jul-2005 (SOS36712 KCPI) -End(2)

-- Added by MaryVong on 31-Mar-2007 (SOS69388 KFP) -Start(2)
-- '6' & '7' - Check with MaxPallet for HostWhCode instead of Loc
-- KFP LOC Setup: Facility    Loc    HostWhCode
--                    Good         LOC1    LOC1   
--                    Good          LOC2   LOC2
--                    Quarantine  LOC1Q  LOC1
--                    Quarantine  LOC2Q  LOC2
IF '6' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
BEGIN
   -- Get the pallet setup
   SELECT @n_MaxPallet = (CASE MaxPallet WHEN NULL THEN 0 ELSE MaxPallet END) FROM LOC (NOLOCK) WHERE LOC = @c_toloc

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
            SELECT @c_reason = 'FAILED - 6 - Fit By Max Pallet, Max Pallet: ' + dbo.fnc_RTrim(CAST(@n_MaxPallet as NVARCHAR(10))) +
                               ' Pallet Required: ' +  dbo.fnc_RTrim( CAST((@n_PalletQty + 1) as NVARCHAR(10)))
                               
            EXEC nspPTD 'nspASNPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
            @c_putawaystrategylinenumber, @n_ptracedetailkey,
            @c_toloc, @c_reason
         END
         SELECT @b_restrictionspassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_reason = 'PASSED - 6 - Fit By Max Pallet, Max Pallet: ' + dbo.fnc_RTrim(CAST(@n_MaxPallet as NVARCHAR(10))) +
                               ' Pallet Required: ' +  dbo.fnc_RTrim( CAST((@n_PalletQty + 1) as NVARCHAR(10)))

            EXEC nspPTD 'nspASNPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
            @c_putawaystrategylinenumber, @n_ptracedetailkey,
            @c_toloc, @c_reason
         END
      END
   END
END

IF '7' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
BEGIN
   -- get the pallet setup
   SELECT @n_MaxPallet = (CASE MaxPallet WHEN NULL THEN 0 ELSE MaxPallet END) FROM  LOC (NOLOCK) WHERE LOC = @c_toloc
   SELECT @n_StackFactor = (CASE StackFactor WHEN NULL THEN 0 ELSE StackFactor END) FROM SKU (NOLOCK) WHERE Storerkey = @c_StorerKey AND Sku = @c_Sku
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
      -- WHERE  LOC = @c_toloc
      WHERE  LOC IN (SELECT LOC FROM LOC (NOLOCK) WHERE HostWhCode = @c_ToHostWhCode)
      AND    (Qty > 0 OR PendingMoveIn > 0 )

      IF @n_PalletQty >= @n_MaxPalletStackFactor
      BEGIN
         -- error
         IF @b_debug = 1
         BEGIN
            SELECT @c_reason = 'FAILED - 7 - Fit By Max Pallet (Stack Factor), Max Pallet: ' + dbo.fnc_RTrim(CAST(@n_MaxPallet as NVARCHAR(10))) +
                               ' Pallet Required: ' +  dbo.fnc_RTrim( CAST((@n_PalletQty + 1) as NVARCHAR(10)))
                               
            EXEC nspPTD 'nspASNPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
            @c_putawaystrategylinenumber, @n_ptracedetailkey,
            @c_toloc, @c_reason
         END
         SELECT @b_restrictionspassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_reason = 'PASSED - 7 - Fit By Max Pallet (Stack Factor), Max Pallet: ' + dbo.fnc_RTrim(CAST(@n_MaxPallet as NVARCHAR(10))) +
                               ' Pallet Required: ' +  dbo.fnc_RTrim( CAST((@n_PalletQty + 1) as NVARCHAR(10)))

            EXEC nspPTD 'nspASNPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
            @c_putawaystrategylinenumber, @n_ptracedetailkey,
            @c_toloc, @c_reason
         END
      END
   END
END
-- Added by MaryVong on 31-Mar-2007 (SOS69388 KFP) -End(2)

SELECT @n_palletwoodwidth  = PACK.PalletWoodWidth,
@n_palletwoodlength = PACK.PalletWoodLength,
@n_palletwoodheight = PACK.PalletWoodHeight,
@n_caselength       = PACK.LengthUOM1,
@n_casewidth        = PACK.WidthUOM1,
@n_caseheight       = PACK.HeightUOM1,
@n_putawayti        = PACK.PalletTI,
@n_putawayhi        = PACK.PalletHI,
@n_packcasecount    = PACK.CaseCnt,
@n_CubeUOM1         = PACK.CubeUOM1,
@n_QtyUOM1          = PACK.CaseCnt,
@n_CubeUOM3         = PACK.CubeUOM3,
@n_QtyUOM3          = PACK.Qty,
@n_CubeUOM4         = PACK.CubeUOM4,
@n_QtyUOM4          = PACK.Pallet
FROM PACK (NOLOCK)
WHERE PACK.Packkey = @c_packkey
IF '1' IN (@cpa_DimensionRestriction01,
@cpa_DimensionRestriction02,
@cpa_DimensionRestriction03,
@cpa_DimensionRestriction04,
@cpa_DimensionRestriction05,
@cpa_DimensionRestriction06)
BEGIN
   IF @n_currlocmultilot = 0
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
      SELECT @n_UOMcapacity = (@n_loc_cubiccapacity / @n_CubeUOM3)
      SELECT @n_QuantityCapacity = @n_UOMcapacity
      -- IF @c_loc_type = 'OTHER'
      -- BEGIN
      -- SELECT @n_loc_cubiccapacity = @n_loc_cubiccapacity - (@n_palletwoodwidth * @n_palletwoodlength * @n_palletwoodheight)
      -- SELECT @n_UOMcapacity = (@n_loc_cubiccapacity / @n_CubeUOM4)
      -- SELECT @n_QuantityCapacity = @n_QuantityCapacity + (@n_UOMcapacity * @n_QtyUOM4)
      -- SELECT @n_loc_cubiccapacity = @n_loc_cubiccapacity - (@n_UOMcapacity * @n_CubeUOM4)
      -- END
      -- SELECT @n_UOMcapacity = (@n_loc_cubiccapacity / @n_CubeUOM1)
      -- SELECT @n_QuantityCapacity = @n_QuantityCapacity + (@n_UOMcapacity * @n_QtyUOM1)
      -- SELECT @n_loc_cubiccapacity = @n_loc_cubiccapacity - (@n_UOMcapacity * @n_CubeUOM1)
      -- IF @c_loc_type = 'PICK'
      -- BEGIN
      -- SELECT @n_UOMcapacity = (@n_loc_cubiccapacity / @n_CubeUOM3)
      -- SELECT @n_QuantityCapacity = @n_QuantityCapacity + (@n_UOMcapacity * @n_QtyUOM3)
      -- END
      SELECT @n_toqty = SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked + LOTxLOCxID.PendingMoveIn)
      FROM LOTxLOCxID (NOLOCK)
      WHERE LOTxLOCxID.StorerKey = @c_StorerKey
      AND LOTxLOCxID.Sku = @c_SKU
      AND LOTxLOCxID.Loc = @c_toloc
      AND (LOTxLOCxID.Qty > 0 OR LOTxLOCxID.PendingMoveIn > 0)
      IF @n_toqty IS NULL
      BEGIN
         SELECT @n_toqty = 0
      END
      IF (@n_toqty + @n_qty ) > @n_QuantityCapacity
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_reason = 'FAILED Qty Fit: QtyCapacity = ' + dbo.fnc_RTrim(CONVERT(char(10),@n_QuantityCapacity)) + '  QtyRequired = ' + dbo.fnc_RTrim(Convert(char(10),(@n_toqty + @n_qty)))
            EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
            @c_putawaystrategylinenumber, @n_ptracedetailkey,
            @c_toloc, @c_reason
         END
         SELECT @b_restrictionspassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_reason = 'PASSED Qty Fit: QtyCapacity = ' + dbo.fnc_RTrim(CONVERT(char(10),@n_QuantityCapacity)) + '  QtyRequired = ' + dbo.fnc_RTrim(Convert(char(10),(@n_toqty + @n_qty)))
            EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
            @c_putawaystrategylinenumber, @n_ptracedetailkey,
            @c_toloc, @c_reason
         END
      END
   END -- End of IF @n_currlocmultilot = 0
   ELSE
   BEGIN
      SELECT @n_tocube = SUM((LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked + LOTxLOCxID.PendingMoveIn) * Sku.StdCube)
      FROM LOTxLOCxID (NOLOCK) ,Sku (NOLOCK)
      WHERE LOTxLOCxID.StorerKey = @c_StorerKey
      AND LOTxLOCxID.Sku = @c_SKU
      AND LOTxLOCxID.Loc = @c_toloc
      AND LOTxLOCxID.StorerKey = sku.StorerKey
      and LOTxLOCxID.sku = sku.sku
      AND (LOTxLOCxID.Qty > 0 OR  LOTxLOCxID.PendingMoveIn > 0)
      IF dbo.fnc_LTrim(@c_id) IS NOT NULL
      BEGIN
         SELECT @n_fromcube = SUM((LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked) * Sku.StdCube)
         FROM LOTxLOCxID (NOLOCK), Sku (NOLOCK)
         WHERE LOTxLOCxID.StorerKey = @c_StorerKey
         AND LOTxLOCxID.Sku = @c_sku
         AND LOTxLOCxID.Loc = @c_fromloc
         AND LOTxLOCxID.Id = @c_id
         AND LOTxLOCxID.StorerKey = sku.StorerKey
         and LOTxLOCxID.sku = sku.sku
         AND LOTxLOCxID.Qty > 0
      END
      ELSE
      BEGIN
         SELECT @n_fromcube = SUM((LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked) * Sku.StdCube)
         FROM LOTxLOCxID (NOLOCK), Sku (NOLOCK)
         WHERE LOTxLOCxID.StorerKey = @c_StorerKey
         AND LOTxLOCxID.Sku = @c_sku  --vicky
         AND LOTxLOCxID.Loc = @c_fromloc
         AND LOTxLOCxID.Lot = @c_lot
         AND LOTxLOCxID.StorerKey = sku.StorerKey
         and LOTxLOCxID.sku = sku.sku
         AND LOTxLOCxID.Qty > 0
      END
      IF @n_loc_cubiccapacity < (@n_tocube + @n_fromcube)
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_reason = 'FAILED Cube Fit: CubeCapacity = ' + dbo.fnc_RTrim(CONVERT(char(10),@n_loc_cubiccapacity)) + '  CubeRequired = ' + dbo.fnc_RTrim(Convert(char(10),(@n_tocube + @n_fromcube)))
            EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
            @c_putawaystrategylinenumber, @n_ptracedetailkey,
            @c_toloc, @c_reason
         END
         SELECT @b_restrictionspassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_reason = 'PASSED Cube Fit: CubeCapacity = ' + dbo.fnc_RTrim(CONVERT(char(10),@n_loc_cubiccapacity)) + '  CubeRequired = ' + dbo.fnc_RTrim(Convert(char(10),(@n_tocube + @n_fromcube)))
            EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
            @c_putawaystrategylinenumber, @n_ptracedetailkey,
            @c_toloc, @c_reason
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
AND @c_loc_type NOT IN ('PICK','CASE')
AND @n_currlocmultilot = 0
BEGIN
   IF @n_putawayti IS NULL
      OR @n_putawayti = 0
   BEGIN
      SELECT @c_reason = 'FAILED LxWxH Fit: Commodity PutawayTi = 0 or is NULL'
      SELECT @b_restrictionspassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   IF  (@n_palletwoodwidth > @n_loc_width OR @n_palletwoodlength > @n_loc_length) AND
      (@n_palletwoodwidth > @n_loc_length OR @n_palletwoodlength > @n_loc_width)
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'FAILED LxWxH Fit: Wood/LocWidth=' + CONVERT(char(4),@n_palletwoodwidth) + ' / ' + CONVERT(char(4),@n_loc_width) + '  Wood/locLength=' + CONVERT(char(4),@n_palletwoodlength) + ' / ' + CONVERT(char(4),@n_loc_length)
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
      SELECT @b_restrictionspassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'PASSED LxWxH Fit: Wood/LocWidth=' + CONVERT(char(4),@n_palletwoodwidth) + ' / ' + CONVERT(char(4),@n_loc_width) + '  Wood/locLength=' + CONVERT(char(4),@n_palletwoodlength) + ' / ' + CONVERT(char(4),@n_loc_length)
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
   END
   SELECT @n_existingquantity = SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked + LOTxLOCxID.PendingMoveIn)
   FROM LOTxLOCxID (NOLOCK)
   WHERE LOTxLOCxID.StorerKey = @c_StorerKey
   AND LOTxLOCxID.Sku = @c_SKU
   AND LOTxLOCxID.Loc = @c_toloc
   AND (LOTxLOCxID.Qty > 0 OR LOTxLOCxID.PendingMoveIn > 0)
   IF @n_existingquantity IS NULL
   BEGIN
      SELECT @n_existingquantity = 0
      SELECT @n_existingheight = @n_palletwoodheight
   END
   ELSE
   BEGIN
      SELECT @n_existinglayers = @n_existingquantity / (@n_putawayti * @n_packcasecount)
      SELECT @n_extralayer = @n_existingquantity % (@n_putawayti * @n_packcasecount)
      IF @n_extralayer > 0
      BEGIN
         SELECT @n_existinglayers = @n_existinglayers + 1
      END
      SELECT @n_existingheight = (@n_existinglayers * @n_caseheight) + @n_palletwoodheight
   END
   SELECT @n_existinglayers = @n_qty / (@n_putawayti * @n_packcasecount)
   SELECT @n_extralayer = @n_qty % (@n_putawayti * @n_packcasecount)
   IF @n_extralayer > 0
   BEGIN
      SELECT @n_existinglayers = @n_existinglayers + 1
   END
   SELECT @n_palletheight = @n_caseheight * @n_existinglayers
   IF @n_existingheight + @n_palletheight > @n_loc_height
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'FAILED LxWxH Fit: LocHeight = ' + dbo.fnc_RTrim(CONVERT(char(20),@n_loc_height)) + '  ExistingHeight = ' + dbo.fnc_RTrim(CONVERT(char(20),@n_existingheight)) + '  AdditionalHeight = ' + dbo.fnc_RTrim(CONVERT(char(20),(@n_palletheight)))
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
      SELECT @b_restrictionspassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'PASSED LxWxH Fit: LocHeight = ' + dbo.fnc_RTrim(CONVERT(char(20),@n_loc_height)) + '  ExistingHeight = ' + dbo.fnc_RTrim(CONVERT(char(20),@n_existingheight)) + '  AdditionalHeight = ' + dbo.fnc_RTrim(CONVERT(char(20),(@n_palletheight)))
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
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
   SELECT @n_toweight = SUM((LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked + LOTxLOCxID.PendingMoveIn) * Sku.StdGrossWgt)
   FROM LOTxLOCxID (NOLOCK), Sku (NOLOCK)
   WHERE LOTxLOCxID.StorerKey = Sku.StorerKey
   AND LOTxLOCxID.Sku = Sku.sku
   AND LOTxLOCxID.Loc = @c_toloc
   AND LOTxLOCxID.Qty > 0
   IF @n_toweight IS NULL
   BEGIN
      SELECT @n_toweight = 0
   END
   IF @b_MultiProductID = 0
   BEGIN
      SELECT @n_fromweight = @n_qty * @n_stdgrosswgt
   END
   ELSE
   BEGIN
      SELECT @n_fromweight = SUM((LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked) * Sku.StdGrossWgt)
      FROM LOTxLOCxID (NOLOCK), Sku (NOLOCK)
      WHERE LOTxLOCxID.StorerKey = Sku.StorerKey
      AND LOTxLOCxID.Sku = Sku.sku
      AND LOTxLOCxID.Id = @c_id
      IF @n_fromweight IS NULL
      BEGIN
         SELECT @n_fromweight = 0
      END
   END
   IF @n_loc_weightcapacity < ( @n_toweight + @n_fromweight )
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'FAILED Weight Fit: LocWeight = ' + dbo.fnc_RTrim(CONVERT(char(20),@n_loc_weightcapacity)) + '  ExistingWeight = ' + dbo.fnc_RTrim(CONVERT(char(20),@n_toweight)) + '  AdditionalWeight = ' + dbo.fnc_RTrim(CONVERT(char(20),(@n_fromweight)))
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
      SELECT @b_restrictionspassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'PASSED Weight Fit: LocWeight = ' + dbo.fnc_RTrim(CONVERT(char(20),@n_loc_weightcapacity)) + '  ExistingWeight = ' + dbo.fnc_RTrim(CONVERT(char(20),@n_toweight)) + '  AdditionalWeight = ' + dbo.fnc_RTrim(CONVERT(char(20),(@n_fromweight)))
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
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
   SELECT @n_qtylocationlimit = QtyLocationLimit
   FROM SKUxLOC (NOLOCK)
   WHERE StorerKey = @c_StorerKey
   AND SKU = @c_sku
   AND Locationtype IN ('PICK', 'CASE')
   AND loc = @c_toloc
   IF @n_qtylocationlimit IS NOT NULL
   BEGIN
      SELECT @n_existingquantity = SUM((Qty - QtyPicked) + PendingMoveIN)
      FROM LOTxLOCxID (NOLOCK)
      WHERE StorerKey = @c_StorerKey
      AND SKU = @c_sku
      AND loc = @c_toloc
      AND (Qty > 0
      OR  PendingMoveIn > 0)
      IF @n_existingquantity IS NULL
      BEGIN
         SELECT @n_existingquantity = 0
      END
      IF @n_qtylocationlimit < (@n_qty + @n_existingquantity)
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_reason = 'FAILED Qty Capacity: LocCapacity = ' + dbo.fnc_RTrim(CONVERT(char(20),@n_qtylocationlimit)) + '  Required = ' + dbo.fnc_RTrim(CONVERT(char(20),(@n_qty + @n_existingquantity)))
            EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
            @c_putawaystrategylinenumber, @n_ptracedetailkey,
            @c_toloc, @c_reason
         END
         SELECT @b_restrictionspassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_reason = 'PASSED Qty Capacity: LocCapacity = ' + dbo.fnc_RTrim(CONVERT(char(20),@n_qtylocationlimit)) + '  Required = ' + dbo.fnc_RTrim(CONVERT(char(20),(@n_qty + @n_existingquantity)))
            EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
            @c_putawaystrategylinenumber, @n_ptracedetailkey,
            @c_toloc, @c_reason
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
   IF ((@n_caseheight * @n_putawayhi) + @n_palletwoodheight) > @n_loc_height
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'FAILED Height Restriction: Loc Height = ' + dbo.fnc_RTrim(CONVERT(char(20), @n_loc_height)) + '. Pallet Build Height = ' +
         dbo.fnc_RTrim(CONVERT(char(20), ((@n_caseheight * @n_putawayhi) + @n_palletwoodheight)))
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
      END
      SELECT @b_restrictionspassed = 0
      GOTO RESTRICTIONCHECKDONE
   END
   ELSE
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'PASSED Height Restriction: Loc Height = ' + dbo.fnc_RTrim(CONVERT(char(20), @n_loc_height)) + '. Pallet Build Height = ' +
         dbo.fnc_RTrim(CONVERT(char(20), ((@n_caseheight * @n_putawayhi) + @n_palletwoodheight)))
         EXEC nspPTD 'nspPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         @c_toloc, @c_reason
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
   @cpa_PAType = '44' or   -- Search ZONE specified in this strategy for empty Multi Pallet location
   -- added for China - Putaaway to location with matching Lottable02 and Lottable04
   @cpa_PAType = '52' or -- Search Zone specified in SKU table for matching Lottable02 and Lottable04
   @cpa_PAType = '54' or
   @cpa_PAType = '55' or -- SOS69388 KFP - Cross facility - search location within specified zone 
                         --                  with matching Lottable02 and Lottable04 (do not mix sku)
   @cpa_PAType = '56' or -- SOS69388 KFP - Cross facility - search Empty Location base on HostWhCode inventory = 0
   @cpa_PAType = '57' or -- SOS69388 KFP - Cross facility - search suitable location within specified zone (mix with diff sku)
   @cpa_PAType = '58'    -- SOS69388 KFP - Cross facility - search suitable location within specified zone (do not mix sku)
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
LOCATION_EXIT:
   IF @b_gotloc = 1
   BEGIN
      DECLARE @c_command NVARCHAR(255)
      SELECT @c_command = 'DECLARE CURSOR_TOLOC CURSOR FOR SELECT ' + 'N'''  + @c_toloc + ''''
      EXEC(@c_command)
   END
   GOTO LOCATION_DONE
   
LOCATION_ERROR:
   SELECT @n_err = 99701
   SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': No Location. (nspPASTD)'
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      
LOCATION_DONE:
END

GO