SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_PickSuggLoc02                                   */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get suggested loc to pick                                   */
/*                                                                      */
/* Called from: rdtfnc_Pick                                             */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 28-07-2017  1.0  James       WMS2561 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_PickSuggLoc02] (
   @nMobile                   INT,
   @nFunc                     INT, 
   @cLangCode                 NVARCHAR( 3),
   @c_Storerkey               NVARCHAR( 15),
   @c_Orderkey                NVARCHAR( 10),
   @c_PickSlipNo              NVARCHAR( 10),
   @c_SKU                     NVARCHAR( 20),
   @c_FromLoc                 NVARCHAR( 10),
   @c_FromID                  NVARCHAR( 18),
	@c_oFieled01               NVARCHAR( 20)      OUTPUT,
	@c_oFieled02               NVARCHAR( 20)      OUTPUT,
   @c_oFieled03               NVARCHAR( 20)      OUTPUT,
   @c_oFieled04               NVARCHAR( 20)      OUTPUT,
   @c_oFieled05               NVARCHAR( 20)      OUTPUT,
   @c_oFieled06               NVARCHAR( 20)      OUTPUT,
   @c_oFieled07               NVARCHAR( 20)      OUTPUT,
   @c_oFieled08               NVARCHAR( 20)      OUTPUT,
   @c_oFieled09               NVARCHAR( 20)      OUTPUT,
   @c_oFieled10               NVARCHAR( 20)      OUTPUT,
	@c_oFieled11               NVARCHAR( 20)      OUTPUT,
	@c_oFieled12               NVARCHAR( 20)      OUTPUT,
   @c_oFieled13               NVARCHAR( 20)      OUTPUT,
   @c_oFieled14               NVARCHAR( 20)      OUTPUT,
   @c_oFieled15               NVARCHAR( 20)      OUTPUT, 
   @bSuccess                  INT                OUTPUT,
   @nErrNo                    INT                OUTPUT,
   @cErrMsg                   NVARCHAR( 20)      OUTPUT   -- screen limitation, 20 NVARCHAR max

)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nStep         INT,
           @cPH_Zone      NVARCHAR( 18), 
           @cPH_OrderKey  NVARCHAR( 10), 
           @cPH_LoadKey   NVARCHAR( 10), 
           @cPickType     NVARCHAR( 1), -- S=SKU/UPC, U=UCC, P=Pallet  
           @cPickPalletNotByPalletUOM NVARCHAR( 1)    

   DECLARE @cCurrLogicalLOC    NVARCHAR( 18)
   DECLARE @cCurrLOC           NVARCHAR( 10)

   SELECT @nStep = Step, @c_SKU = V_SKU FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

   SET @cCurrLOC = @c_FromLoc

   -- Get logical LOC
   SET @cCurrLogicalLOC = ''
   SELECT @cCurrLogicalLOC = LogicalLocation 
   FROM dbo.LOC WITH (NOLOCK) 
   WHERE LOC = @cCurrLOC

   -- Set pick type  
   SET @cPickType =   
      CASE @nFunc  
         WHEN 860 THEN 'S' -- SKU/UPC  
         WHEN 861 THEN 'U' -- UCC  
         WHEN 862 THEN 'P' -- Pallet  
         WHEN 863 THEN 'D' -- Pick By Drop ID  
      END  

   IF @cPickType = 'P'    
      SET @cPickPalletNotByPalletUOM = rdt.RDTGetConfig( 0, 'PickPalletNotByPalletUOM', @c_Storerkey)    
   
   /*
   Suggest location logic:
   i.	   SKU
   ii.	Location Sequence (loc.Logicalloc)
   iii.	Location (Loc.loc)
   */
   IF ISNULL(@c_PickSlipNo, '') = ''
   BEGIN
      SET @cErrMsg = 'BLANK PICKSLIP NO'
      GOTO Quit
   END

   SELECT @cPH_Zone = Zone, @cPH_OrderKey = OrderKey, @cPH_LoadKey = ExternOrderKey     
   FROM dbo.PickHeader WITH (NOLOCK)     
   WHERE PickHeaderKey = @c_PickSlipNo   

   IF @nStep = '1'
   BEGIN
      IF ISNULL(@cPH_Zone, '') = 'XD' OR ISNULL(@cPH_Zone, '') = 'LB' OR ISNULL(@cPH_Zone, '') = 'LP' 
      BEGIN
         SELECT TOP 1 @c_oFieled01 = PD.LOC
         FROM dbo.PickDetail PD (NOLOCK) 
         JOIN dbo.RefKeyLookup RPL WITH (NOLOCK) ON RPL.PickDetailKey = PD.PickDetailKey
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         WHERE RPL.PickslipNo = @c_PickSlipNo    
         AND   PD.Status = '0'
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
         AND LTRIM( LOC.LogicalLocation + LOC.LOC) > ( @cCurrLogicalLOC + @cCurrLOC)
         ORDER BY PD.SKU, LOC.LogicalLocation, LOC.LOC
      END
      ELSE
      BEGIN
         IF ISNULL(@cPH_OrderKey, '') <> '' 
         BEGIN
            SELECT TOP 1 @c_oFieled01 = PD.LOC
            FROM dbo.PickHeader PH WITH (NOLOCK) 
            JOIN dbo.PickDetail PD (NOLOCK) ON PH.OrderKey = PD.OrderKey
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            WHERE PH.PickHeaderKey = @c_PickSlipNo    
            AND   PD.Status = '0'
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
            AND LTRIM( LOC.LogicalLocation + LOC.LOC) > ( @cCurrLogicalLOC + @cCurrLOC)
            ORDER BY PD.SKU, LOC.LogicalLocation, LOC.LOC
         END
         ELSE
         BEGIN
            SELECT TOP 1 @c_oFieled01 = PD.LOC
            FROM dbo.PickHeader PH WITH (NOLOCK) 
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
            JOIN dbo.PickDetail PD (NOLOCK) ON LPD.OrderKey = PD.OrderKey
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            WHERE PH.PickHeaderKey = @c_PickSlipNo    
            AND   PD.Status = '0'
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
            AND LTRIM( LOC.LogicalLocation + LOC.LOC) > ( @cCurrLogicalLOC + @cCurrLOC)
            ORDER BY PD.SKU, LOC.LogicalLocation, LOC.LOC
         END
      END
   END
   ELSE
   BEGIN
      IF ISNULL(@cPH_Zone, '') = 'XD' OR ISNULL(@cPH_Zone, '') = 'LB' OR ISNULL(@cPH_Zone, '') = 'LP' 
      BEGIN
         SELECT TOP 1 @c_oFieled01 = PD.LOC
         FROM dbo.PickDetail PD (NOLOCK) 
         JOIN dbo.RefKeyLookup RPL WITH (NOLOCK) ON RPL.PickDetailKey = PD.PickDetailKey
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         WHERE RPL.PickslipNo = @c_PickSlipNo    
         AND   PD.Status = '0'
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
         AND LTRIM( PD.SKU + LOC.LogicalLocation + LOC.LOC) > ( @c_SKU + @cCurrLogicalLOC + @cCurrLOC)
         ORDER BY PD.SKU, LOC.LogicalLocation, LOC.LOC
      END
      ELSE
      BEGIN
         IF ISNULL(@cPH_OrderKey, '') <> '' 
         BEGIN
            SELECT TOP 1 @c_oFieled01 = PD.LOC
            FROM dbo.PickHeader PH WITH (NOLOCK) 
            JOIN dbo.PickDetail PD (NOLOCK) ON PH.OrderKey = PD.OrderKey
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            WHERE PH.PickHeaderKey = @c_PickSlipNo    
            AND   PD.Status = '0'
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
            AND LTRIM( PD.SKU + LOC.LogicalLocation + LOC.LOC) > ( @c_SKU + @cCurrLogicalLOC + @cCurrLOC)
            ORDER BY PD.SKU, LOC.LogicalLocation, LOC.LOC
         END
         ELSE
         BEGIN
            SELECT TOP 1 @c_oFieled01 = PD.LOC
            FROM dbo.PickHeader PH WITH (NOLOCK) 
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
            JOIN dbo.PickDetail PD (NOLOCK) ON LPD.OrderKey = PD.OrderKey
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            WHERE PH.PickHeaderKey = @c_PickSlipNo    
            AND   PD.Status = '0'
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
            AND LTRIM( PD.SKU + LOC.LogicalLocation + LOC.LOC) > ( @c_SKU + @cCurrLogicalLOC + @cCurrLOC)
            ORDER BY PD.SKU, LOC.LogicalLocation, LOC.LOC
         END
      END
   END

   IF ISNULL(@c_oFieled01, '') = ''
   BEGIN
      SET @cErrMsg = 'NO SUGGEST LOC'
   END
Quit:
END

GO