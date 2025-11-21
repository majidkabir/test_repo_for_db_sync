SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/***************************************************************************/    
/* Store procedure: rdt_PickPallet_GetTaskInLOC                            */    
/* Copyright      : IDS                                                    */    
/*                                                                         */    
/* Purpose: Post Pick Packing                                              */    
/*                                                                         */      
/* Modifications log:                                                      */    
/*                                                                         */    
/* Date       Rev  Author     Purposes                                     */    
/* 2021-06-14 1.0  Chermaine  WMS-17140 Created (dup rdt_Pick_GetTaskInLOC)*/    
/***************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_PickPallet_GetTaskInLOC] (    
   @cStorer        NVARCHAR( 15),     
   @cPickSlipNo    NVARCHAR( 10),     
   @cLOC           NVARCHAR( 15),     
   @cPrefUOM       NVARCHAR( 1),         -- Pref UOM    
   @cPickType      NVARCHAR( 1),         -- Picking P=Pallet    
   @cDropID        NVARCHAR( 18) = '',  --  Pickdetail.DropID    
   @cID            NVARCHAR( 18) OUTPUT,     
   @cSKU           NVARCHAR( 20) OUTPUT,     
   @cUOM           NVARCHAR( 10) OUTPUT,  
   @cLottable01    NVARCHAR( 18) OUTPUT,
   @cLottable02    NVARCHAR( 18) OUTPUT,
   @cLottable03    NVARCHAR( 18) OUTPUT,
   @dLottable04    DATETIME      OUTPUT,
   @dLottable05    DATETIME      OUTPUT,
   @cLottable06    NVARCHAR( 30) OUTPUT,
   @cLottable07    NVARCHAR( 30) OUTPUT,
   @cLottable08    NVARCHAR( 30) OUTPUT,
   @cLottable09    NVARCHAR( 30) OUTPUT,
   @cLottable10    NVARCHAR( 30) OUTPUT,
   @cLottable11    NVARCHAR( 30) OUTPUT,
   @cLottable12    NVARCHAR( 30) OUTPUT,
   @dLottable13    DATETIME      OUTPUT,
   @dLottable14    DATETIME      OUTPUT,
   @dLottable15    DATETIME      OUTPUT, 
   @nTaskQTY       INT           OUTPUT, -- Task's QTY (in EA)    
   @nTask          INT           OUTPUT, -- Number of tasks    
   @cSKUDescr      NVARCHAR( 60) OUTPUT,     
   @cUOMDesc       NVARCHAR( 5)  OUTPUT,     
   @cPPK           NVARCHAR( 5)  OUTPUT,     
   @nCaseCnt       INT           OUTPUT,     
   @cPrefUOM_Desc  NVARCHAR( 5)  OUTPUT, -- Pref UOM Desc    
   @nPrefQTY       INT           OUTPUT, -- QTY in Pref UOM    
   @cMstUOM_Desc   NVARCHAR( 5)  OUTPUT, -- Master UOM Desc    
   @nMstQTY        INT           OUTPUT  -- Remaining QTY in master UOM    
) AS    
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    

/*    
   Defination of a task = LOC + SKU + UOM + Lottable02..04, in PickDetail    
   Note: It does not consider the LOT no    
         Multiple PickDetail records can be combined to form a task    
*/    
DECLARE @nRowCount INT    
DECLARE @nChkTask  INT  -- Test Task returned    
DECLARE @nChkQTY   INT  -- Test QTY returned    
DECLARE @cOldSKU   NVARCHAR( 20)    
DECLARE @nPrefUOM_Div INT    
DECLARE @dZero     DATETIME -- For comparing NULL and date    
DECLARE @cPickPalletNotByPalletUOM NVARCHAR( 1)    
    
 
DECLARE @cZone    NVARCHAR(18),    
        @cStatus  NVARCHAR(1)   


DECLARE @cCondition     NVARCHAR(MAX),    -- (james05)
        @cPH_OrderKey   NVARCHAR( 10),    -- (james04)
        @cPH_LoadKey    NVARCHAR( 10),    -- (james04)
        @nFunc          INT,              -- (james05)
        @cSkipFilterByDropID  NVARCHAR( 1)-- (james05)

SELECT @nFunc = Func FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE UserName = sUser_sName()

SET @cSkipFilterByDropID = rdt.RDTGetConfig( @nFunc, 'SkipFilterByDropID', @cStorer)    

-- Save old value    
SET @cOldSKU = ISNULL(@cSKU, '')    
SET @dZero = 0    
    
IF @cPickType = 'P'    
   SET @cPickPalletNotByPalletUOM = rdt.RDTGetConfig( 0, 'PickPalletNotByPalletUOM', @cStorer)    
    
