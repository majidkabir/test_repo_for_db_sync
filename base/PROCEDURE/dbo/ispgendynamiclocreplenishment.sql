SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: ispGenDynamicLocReplenishment                      */      
/* Creation Date: 30-Jun-2009                                           */      
/* Copyright: IDS                                                       */      
/* Written by: Shong                                                    */      
/*                                                                      */      
/* Purpose: SOS140686                                                   */      
/*          Replenishment and Dynamic Pick location assignment          */      
/*                                                                      */      
/* Called By: RCM Option From Wave maintenance Screen                   */      
/*                                                                      */      
/* PVCS Version: 1.0                                                    */      
/*                                                                      */      
/* Version: 6.0                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author   Ver  Purposes                                  */      
/* 01-Feb-2010  Shong    1.0  Added new storer config control to force  */    
/*                            grouping by SKU instead of Style          */    
/* 27-May-2011  NJOW01   1.1  216932-Empty id for dynamic pick loc      */    
/* 21-Jun-2011  TLTING   1.2  Performance Tune, SQL std, TraceInfo      */    
/* 23-Jun-2011  TLTING   1.3  Commit by line                            */    
/* 09-Nov-2011  SHONG    1.4  Assign Dny Loc by SKU, Lottable02         */    
/*                            (SHONG001) SkipJack Project               */    
/* 13-Dec-2011  SHONG    1.5  Do not allow more then 1 Storer Config    */    
/*                            Replenishment Grouping Set in system      */    
/* 20-Dec-2011  SHONG    1.6  Include Qty Allocated > 0 As Non-Empty Loc*/    
/* 30-Dec-2011  ChewKP   1.7  Do Not Loose ID when Generate Replen      */  
/*                            (ChewKP01)                                */  
/* 31-Dec-2011  James    1.8  Use config to control whether reuse last  */  
/*                            DP LOC if no more empty DP LOC (james01)  */ 
/* 09-Jan-2012  James    1.9  Check facility between orders.facility and*/  
/*                            start dynamic loc (james02)               */
/* 2012-01-12   ChewKP   2.0  Insert PICKRESLOG to TransmitLog3         */
/*                            (ChewKP02)                                */
/* 2012-02-21   Shong    2.1  Bug Fixing - Wrong Zone                   */
/* 2012-04-02   SHONG    2.2  Exclude HOLD Location when search DPP Loc */
/*                            SOS#240525                                */
/* 2012-04-07   SHONG    2.3  Validate Tot PickDet Qty vs Replen Qty    */
/* 2025-02-03   Wan01    2.4  UWP-29796 - Error on Gen Replenishment for*/
/*                            multiple pickdetail record for same lot,  */
/*                            loc and id                                */
/* 2025-02-24                 - fixed incorrect pendingmovein           */
/************************************************************************/      
CREATE   PROC [dbo].[ispGenDynamicLocReplenishment]     
   @cWaveKey NVARCHAR(10),    
   @bSuccess INT OUTPUT,    
   @nErrNo   INT OUTPUT,    
   @cErrMsg  NVARCHAR(215) OUTPUT    
