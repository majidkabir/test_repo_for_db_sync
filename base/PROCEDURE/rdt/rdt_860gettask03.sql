SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/    
/* Store procedure: rdt_860GetTask03                                    */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Pick by SKU/UPC customised fetc task stored proc            */    
/*          Default pick qty = pickdetail qty                           */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2018-03-26 1.0  James    WMS3621. Created                            */
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_860GetTask03] (    
   @n_Mobile        INT,
   @n_Func          INT, 
   @c_LangCode      NVARCHAR(3), 
   @c_StorerKey     NVARCHAR( 15),     
   @c_PickSlipNo    NVARCHAR( 10),     
   @c_LOC           NVARCHAR( 10),     
   @c_PrefUOM       NVARCHAR( 1),         -- Pref UOM    
   @c_PickType      NVARCHAR( 1),         -- Picking P=Pallet    
   @c_DropID        NVARCHAR( 18) = '',  --  Pickdetail.DropID    
   @c_ID            NVARCHAR( 18) OUTPUT,     
   @c_SKU           NVARCHAR( 20) OUTPUT,     
   @c_UOM           NVARCHAR( 10) OUTPUT,  
   @c_Lottable1     NVARCHAR( 18) OUTPUT,     
   @c_Lottable2     NVARCHAR( 18) OUTPUT,     
   @c_Lottable3     NVARCHAR( 18) OUTPUT,     
   @d_Lottable4     DATETIME      OUTPUT,     
   @c_SKUDescr      NVARCHAR( 60) OUTPUT,    
   @c_oFieled01     NVARCHAR( 20) OUTPUT,
   @c_oFieled02     NVARCHAR( 20) OUTPUT,
   @c_oFieled03     NVARCHAR( 20) OUTPUT,
   @c_oFieled04     NVARCHAR( 20) OUTPUT,
   @c_oFieled05     NVARCHAR( 20) OUTPUT,
   @c_oFieled06     NVARCHAR( 20) OUTPUT,
   @c_oFieled07     NVARCHAR( 20) OUTPUT,
   @c_oFieled08     NVARCHAR( 20) OUTPUT,
   @c_oFieled09     NVARCHAR( 20) OUTPUT,
   @c_oFieled10     NVARCHAR( 20) OUTPUT,
   @c_oFieled11     NVARCHAR( 20) OUTPUT,
   @c_oFieled12     NVARCHAR( 20) OUTPUT,
   @c_oFieled13     NVARCHAR( 20) OUTPUT,
   @c_oFieled14     NVARCHAR( 20) OUTPUT,
   @c_oFieled15     NVARCHAR( 20) OUTPUT,
   @b_Success       INT           OUTPUT, 
   @n_ErrNo         INT           OUTPUT, 
   @c_ErrMsg        NVARCHAR( 20) OUTPUT
) AS    
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    
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
DECLARE @nTaskQTY INT
DECLARE @nTask   INT
DECLARE @cUOMDesc   NVARCHAR( 5)
DECLARE @cPPK       NVARCHAR( 5)
DECLARE @nMstQTY INT
DECLARE @nCaseCnt INT
DECLARE @nPrefQTY INT
DECLARE @cPrefUOM_Desc NVARCHAR( 5)
DECLARE @cMstUOM_Desc NVARCHAR( 5)
    
-- (james01)    
DECLARE @cZone    NVARCHAR(18),    
        @cStatus  NVARCHAR(1)   

-- (james03)
DECLARE @cCondition     NVARCHAR(MAX),    -- (james05)
        @cPH_OrderKey   NVARCHAR( 10),    -- (james04)
        @cPH_LoadKey    NVARCHAR( 10),    -- (james04)
        @nFunc          INT,              -- (james05)
        @cSkipFilterByDropID  NVARCHAR( 1)-- (james05)

SELECT @nFunc = Func FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE UserName = sUser_sName()

SET @cSkipFilterByDropID = rdt.RDTGetConfig( @nFunc, 'SkipFilterByDropID', @c_StorerKey)    

-- Save old value    
SET @cOldSKU = ISNULL(@c_SKU, '')    
SET @dZero = 0    
    
IF @c_PickType = 'P'    
   SET @cPickPalletNotByPalletUOM = rdt.RDTGetConfig( 0, 'PickPalletNotByPalletUOM', @c_StorerKey)    
    
SELECT @cZone = Zone, @cPH_OrderKey = OrderKey, @cPH_LoadKey = ExternOrderKey     
FROM dbo.PickHeader WITH (NOLOCK)     
WHERE PickHeaderKey = @c_PickSlipNo    

IF rdt.RDTGetConfig( 0, 'EXCLUDESHORTPICKTASK', @c_StorerKey) = '1'
   SET @cStatus = '4'
