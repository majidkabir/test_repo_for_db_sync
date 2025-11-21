SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: nspASNPASTDTH                                       */  
/* Creation Date:                                                        */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose:                                                              */
/*                                                                       */
/*                                                                       */  
/* Called By: Wave                                                       */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/*************************************************************************/

CREATE PROC    [dbo].[nspASNPASTDTH]
@c_userid           NVARCHAR(18)
,              @c_StorerKey        NVARCHAR(15)
,              @c_lot              NVARCHAR(10)
,              @c_sku              NVARCHAR(20)
,              @c_id               NVARCHAR(18)
,              @c_fromloc          NVARCHAR(10)
,              @n_qty              int
,              @c_uom              NVARCHAR(10)
,              @c_packkey          NVARCHAR(10)
,              @n_putawaycapacity  int
,              @c_final_toloc      NVARCHAR(10) OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @n_err int
   DECLARE @c_errmsg NVARCHAR(255)
   DECLARE @b_debug int
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
   @c_Facility NVARCHAR(5) -- SOS6421
   ,@n_MaxPallet int 
   ,@n_PalletQty int 
   
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
      EXEC nspPTH 'nspASNPASTDTH', @c_userid, @c_StorerKey,
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
   @cpa_LocType                NVARCHAR(10)  ,
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
      @cpa_LocationFlagInclude03      =  LocationFlagInclude03         ,
      @cpa_LocationCategoryInclude01  =  LocationCategoryInclude01     ,
      @cpa_LocationCategoryInclude02  =  LocationCategoryInclude02 ,
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
      SET ROWCOUNT 0
      IF @b_debug = 1
      BEGIN
         SELECT @c_reason = 'CHANGE of Putaway Type to ' + @cpa_PAType
         EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
         @c_putawaystrategylinenumber, @n_ptracedetailkey,
         '', @c_reason
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
                        EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
                     EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
               @c_putawaystrategylinenumber, @n_ptracedetailkey,
               @c_toloc, @c_reason
            END
         END

         CONTINUE
      END

      IF @cpa_PAType = '02' or -- IF source is FROMLOC then move to a location within the specified zone
         @cpa_PAType = '04' or -- Search ZONE specified on this strategy record
         @cpa_PAType = '12'    -- Search ZONE specified in sku table
      BEGIN
         IF @cpa_PAType = '02'
         BEGIN
            IF @c_fromloc = @cpa_fromloc
            BEGIN
               SELECT @c_searchzone = @cpa_zone
            END
         END
         IF @cpa_PAType = '04'
         BEGIN
            SELECT @c_searchzone = @cpa_zone
         END
         IF @cpa_PAType = '12'
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
                  SELECT @c_reason = 'FAILED PAType=12: Commodity and Storer combination not found'
                  EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
                  @c_putawaystrategylinenumber, @n_ptracedetailkey,
                  @c_toloc, @c_reason
               END

               CONTINUE -- This search does not apply because there is no sku
            END
         END

         IF dbo.fnc_LTrim(@c_searchzone) IS NOT NULL
         BEGIN
            IF @cpa_LocSearchType = '1' -- Search Zone By Location Code
            BEGIN 
               DECLARE @n_StdCube float
               DECLARE @c_SelectSQL nvarchar(4000) 
               DECLARE @c_LocFlagRestriction nvarchar(1000)
               DECLARE @c_LocTypeRestriction nvarchar(1000)
               DECLARE @n_NoOfInclude int
               DECLARE @c_DimRestSQL nvarchar(3000) 
   
               SELECT @n_StdCube =  Sku.StdCube, 
                      @n_StdGrossWgt = Sku.StdGrossWgt
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
                     ' SET ROWCOUNT 1 ' + 
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
                     ' ORDER BY LOC.LOC '
      
                     -- modify by SHONG on 15-JAN-2004
                     -- to disable further checking of all locationstaterestriction = '1'
                     IF @cpa_LocationStateRestriction1 = '1'
                     BEGIN
                        select @cpa_LocationStateRestriction1 = '',
                        @cpa_LocationStateRestriction2 = '',
                        @cpa_LocationStateRestriction3 = ''
                     END
   						IF @n_NoOfInclude = 1 
   						BEGIN
   							SELECT @cpa_LocationTypeExclude01 = ''
   						END
                   
                  END -- loc must be empty
                  ELSE IF '3' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
                  BEGIN -- do not mix lot
                     SELECT @c_SelectSQL =
                     ' SET ROWCOUNT 1 ' + 
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
                     SELECT @c_DimRestSQL = ''
                     IF '1' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                     @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        IF dbo.fnc_RTrim(@c_DimRestSQL) IS NULL OR dbo.fnc_RTrim(@c_DimRestSQL) = ''
                           SELECT @c_DimRestSQL = ' HAVING '
                        ELSE
                           SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' AND '
         
								-- Changed by June 15.Jul.2004 - SOS25233
                        -- SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' MAX(LOC.Cube) - ' +
								SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' MAX(LOC.CubicCapacity) - ' +
                        '( ( SUM(ISNULL(LOTxLOCxID.Qty, 0)) - SUM(ISNULL(LOTxLOCxID.QtyPicked,0)) + SUM(ISNULL(LOTxLOCxID.PendingMoveIn,0))) ' +
                        '* ' + dbo.fnc_RTrim(CAST(@n_StdCube as NVARCHAR(20))) + ') >= (' + dbo.fnc_RTrim(CAST(@n_StdCube as NVARCHAR(20))) + ' * ' + dbo.fnc_RTrim(CAST(@n_Qty as NVARCHAR(10))) + ')'
                     END
         
                     -- Fit by Weight
                     IF '3' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                     @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        IF dbo.fnc_RTrim(@c_DimRestSQL) IS NULL OR dbo.fnc_RTrim(@c_DimRestSQL) = ''
                           SELECT @c_DimRestSQL = ' HAVING '
                        ELSE
                           SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' AND '
         

								-- Changed by June 15.Jul.2004 - SOS25233
                        -- SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' MAX(LOC.Cube) - ' +
                        SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' MAX(LOC.WeightCapacity) - ' +
                        '( ( SUM(ISNULL(LOTxLOCxID.Qty, 0)) - SUM(ISNULL(LOTxLOCxID.QtyPicked,0)) + SUM(ISNULL(LOTxLOCxID.PendingMoveIn,0))) ' +
                        '* ' + dbo.fnc_RTrim(CAST(@n_StdGrossWgt as NVARCHAR(20))) + ') >= (' + dbo.fnc_RTrim(CAST(@n_StdGrossWgt as NVARCHAR(20))) + ' * ' + dbo.fnc_RTrim(CAST(@n_Qty as NVARCHAR(10))) + ')'
                     END
         
                     SELECT @c_SelectSQL = dbo.fnc_RTrim(@c_SelectSQL) + @c_DimRestSQL + 
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
                     ' SET ROWCOUNT 1 ' + 
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
                     SELECT @c_DimRestSQL = ''
                     IF '1' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                     @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        IF dbo.fnc_RTrim(@c_DimRestSQL) IS NULL OR dbo.fnc_RTrim(@c_DimRestSQL) = ''
                           SELECT @c_DimRestSQL = ' HAVING '
                        ELSE
                           SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' AND '
                  
								-- Changed by June 15.Jul.2004 - SOS25233
                        -- SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' MAX(LOC.Cube) - ' +
                        SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' MAX(LOC.CubicCapacity) - ' +
                        '( ( SUM(ISNULL(LOTxLOCxID.Qty, 0)) - SUM(ISNULL(LOTxLOCxID.QtyPicked,0)) + SUM(ISNULL(LOTxLOCxID.PendingMoveIn,0))) ' +
                        '* ' + dbo.fnc_RTrim(CAST(@n_StdCube as NVARCHAR(20))) + ') >= (' + dbo.fnc_RTrim(CAST(@n_StdCube as NVARCHAR(20))) + ' * ' + dbo.fnc_RTrim(CAST(@n_Qty as NVARCHAR(10))) + ')'
                     END
                  
                     -- Fit by Weight
                     IF '3' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                     @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        IF dbo.fnc_RTrim(@c_DimRestSQL) IS NULL OR dbo.fnc_RTrim(@c_DimRestSQL) = ''
                           SELECT @c_DimRestSQL = ' HAVING '
                        ELSE
                           SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' AND '
                  
                        SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' MAX(LOC.WeightCapacity) - ' +
                        '( ( SUM(ISNULL(LOTxLOCxID.Qty, 0)) - SUM(ISNULL(LOTxLOCxID.QtyPicked,0)) + SUM(ISNULL(LOTxLOCxID.PendingMoveIn,0))) ' +
                        '* ' + dbo.fnc_RTrim(CAST(@n_StdGrossWgt as NVARCHAR(20))) + ') >= (' + dbo.fnc_RTrim(CAST(@n_StdGrossWgt as NVARCHAR(20))) + ' * ' + dbo.fnc_RTrim(CAST(@n_Qty as NVARCHAR(10))) + ')'
                     END
                  
                     SELECT @c_SelectSQL = dbo.fnc_RTrim(@c_SelectSQL) + @c_DimRestSQL +
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
                        SELECT @c_DimRestSQL = ''
                        IF '1' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                        @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                        BEGIN
                           IF dbo.fnc_RTrim(@c_DimRestSQL) IS NULL OR dbo.fnc_RTrim(@c_DimRestSQL) = ''
                              SELECT @c_DimRestSQL = ' HAVING '
                           ELSE
                              SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' AND '
                  
								-- Changed by June 15.Jul.2004 - SOS25233
                        -- SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + 'MAX(LOC.Cube) - ' +
                           SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' MAX(LOC.CubicCapacity) - ' +
                           '( SUM(( ISNULL(LOTxLOCxID.Qty, 0) - ISNULL(LOTxLOCxID.QtyPicked,0) + ISNULL(LOTxLOCxID.PendingMoveIn,0) ) ' +
                           ' * ISNULL(SKU.StdCube,0) )) >= (' + dbo.fnc_RTrim(CAST(@n_StdCube as NVARCHAR(20))) + ' * ' + dbo.fnc_RTrim(CAST(@n_Qty as NVARCHAR(10))) + ')'
                        END
                  
                        -- Fit by Weight
                        IF '3' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                        @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                        BEGIN
                           IF dbo.fnc_RTrim(@c_DimRestSQL) IS NULL OR dbo.fnc_RTrim(@c_DimRestSQL) = ''
                           SELECT @c_DimRestSQL = ' HAVING '
                        ELSE
                           SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' AND '
                  
                           SELECT @c_DimRestSQL = dbo.fnc_RTrim(@c_DimRestSQL) + ' MAX(LOC.WeightCapacity)  - ' +
                           ' ( SUM(( ISNULL(LOTxLOCxID.Qty, 0) - ISNULL(LOTxLOCxID.QtyPicked,0) + ISNULL(LOTxLOCxID.PendingMoveIn,0) ) ' +
                           ' * ISNULL(SKU.StdGrossWgt,0) )) >= (' + dbo.fnc_RTrim(CAST(@n_StdGrossWgt as NVARCHAR(20))) + ' * ' + dbo.fnc_RTrim(CAST(@n_Qty as NVARCHAR(10))) + ')'
                        END
                  
                        SELECT @c_SelectSQL = dbo.fnc_RTrim(@c_SelectSQL) + @c_DimRestSQL +
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

                  SELECT @c_toloc = SPACE(10)
                  SELECT @cpa_toloc = SPACE(10)
               

               WHILE (1=1)
               BEGIN
                  -- print @c_SelectSQL
                  SELECT @c_toloc = SPACE(10)
                  EXEC sp_executesql @c_SelectSQL, N'@c_LastLoc NVARCHAR(10), @c_Loc NVARCHAR(10) output', @cpa_toloc, @c_toloc output
                  
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
                     PATYPE02_BYLOC:
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
               END -- While 

               SET ROWCOUNT 0
               IF @b_gotloc = 1
               BEGIN
                  IF @b_debug = 1
                  BEGIN
                     SELECT @c_reason = 'FOUND PAType=' + @cpa_PAType + ': Search Type by Location'
                     EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
                     @c_putawaystrategylinenumber, @n_ptracedetailkey,
                     @c_toloc, @c_reason
                  END

                  BREAK
               END
            END -- @cpa_LocSearchType = '1' 
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
                     AND Facility = @c_Facility -- SOS6421
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
                        EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
                           @c_putawaystrategylinenumber, @n_ptracedetailkey,
                           @c_toloc, @c_reason
                     END

                     BREAK
                  END
               END
            END -- dbo.fnc_LTrim(dbo.fnc_RTrim(@c_searchzone)) IS NOT NULL

            CONTINUE
         END
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
                        EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
                     EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
         BEGIN
            IF @b_MultiProductID = 0
            BEGIN
               SELECT @c_toloc = ''
               WHILE (1=1)
               BEGIN
                  SET ROWCOUNT 1

                  SELECT @c_toloc = SKUxLOC.LOC
                  FROM SKUxLOC (NOLOCK)
                  JOIN LOC (NOLOCK) ON LOC.Loc = SKUxLOC.Loc -- SOS6421 
                  WHERE StorerKey = @c_StorerKey
                  AND SKU = @c_sku
                  AND Loc.Facility = @c_Facility -- SOS6421
                  AND SKUxLOC.LOCATIONTYPE = 'PICK'                  
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
                  IF @cpa_PAType = '07'
                  BEGIN
                     -- Added By SHONG 
                     IF EXISTS(SELECT *
                        FROM SKUxLOC (NOLOCK)
                        JOIN  LOC (NOLOCK) ON (LOC.LOC = SKUxLOC.LOC)
                        WHERE SKUxLOC.StorerKey = @c_StorerKey
                        AND  SKUxLOC.Sku = @c_sku
                        AND Loc.Facility = @c_Facility 
                        AND (SKUxLOC.Qty - SKUxLOC.QtyPicked) > 0
                        AND SKUxLOC.LOC <> @c_FromLoc )
                     BEGIN
                        SELECT @c_toloc = ''
                        IF @b_debug = 1
                        BEGIN
                           SELECT @c_reason = 'FAILED PAType=07: Commodity has balance-on-hand qty'
                           EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
                              @c_putawaystrategylinenumber, @n_ptracedetailkey,
                              @c_toloc, @c_reason
                        END
                        BREAK
                     END
                  END
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
               END -- While 1=1
               SET ROWCOUNT 0
               IF @b_gotloc = 1
               BEGIN
                  IF @b_debug = 1
                  BEGIN
                     SELECT @c_reason = 'FOUND PAType=' + @cpa_PAType + ': Putaway to Assigned Piece Pick'
                     EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
                        @c_putawaystrategylinenumber, @n_ptracedetailkey,
                        @c_toloc, @c_reason
                  END
                  BREAK
               END
            END -- IF @b_MultiProductID = 0
            CONTINUE
         END -- IF @cpa_PAType = '8'
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
                           EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
                        EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
                  EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
                        @c_putawaystrategylinenumber, @n_ptracedetailkey,
                        @c_toloc, @c_reason
               END
            END
         END -- IF @b_MultiProductID = 0
         CONTINUE
      END -- IF @cpa_PAType = '9'
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
               JOIN LOC (NOLOCK) ON LOC.Loc = SKUxLOC.Loc -- SOS6421
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
            END -- WHILE 1=1
            SET ROWCOUNT 0
            IF @b_gotloc = 1
            BEGIN
               IF @b_debug = 1
               BEGIN
                  SELECT @c_reason = 'FOUND PAType=15: Putaway to Assogned Case Pick'
                  EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
         UPDATE PTRACEHEAD SET EndTime = getdate(), PA_locFound = @c_toloc, PA_LocsReviewed = @n_locsreviewed
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
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
               SELECT @c_reason = 'PASSED Location category ' + dbo.fnc_RTrim(@c_loc_category) + ' was one of the specified values'
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
            EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
            @c_putawaystrategylinenumber, @n_ptracedetailkey,
            @c_toloc, @c_reason
         END
      END
      ELSE
      BEGIN
         IF EXISTS(SELECT *
            FROM LOTxLOCxID (NOLOCK)
            WHERE LOC = @c_toloc
            AND (QTY > 0 OR PendingMoveIN > 0)
            AND (StorerKey <> @c_StorerKey
            OR  SKU <> @c_sku))
         BEGIN
            IF @b_debug = 1
            BEGIN
               SELECT @c_reason = 'INFO   Commingled Sku Current Loc/Putaway Pallet Situation'
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
            EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
            @c_putawaystrategylinenumber, @n_ptracedetailkey,
            @c_toloc, @c_reason
         END
      END
      ELSE
      BEGIN
         IF EXISTS(SELECT *
            FROM LOTxLOCxID (NOLOCK)
            WHERE LOC = @c_toloc
            AND (QTY > 0 OR PendingMoveIN > 0)
            AND LOT <> @c_lot)
         BEGIN
            IF @b_debug = 1
            BEGIN
               SELECT @c_reason = 'INFO   Commingled Lot Current Loc/Putaway Pallet Situation'
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
      SELECT @cpa_areatypeexclude01 = dbo.fnc_LTrim(@cpa_areatypeexclude01)
      IF @cpa_areatypeexclude01 IS NOT NULL
      BEGIN
         IF EXISTS(SELECT *
            FROM AREADETAIL (NOLOCK)
            WHERE PUTAWAYZONE = @c_loc_zone
            AND AREAKEY = @cpa_areatypeexclude01)
         BEGIN
            IF @b_debug = 1
            BEGIN
               SELECT @c_reason = 'FAILED Zone: ' + dbo.fnc_RTrim(@c_loc_zone) + ' falls in excluded Area1: ' +  dbo.fnc_RTrim(@cpa_areatypeexclude01)
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
            EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
            @c_putawaystrategylinenumber, @n_ptracedetailkey,
            @c_toloc, @c_reason
         END
      END
   END
   SELECT @cpa_areatypeexclude02 = dbo.fnc_LTrim(@cpa_areatypeexclude02)
   IF @cpa_areatypeexclude02 IS NOT NULL
   BEGIN
      IF EXISTS(SELECT *
         FROM AREADETAIL (NOLOCK)
         WHERE PUTAWAYZONE = @c_loc_zone
         AND AREAKEY = @cpa_areatypeexclude02)
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_reason = 'FAILED Zone: ' + dbo.fnc_RTrim(@c_loc_zone) + ' falls in excluded Area2: ' +  dbo.fnc_RTrim(@cpa_areatypeexclude02)
            EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
            EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
            @c_putawaystrategylinenumber, @n_ptracedetailkey,
            @c_toloc, @c_reason
         END
      END
   END
   SELECT @cpa_areatypeexclude03 = dbo.fnc_LTrim(@cpa_areatypeexclude03)
   IF @cpa_areatypeexclude03 IS NOT NULL
   BEGIN
      IF EXISTS(SELECT *
         FROM AREADETAIL (NOLOCK)
         WHERE PUTAWAYZONE = @c_loc_zone
         AND AREAKEY = @cpa_areatypeexclude03)
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_reason = 'FAILED Zone: ' + dbo.fnc_RTrim(@c_loc_zone) + ' falls in excluded Area3:' +  dbo.fnc_RTrim(@cpa_areatypeexclude03)
            EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
            EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
            @c_putawaystrategylinenumber, @n_ptracedetailkey,
            @c_toloc, @c_reason
         END
      END
   END
   IF '1' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
   BEGIN
      IF EXISTS(SELECT *
         FROM LOTxLOCxID (NOLOCK)
         WHERE LOC = @c_toloc
         AND (QTY > 0 or PendingMoveIN > 0))
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_reason = 'FAILED Location state says Location must be empty, but its not'
            EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
            EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
            EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
            EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
            EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
            EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
            @c_putawaystrategylinenumber, @n_ptracedetailkey,
            @c_toloc, @c_reason
         END
      END
   END
   IF '4' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
   BEGIN
      -- get the pallet setup
      SELECT @n_MaxPallet = (CASE MaxPallet WHEN NULL THEN 0 ELSE MaxPallet END)
      FROM  LOC (NOLOCK)
      WHERE LOC = @c_toloc

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
                                  
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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

               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
               @c_putawaystrategylinenumber, @n_ptracedetailkey,
               @c_toloc, @c_reason
            END
         END

      END
   END
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

   IF  '1' IN (@cpa_DimensionRestriction01,
            @cpa_DimensionRestriction02,
            @cpa_DimensionRestriction03,
            @cpa_DimensionRestriction04,
            @cpa_DimensionRestriction05,
            @cpa_DimensionRestriction06)
   BEGIN
      IF  @n_currlocmultilot = 0
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
         
            SELECT @n_toqty = SUM(LotxLocxId.Qty - LotxLocxId.QtyPicked + LotxLocxID.PendingMoveIn)
            FROM LotxLocxId (NOLOCK)
            WHERE LotxLocxId.StorerKey = @c_StorerKey
            AND LotxLocxId.Sku = @c_SKU
            AND LotxLocxId.Loc = @c_toloc
            AND (LotxLocxID.Qty > 0
            OR  LotxLocxID.PendingMoveIn > 0)
   
            IF @n_toqty IS NULL
            BEGIN
               SELECT @n_toqty = 0
            END
            IF (@n_toqty + @n_qty ) > @n_QuantityCapacity
            BEGIN
               IF @b_debug = 1
               BEGIN
                  SELECT @c_reason = 'FAILED Qty Fit: QtyCapacity = ' + dbo.fnc_RTrim(CONVERT(char(10),@n_QuantityCapacity)) + '  QtyRequired = ' + dbo.fnc_RTrim(Convert(char(10),(@n_toqty + @n_qty)))
                  EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
               @c_putawaystrategylinenumber, @n_ptracedetailkey,
               @c_toloc, @c_reason
            END
         END
      END
      ELSE
      BEGIN
         SELECT @n_tocube = SUM((LotxLocxId.Qty - LotxLocxId.QtyPicked + LotxLocxID.PendingMoveIn) * Sku.StdCube)
         FROM LotxLocxId (NOLOCK) ,Sku (NOLOCK)
         WHERE LotxLocxId.StorerKey = Sku.StorerKey
         AND LotxLocxId.Sku = Sku.Sku
         AND LotxLocxId.Loc = @c_toloc
         AND (LotxLocxID.Qty > 0
         OR  LotxLocxID.PendingMoveIn > 0)
         IF dbo.fnc_LTrim(@c_id) IS NOT NULL
         BEGIN
            SELECT @n_fromcube = SUM((LotxLocxId.Qty - LotxLocxId.QtyPicked) * Sku.StdCube)
            FROM LotxLocxId (NOLOCK), Sku (NOLOCK) 
            WHERE LotxLocxId.StorerKey = Sku.StorerKey
            AND LotxLocxId.Sku = Sku.Sku
            AND LotxLocxId.Loc = @c_fromloc
            AND LotxLocxID.Id = @c_id
            AND LotxLocxID.Qty > 0
         END
         ELSE
         BEGIN
            SELECT @n_fromcube = SUM((LotxLocxId.Qty - LotxLocxId.QtyPicked) * Sku.StdCube)
            FROM LotxLocxId (NOLOCK), Sku (NOLOCK)
            WHERE LotxLocxId.StorerKey = Sku.StorerKey
            AND LotxLocxId.Sku = Sku.Sku
            AND LotxLocxId.Loc = @c_fromloc
            AND LotxLocxID.Lot = @c_lot
            AND LotxLocxID.Qty > 0
         END
         IF @n_loc_cubiccapacity < ( @n_tocube + @n_fromcube )
         BEGIN
            IF @b_debug = 1
            BEGIN
               SELECT @c_reason = 'FAILED Cube Fit: CubeCapacity = ' + dbo.fnc_RTrim(CONVERT(char(10),@n_loc_cubiccapacity)) + '  CubeRequired = ' + dbo.fnc_RTrim(Convert(char(10),(@n_tocube + @n_fromcube)))
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
      IF  (@n_palletwoodwidth > @n_loc_width
         OR   @n_palletwoodlength > @n_loc_length)
         AND (@n_palletwoodwidth > @n_loc_length
         OR   @n_palletwoodlength > @n_loc_width)
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_reason = 'FAILED LxWxH Fit: Wood/LocWidth=' + CONVERT(char(4),@n_palletwoodwidth) + ' / ' + CONVERT(char(4),@n_loc_width) + '  Wood/locLength=' + CONVERT(char(4),@n_palletwoodlength) + ' / ' + CONVERT(char(4),@n_loc_length)
            EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
            EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
               @c_putawaystrategylinenumber, @n_ptracedetailkey,
               @c_toloc, @c_reason
         END
      END
      SELECT @n_existingquantity = SUM(LotxLocxID.Qty - LotxLocxId.QtyPicked + LotxLocxID.PendingMoveIn)
      FROM LOTxLOCxID (NOLOCK)
      WHERE LotxLocxId.StorerKey = @c_StorerKey
      AND LotxLocxId.Sku = @c_SKU
      AND LotxLocxId.Loc = @c_toloc
      AND (LotxLocxID.Qty > 0
      OR  LotxLocxID.PendingMoveIn > 0)

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
            EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
            EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
      SELECT @n_toweight = SUM((LotxLocxId.Qty - LotxLocxId.QtyPicked + LotxLocxID.PendingMoveIn) * Sku.StdGrossWgt)
      FROM LotxLocxId (NOLOCK), Sku (NOLOCK)
      WHERE LotxLocxId.StorerKey = Sku.StorerKey
      AND LotxLocxId.Sku = Sku.sku
      AND LotxLocxId.Loc = @c_toloc
      AND LotxLocxID.Qty > 0
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
         SELECT @n_fromweight = SUM((LotxLocxId.Qty - LotxLocxId.QtyPicked) * Sku.StdGrossWgt)
         FROM LotxLocxId (NOLOCK), Sku (NOLOCK)
         WHERE LotxLocxId.StorerKey = Sku.StorerKey
         AND LotxLocxId.Sku = Sku.sku
         AND LotxLocxId.Id = @c_id
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
            EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
            EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
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
               EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
               @c_putawaystrategylinenumber, @n_ptracedetailkey,
               @c_toloc, @c_reason
            END
         END
      END
   END
   
   /********************************************************************
   BEGIN - Modified by Teoh To Cater for Height Restriction 30/3/2000
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
            EXEC nspPTD 'nspAutoPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
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
            EXEC nspPTD 'nspAutoPASTD', @n_ptraceheadkey, @c_putawaystrategykey,
            @c_putawaystrategylinenumber, @n_ptracedetailkey,
            @c_toloc, @c_reason
         END   
      END
   END
   
   /********************************************************************
   END - Modified by Teoh To Cater for Height Restriction 30/3/2000
   *********************************************************************/
   RESTRICTIONCHECKDONE:
   IF @cpa_PAType = '01'
   
   BEGIN
      GOTO PATYPE01
   END
   IF @cpa_PAType = '02' or @cpa_PAType = '04' or @cpa_PAType = '12'
   BEGIN
      IF @cpa_LocSearchType = '1'
      BEGIN
         GOTO PATYPE02_BYLOC
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
   LOCATION_EXIT:
   IF @b_debug = 1
   BEGIN 
      EXEC nspPTD 'nspASNPASTDTH', @n_ptraceheadkey, @c_putawaystrategykey,
      @c_putawaystrategylinenumber, @n_ptracedetailkey,
      @c_toloc, @b_gotloc
   END
   IF @b_gotloc = 1
   BEGIN 
      SELECT @c_final_toloc = @c_toloc
   END
   GOTO LOCATION_DONE
   LOCATION_ERROR:
   SELECT @n_err = 99701
   SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': No Location. (nspASNPASTDTH)'
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   LOCATION_DONE:
   RETURN 
END

GO