AS
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF       
   SET QUOTED_IDENTIFIER OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF         
    
        
    DECLARE @cStartDynamicP_PalletLoc  NVARCHAR(20)    
           ,@cStartDynamicP_RackLoc    NVARCHAR(20)    
           ,@cDynamicP_PalletZone      NVARCHAR(10)    
           ,@cDynamicP_RackZone        NVARCHAR(10)    
           ,@nDynPalletCBM             FLOAT    
           ,@nContinue                 INT    
           ,@nStartTranCount           INT    
           ,@cFacility                 NVARCHAR(5)    
           ,@cDynGroup                 NVARCHAR(50)    
           ,@cStorerKey                NVARCHAR(15)    
           ,@cSKU                      NVARCHAR(20)    
           ,@cLOT                      NVARCHAR(10)    
           ,@cLOC                      NVARCHAR(10)    
           ,@cID                       NVARCHAR(18)    
           ,@cNextDynPickLoc           NVARCHAR(10)    
           ,@bDebug                    INT    
           ,@nRowID                    INT    
           ,@cReplenishmentKey         NVARCHAR(10)    
           ,@cPickDetailKey            NVARCHAR(10)    
           ,@nErr                      INT    
           ,@nQty                      INT    
           ,@cDynamicPickLoc           NVARCHAR(10)    
           ,@cPackKey                  NVARCHAR(10)    
           ,@cUOM                      NVARCHAR(10)    
           ,@cGenDynLocReplenBySKUBatch NVARCHAR(10)    
           ,@cDynLocReplenNotGetLastLoc NVARCHAR(1)  -- (james01)  
           ,@cOrders_Facility          NVARCHAR(5)   -- (james02)
           ,@c_authority_pickreslog    NVARCHAR(1) -- Generic Pick Release Interface -- (ChewKP02)
           ,@c_OrderKey                NVARCHAR(10) -- (ChewKP02)
           ,@b_success                 INT  -- (CheWKP02)
           ,@nPDT_TotReplenQty         INT 
           ,@nRPL_TotReplenQty         INT     
        
    SET @nContinue = 0    
    SET @nErrNo = 0    
    SET @cErrMsg = ''    
    SET @nStartTranCount = @@TRANCOUNT     
    SET @nErrNo = 70500    
        
    SET @bDebug = 0    
    IF @bSuccess=9    
        SET @bDebug = 1    
        
    BEGIN TRAN     
        
    SELECT @cStartDynamicP_PalletLoc = WAVE.UserDefine02    
          ,@cStartDynamicP_RackLoc = WAVE.UserDefine03    
    FROM   WAVE WITH (NOLOCK)    
    WHERE  Wavekey = @cWaveKey    
        
    IF ISNULL(RTRIM(@cStartDynamicP_PalletLoc) ,'')=''    
    BEGIN    
        SET @nErrNo = @nErrNo+1    
        SET @cErrMsg = 'Start Dynamic Pick Pallet Location Cannot Be Blank!'    
        SET @nContinue = 3     
        GOTO ErrorHandling    
    END     
    
    IF EXISTS(SELECT ORDERS.STORERKEY FROM ORDERS WITH (NOLOCK)    
              JOIN WAVEDETAIL WITH (NOLOCK)    
                   ON  WAVEDETAIL.OrderKey = ORDERS.OrderKey    
              JOIN STORERCONFIG SCFG WITH (NOLOCK) ON SCFG.StorerKey = ORDERS.StorerKey AND     
                       SCFG.ConfigKey IN ('GenDynLocReplenBySKU', 'GenDynLocReplenBySKUBatch') AND SCfg.sValue = '1'    
              WHERE  WAVEDETAIL.WaveKey = @cWaveKey     
              GROUP BY ORDERS.STORERKEY     
              HAVING COUNT(DISTINCT SCFG.ConfigKey) > 1 )     
    BEGIN    
        SET @nErrNo = @nErrNo+1    
        SET @cErrMsg = 'More Than One Replenishment Grouping Found in Storer Configuration. '    
        SET @nContinue = 3     
        GOTO ErrorHandling    
    END     
    
    SET @cGenDynLocReplenBySKUBatch = '0'    
    SELECT TOP 1 @cGenDynLocReplenBySKUBatch = ISNULL(RTRIM(SCfg.sValue),'0')     
    FROM ORDERS WITH (NOLOCK)    
    JOIN WAVEDETAIL WITH (NOLOCK) ON  WAVEDETAIL.OrderKey = ORDERS.OrderKey    
    JOIN STORERCONFIG SCFG WITH (NOLOCK) ON SCFG.StorerKey = ORDERS.StorerKey AND     
                      SCFG.ConfigKey = 'GenDynLocReplenBySKUBatch'    
    WHERE  WAVEDETAIL.WaveKey = @cWaveKey    
  
    -- (james01)  
    SET @cDynLocReplenNotGetLastLoc = '0'    
    SELECT TOP 1 @cDynLocReplenNotGetLastLoc = ISNULL(RTRIM(SCfg.sValue),'0')     
    FROM ORDERS WITH (NOLOCK)    
    JOIN WAVEDETAIL WITH (NOLOCK) ON  WAVEDETAIL.OrderKey = ORDERS.OrderKey    
    JOIN STORERCONFIG SCFG WITH (NOLOCK) ON SCFG.StorerKey = ORDERS.StorerKey AND     
                      SCFG.ConfigKey = 'DynLocReplenNotGetLastLoc'    
    WHERE  WAVEDETAIL.WaveKey = @cWaveKey   
         
    -- (james02)
    SET @cOrders_Facility = ''
    SELECT DISTINCT TOP 1 @cOrders_Facility = ORDERS.Facility 
    FROM ORDERS WITH (NOLOCK)    
    JOIN WAVEDETAIL WITH (NOLOCK) ON  WAVEDETAIL.OrderKey = ORDERS.OrderKey   
    WHERE  WAVEDETAIL.WaveKey = @cWaveKey
    
    SELECT @cDynamicP_PalletZone = ISNULL(LOC.PutawayZone ,'')    
          ,@cFacility = LOC.Facility    
    FROM   LOC WITH (NOLOCK)    
    WHERE  LOC = @cStartDynamicP_PalletLoc    

    -- If Orders.Facility <> facility for start dynamic pallet loc (james02)
    IF @cOrders_Facility <> @cFacility
    BEGIN    
        SET @nErrNo = @nErrNo+1    
        SET @cErrMsg = 'Facility different between Pallet Start location '+RTRIM(@cStartDynamicP_PalletLoc)
           +' and ORDERS Facility'    
        SET @nContinue = 3     
        GOTO ErrorHandling    
    END     
    
    IF ISNULL(RTRIM(@cDynamicP_PalletZone) ,'')=''    
    BEGIN    
        SET @nErrNo = @nErrNo+1    
        SET @cErrMsg = 'Putaway Zone for Pallet Start location: '+@cStartDynamicP_PalletLoc     
           +' is BLANK.'    
            
        SET @nContinue = 3     
        GOTO ErrorHandling    
    END     
        
    SELECT @cDynamicP_RackZone = LOC.PutawayZone    
    FROM   LOC WITH (NOLOCK)    
    WHERE  LOC = @cStartDynamicP_RackLoc    
        
    IF ISNULL(RTRIM(@cDynamicP_PalletZone) ,'')=''    
    BEGIN    
        SET @nErrNo = @nErrNo+1    
        SET @cErrMsg = 'Putaway Zone for Rack Start location: '+@cStartDynamicP_PalletLoc     
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

    -- Added By Shong on 07-Apr-2012
    DECLARE @nStorerConfigCount INT
    SET @nStorerConfigCount = 0
   
    SELECT @nStorerConfigCount = COUNT(DISTINCT SCFG.ConfigKey) 
    FROM  ORDERS WITH (NOLOCK)    
    JOIN WAVEDETAIL WITH (NOLOCK) ON  WAVEDETAIL.OrderKey = ORDERS.OrderKey  
    JOIN STORERCONFIG SCFG WITH (NOLOCK) ON SCFG.StorerKey = ORDERS.StorerKey AND
         SCFG.ConfigKey IN ('GenDynLocReplenBySKU', 'GenDynLocReplenBySKUBatch') 
    AND SCfg.sValue = '1' 
    AND WAVEDETAIL.WaveKey = @cWaveKey
    IF @nStorerConfigCount > 1 
    BEGIN
        SET @nErrNo = @nErrNo+1    
        SET @cErrMsg = 'Found More then 1 Dynamic Replen Configuration Setup'    
        SET @nContinue = 3     
        GOTO ErrorHandling          
    END
                        
    CREATE TABLE #DynPick    
    (    
        RowID           INT IDENTITY(1 ,1)  Primary Key    
       ,PickDetailKey  NVARCHAR(10)    
       ,DynGroup       NVARCHAR(50)    
       ,StorerKey      NVARCHAR(15)    
       ,SKU            NVARCHAR(20)    
       ,LOT            NVARCHAR(10)    
       ,LOC            NVARCHAR(10)    
       ,ID             NVARCHAR(18)    
       ,Qty            INT    
       ,D_Pick_LOC     NVARCHAR(10)    
       ,StdCube        FLOAT    
    )    
        
    INSERT INTO #DynPick    
      (    
        PickDetailKey, DynGroup, StorerKey, SKU, LOT, LOC, ID, Qty, D_Pick_LOC,     
        StdCube    
      )    
    SELECT PickDetailKey    
          ,CASE WHEN ISNULL(SCFG.ConfigKey, '') = 'GenDynLocReplenBySKU'     
                     THEN RTRIM(SKU.SKU)      
                WHEN ISNULL(SCFG.ConfigKey, '') = 'GenDynLocReplenBySKUBatch'     
                     THEN RTRIM(SKU.SKU) + RTRIM(ISNULL(LA.Lottable02,''))    
                ELSE ISNULL(SKU.Style ,'')     
           END -- SHONG001    
          ,SKU.StorerKey    
          ,SKU.SKU    
          ,PICKDETAIL.LOT    
          ,PICKDETAIL.LOC    
          ,PICKDETAIL.ID    
          ,PICKDETAIL.Qty    
          ,'' AS D_Pick_Loc    
          ,SKU.StdCube    
    FROM   PICKDETAIL WITH (NOLOCK)    
           JOIN WAVEDETAIL WITH (NOLOCK)    
                ON  WAVEDETAIL.OrderKey = PICKDETAIL.OrderKey    
           JOIN SKU WITH (NOLOCK)    
                ON  SKU.StorerKey = PICKDETAIL.StorerKey AND    
                    SKU.SKU = PICKDETAIL.SKU    
           JOIN LOC WITH (NOLOCK)    
                ON  LOC.LOC = PICKDETAIL.LOC AND    
                    LOC.LocationType NOT IN ('DYNPICKP','DYNPICKR')    
           JOIN SKUxLOC WITH (NOLOCK)    
                ON  SKUxLOC.StorerKey = PICKDETAIL.StorerKey AND    
                    SKUxLOC.SKU = PICKDETAIL.SKU AND    
                    SKUxLOC.LOC = PICKDETAIL.LOC AND    
                    LOC.LocationType NOT IN ('PICK' ,'CASE')     
           JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LA.LOT = PICKDETAIL.LOT     
           LEFT OUTER JOIN STORERCONFIG SCFG WITH (NOLOCK) ON SCFG.StorerKey = PICKDETAIL.StorerKey AND     
                SCFG.ConfigKey IN ('GenDynLocReplenBySKU', 'GenDynLocReplenBySKUBatch') AND SCfg.sValue = '1'    
    WHERE  WAVEDETAIL.WaveKey = @cWaveKey     
        
    IF EXISTS(SELECT 1 
              FROM #DynPick DP 
              JOIN PICKDETAIL p WITH (NOLOCK) ON DP.PickDetailKey = P.PickDetailKey 
              JOIN REPLENISHMENT r WITH (NOLOCK) ON R.ReplenishmentKey = P.PickHeaderKey 
                           AND r.Confirmed IN ('S', 'N')
              WHERE R.Wavekey = @cWaveKey )
    BEGIN
        SET @nErrNo = @nErrNo+1    
        SET @cErrMsg = 'Not Allow to Regenerate Modified PickDetail while Replenishment Already Generated'    
        SET @nContinue = 3     
        GOTO ErrorHandling                
    END
                  
              