SELECT @cZone = Zone, @cPH_OrderKey = OrderKey, @cPH_LoadKey = ExternOrderKey     
FROM dbo.PickHeader WITH (NOLOCK)     
WHERE PickHeaderKey = @cPickSlipNo    

IF rdt.RDTGetConfig( 0, 'EXCLUDESHORTPICKTASK', @cStorer) = '1'
   SET @cStatus = '4'
ELSE
   SET @cStatus = '5'


IF (@cID + @cSKU + @cUOM + @cLottable01+ @cLottable02 + @cLottable03 + CONVERT( NVARCHAR( 20), @dLottable04, 112)) = '19000101' 
   SET @cCondition = ''
ELSE
   SET @cCondition = (@cID + @cSKU + @cUOM + @cLottable01 + @cLottable02 + @cLottable03 + CONVERT( NVARCHAR( 10), @dLottable04, 112)) 
   

If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' -- OR ISNULL(@cZone, '') = '7'    
BEGIN    
   -- Get next task in current location    
   SELECT TOP 1    
      @cID  = PD.ID,     
      @cSKU = PD.SKU,     
      @cUOM = PD.UOM,     
      @cLottable01 = LA.Lottable01,     
      @cLottable02 = LA.Lottable02,     
      @cLottable03 = LA.Lottable03,     
      @dLottable04 = LA.Lottable04,
      @dLottable05 = LA.Lottable05,   
      @cLottable06 = LA.Lottable06,
      @cLottable07 = LA.Lottable07,
      @cLottable08 = LA.Lottable08,
      @cLottable09 = LA.Lottable09,
      @cLottable10 = LA.Lottable10,
      @cLottable11 = LA.Lottable11,
      @cLottable12 = LA.Lottable12,   
      @dLottable13 = LA.Lottable13,  
      @dLottable14 = LA.Lottable14,
      @dLottable15 = LA.Lottable15,         
      @nChkQTY = SUM( PD.QTY)      
   FROM dbo.PickDetail PD (NOLOCK) 
   JOIN RefKeyLookup RPL WITH (NOLOCK) ON RPL.PickDetailKey = PD.PickDetailKey
   JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT)    
   WHERE RPL.PickslipNo = @cPickSlipNo    
      --AND PD.Status < '5' -- Not yet picked  commented (james02)
      AND PD.Status < @cStatus
      AND PD.QTY > 0
      AND PD.LOC = @cLOC    
      AND 1 =     
         -- Filter by UOM    
         CASE     
            WHEN @cPickType = 'P' THEN      
               CASE WHEN @cPickPalletNotByPalletUOM = '1' THEN 1  -- If pick pallet regardless UOM, return true    
                    WHEN PD.UOM = 1 THEN 1                        -- If pick pallet and PD is pallet, return true    
                    ELSE 0 -- return false    
               END    
            WHEN @cPickType <> 'P' AND PD.UOM <> 1 THEN 1 -- If pick lose (not pallet) and PD is lose (not pallet), return true    
            ELSE 0 -- return false    
         END    
      -- Get task greater than current one    
      -- Use LTRIM to prevent the first field is blank and causing comparison failed    
      AND LTRIM(PD.ID + PD.SKU + PD.UOM + LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + CONVERT( NVARCHAR( 10), LA.Lottable04, 112)) >  
          @cCondition
      -- If function id = 1808 then no need filter dropid (james05)
      AND PD.DropID = CASE WHEN ISNULL(@cDropID, '') = '' OR @cSkipFilterByDropID = '1' THEN DropID ELSE @cDropID END -- If pick by dropid only        
   GROUP BY PD.ID, PD.SKU, PD.UOM, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, LA.Lottable05, 
   LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10, 
   LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15    
   ORDER BY PD.ID, PD.SKU, PD.UOM, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, LA.Lottable05, 
   LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10, 
   LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15  