ELSE
   SET @cStatus = '5'

-- (james03)
IF (@c_ID + @c_SKU + @c_UOM + @c_Lottable1+ @c_Lottable2 + @c_Lottable3 + CONVERT( NVARCHAR( 20), @d_Lottable4, 112)) = '19000101' 
   SET @cCondition = ''
ELSE
   SET @cCondition = (@c_ID + @c_SKU + @c_UOM + @c_Lottable1 + @c_Lottable2 + @c_Lottable3 + CONVERT( NVARCHAR( 10), @d_Lottable4, 112)) 

If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' -- OR ISNULL(@cZone, '') = '7'    
BEGIN    
   -- Get next task in current location    
   SELECT TOP 1    
      @c_ID  = PD.ID,     
      @c_SKU = PD.SKU,     
      @c_UOM = PD.UOM,     
      @c_Lottable1 = LA.Lottable01,     
      @c_Lottable2 = LA.Lottable02,     
      @c_Lottable3 = LA.Lottable03,     
      @d_Lottable4 = LA.Lottable04,     
      @nChkQTY = SUM( PD.QTY)      
   FROM dbo.PickDetail PD (NOLOCK) 
   JOIN RefKeyLookup RPL WITH (NOLOCK) ON RPL.PickDetailKey = PD.PickDetailKey
   JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT)    
   WHERE RPL.PickslipNo = @c_PickSlipNo    
      --AND PD.Status < '5' -- Not yet picked  commented (james02)
      AND PD.Status < @cStatus
      AND PD.QTY > 0
      AND PD.LOC = @c_LOC    
      AND 1 =     
         -- Filter by UOM    
         CASE     
            WHEN @c_PickType = 'P' THEN      
               CASE WHEN @cPickPalletNotByPalletUOM = '1' THEN 1  -- If pick pallet regardless UOM, return true    
                    WHEN PD.UOM = 1 THEN 1                        -- If pick pallet and PD is pallet, return true    
                    ELSE 0 -- return false    
               END    
            WHEN @c_PickType <> 'P' AND PD.UOM <> 1 THEN 1 -- If pick lose (not pallet) and PD is lose (not pallet), return true    
            ELSE 0 -- return false    
         END    
      -- Get task greater than current one    
      -- Use LTRIM to prevent the first field is blank and causing comparison failed    
      AND LTRIM(PD.ID + PD.SKU + PD.UOM + LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + CONVERT( NVARCHAR( 10), LA.Lottable04, 112)) >  
          @cCondition
      -- If function id = 1808 then no need filter dropid (james05)
      AND PD.DropID = CASE WHEN ISNULL(@c_DropID, '') = '' OR @cSkipFilterByDropID = '1' THEN DropID ELSE @c_DropID END -- If pick by dropid only        
   GROUP BY PD.ID, PD.SKU, PD.UOM, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04    
   ORDER BY PD.ID, PD.SKU, PD.UOM, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04    