--    CREATE UNIQUE CLUSTERED INDEX IX_DynPick_RowID ON #DynPick(RowID)    
    CREATE INDEX IX_DynPick_RowID ON #DynPick(StorerKey, DynGroup)    
        
    CREATE TABLE #DYNPICK_PALLET ( TOLOC NVARCHAR(10) )    
        
    INSERT INTO #DYNPICK_PALLET ( TOLOC )    
    SELECT R.TOLOC    
    FROM   REPLENISHMENT R WITH (NOLOCK)    
           JOIN LOC WITH (NOLOCK) ON  R.TOLOC = LOC.LOC    
    WHERE  LOC.LocationType IN ('DYNPICKP') AND    
           LOC.PutawayZone = @cDynamicP_PalletZone AND    
           LOC.Facility = @cFacility AND    
           LOC.LocationFlag NOT IN ('HOLD','DAMAGE')  AND  
           LOC.[Status]     <> 'HOLD' AND 
           R.Confirmed<>'Y'    
    GROUP BY R.TOLOC    
    HAVING SUM(R.Qty)>0     
        
    CREATE TABLE #DYNPICK_RACK ( TOLOC NVARCHAR(10))    
        
    INSERT INTO #DYNPICK_RACK( TOLOC )    
    SELECT R.TOLOC    
    FROM   REPLENISHMENT R WITH (NOLOCK)    
           JOIN LOC WITH (NOLOCK)    
                ON  R.TOLOC = LOC.LOC    
    WHERE  LOC.LocationType = ('DYNPICKR') AND    
           LOC.PutawayZone = @cDynamicP_RackZone AND    
           LOC.Facility = @cFacility AND 
           LOC.LocationFlag NOT IN ('HOLD','DAMAGE')  AND  
           LOC.[Status]     <> 'HOLD' AND    
           R.Confirmed<>'Y'    
    GROUP BY    
           R.TOLOC    
    HAVING SUM(R.Qty)>0     
        
    CREATE TABLE #DP_RACK_NON_EMPTY ( LOC NVARCHAR(10) )
    
    INSERT INTO #DP_RACK_NON_EMPTY ( LOC )    
    SELECT SKUxLOC.LOC    
    FROM   SKUxLOC WITH (NOLOCK)    
           JOIN LOC WITH (NOLOCK)    
                ON  SKUxLOC.LOC = LOC.LOC    
    WHERE  LOC.LocationType = ('DYNPICKR') AND    
           LOC.PutawayZone = @cDynamicP_RackZone AND    
           LOC.Facility = @cFacility    
    GROUP BY    
           SKUxLOC.LOC    
    --HAVING SUM(Qty)>0     
    --Include Qty Allocated > 0 As Non-Empty Loc    
    HAVING SUM((Qty - QtyPicked) + QtyAllocated)>0    
        
    CREATE TABLE #DP_PALLET_NON_EMPTY ( LOC NVARCHAR(10) )     
    INSERT INTO #DP_PALLET_NON_EMPTY ( LOC )    
    SELECT SKUxLOC.LOC    
    FROM   SKUxLOC WITH (NOLOCK)    
           JOIN LOC WITH (NOLOCK)    
                ON  SKUxLOC.LOC = LOC.LOC    
    WHERE  LOC.LocationType IN ('DYNPICKP') AND    
           LOC.PutawayZone = @cDynamicP_PalletZone AND    
           LOC.Facility = @cFacility    
    GROUP BY SKUxLOC.LOC    
    --HAVING SUM(Qty)>0    
    --Include Qty Allocated > 0 As Non-Empty Loc     
    HAVING SUM((Qty - QtyPicked) + QtyAllocated) > 0     
        
    CREATE TABLE #SKUDynGroup    
    (    
        StorerKey  NVARCHAR(15)    
       ,SKU        NVARCHAR(20)    
       ,DynGroup   NVARCHAR(50)    
    )    
    
    INSERT INTO #SKUDynGroup    
      (    
        StorerKey, SKU, DynGroup    
      )    
    SELECT DISTINCT StorerKey    
          ,SKU    
          ,DynGroup    
    FROM #DynPick DynPick    
        
    -- Assign Pallet Dynamic Pick Location for Total Cube > DynPalletCBM    
    -- Initial the Value    
    SELECT @cNextDynPickLoc = ''     
  
    IF @bDebug = 1  
    BEGIN  
      SELECT * FROM #SKUDynGroup   
    END         
        
    DECLARE CUR_DynPallet_DynGroup  CURSOR LOCAL FAST_FORWARD READ_ONLY     
    FOR    
        SELECT StorerKey    
              ,DynGroup                 
        FROM   #DynPick    
        WHERE  DynGroup>''    
        GROUP BY    
               StorerKey    
              ,DynGroup                 
               --   HAVING SUM(Qty * StdCube) >= @nDynPalletCBM    
        ORDER BY    
               StorerKey    
              ,DynGroup                 
        
    OPEN CUR_DynPallet_DynGroup     
        
    FETCH NEXT FROM CUR_DynPallet_DynGroup INTO @cStorerKey, @cDynGroup                                     
    WHILE @@FETCH_STATUS<>-1    
    BEGIN    
        GetNextDynamicPickPalletLocation:    
            
        SET @cNextDynPickLoc = ''    
            
        -- Find any Dynamic pick location already assign with same DynGroup?    
        -- if yes, then assign same location to this DynGroup    
        -- Get From Temp Table 1st    
        SELECT TOP 1 @cNextDynPickLoc = D_Pick_Loc    
        FROM   #DynPick    
        WHERE  DynGroup = @cDynGroup     
  
        IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')<>'' AND @bDebug = 1 PRINT 'AAA- @cNextDynPickLoc: ' + @cNextDynPickLoc + ' @cDynGroup: ' +   @cDynGroup  
            
        IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')=''    
        BEGIN    
            IF @cGenDynLocReplenBySKUBatch = '1'    
            BEGIN    
               SELECT TOP 1    
                      @cNextDynPickLoc = ISNULL(LOC.LOC,'')    
               FROM   LotxLocxID LLI WITH (NOLOCK)    
                JOIN #SKUDynGroup SKUDynGroup ON  SKUDynGroup.StorerKey = LLI.StorerKey AND    
                                                  SKUDynGroup.SKU = LLI.SKU    
                JOIN LOC WITH (NOLOCK) ON  LLI.LOC = LOC.LOC    
                JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON  SKUDynGroup.StorerKey = LA.StorerKey AND    
                                                       SKUDynGroup.SKU = LA.SKU     
               WHERE  SKUDynGroup.DynGroup = @cDynGroup AND     
                      (RTRIM(LA.SKU) + RTRIM(LA.Lottable02)) = @cDynGroup AND    
                      LOC.LocationType IN ('DYNPICKP') AND 
                      LOC.LocationFlag NOT IN ('HOLD','DAMAGE')  AND  
                      LOC.[Status]     <> 'HOLD' AND 
                      LOC.PutawayZone = @cDynamicP_PalletZone AND     
                      (LLI.Qty-LLI.QtyPicked+LLI.QtyAllocated)<>0      
  
               IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')<>'' AND @bDebug = 1 PRINT 'BBB- @cNextDynPickLoc: ' + @cNextDynPickLoc + ' @cDynGroup: ' +   @cDynGroup  
                          
            END    
            ELSE    
            BEGIN     
               SELECT TOP 1    
                      @cNextDynPickLoc = ISNULL(LOC.LOC,'')    
               FROM   LotxLocxID LLI WITH (NOLOCK)    
                      JOIN #SKUDynGroup SKUDynGroup    
                           ON  SKUDynGroup.StorerKey = LLI.StorerKey AND    
                               SKUDynGroup.SKU = LLI.SKU    
                      JOIN LOC WITH (NOLOCK) ON  LLI.LOC = LOC.LOC    
               WHERE  SKUDynGroup.DynGroup = @cDynGroup AND     
                      LOC.LocationType IN ('DYNPICKP') AND
                      LOC.LocationFlag NOT IN ('HOLD','DAMAGE')  AND  
                      LOC.[Status]     <> 'HOLD' AND                            
                      LOC.PutawayZone = @cDynamicP_PalletZone AND    
                      (LLI.Qty- LLI.QtyPicked+LLI.QtyAllocated)<>0    
  
               IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')<>'' AND @bDebug = 1 PRINT 'CCC- @cNextDynPickLoc: ' + @cNextDynPickLoc + ' @cDynGroup: ' +   @cDynGroup  
            END     
        END    
            
        -- If no location with same DynGroup found, then assign the empty location    
        IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')=''    
        BEGIN    
            SELECT TOP 1 @cNextDynPickLoc = ISNULL(LOC.LOC,'')    
            FROM   LOC WITH (NOLOCK)     
            WHERE  LOC.Facility = @cFacility AND    
                   LOC.LocationType IN ('DYNPICKP') AND 
                   LOC.LocationFlag NOT IN ('HOLD','DAMAGE')  AND  
                   LOC.[Status]     <> 'HOLD' AND                        
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
            ORDER BY LOC.LOC  
  
            IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')<>'' AND @bDebug = 1 PRINT 'DDD- @cNextDynPickLoc: ' + @cNextDynPickLoc + ' @cDynGroup: ' +   @cDynGroup    
        END     
          
        IF @cDynLocReplenNotGetLastLoc = 1 AND ISNULL(RTRIM(@cNextDynPickLoc) ,'')='' -- (james01)  
        BEGIN  
            SET @nErrNo = @nErrNo+1    
            SET @cErrMsg =     
                'Dynamic Pallet Location Not Setup / Not enough Dynamic Pallet Location.'    
                
            SET @nContinue = 3     
            GOTO ErrorHandling    
        END     
          
        -- If no more DP loc then goto to last DP loc    
        IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')=''    
        BEGIN    
            SELECT TOP 1 @cNextDynPickLoc = LOC.LOC    
            FROM   LOC WITH (NOLOCK)    
            WHERE  LOC.LocationType IN ('DYNPICKP') AND 
                   LOC.LocationFlag NOT IN ('HOLD','DAMAGE')  AND  
                   LOC.[Status]     <> 'HOLD' AND     
                   LOC.PutawayZone = @cDynamicP_PalletZone AND    
                   LOC.Facility = @cFacility    
            ORDER BY LOC.LOC DESC  
  
            IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')<>'' AND @bDebug = 1 PRINT 'EEE- @cNextDynPickLoc: ' + @cNextDynPickLoc + ' @cDynGroup: ' +   @cDynGroup    
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
        --@cDynGroup '@cDynGroup'    
            
        UPDATE #DynPick    
        SET    D_Pick_Loc = @cNextDynPickLoc    
        WHERE  StorerKey = @cStorerKey AND    
               DynGroup = @cDynGroup     
            
        FETCH NEXT FROM CUR_DynPallet_DynGroup INTO @cStorerKey, @cDynGroup    
    END     
    CLOSE CUR_DynPallet_DynGroup     
    DEALLOCATE CUR_DynPallet_DynGroup     
    --------------------------------------------------------------------------------------------    
    -- Assign the Dynamic Rack Location for total CBM < DynPalletCBM    
    IF @bDebug=1    
    BEGIN    
        PRINT 'Assign the Dynamic Rack Location for total CBM < DynPalletCBM'    
        SELECT StorerKey    
              ,DynGroup    
        FROM   #DynPick    
        WHERE  D_Pick_Loc = ''    
        GROUP BY    
               StorerKey    
              ,DynGroup    
        HAVING SUM(Qty * ISNULL(StdCube,0))<@nDynPalletCBM    
        ORDER BY    
               StorerKey    
              ,DynGroup    
    END    
        
    DECLARE CUR_DynRack_DynGroup  CURSOR LOCAL FAST_FORWARD READ_ONLY     
    FOR    
        SELECT StorerKey    
              ,DynGroup               
        FROM   #DynPick    
        WHERE  D_Pick_Loc = ''    
        GROUP BY    
               StorerKey    
              ,DynGroup               
        HAVING SUM(Qty * ISNULL(StdCube,0))<@nDynPalletCBM    
        ORDER BY    
               StorerKey    
              ,DynGroup               
        
    OPEN CUR_DynRack_DynGroup     
        
    FETCH NEXT FROM CUR_DynRack_DynGroup INTO @cStorerKey, @cDynGroup                                   
    WHILE @@FETCH_STATUS<>-1    
    BEGIN    
        DECLARE CUR_DynGroup_PickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY     
        FOR    
            SELECT DISTINCT SKU    
            FROM   #DynPick    
            WHERE  StorerKey = @cStorerKey AND    
                   DynGroup = @cDynGroup     
            
            
        OPEN CUR_DynGroup_PickDetail            
        FETCH NEXT FROM CUR_DynGroup_PickDetail INTO @cSKU     
        WHILE @@FETCH_STATUS<>-1    
        BEGIN    
            SET @cNextDynPickLoc = ''    
                
            -- Find any Dynamic pick location already assign with same style?    
            -- if yes, then assign same location to this DynGroup    
            SELECT TOP 1 @cNextDynPickLoc = D_Pick_Loc    
            FROM   #DynPick DP    
                   JOIN LOC WITH (NOLOCK)    
                        ON  DP.D_Pick_Loc = LOC.LOC    
            WHERE  DynGroup = @cDynGroup AND    
                   StorerKey = @cStorerKey AND    
                   SKU = @cSKU AND    
                   LOC.LocationType = ('DYNPICKR')    
                
            IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')=''    
            BEGIN    
                    
                SELECT TOP 1    
                       @cNextDynPickLoc = LOC.LOC    
                FROM   LotxLocxID LLI WITH (NOLOCK)    
                       JOIN LOC WITH (NOLOCK)    
                            ON  LLI.LOC = LOC.LOC    
                WHERE  LLI.StorerKey = @cStorerKey AND    
                       LLI.SKU = @cSKU AND    
                       LOC.LocationType = ('DYNPICKR') AND    
                       LOC.PutawayZone = @cDynamicP_RackZone AND    
                       (LLI.Qty- LLI.QtyPicked+LLI.QtyAllocated)<>0    
            END    
                
            --select @cDynamicP_RackZone '@cDynamicP_RackZone', @cFacility '@cFacility', @cStartDynamicP_RackLoc '@cStartDynamicP_RackLoc',    
            --@cDynGroup '@cDynGroup', @cSKU '@cSKU'    
                
            -- If no location with same DynGroup found, then assign the empty location    
            IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')=''    
            BEGIN    
               SELECT TOP 1 @cNextDynPickLoc = LOC.LOC    
                FROM   LOC WITH (NOLOCK)    
                WHERE  LOC.Facility = @cFacility AND    
                       LOC.LocationType = ('DYNPICKR') AND    
                       LOC.PutawayZone = @cDynamicP_RackZone AND    
                       LOC.LOC>= @cStartDynamicP_RackLoc AND    
                      NOT EXISTS(    
                          SELECT 1    
                          FROM   #DP_RACK_NON_EMPTY E    
                          WHERE  E.LOC = LOC.LOC    
                      ) AND    
                      NOT EXISTS(    
                          SELECT 1    
                          FROM   #DYNPICK_RACK AS ReplenLoc    
                          WHERE  ReplenLoc.TOLOC = LOC.LOC    
                      ) AND    
                      NOT EXISTS(    
                          SELECT 1    
                          FROM   #DynPick AS DynPick    
                          WHERE  DynPick.D_Pick_Loc = LOC.LOC    
                      )                           
                ORDER BY LOC.LOC    
            END     
  
           IF @cDynLocReplenNotGetLastLoc = 1 AND ISNULL(RTRIM(@cNextDynPickLoc) ,'')='' -- (james01)  
           BEGIN  
               SET @nErrNo = @nErrNo+1    
               SET @cErrMsg =     
                   'Dynamic Pallet Location Not Setup / Not enough Dynamic Pallet Location.'    
                   
               SET @nContinue = 3     
               GOTO ErrorHandling    
           END     
          
            -- If no more DP loc then goto last DP loc    
            IF ISNULL(RTRIM(@cNextDynPickLoc) ,'')=''    
            BEGIN    
                SELECT TOP 1 @cNextDynPickLoc = LOC.LOC    
                FROM   LOC WITH (NOLOCK)    
                WHERE  LOC.LocationType = ('DYNPICKR') AND    
                       LOC.PutawayZone = @cStartDynamicP_RackLoc AND    
                       LOC.Facility = @cFacility    
                ORDER BY LOC.LOC DESC    
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
                   DynGroup = @cDynGroup     
                
            FETCH NEXT FROM CUR_DynGroup_PickDetail INTO @cSKU    
        END     
        CLOSE CUR_DynGroup_PickDetail    
        DEALLOCATE CUR_DynGroup_PickDetail    
            
        FETCH NEXT FROM CUR_DynRack_DynGroup INTO @cStorerKey, @cDynGroup    
    END     
    CLOSE CUR_DynRack_DynGroup     
    DEALLOCATE CUR_DynRack_DynGroup     
    
    WHILE @@TRANCOUNT>0    
          COMMIT TRAN    
                  
    IF @bDebug=1    
    BEGIN    
        SELECT D_Pick_Loc    
              ,DynGroup    
              ,SKU    
              ,SUM(Qty*StdCube)    
        FROM   #DynPick    
        GROUP BY    
               D_Pick_Loc    
              ,DynGroup    
              ,SKU    
    END     
        
    IF EXISTS(    
           SELECT 1    
           FROM   #DynPick    
           WHERE  D_Pick_Loc = ''    
       )    
    BEGIN    
        SET @nErrNo = @nErrNo+1    
        SET @cErrMsg = 'Fail to assign Dynamic Pick Location (Pallet/Rack)'    
        SET @nContinue = 3     
        GOTO ErrorHandling    
    END     
        
    DECLARE CUR_GEN_REPLEN    CURSOR LOCAL FAST_FORWARD READ_ONLY     
    FOR    
        SELECT RowID    
        FROM   #DynPick    
        ORDER BY RowID    
        
    OPEN CUR_GEN_REPLEN    
        
    FETCH NEXT FROM CUR_GEN_REPLEN INTO @nRowID                           
        
    WHILE @@FETCH_STATUS<>-1    
    BEGIN    
       BEGIN TRAN -- tlting commit by line    
             
       SET @cPickDetailKey = ''    
       SET @cStorerKey = ''    
       SET @cSKU = ''    
       SET @cLOT = ''    
       SET @cLOC = ''    
       SET @cID  = ''    
       SET @nQty = 0    
       SET @cDynamicPickLoc = ''    
          
       SELECT  @cPickDetailKey = PickDetailKey    
              ,@cStorerKey = StorerKey    
              ,@cSKU = SKU    
              ,@cLOT = LOT    
              ,@cLOC = LOC    
              ,@cID  = ID    
              ,@nQty = Qty    
              ,@cDynamicPickLoc = D_Pick_LOC    
        FROM   #DynPick    
        WHERE RowID = @nRowID    
                         
        SET @cReplenishmentKey = ''    
            
        SELECT TOP 1     
               @cReplenishmentKey = ReplenishmentKey    
        FROM   REPLENISHMENT WITH (NOLOCK)    
        WHERE  WaveKey = @cWaveKey AND    
               LOT = @cLOT AND    
               FromLOC = @cLOC AND    
               ID = @cID AND    
               ToLOC = @cDynamicPickLoc AND 
               Confirmed = 'N'
            
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
                SELECT @cPackKey = PACK.PackKey    
                      ,@cUOM = PACK.PackUOM3    
                FROM   SKU WITH (NOLOCK)    
                       JOIN PACK WITH (NOLOCK)    
                            ON  PACK.PackKey = SKU.PackKey    
                WHERE  SKU.StorerKey = @cStorerKey AND    
                       SKU.SKU = @cSKU     
                    
                    
                IF @bDebug=1    
                BEGIN    
                    PRINT 'Insert Replenishment....'    
                    SELECT @cReplenishmentKey '@cReplenishmentKey'    
                          ,@cSKU '@cSKU'    
                          ,@cLOT '@cLOT'    
                          ,@cLOC '@cLOC'    
                          ,@cID '@cID'    
                          ,@cDynamicPickLoc '@cDynamicPickLoc'    
                          ,@cPickDetailKey '@cPickDetailKey'    
               END     
                    
                INSERT INTO Replenishment    
                  (    
                    ReplenishmentKey, ReplenishmentGroup, StorerKey, SKU,     
                    FromLOC, ToLOC, Lot, Id, Qty, UOM, PackKey, Priority,     
                    QtyMoved, QtyInPickLOC, RefNo, Confirmed, WaveKey, Remark,     
                    OriginalFromLoc, OriginalQty    
                  )    
                VALUES    
                  (    
                    @cReplenishmentKey, 'DYNAMIC', @cStorerKey, @cSKU, @cLOC, @cDynamicPickLoc,     
                    @cLOT, @cID, @nQty, @cUOM, @cPackkey, '1', 0, 0, @cPickDetailKey,     
                    'N', @cWaveKey, '', @cLOC, @nQty    
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
                      ,@cPickDetailKey '@cPickDetailKey'    
            END     
                
            UPDATE Replenishment WITH (ROWLOCK)    
            SET    Qty = Qty+@nQty    
                  ,OriginalQty = OriginalQty+@nQty
                  ,ArchiveCop  = NULL                                               --Wan01
            WHERE  ReplenishmentKey = @cReplenishmentKey     
                
            SET @nErr = @@ERROR    
        END     
            
        IF @nErr=0    
        BEGIN    
            UPDATE LOTxLOCxID WITH (ROWLOCK)    
            SET    QtyReplen = ISNULL(QtyReplen ,0)+@nQty    
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
                              --ID = '' --NJOW01    
                              ID = @cID --(ChewKP01)  
                   )    
                BEGIN    
                    INSERT INTO LOTxLOCxID    
                      (    
                        StorerKey, SKU, LOT, LOC, ID, Qty, PendingMoveIN            --(Wan01)    
                      )    
              VALUES    
                      (    
                        --@cStorerKey, @cSKU, @cLOT, @cDynamicPickLoc, '', 0   --NJOW01    
                        --@cStorerKey, @cSKU, @cLOT, @cDynamicPickLoc, @cID, 0   --(ChewKP01) 
                        @cStorerKey, @cSKU, @cLOT, @cDynamicPickLoc, @cID, 0, @nQty --(Wan01)  
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
                   --NJOW01    
                    UPDATE LOTxLOCxID WITH (ROWLOCK)    
                    SET    PendingMoveIN = ISNULL(PendingMoveIN ,0)+@nQty                       
                    WHERE  LOT = @cLOT AND    
                           LOC = @cDynamicPickLoc AND    
                           --ID = ''   
                           ID = @cID --(ChewKP01)  
    
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
                SET    LOC = @cDynamicPickLoc    
                      ,PickHeaderKey = @cReplenishmentKey    
                      --,ID = '' --NJOW01  -- (ChewKP01)  
                WHERE  PickDetailKey = @cPickDetailKey    
                    
                IF @@ERROR<>0    
                BEGIN    
                    SET @nErrNo = @nErrNo+1    
                    SET @cErrMsg = 'Fail to update Pickdetail'    
                    SET @nContinue = 3     
                    GOTO ErrorHandling    
                END-- Update PickDetail Failed    
                
                SET @nPDT_TotReplenQty = 0 
                SET @nRPL_TotReplenQty = 0 
                
                SELECT  @nPDT_TotReplenQty = ISNULL(SUM(Qty),0)
                FROM    PICKDETAIL p WITH (NOLOCK) 
                JOIN    WAVEDETAIL w WITH (NOLOCK) ON w.OrderKey = p.OrderKey  
                WHERE   p.PickHeaderKey = @cReplenishmentKey 
                  AND   w.WaveKey = @cWaveKey
                 
                SELECT @nRPL_TotReplenQty = r.OriginalQty 
                FROM REPLENISHMENT r WITH (NOLOCK) 
                WHERE r.Wavekey = @cWaveKey 
                AND   r.ReplenishmentKey = @cReplenishmentKey 
                
                IF @nPDT_TotReplenQty <> @nRPL_TotReplenQty
                BEGIN
                    SET @nErrNo = @nErrNo+1    
                    SET @cErrMsg = 'PickDetail Qty <> Replenishment Qty'    
                    SET @nContinue = 3     
                    GOTO ErrorHandling                   
                END
                               
            END-- Update LOTxLOCxID Succeed    
        END -- Insert Replen Succeed     
    
        WHILE @@TRANCOUNT > 0    
        BEGIN    
           COMMIT TRAN    
        END    
              
        FETCH NEXT FROM CUR_GEN_REPLEN INTO @nRowID    
    END     
    CLOSE CUR_GEN_REPLEN    
    DEALLOCATE CUR_GEN_REPLEN   
    
    -- Start (ChewKP02)
      
    SELECT @b_success = 0          
        
    EXECUTE dbo.nspGetRight  NULL,          
             @cStorerKey,        -- Storer          
             '',                  -- Sku          
             'PICKRESLOG',        -- ConfigKey          
             @b_success              OUTPUT,          
             @c_authority_pickreslog OUTPUT,          
             @nErrNo                 OUTPUT,          
             @cErrMsg                OUTPUT          
        
    IF @b_success <> 1          
    BEGIN          
       SELECT @nContinue = 3          
       SELECT @nErrNo = @nErrNo + 1
       SELECT @cErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@nErrNo,0))           
                        + ': Retrieve of Right (PICKRESLOG) Failed ( '           
                        + ' (ispGenDynamicLocReplenishment)'                        --Put correct SP name   
    END
    
    IF @c_authority_pickreslog = '1'
    BEGIN
        
        DECLARE CursorWaveDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
        
        SELECT OrderKey FROM WaveDetail WITH (NOLOCK)
        WHERE WaveKey = @cWaveKey 
        
        OPEN CursorWaveDetail   
   
        FETCH NEXT FROM CursorWaveDetail INTO @c_OrderKey
        
        WHILE @@FETCH_STATUS <> -1               
        BEGIN
          
           EXEC dbo.ispGenTransmitLog3 'PICKRESLOG', @c_OrderKey, '', @cStorerKey, ''          
                               , @b_success OUTPUT          
                               , @nErrNo OUTPUT          
                               , @cErrMsg OUTPUT   
                                                         
           IF @b_success <> 1          
           BEGIN          
              SELECT @nContinue = 3 
              GOTO ErrorHandling          
           END    
        
          FETCH NEXT FROM CursorWaveDetail INTO @c_OrderKey
        END
        CLOSE CursorWaveDetail            
        DEALLOCATE CursorWaveDetail  
    END
    
    
    -- End (ChewKP02) 
        
    WHILE @@TRANCOUNT>@nStartTranCount     
          COMMIT TRAN     
        
    RETURN    
        
    ErrorHandling:    
    IF @nContinue=3    
    BEGIN    
        IF @@TRANCOUNT>@nStartTranCount    
            ROLLBACK TRAN    
            
        EXECUTE nsp_Logerror @nErrNo, @cErrMsg, 'ispGenDynamicLocReplenishment'    
        RAISERROR (@cErrMsg, 16, 1) WITH SETERROR    -- SQL2012    
        RETURN    
    END    
END -- Procedure

GO