END    
ELSE    
BEGIN    
   IF ISNULL(@cPH_OrderKey, '') <> ''
   BEGIN
      -- Get next task in current location    
      SELECT TOP 1    
         @cID  = PD.ID,     
         @cSKU = PD.SKU,     
         @cUOM = PD.UOM,     
         @cLottable01 = LA.Lottable01,     
         @cLottable02 = LA.Lottable02,     
         @cLottable03 = LA.Lottable03,     
         @dLottable04 = LA.Lottable04,
         @dLottable05 = LA.Lottable05,   
         @cLottable06 = LA.Lottable06,
         @cLottable07 = LA.Lottable07,
         @cLottable08 = LA.Lottable08,
         @cLottable09 = LA.Lottable09,
         @cLottable10 = LA.Lottable10,
         @cLottable11 = LA.Lottable11,
         @cLottable12 = LA.Lottable12,   
         @dLottable13 = LA.Lottable13,  
         @dLottable14 = LA.Lottable14,
         @dLottable15 = LA.Lottable15,      
         @nChkQTY = SUM( PD.QTY)    
      FROM dbo.PickHeader PH (NOLOCK)     
         INNER JOIN dbo.PickDetail PD (NOLOCK) ON (PH.OrderKey = PD.OrderKey)    
         INNER JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT)    
      WHERE PH.PickHeaderKey = @cPickSlipNo    
         --AND PD.Status < '5' -- Not yet picked  commented (james02)
         AND PD.Status < @cStatus
         AND PD.QTY > 0
         AND PD.LOC = @cLOC    
         AND 1 =     
            -- Filter by UOM    
            CASE     
               WHEN @cPickType = 'P' THEN      
                  CASE WHEN @cPickPalletNotByPalletUOM = '1' THEN 1  -- If pick pallet regardless UOM, return true    
                       WHEN PD.UOM = 1 THEN 1                        -- If pick pallet and PD is pallet, return true    
                       ELSE 0 -- return false    
                  END    
               WHEN @cPickType <> 'P' AND PD.UOM <> 1 THEN 1 -- If pick lose (not pallet) and PD is lose (not pallet), return true    
               ELSE 0 -- return false    
            END    
         -- Get task greater than current one    
         AND LTRIM(PD.ID + PD.SKU + PD.UOM + LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + CONVERT( NVARCHAR( 10), IsNULL( LA.Lottable04, @dZero), 112)) >     
             @cCondition
         -- If function id = 1808 then no need filter dropid (james05)
         AND PD.DropID = CASE WHEN ISNULL(@cDropID, '') = '' OR @cSkipFilterByDropID = '1' THEN DropID ELSE @cDropID END -- If pick by dropid only         
      GROUP BY PD.ID, PD.SKU, PD.UOM, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, LA.Lottable05, 
      LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10, 
      LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15    
      ORDER BY PD.ID, PD.SKU, PD.UOM, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, LA.Lottable05, 
      LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10, 
      LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15    
   END
   ELSE
   BEGIN
      -- Get next task in current location    
      SELECT TOP 1    
         @cID  = PD.ID,     
         @cSKU = PD.SKU,     
         @cUOM = PD.UOM,     
         @cLottable01 = LA.Lottable01,     
         @cLottable02 = LA.Lottable02,     
         @cLottable03 = LA.Lottable03,     
         @dLottable04 = LA.Lottable04,
         @dLottable05 = LA.Lottable05,   
         @cLottable06 = LA.Lottable06,
         @cLottable07 = LA.Lottable07,
         @cLottable08 = LA.Lottable08,
         @cLottable09 = LA.Lottable09,
         @cLottable10 = LA.Lottable10,
         @cLottable11 = LA.Lottable11,
         @cLottable12 = LA.Lottable12,   
         @dLottable13 = LA.Lottable13,  
         @dLottable14 = LA.Lottable14,
         @dLottable15 = LA.Lottable15,      
         @nChkQTY = SUM( PD.QTY)    
      FROM dbo.PickHeader PH (NOLOCK)     
         INNER JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
         INNER JOIN dbo.PickDetail PD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)    
         INNER JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT)    
      WHERE PH.PickHeaderKey = @cPickSlipNo    
         --AND PD.Status < '5' -- Not yet picked  commented (james02)
         AND PD.Status < @cStatus
         AND PD.QTY > 0
         AND PD.LOC = @cLOC    
         AND 1 =     
            -- Filter by UOM    
            CASE     
               WHEN @cPickType = 'P' THEN      
                  CASE WHEN @cPickPalletNotByPalletUOM = '1' THEN 1  -- If pick pallet regardless UOM, return true    
                       WHEN PD.UOM = 1 THEN 1                        -- If pick pallet and PD is pallet, return true    
                       ELSE 0 -- return false    
                  END    
               WHEN @cPickType <> 'P' AND PD.UOM <> 1 THEN 1 -- If pick lose (not pallet) and PD is lose (not pallet), return true    
               ELSE 0 -- return false    
            END    
         -- Get task greater than current one    
         AND LTRIM(PD.ID + PD.SKU + PD.UOM + LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + CONVERT( NVARCHAR( 10), IsNULL( LA.Lottable04, @dZero), 112)) >     
             @cCondition
         -- If function id = 1808 then no need filter dropid (james05)
         AND PD.DropID = CASE WHEN ISNULL(@cDropID, '') = ''  OR @cSkipFilterByDropID = '1' THEN DropID ELSE @cDropID END -- If pick by dropid only         
      GROUP BY PD.ID, PD.SKU, PD.UOM, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, LA.Lottable05, 
      LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10, 
      LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15    
      ORDER BY PD.ID, PD.SKU, PD.UOM, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, LA.Lottable05, 
      LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10, 
      LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15    
   END