END    
ELSE    
BEGIN    
   IF ISNULL(@cPH_OrderKey, '') <> ''
   BEGIN
      -- Get next task in current location    
      SELECT TOP 1    
         @c_ID  = PD.ID,     
         @c_SKU = PD.SKU,     
         @c_UOM = PD.UOM,     
         @c_Lottable1 = LA.Lottable01,     
         @c_Lottable2 = LA.Lottable02,     
         @c_Lottable3 = LA.Lottable03,     
         @d_Lottable4 = LA.Lottable04,     
         @nChkQTY = SUM( PD.QTY)    
      FROM dbo.PickHeader PH (NOLOCK)     
         INNER JOIN dbo.PickDetail PD (NOLOCK) ON (PH.OrderKey = PD.OrderKey)    
         INNER JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT)    
      WHERE PH.PickHeaderKey = @c_PickSlipNo    
         --AND PD.Status < '5' -- Not yet picked  commented (james02)
         AND PD.Status < @cStatus
         AND PD.QTY > 0
         AND PD.LOC = @c_LOC    
         AND 1 =     
            -- Filter by UOM    
            CASE     
               WHEN @c_PickType = 'P' THEN      
                  CASE WHEN @cPickPalletNotByPalletUOM = '1' THEN 1  -- If pick pallet regardless UOM, return true    
                       WHEN PD.UOM = 1 THEN 1                        -- If pick pallet and PD is pallet, return true    
                       ELSE 0 -- return false    
                  END    
               WHEN @c_PickType <> 'P' AND PD.UOM <> 1 THEN 1 -- If pick lose (not pallet) and PD is lose (not pallet), return true    
               ELSE 0 -- return false    
            END    
         -- Get task greater than current one    
         AND LTRIM(PD.ID + PD.SKU + PD.UOM + LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + CONVERT( NVARCHAR( 10), IsNULL( LA.Lottable04, @dZero), 112)) >     
             @cCondition
         -- If function id = 1808 then no need filter dropid (james05)
         AND PD.DropID = CASE WHEN ISNULL(@c_DropID, '') = '' OR @cSkipFilterByDropID = '1' THEN DropID ELSE @c_DropID END -- If pick by dropid only         
      GROUP BY PD.ID, PD.SKU, PD.UOM, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04    
      ORDER BY PD.ID, PD.SKU, PD.UOM, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04    
   END
   ELSE
   BEGIN
      -- Get next task in current location    
      SELECT TOP 1    
         @c_ID  = PD.ID,     
         @c_SKU = PD.SKU,     
         @c_UOM = PD.UOM,     
         @c_Lottable1 = LA.Lottable01,     
         @c_Lottable2 = LA.Lottable02,     
         @c_Lottable3 = LA.Lottable03,     
         @d_Lottable4 = LA.Lottable04,     
         @nChkQTY = SUM( PD.QTY)    
      FROM dbo.PickHeader PH (NOLOCK)     
         INNER JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
         INNER JOIN dbo.PickDetail PD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)    
         INNER JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT)    
      WHERE PH.PickHeaderKey = @c_PickSlipNo    
         --AND PD.Status < '5' -- Not yet picked  commented (james02)
         AND PD.Status < @cStatus
         AND PD.QTY > 0
         AND PD.LOC = @c_LOC    
         AND 1 =     
            -- Filter by UOM    
            CASE     
               WHEN @c_PickType = 'P' THEN      
                  CASE WHEN @cPickPalletNotByPalletUOM = '1' THEN 1  -- If pick pallet regardless UOM, return true    
                       WHEN PD.UOM = 1 THEN 1                        -- If pick pallet and PD is pallet, return true    
                       ELSE 0 -- return false    
                  END    
               WHEN @c_PickType <> 'P' AND PD.UOM <> 1 THEN 1 -- If pick lose (not pallet) and PD is lose (not pallet), return true    
               ELSE 0 -- return false    
            END    
         -- Get task greater than current one    
         AND LTRIM(PD.ID + PD.SKU + PD.UOM + LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + CONVERT( NVARCHAR( 10), IsNULL( LA.Lottable04, @dZero), 112)) >     
             @cCondition
         -- If function id = 1808 then no need filter dropid (james05)
         AND PD.DropID = CASE WHEN ISNULL(@c_DropID, '') = ''  OR @cSkipFilterByDropID = '1' THEN DropID ELSE @c_DropID END -- If pick by dropid only         
      GROUP BY PD.ID, PD.SKU, PD.UOM, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04    
      ORDER BY PD.ID, PD.SKU, PD.UOM, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04    
   END
END    
    
-- This statement must run immediately after the SELECT above. Otherwise @@ROWCOUNT get overwritten    
SET @nRowCount = @@ROWCOUNT    
    
IF @nChkQTY IS NULL  -- No task found    
BEGIN    
   -- Reset task properties    
   SET @nTaskQTY    = 0    
   SET @nTask       = 0    
   SET @c_SKU        = ''    
   SET @c_UOM        = ''    
   SET @c_Lottable1  = ''      
   SET @c_Lottable2  = ''    
   SET @c_Lottable3  = ''    
   SET @d_Lottable4  = 0 -- 1900-01-01    
   SET @c_SKUDescr   = ''    
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
      @c_SKUDescr = SKU.Descr,     
      @nCaseCnt = Pack.CaseCnt,     
      @cUOMDesc =     
         CASE @c_UOM    
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
         CASE @c_PrefUOM    
            WHEN '2' THEN Pack.PackUOM1 -- Case    
            WHEN '3' THEN Pack.PackUOM2 -- Inner pack    
            WHEN '6' THEN Pack.PackUOM3 -- Master unit    
            WHEN '1' THEN Pack.PackUOM4 -- Pallet    
            WHEN '4' THEN Pack.PackUOM8 -- Other unit 1    
            WHEN '5' THEN Pack.PackUOM9 -- Other unit 2    
         END,     
      @nPrefUOM_Div = CAST( IsNULL(     
         CASE @c_PrefUOM    
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
   WHERE StorerKey = @c_StorerKey    
      AND SKU = @c_SKU    
          
   -- Convert to prefer UOM QTY    
   IF @c_PrefUOM = '6' OR -- When preferred UOM = master unit     
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
   SET @c_oFieled06 = ''
   SET @c_oFieled09 = '1'
   SET @c_oFieled02 = '1'
END 

GO