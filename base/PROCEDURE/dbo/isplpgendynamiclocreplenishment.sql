SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispLPGenDynamicLocReplenishment                    */  
/* Creation Date: 21-Jun-2011                                           */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: SOS218874                                                   */  
/*          Replenishment and Dynamic Pick location assignment          */  
/*                                                                      */  
/* Called By: RCM Option From Load Plan maintenance Screen              */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 6.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/************************************************************************/  
CREATE PROC [dbo].[ispLPGenDynamicLocReplenishment] 
   @cLoadKey NVARCHAR(10),
   @bSuccess INT OUTPUT,
   @nErrNo   INT OUTPUT,
   @cErrMsg  NVARCHAR(215) OUTPUT
AS
BEGIN
    SET NOCOUNT ON			-- SQL 2005 Standard
    SET QUOTED_IDENTIFIER OFF
    SET ANSI_NULLS OFF
    SET CONCAT_NULL_YIELDS_NULL OFF
       
    DECLARE @cStartDynamicP_PalletLoc  NVARCHAR(20)
           --,@cStartDynamicP_RackLoc    NVARCHAR(20)
           ,@cDynamicP_PalletZone      NVARCHAR(10)
           --,@cDynamicP_RackZone        NVARCHAR(10)
           --,@nDynPalletCBM             FLOAT
           ,@cFacility                 NVARCHAR(5)
           ,@cSortGroup                NVARCHAR(30)
           ,@cStorerKey                NVARCHAR(15)
           ,@cSKU                      NVARCHAR(20)
           ,@cLOT                      NVARCHAR(10)
           ,@cLOC                      NVARCHAR(10)
           ,@cID                       NVARCHAR(18)
           ,@cNextDynPickLoc           NVARCHAR(10)
           --,@nRowID                    INT
           ,@cReplenishmentKey         NVARCHAR(10)
           --,@cPickDetailKey            NVARCHAR(10)
           ,@nQty                      INT
           ,@cDynamicPickLoc           NVARCHAR(10)
           ,@cPackKey                  NVARCHAR(10)
           ,@cUOM                      NVARCHAR(10)
           ,@cPickUOM                  NVARCHAR(10)
           ,@cReplenStrategykey        NVARCHAR(10)
           ,@nQtyBal                   INT
           ,@nCaseCnt                  INT
           ,@nReplenQty                INT
           ,@nFullCtnQty               INT
           ,@cDPP_LOT                  NVARCHAR(10)
           ,@cDPP_LOC                  NVARCHAR(10)
           ,@cDPP_ID                   NVARCHAR(18)


    DECLARE @bDebug                    INT
           ,@nContinue                 INT
           ,@nStartTranCount           INT
           ,@nErr                      INT   
    
    SELECT @nContinue = 0, @nErrNo = 0, @cErrMsg = '', @nStartTranCount = @@TRANCOUNT, @nErrNo = 70500, @bDebug = 0 
    
    IF @bSuccess=9
        SET @bDebug = 1
    
    BEGIN TRAN 
    
    SELECT @cStartDynamicP_PalletLoc = Loadplan.UserDefine02
          --,@cStartDynamicP_RackLoc = Loadplan.UserDefine03
    FROM   Loadplan WITH (NOLOCK)
    WHERE  LoadKey = @cLoadKey
    
    IF ISNULL(RTRIM(@cStartDynamicP_PalletLoc) ,'')=''
    BEGIN
        SET @nErrNo = @nErrNo+1
        SET @cErrMsg = 'Start Dynamic Pick Pallet Location Cannot Be Blank!'
        SET @nContinue = 3 
        GOTO ErrorHandling
    END 
    
    SELECT @cDynamicP_PalletZone = ISNULL(LOC.PutawayZone ,''), @cFacility = LOC.Facility
    FROM   LOC WITH (NOLOCK)
    WHERE  LOC = @cStartDynamicP_PalletLoc
    
    IF ISNULL(RTRIM(@cDynamicP_PalletZone) ,'')=''
    BEGIN
        SET @nErrNo = @nErrNo+1
        SET @cErrMsg = 'Putaway Zone for Pallet Start location: '+@cStartDynamicP_PalletLoc 
           +' is BLANK.'        
        SET @nContinue = 3 
        GOTO ErrorHandling
    END 
    
    /*
    SELECT @cDynamicP_RackZone = LOC.PutawayZone
    FROM   LOC WITH (NOLOCK)
    WHERE  LOC = @cStartDynamicP_RackLoc
    
    IF ISNULL(RTRIM(@cDynamicP_RackZone) ,'')=''
    BEGIN
        SET @nErrNo = @nErrNo+1
        SET @cErrMsg = 'Putaway Zone for Rack Start location: '+@cStartDynamicP_RackLoc 
           +' is BLANK.'        
        SET @nContinue = 3 
        GOTO ErrorHandling
    END 
    
    SELECT @nDynPalletCBM = ISNULL(SHORT ,'0')
    FROM   CodeLkUp WITH (NOLOCK)
    WHERE  ListName = 'DYNPICK' AND
           CODE = 'DynPalletCBM'
    
    IF ISNULL(RTRIM(@nDynPalletCBM) ,'0')='0'
    BEGIN
        SET @nErrNo = @nErrNo+1
        SET @cErrMsg = 
            'Dynamic Pallet Location CBM Not Found in Code Lookup Table '
        
        SET @nContinue = 3 
        GOTO ErrorHandling
    END
    
    IF ISNUMERIC(@nDynPalletCBM)<>1
    BEGIN
        SET @nErrNo = @nErrNo+1
        SET @cErrMsg = 'Dynamic Pallet Location CBM Is not Numeric '
        SET @nContinue = 3 
        GOTO ErrorHandling
    END
    */ 
    
    CREATE TABLE #DynPick
    (
       RowID           						INT IDENTITY(1 ,1)
       ,PickDetailKey  					 NVARCHAR(10)
       ,SortGroup      					 NVARCHAR(30)
       ,StorerKey      					 NVARCHAR(15)
       ,SKU            					 NVARCHAR(20)
       ,LOT            					 NVARCHAR(10)
       ,LOC            					 NVARCHAR(10)
       ,ID             					 NVARCHAR(18)
       ,Qty            						INT
       ,D_Pick_LOC     					 NVARCHAR(10)
       ,StdCube        						FLOAT
       ,Casecnt                   INT
       ,ReplenStrategyKey 			 NVARCHAR(10)
       ,PickUOM                   NVARCHAR(10)
       ,QtyBal                    INT
       ,Packkey                   NVARCHAR(10)
       ,UOM                       NVARCHAR(10)
    )
   
   -- Dynamic replenishment strategykey   
   -- 01 = Round down 100% with DPP. Dyn Loc Sort By Sku
   -- 02 = Round down 100% with DPP. Dyn Loc Sort By Style    
   
   -- Get bulk location Pickdetail for dynamic replenishment
    INSERT INTO #DynPick
      (PickDetailKey, SortGroup, StorerKey, SKU, LOT, LOC, ID, Qty, D_Pick_LOC, 
       StdCube, CaseCnt, ReplenStrategykey, PickUOM, QtyBal, Packkey, UOM)
    SELECT PickDetailKey
      		,CASE WHEN STRATEGY.ReplenishmentStrategyKey IN('02') THEN ISNULL(SKU.Style ,'') 
      	    		ELSE SKU.Sku END AS Sortgroup
          ,SKU.StorerKey
          ,SKU.SKU
          ,PICKDETAIL.LOT
          ,PICKDETAIL.LOC
          ,PICKDETAIL.ID
          ,PICKDETAIL.Qty
          ,'' AS D_Pick_Loc
          ,SKU.StdCube
          ,PACK.CaseCnt
          ,STRATEGY.ReplenishmentStrategyKey
          ,PICKDETAIL.UOM
          ,(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) 
          ,PACK.Packkey
          ,PACK.PackUOM3 
    FROM   PICKDETAIL WITH (NOLOCK)
           JOIN LOADPLANDETAIL WITH (NOLOCK)
                ON  LOADPLANDETAIL.OrderKey = PICKDETAIL.OrderKey
           JOIN SKU WITH (NOLOCK)
                ON  SKU.StorerKey = PICKDETAIL.StorerKey AND
                    SKU.SKU = PICKDETAIL.SKU
           JOIN LOC WITH (NOLOCK)
                ON  LOC.LOC = PICKDETAIL.LOC AND
                    LOC.LocationType NOT IN ('DYNPICKP' ,'DYNPPICK')
                    --LOC.LocationType NOT IN ('DYNPICKP', 'DYNPICKR', 'DYNPPICK')
           JOIN SKUxLOC WITH (NOLOCK)
                ON  SKUxLOC.StorerKey = PICKDETAIL.StorerKey AND
                    SKUxLOC.SKU = PICKDETAIL.SKU AND
                    SKUxLOC.LOC = PICKDETAIL.LOC AND
                    SKUxLOC.LocationType NOT IN ('PICK' ,'CASE')
           JOIN LOTxLOCxID LLI WITH (NOLOCK)
                ON  LLI.LOT = PICKDETAIL.LOT AND                    
                    LLI.LOC = PICKDETAIL.LOC AND
                    LLI.ID = PICKDETAIL.ID 
           JOIN STRATEGY WITH (NOLOCK) ON SKU.StrategyKey = STRATEGY.StrategyKey
           JOIN PACK WITH (NOLOCK) ON SKU.PACKKey = PACK.PackKey
    WHERE  LOADPLANDETAIL.LoadKey = @cLoadKey 
    
    IF @@ROWCOUNT = 0
    BEGIN
        SET @nErrNo = @nErrNo+1
        SET @cErrMsg = 'No Bulk Pick Detail To Replenish'
        SET @nContinue = 3 
        GOTO ErrorHandling
    END 
    
    CREATE UNIQUE CLUSTERED INDEX IX_DynPick_RowID ON #DynPick(RowID)
    
    CREATE TABLE #DYNPICK_PALLET (TOLOC NVARCHAR(10))
    
    --Dynamic pick loc in replenishment
    INSERT INTO #DYNPICK_PALLET (TOLOC)
       SELECT R.TOLOC
       FROM   REPLENISHMENT R WITH (NOLOCK)
              JOIN LOC WITH (NOLOCK) ON  R.TOLOC = LOC.LOC
       WHERE  LOC.LocationType IN ('DYNPICKP') AND
              LOC.PutawayZone = @cDynamicP_PalletZone AND
              LOC.Facility = @cFacility AND
              R.Confirmed<>'Y'
       GROUP BY R.TOLOC
       HAVING SUM(R.Qty)>0 

    CREATE TABLE #DYNPPICK_SKU (TOLOC NVARCHAR(10))
    
    --Dynamic permanent pick loc in replenishment
    INSERT INTO #DYNPPICK_SKU (TOLOC)
       SELECT R.TOLOC
       FROM   REPLENISHMENT R WITH (NOLOCK)
              JOIN LOC WITH (NOLOCK) ON  R.TOLOC = LOC.LOC
       WHERE  LOC.LocationType IN('DYNPPICK') AND
              --LOC.PutawayZone = @cDynamicP_PalletZone AND
              LOC.Facility = @cFacility AND
              R.Confirmed<>'Y'
       GROUP BY R.TOLOC
       HAVING SUM(R.Qty)>0 
    
    /*
    CREATE TABLE #DYNPICK_RACK (TOLOC NVARCHAR(10))
    
    INSERT INTO #DYNPICK_RACK (TOLOC)
       SELECT R.TOLOC
       FROM   REPLENISHMENT R WITH (NOLOCK)
              JOIN LOC WITH (NOLOCK)
                   ON  R.TOLOC = LOC.LOC
       WHERE  LOC.LocationType = ('DYNPICKR') AND
              LOC.PutawayZone = @cDynamicP_RackZone AND
              LOC.Facility = @cFacility AND
              R.Confirmed<>'Y'
       GROUP BY R.TOLOC
       HAVING SUM(R.Qty)>0 
    
    CREATE TABLE #DP_RACK_NON_EMPTY (LOC NVARCHAR(10))     
    
    INSERT INTO #DP_RACK_NON_EMPTY (LOC)
       SELECT SKUxLOC.LOC
       FROM   SKUxLOC WITH (NOLOCK)
              JOIN LOC WITH (NOLOCK)
                   ON  SKUxLOC.LOC = LOC.LOC
       WHERE  LOC.LocationType = ('DYNPICKR') AND
              LOC.PutawayZone = @cDynamicP_RackZone AND
              LOC.Facility = @cFacility
       GROUP BY
              SKUxLOC.LOC
       HAVING SUM(Qty)>0
    */
    
    CREATE TABLE #DP_PALLET_NON_EMPTY (LOC NVARCHAR(10)) 
     
    --Dynamic pick loc with qty  
    INSERT INTO #DP_PALLET_NON_EMPTY (LOC)
       SELECT SKUxLOC.LOC
       FROM   SKUxLOC WITH (NOLOCK)
              JOIN LOC WITH (NOLOCK) ON SKUxLOC.LOC = LOC.LOC
       WHERE  LOC.LocationType IN ('DYNPICKP') AND
              LOC.PutawayZone = @cDynamicP_PalletZone AND
              LOC.Facility = @cFacility
       GROUP BY SKUxLOC.LOC
       HAVING SUM(Qty)>0

    CREATE TABLE #DPP_SKU_NON_EMPTY (LOC NVARCHAR(10)) 
      
    --Dynamic permanent pick loc with qty  
    INSERT INTO #DPP_SKU_NON_EMPTY(LOC)
       SELECT SKUxLOC.LOC
       FROM   SKUxLOC WITH (NOLOCK)
              JOIN LOC WITH (NOLOCK) ON SKUxLOC.LOC = LOC.LOC
       WHERE  LOC.LocationType IN ('DYNPPICK') AND
              --LOC.PutawayZone = @cDynamicP_PalletZone AND
              LOC.Facility = @cFacility
       GROUP BY SKUxLOC.LOC
       HAVING SUM(Qty)>0

    
    CREATE TABLE #SKUSortGroup
    (
       StorerKey          NVARCHAR(15)
       ,SKU               NVARCHAR(20)
       ,SortGroup         NVARCHAR(30)
       ,ReplenStrategyKey NVARCHAR(10)
    )
    
    INSERT INTO #SKUSortGroup (StorerKey, SKU, SortGroup, ReplenStrategyKey)      
       SELECT DISTINCT S.Storerkey, S.Sku, 
            CASE WHEN SY.ReplenishmentStrategykey IN('02') THEN ISNULL(S.Style,'') ELSE S.SKU END AS SortGroup, 
            SY.ReplenishmentStrategykey 
       FROM SKU S WITH (NOLOCK)
       JOIN STRATEGY SY WITH (NOLOCK) 
            ON  SY.Strategykey = S.Strategykey
       JOIN #DynPick DynPick ON DynPick.Storerkey = S.Storerkey          
    
    -- Assign Pallet Dynamic Pick Location for Total Cube > DynPalletCBM
    -- Initial the Value
    SELECT @cNextDynPickLoc = '' 
        
    DECLARE CUR_DynPallet_SortGroup CURSOR LOCAL FAST_FORWARD READ_ONLY 
    FOR
        SELECT StorerKey, ReplenStrategyKey, SortGroup             
        FROM   #DynPick
        WHERE  PickUOM = '2' --Full Case
        GROUP BY StorerKey, SortGroup, ReplenStrategyKey
        ORDER BY StorerKey, SortGroup, ReplenStrategyKey
    
    OPEN CUR_DynPallet_SortGroup
    
    FETCH NEXT FROM CUR_DynPallet_SortGroup INTO @cStorerKey, @cReplenStrategykey, @cSortGroup                                 
    WHILE @@FETCH_STATUS<>-1
    BEGIN
        GetNextDynamicPickPalletLocation:
        
        SET @cNextDynPickLoc = ''
        
        -- Find any Dynamic pick location already assign with same style?
        -- if yes, then assign same location to this style
        -- Get From Temp Table 1st
        /*SELECT TOP 1 @cNextDynPickLoc = D_Pick_Loc
        FROM   #DynPick
        WHERE  SortGroup = @cSortGroup
        AND PickUOM = '2'
        AND Storerkey = @cStorerKey
        AND ReplenStrategykey = @cReplenStrategykey*/
        
        -- Assign loc with same style/sku already assigned in other replenishment
        IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')=''
        BEGIN            
            SELECT TOP 1
                   @cNextDynPickLoc = LOC.LOC
            FROM   REPLENISHMENT REP WITH (NOLOCK)
                   JOIN #SKUSortGroup SKUSortGroup
                        ON  SKUSortGroup.StorerKey = REP.StorerKey AND
                            SKUSortGroup.SKU = REP.SKU
                   JOIN LOC WITH (NOLOCK)
                        ON  REP.TOLOC = LOC.LOC
            WHERE  SKUSortGroup.SortGroup = @cSortGroup AND
                   LOC.LocationType IN ('DYNPICKP') AND
                   LOC.PutawayZone = @cDynamicP_PalletZone AND
									 LOC.LOC >= @cStartDynamicP_PalletLoc AND
                   REP.Confirmed <> 'Y' AND
                   REP.Qty > 0 AND
                   SKUSortGroup.Storerkey = @cStorerkey AND
                   SKUSortGroup.ReplenStrategyKey = @cReplenStrategykey                    
        END
        
        -- Assign loc with same style/sku and qty available
        IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')=''
        BEGIN
            
            SELECT TOP 1
                   @cNextDynPickLoc = LOC.LOC
            FROM   LotxLocxID LLI WITH (NOLOCK)
                   JOIN #SKUSortGroup SKUSortGroup
                        ON  SKUSortGroup.StorerKey = LLI.StorerKey AND
                            SKUSortGroup.SKU = LLI.SKU
                   JOIN LOC WITH (NOLOCK)
                        ON  LLI.LOC = LOC.LOC
            WHERE  SKUSortGroup.SortGroup = @cSortGroup AND
                   LOC.LocationType IN ('DYNPICKP') AND
                   LOC.PutawayZone = @cDynamicP_PalletZone AND
									 LOC.LOC >= @cStartDynamicP_PalletLoc AND
                   (LLI.Qty- LLI.QtyPicked+LLI.QtyAllocated)<>0 AND
                   SKUSortGroup.Storerkey = @cStorerkey AND
                   SKUSortGroup.ReplenStrategyKey = @cReplenStrategykey 
                   
        END
        
        -- If no location with same style/sku found, then assign the empty location
        IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')=''
        BEGIN
            SELECT TOP 1 @cNextDynPickLoc = LOC.LOC
            FROM   LOC WITH (NOLOCK) 
            WHERE  LOC.Facility = @cFacility AND
                   LOC.LocationType IN ('DYNPICKP') AND
                   LOC.PutawayZone = @cDynamicP_PalletZone AND
                   LOC.LOC>= @cStartDynamicP_PalletLoc AND
                   NOT EXISTS(
                       SELECT 1
                       FROM   #DP_PALLET_NON_EMPTY E
                       WHERE  E.LOC = LOC.LOC
                   ) AND
                   NOT EXISTS(
                       SELECT 1
                       FROM   #DYNPICK_PALLET AS ReplenLoc
                       WHERE  ReplenLoc.TOLOC = LOC.LOC
                   ) AND
                   NOT EXISTS(
                       SELECT 1
                       FROM   #DynPick AS DynPick
                       WHERE  DynPick.D_Pick_Loc = LOC.LOC
                   )
            ORDER BY
                   LOC.LOC
        END 
        
        -- If no more DP loc then goto to last DP loc
        IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')=''
        BEGIN
            SELECT TOP 1 @cNextDynPickLoc = LOC.LOC
            FROM   LOC WITH (NOLOCK)
            WHERE  LOC.LocationType IN ('DYNPICKP') AND
                   LOC.PutawayZone = @cDynamicP_PalletZone AND
                   LOC.Facility = @cFacility
            ORDER BY
                   LOC.LOC DESC
        END
        
        IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')=''
        BEGIN
            SET @nErrNo = @nErrNo+1
            SET @cErrMsg = 
                'Dynamic Pallet Location Not Setup / Not enough Dynamic Pallet Location.'
            
            SET @nContinue = 3 
            GOTO ErrorHandling
        END 
        
        --select @cDynamicP_PalletZone '@cDynamicP_PalletZone', @cFacility '@cFacility', @cNextDynPickLoc '@cNextDynPickLoc',
        --@cStyle '@cStyle'
        
        UPDATE #DynPick
        SET    D_Pick_Loc = @cNextDynPickLoc
        WHERE  StorerKey = @cStorerKey AND
               SortGroup = @cSortGroup AND
               ReplenStrategyKey = @cReplenStrategykey AND 
               PickUOM = '2'  --Full case
        
        FETCH NEXT FROM CUR_DynPallet_SortGroup INTO @cStorerKey, @cReplenStrategykey, @cSortGroup
    END 
    CLOSE CUR_DynPallet_SortGroup
    DEALLOCATE CUR_DynPallet_SortGroup 
    
    --------------------------------------------------------------------------------------------
    /*
    DECLARE CUR_DynRack_SortGroup  CURSOR LOCAL FAST_FORWARD READ_ONLY 
    FOR
        SELECT StorerKey, ReplenStrategyKey, SortGroup           
        FROM   #DynPick
        WHERE  D_Pick_Loc = ''
        AND    PickUOM = '2'
        GROUP BY StorerKey ,SortGroup       
        HAVING SUM(Qty * ISNULL(StdCube,0))<@nDynPalletCBM
        ORDER BY StorerKey ,SortGroup           
    
    OPEN CUR_DynRack_SortGroup 
    
    FETCH NEXT FROM CUR_DynRack_SortGroup INTO @cStorerKey, @cReplenStrategykey, @cSortGroup                               
    WHILE @@FETCH_STATUS<>-1
    BEGIN
        DECLARE CUR_SortGroup_PickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY 
        FOR
            SELECT DISTINCT SKU
            FROM   #DynPick
            WHERE  StorerKey = @cStorerKey AND
                   SortGroup = @cSortGroup AND
                   PickUOM = '2' AND
                   ReplenStrategyKey = @cReplenStrategykey         
        
        OPEN CUR_SortGroup_PickDetail
        FETCH NEXT FROM CUR_SortGroup_PickDetail INTO @cSKU 
        WHILE @@FETCH_STATUS<>-1
        BEGIN
            SET @cNextDynPickLoc = ''
            
            -- Find any Dynamic pick location already assign with same style?
            -- if yes, then assign same location to this style
            SELECT TOP 1 @cNextDynPickLoc = D_Pick_Loc
            FROM   #DynPick DP
                   JOIN LOC WITH (NOLOCK)
                        ON  DP.D_Pick_Loc = LOC.LOC
            WHERE  SortGroup = @cSortGroup AND
                   StorerKey = @cStorerKey AND
                   SKU = @cSKU AND
                   PickUOM = '2' AND
                   ReplenStrategykey = @cReplenStrategykey AND
                   LOC.LocationType In ('DYNPICKR')
            
            IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')=''
            BEGIN                
                SELECT TOP 1
                       @cNextDynPickLoc = LOC.LOC
                FROM   LotxLocxID LLI WITH (NOLOCK)
                       JOIN LOC WITH (NOLOCK)
                            ON  LLI.LOC = LOC.LOC
                WHERE  LLI.StorerKey = @cStorerKey AND
                       LLI.SKU = @cSKU AND
                       LOC.LocationType IN ('DYNPICKR') AND
                       LOC.PutawayZone = @cDynamicP_RackZone AND
                       (LLI.Qty- LLI.QtyPicked+LLI.QtyAllocated)<>0
            END
            
            --select @cDynamicP_RackZone '@cDynamicP_RackZone', @cFacility '@cFacility', @cStartDynamicP_RackLoc '@cStartDynamicP_RackLoc',
            --@cStyle '@cStyle', @cSKU '@cSKU'
            
            -- If no location with same style found, then assign the empty location
            IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')=''
            BEGIN
                SELECT TOP 1 @cNextDynPickLoc = LOC.LOC
                FROM   LOC WITH (NOLOCK)
                       LEFT OUTER JOIN #DP_RACK_NON_EMPTY AS NonEmptyLoc
                            ON  NonEmptyLoc.LOC = LOC.LOC
                       LEFT OUTER JOIN #DYNPICK_RACK AS ReplenLoc
                            ON  ReplenLoc.TOLOC = LOC.LOC
                       LEFT OUTER JOIN #DynPick AS DynPick
                            ON  DynPick.D_Pick_Loc = LOC.LOC
                WHERE  LOC.Facility = @cFacility AND
                       LOC.LocationType IN ('DYNPICKR') AND
                       LOC.PutawayZone = @cDynamicP_RackZone AND
                       LOC.LOC>= @cStartDynamicP_RackLoc AND
                       NonEmptyLoc.LOC IS NULL AND
                       ReplenLoc.TOLOC IS NULL AND
                       DynPick.D_Pick_Loc IS NULL
                ORDER BY
                       LOC.LOC
            END 
            
            -- If no more DP loc then goto last DP loc
            IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')=''
            BEGIN
                SELECT TOP 1 @cNextDynPickLoc = LOC.LOC
                FROM   LOC WITH (NOLOCK)
                WHERE  LOC.LocationType = ('DYNPICKR') AND
                       LOC.PutawayZone = @cDynamicP_PalletZone AND
                       LOC.Facility = @cFacility
                ORDER BY
                       LOC.LOC DESC
            END
            
            IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')=''
            BEGIN
                SET @nErrNo = @nErrNo+1
                SET @cErrMsg = 
                    'Dynamic Rack Location Not Setup / Not enough Dynamic Rack Location.'
                
                SET @nContinue = 3 
                GOTO ErrorHandling
            END 
            
            UPDATE #DynPick
            SET    D_Pick_Loc = @cNextDynPickLoc
            WHERE  StorerKey = @cStorerKey AND
                   SKU = @cSKU AND
                   SortGroup = @cSortGroup AND  
                   ReplenStrategyKey = @cReplenStrategykey AND 
                   PickUOM = '2'
            
            FETCH NEXT FROM CUR_SortGroup_PickDetail INTO @cSKU
        END 
        CLOSE CUR_SortGroup_PickDetail
        DEALLOCATE CUR_SortGroup_PickDetail
        
        FETCH NEXT FROM CUR_DynRack_SortGroup INTO @cStorerKey, @cReplenStrategykey, @cSortGroup                               
    END 
    CLOSE CUR_DynRack_SortGroup 
    DEALLOCATE CUR_DynRack_SortGroup 
     */
    -----------------------------------Assign Dynamic Permanent Pick or Permanent Pick Loc for loose qty--------------------------------------
    
    SELECT @cNextDynPickLoc = ''     
    
    DECLARE CUR_DynPP_SKU CURSOR LOCAL FAST_FORWARD READ_ONLY 
    FOR
        SELECT StorerKey, ReplenStrategyKey, Sku             
        FROM   #DynPick
        WHERE PickUOM <> '2'  --Loose qty
        GROUP BY StorerKey, Sku, ReplenStrategyKey
        ORDER BY StorerKey, Sku, ReplenStrategyKey
    
    OPEN CUR_DynPP_SKU 
    
    FETCH NEXT FROM CUR_DynPP_SKU INTO @cStorerKey, @cReplenStrategykey, @cSku                                 
    WHILE @@FETCH_STATUS<>-1
    BEGIN
        GetNextDynamicPPickLocation:
        
        SET @cNextDynPickLoc = ''
        
        -- Find any Dynamic pick location already assign with same style?
        -- if yes, then assign same location to this style
        -- Get From Temp Table 1st
        /*SELECT TOP 1 @cNextDynPickLoc = D_Pick_Loc
        FROM   #DynPick
        WHERE Sku = @cSku
        AND Storerkey = @cStorerKey
        AND UOM <> '1'*/
        
        -- Assign loc with same sku already assigned in other replenishment
        IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')=''
        BEGIN            
            SELECT TOP 1
                   @cNextDynPickLoc = LOC.LOC
            FROM   REPLENISHMENT REP WITH (NOLOCK)
                   JOIN LOC WITH (NOLOCK)
                        ON  REP.TOLOC = LOC.LOC
                   JOIN SKUXLOC SL WITH (NOLOCK) 
                        ON  REP.Storerkey = SL.Storerkey AND
                            REP.Sku = SL.Sku AND
                            REP.Toloc = SL.Loc
            WHERE  (LOC.LocationType IN ('DYNPPICK') OR SL.LocationType IN('PICK','CASE')) AND
                   REP.Confirmed <> 'Y' AND
                   REP.Qty > 0 AND
                   REP.Storerkey = @cStorerkey AND
                   REP.Sku = @cSku
        END

        -- Assign loc with same sku and qty available
        IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')=''
        BEGIN            
            SELECT TOP 1
                   @cNextDynPickLoc = LOC.LOC
            FROM   LotxLocxID LLI WITH (NOLOCK)
                   JOIN LOC WITH (NOLOCK)
                        ON  LLI.LOC = LOC.LOC
                   JOIN SKUXLOC SL WITH (NOLOCK) 
                        ON  LLI.Storerkey = SL.Storerkey AND
                            LLI.Sku = SL.Sku AND
                            LLI.Loc = SL.Loc
            WHERE  (LOC.LocationType IN ('DYNPPICK') OR SL.LocationType IN('PICK','CASE')) AND
                   (LLI.Qty- LLI.QtyPicked+LLI.QtyAllocated)<>0 AND
                   LLI.Storerkey = @cStorerkey AND
                   LLI.Sku = @cSku
        END

        -- Assign permanent pick loc
        IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')=''
        BEGIN            
            SELECT TOP 1
                   @cNextDynPickLoc = LOC.LOC
            FROM   SKUXLOC SL WITH (NOLOCK) 
                   JOIN LOC WITH (NOLOCK)
                        ON  SL.LOC = LOC.LOC
            WHERE  SL.LocationType IN('PICK','CASE') AND
                   SL.Storerkey = @cStorerkey AND
                   SL.Sku = @cSku AND
                   LOC.Facility = @cFacility
        END
        
        -- If no location with same sku found, then assign the empty location
        IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')=''
        BEGIN
            SELECT TOP 1 @cNextDynPickLoc = LOC.LOC
            FROM   LOC WITH (NOLOCK) 
            WHERE  LOC.Facility = @cFacility AND
                   LOC.LocationType IN ('DYNPPICK') AND
                   --LOC.PutawayZone = @cDynamicP_PalletZone AND
                   --LOC.LOC>= @cStartDynamicP_PalletLoc AND
                   NOT EXISTS(
                       SELECT 1
                       FROM   #DPP_SKU_NON_EMPTY E
                       WHERE  E.LOC = LOC.LOC
                   ) AND
                   NOT EXISTS(
                       SELECT 1
                       FROM   #DYNPPICK_SKU AS ReplenLoc
                       WHERE  ReplenLoc.TOLOC = LOC.LOC
                   ) AND
                   NOT EXISTS(
                       SELECT 1
                       FROM   #DynPick AS DynPick
                       WHERE  DynPick.D_Pick_Loc = LOC.LOC
                   )
            ORDER BY
                   LOC.LOC
        END 
        
        -- If no more DP loc then goto to last DP loc
        IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')=''
        BEGIN
            SELECT TOP 1 @cNextDynPickLoc = LOC.LOC
            FROM   LOC WITH (NOLOCK)
            WHERE  LOC.LocationType IN ('DYNPPICK') AND
                   --LOC.PutawayZone = @cDynamicP_PalletZone AND
                   LOC.Facility = @cFacility
            ORDER BY
                   LOC.LOC DESC
        END
        
        IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')=''
        BEGIN
            SET @nErrNo = @nErrNo+1
            SET @cErrMsg = 
                'Dynamic Permanent Pick Location Not Setup / Not enough Dynamic Permanent Location.'            
            SET @nContinue = 3 
            GOTO ErrorHandling
        END 
        
        --select @cDynamicP_PalletZone '@cDynamicP_PalletZone', @cFacility '@cFacility', @cNextDynPickLoc '@cNextDynPickLoc',
        --@cStyle '@cStyle'
        
        UPDATE #DynPick
        SET    D_Pick_Loc = @cNextDynPickLoc
        WHERE  StorerKey = @cStorerKey AND
               Sku = @cSku AND
               PickUOM <> '2' -- Loose qty
        
        FETCH NEXT FROM CUR_DynPP_SKU INTO @cStorerKey, @cReplenStrategykey, @cSKU
    END 
    CLOSE CUR_DynPP_SKU
    DEALLOCATE CUR_DynPP_SKU 
    
    -----------------------------------------Validation--------------------------------------------------

    IF @bDebug=1
    BEGIN
        SELECT D_Pick_Loc
              ,SortGroup
              ,SKU
              ,SUM(Qty*StdCube)
        FROM   #DynPick
        GROUP BY
               D_Pick_Loc
              ,SortGroup
              ,SKU
    END 
    
    IF EXISTS(
           SELECT 1
           FROM   #DynPick
           WHERE  D_Pick_Loc = ''
       )
    BEGIN
        SET @nErrNo = @nErrNo+1
        SET @cErrMsg = 'Fail to assign Dynamic Pick Loc (Pallet) / Dynamic Permanent Pick Loc / Permanent Pick Loc'
        SET @nContinue = 3 
        GOTO ErrorHandling
    END 
    
    ----------------------------------------Create Replenishment------------------------------------------------------------
    DECLARE CUR_GEN_REPLEN    CURSOR LOCAL FAST_FORWARD READ_ONLY 
    FOR
        SELECT Storerkey, Sku, Lot, Loc, ID, D_Pick_Loc, ReplenStrategyKey, SUM(Qty), Packkey, UOM, QtyBal, Casecnt,
             CASE WHEN PickUOM = '2' THEN '2' ELSE '6' END
        FROM #DynPick
        GROUP BY Storerkey, Sku, Lot, Loc, ID, D_Pick_Loc, ReplenStrategyKey, Packkey, UOM, QtyBal, Casecnt, CASE WHEN PickUOM = '2' THEN '2' ELSE '6' END
        ORDER BY Storerkey, Loc, Sku, Lot, ID        
        
    OPEN CUR_GEN_REPLEN
    
    FETCH NEXT FROM CUR_GEN_REPLEN INTO @cStorerKey, @cSKU, @cLOT, @cLOC, @cID, @cDynamicPickLoc, 
                                        @cReplenStrategyKey, @nQty, @cPackkey, @cUOM, @nQtyBal, @nCaseCnt, @cPickUOM                             
    
    WHILE @@FETCH_STATUS<>-1
    BEGIN
        SET @cReplenishmentKey = ''
        
        SET @nReplenQty = @nQty
        
        IF @nCaseCnt > 0
        BEGIN
        	 SET @nFullCtnQty = Ceiling(cast(@nQty AS float) / @nCaseCnt) * @nCaseCnt
           IF (@nFullCtnQty - @nQty) <= @nQtyBal
              SET @nReplenQty = @nFullCtnQty
        END
        
        IF @cPickUOM = '6'
        BEGIN
        	    SELECT TOP 1 @cDPP_Lot=LLI.Lot, @cDPP_Loc = LLI.Loc, @cDPP_ID = LLI.ID 
        	    FROM LOTXLOCXID LLI (NOLOCK)
        	    JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey 
        	                             AND LLI.Sku = SL.Sku
        	                             AND LLI.Loc = SL.Loc
        	    JOIN LOC (NOLOCK) ON SL.Loc = LOC.Loc
        	    WHERE (LOC.LocationType IN ('DYNPPICK')OR SL.LocationType IN('PICK','CASE'))
        	    AND LLI.Storerkey = @cStorerkey
        	    AND LLI.Sku = @cSKU
        	    AND LOC.Facility = @cFacility
        	    AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIN) >= @nQty
        	    
        	    IF @@ROWCOUNT > 0
        	    BEGIN
        	       UPDATE PickDetail WITH (ROWLOCK)               
                 SET    PickDetail.Loc = @cDPP_Loc
                       ,PickDetail.Lot = @cDPP_Lot
                       ,PickDetail.ID = @cDPP_ID 
                       --,PickDetail.PickHeaderKey = ''
                 FROM   PickDetail 
                 JOIN  #DynPick ON #DynPick.Pickdetailkey = PickDetail.Pickdetailkey
                 WHERE #DynPick.Lot = @cLot
                 AND   #DynPick.Loc = @cLoc
                 AND   #DynPick.ID = @cID
                 AND   #DynPick.D_Pick_Loc = @cDynamicPickLoc
                 
          	     GOTO Skip_To_Next_Replen       	 
              END        	    
        END
        
        SELECT TOP 1 
               @cReplenishmentKey = ReplenishmentKey
        FROM   REPLENISHMENT WITH (NOLOCK)
        WHERE  LoadKey = @cLoadKey AND
               LOT = @cLOT AND
               FromLOC = @cLOC AND
               ID = @cID AND
               ToLOC = @cDynamicPickLoc AND
               Confirmed NOT IN('Y','R','S')
                       
        IF ISNULL(RTRIM(@cReplenishmentKey) ,'')=''
        BEGIN
            EXECUTE nspg_GetKey 
            @keyname='REPLENISHMENT', 
            @fieldlength=10, 
            @keystring=@cReplenishmentKey OUTPUT, 
            @b_success=@bSuccess OUTPUT, 
            @n_err=@nErr OUTPUT, 
            @c_errmsg=@cErrMsg OUTPUT  
            
            IF NOT @bSuccess=1
            BEGIN
                SELECT @nContinue = 3
            END
            ELSE
            BEGIN                                
                IF @bDebug=1
                BEGIN
                    PRINT 'Insert Replenishment....'
                    SELECT @cReplenishmentKey '@cReplenishmentKey'
                          ,@cSKU '@cSKU'
                          ,@cLOT '@cLOT'
                          ,@cLOC '@cLOC'
                          ,@cID '@cID'
                          ,@cDynamicPickLoc '@cDynamicPickLoc'
                END 
                
                INSERT INTO Replenishment
                  (
                    ReplenishmentKey, ReplenishmentGroup, StorerKey, SKU, 
                    FromLOC, ToLOC, Lot, Id, Qty, UOM, PackKey, Priority, 
                    QtyMoved, QtyInPickLOC, RefNo, Confirmed, LoadKey, Remark, 
                    OriginalFromLoc, OriginalQty
                  )
                VALUES
                  (
                    @cReplenishmentKey, 'DYNAMIC', @cStorerKey, @cSKU, @cLOC, @cDynamicPickLoc, 
                    @cLOT, @cID, @nReplenQty, @cUOM, @cPackkey, '1', 0, 0, CAST(@nQty AS NVARCHAR(10)), 
                    'N', @cLoadKey, '', @cLOC, @nReplenQty
                  ) 
                
                SET @nErr = @@ERROR
            END
        END-- If Not Exists in Replen
        ELSE
        BEGIN
            IF @bDebug=1
            BEGIN
                PRINT 'Update Replenishment....'
                SELECT @cReplenishmentKey '@cReplenishmentKey'
                      ,@cSKU '@cSKU'
                      ,@cLOT '@cLOT'
                      ,@cLOC '@cLOC'
                      ,@cID '@cID'
                      ,@cDynamicPickLoc '@cDynamicPickLoc'
            END 
            
            UPDATE Replenishment WITH (ROWLOCK)
            SET    Qty = Qty+@nReplenQty
                  ,OriginalQty = OriginalQty+@nReplenQty
            WHERE  ReplenishmentKey = @cReplenishmentKey 
            
            SET @nErr = @@ERROR
        END 
       
        IF @nErr=0
        BEGIN
            UPDATE LOTxLOCxID WITH (ROWLOCK)
            SET    QtyReplen = ISNULL(QtyReplen ,0)+@nReplenQty                   
            WHERE  LOT = @cLOT AND
                   LOC = @cLOC AND
                   ID = @cID
            
            IF @@ERROR=0
            BEGIN
                IF NOT EXISTS(
                       SELECT 1
                       FROM   LOTxLOCxID WITH (NOLOCK)
                       WHERE  LOT = @cLOT AND
                              LOC = @cDynamicPickLoc AND
                              ID = ''
                   )
                BEGIN
                    INSERT INTO LOTxLOCxID
                      (
                        StorerKey, SKU, LOT, LOC, ID, Qty, PendingMoveIN
                      )
                    VALUES
                      (
                        @cStorerKey, @cSKU, @cLOT, @cDynamicPickLoc, '', 0, @nReplenQty  
                      )
                    IF @@ERROR<>0
                    BEGIN
                        SET @nErrNo = @nErrNo+1
                        SET @cErrMsg = 'Fail to Insert LOTxLOCxID'
                        SET @nContinue = 3 
                        GOTO ErrorHandling
                    END-- Update PickDetail Failed
                END
                ELSE 
                BEGIN                	
                    UPDATE LOTxLOCxID WITH (ROWLOCK)
                    SET    PendingMoveIN = ISNULL(PendingMoveIN ,0)+@nReplenQty                   
                    WHERE  LOT = @cLOT AND
                           LOC = @cDynamicPickLoc AND
                           ID = ''

                    IF @@ERROR<>0
                    BEGIN
                        SET @nErrNo = @nErrNo+1
                        SET @cErrMsg = 'Fail to Insert LOTxLOCxID'
                        SET @nContinue = 3 
                        GOTO ErrorHandling
                    END-- Update PickDetail Failed
                END
                
                IF NOT EXISTS(
                       SELECT 1
                       FROM   SKUxLOC WITH (NOLOCK)
                       WHERE  StorerKey = @cStorerKey AND
                              SKU = @cSKU AND
                              LOC = @cDynamicPickLoc
                   )
                BEGIN
                    INSERT INTO SKUxLOC
                      (
                        StorerKey, SKU, LOC, Qty
                      )
                    VALUES
                      (
                        @cStorerKey, @cSKU, @cDynamicPickLoc, 0
                      )
                    IF @@ERROR<>0
                    BEGIN
                        SET @nErrNo = @nErrNo+1
                        SET @cErrMsg = 'Fail to Insert LOTxLOCxID'
                        SET @nContinue = 3 
                        GOTO ErrorHandling
                    END-- Update PickDetail Failed
                END 
                
                UPDATE PickDetail WITH (ROWLOCK)               
                SET    PickDetail.Loc = @cDynamicPickLoc
                      ,PickDetail.PickHeaderKey = @cReplenishmentKey
                      ,PickDetail.ID = '' 
                FROM   PickDetail 
                JOIN  #DynPick ON #DynPick.Pickdetailkey = PickDetail.Pickdetailkey
                WHERE #DynPick.Lot = @cLot
                AND   #DynPick.Loc = @cLoc
                AND   #DynPick.ID = @cID
                AND   #DynPick.D_Pick_Loc = @cDynamicPickLoc
                
                IF @@ERROR<>0
                BEGIN
                    SET @nErrNo = @nErrNo+1
                    SET @cErrMsg = 'Fail to update Pickdetail'
                    SET @nContinue = 3 
                    GOTO ErrorHandling
                END-- Update PickDetail Failed
            END-- Update LOTxLOCxID Succeed
        END -- Insert Replen Succeed 
        
        Skip_To_Next_Replen:
        
        FETCH NEXT FROM CUR_GEN_REPLEN INTO @cStorerKey, @cSKU, @cLOT, @cLOC, @cID, @cDynamicPickLoc, 
                                            @cReplenStrategyKey, @nQty, @cPackkey, @cUOM, @nQtyBal, @nCaseCnt, @cPickUOM                              
    END 
    CLOSE CUR_GEN_REPLEN
    DEALLOCATE CUR_GEN_REPLEN
    
    WHILE @@TRANCOUNT>@nStartTranCount 
          COMMIT TRAN 
    
    RETURN
    
    ErrorHandling:
    IF @nContinue=3
    BEGIN
        IF @@TRANCOUNT>@nStartTranCount
            ROLLBACK TRAN
        
        EXECUTE nsp_Logerror @nErrNo, @cErrMsg, 'ispLPGenDynamicLocReplenishment'
        RAISERROR (@cErrMsg, 16, 1) WITH SETERROR    -- SQL2012
        RETURN
    END
END -- Procedure

GO