END    
    
-- This statement must run immediately after the SELECT above. Otherwise @@ROWCOUNT get overwritten    
SET @nRowCount = @@ROWCOUNT    
    
IF @nChkQTY IS NULL  -- No task found    
BEGIN    
   -- Reset task properties    
   SET @nTaskQTY    = 0    
   SET @nTask       = 0    
   SET @cSKU        = ''    
   SET @cUOM        = ''    
   SET @cLottable01 = ''      
   SET @cLottable02 = ''    
   SET @cLottable03 = ''    
   SET @dLottable04 = 0 -- 1900-01-01    
   SET @dLottable05 = 0 -- 1900-01-01   
   SET @cLottable06 = ''
   SET @cLottable07 = ''
   SET @cLottable08 = ''
   SET @cLottable09 = ''
   SET @cLottable10 = ''
   SET @cLottable11 = ''
   SET @cLottable12 = ''  
   SET @dLottable13 =  0 -- 1900-01-01  
   SET @dLottable14 =  0 -- 1900-01-01 
   SET @dLottable15 =  0 -- 1900-01-01 
   SET @cSKUDescr   = ''    
   SET @cUOMDesc    = ''    
   SET @cPPK        = ''    
   SET @nCaseCnt    = 0    
   SET @cPrefUOM_Desc = ''    
   SET @nPrefQTY      = 0    
   SET @cMstUOM_Desc  = ''    
   SET @nMstQTY       = 0    
END    
ELSE    
BEGIN    
   SET @nTaskQTY = @nChkQTY    
   SET @nMstQTY  = @nChkQTY    
   SET @nTask = @nRowCount    
       
   -- Get SKU desc, UOM desc, PPK    
   SELECT TOP 1    
      @cSKUDescr = SKU.Descr,     
      @nCaseCnt = Pack.CaseCnt,     
      @cUOMDesc =     
         CASE @cUOM    
            WHEN '2' THEN Pack.PackUOM1 -- Case    
            WHEN '3' THEN Pack.PackUOM2 -- Inner pack    
            WHEN '6' THEN Pack.PackUOM3 -- Master unit    
            WHEN '1' THEN Pack.PackUOM4 -- Pallet    
            WHEN '4' THEN Pack.PackUOM8 -- Other unit 1    
            WHEN '5' THEN Pack.PackUOM9 -- Other unit 2    
            ELSE ''    
         END,    
      @cMstUOM_Desc = Pack.PackUOM3,     
      @cPrefUOM_Desc =     
         CASE @cPrefUOM    
            WHEN '2' THEN Pack.PackUOM1 -- Case    
            WHEN '3' THEN Pack.PackUOM2 -- Inner pack    
            WHEN '6' THEN Pack.PackUOM3 -- Master unit    
            WHEN '1' THEN Pack.PackUOM4 -- Pallet    
            WHEN '4' THEN Pack.PackUOM8 -- Other unit 1    
            WHEN '5' THEN Pack.PackUOM9 -- Other unit 2    
         END,     
      @nPrefUOM_Div = CAST( IsNULL(     
         CASE @cPrefUOM    
            WHEN '2' THEN Pack.CaseCNT    
            WHEN '3' THEN Pack.InnerPack    
            WHEN '6' THEN Pack.QTY    
            WHEN '1' THEN Pack.Pallet    
            WHEN '4' THEN Pack.OtherUnit1    
            WHEN '5' THEN Pack.OtherUnit2    
         END, 1) AS INT),     
      @cPPK =     
         CASE WHEN SKU.PrePackIndicator = '2'     
            THEN CAST( SKU.PackQtyIndicator AS NVARCHAR( 5))     
            ELSE ''     
         END    
   FROM dbo.SKU SKU (NOLOCK)    
      INNER JOIN dbo.Pack Pack (NOLOCK) ON (SKU.PackKey = Pack.PackKey)    
   WHERE StorerKey = @cStorer    
      AND SKU = @cSKU    
          
   -- Convert to prefer UOM QTY    
   IF @cPrefUOM = '6' OR -- When preferred UOM = master unit     
      @nPrefUOM_Div = 0 -- UOM not setup    
   BEGIN    
      SET @cPrefUOM_Desc = ''    
      SET @nPrefQTY = 0    
   END    
   ELSE    
   BEGIN    
      SET @nPrefQTY = @nTaskQTY / @nPrefUOM_Div -- Calc QTY in Pref UOM    
      SET @nMstQTY = @nTaskQTY % @nPrefUOM_Div  -- Calc remaining QTY in master unit    
   END    
END 

GO