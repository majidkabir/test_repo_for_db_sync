SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_955PickSuggLoc01                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get suggested loc to pick                                   */
/*                                                                      */
/* Called from: rdtfnc_Pick_CaptureDropID                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 07-11-2017  1.0  James       WMS3294. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_955PickSuggLoc01] (
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

   DECLARE @cPH_Zone      NVARCHAR( 18), 
           @cPH_OrderKey  NVARCHAR( 10), 
           @cPH_LoadKey   NVARCHAR( 10), 
           @cPickType     NVARCHAR( 1), -- S=SKU/UPC, U=UCC, P=Pallet  
           @cPickPalletNotByPalletUOM NVARCHAR( 1)    

   DECLARE @cCurrLogicalLOC    NVARCHAR( 18)
   DECLARE @cCurrLOC           NVARCHAR( 10)

   SET @cCurrLOC = @c_FromLoc

   -- Get logical LOC
   SET @cCurrLogicalLOC = ''
   SELECT @cCurrLogicalLOC = LogicalLocation 
   FROM dbo.LOC WITH (NOLOCK) 
   WHERE LOC = @cCurrLOC

   /*
   Suggest location logic:
   i.	   Picking Slip #
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

   IF ISNULL(@cPH_Zone, '') = 'XD' OR ISNULL(@cPH_Zone, '') = 'LB' OR ISNULL(@cPH_Zone, '') = 'LP' 
   BEGIN
      SELECT TOP 1 @c_oFieled01 = PD.LOC
      FROM dbo.PickDetail PD (NOLOCK) 
      JOIN dbo.RefKeyLookup RPL WITH (NOLOCK) ON RPL.PickDetailKey = PD.PickDetailKey
      JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
      WHERE RPL.PickslipNo = @c_PickSlipNo    
      AND   PD.Status = '0'
      AND (LOC.LogicalLocation > @cCurrLogicalLOC
      OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))
      ORDER BY LOC.LogicalLocation, LOC.LOC
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
         AND (LOC.LogicalLocation > @cCurrLogicalLOC
         OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))
         ORDER BY LOC.LogicalLocation, LOC.LOC
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
         AND (LOC.LogicalLocation > @cCurrLogicalLOC
         OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))
         ORDER BY LOC.LogicalLocation, LOC.LOC
      END
   END

   IF ISNULL(@c_oFieled01, '') = ''
   BEGIN
      SET @cErrMsg = 'NO SUGGEST LOC'
   END
Quit:
END

GO