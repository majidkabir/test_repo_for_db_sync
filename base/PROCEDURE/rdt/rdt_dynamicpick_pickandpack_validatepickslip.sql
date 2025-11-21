SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_DynamicPick_PickAndPack_ValidatePickSlip        */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get next location for Pick And Pack function                */
/*                                                                      */
/* Called from: rdtfnc_DynamicPick_PickAndPack                          */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 21-Jun-2008 1.0  MaryVong    Created                                 */
/* 13-May-2009 1.1  Leong       SOS136610 - Include PackDetail Qty Check*/
/* 19-Apr-2013 1.2  Ung         SOS276057 Check cancel order            */
/* 26-Jul-2016 1.3  Ung         SOS375224 Add LoadKey, Zone optional    */
/************************************************************************/

CREATE   PROC [RDT].[rdt_DynamicPick_PickAndPack_ValidatePickSlip] (
   @nMobile       INT,             
   @nFunc         INT,             
   @cLangCode     NVARCHAR( 3),    
   @nStep         INT,             
   @nInputKey     INT,             
   @cFacility     NVARCHAR( 5),     
   @cStorerKey    NVARCHAR( 15),  
	@cWaveKey      NVARCHAR( 10),
	@cLoadKey      NVARCHAR( 10),
   @cPickZone     NVARCHAR( 10),
   @cCountry      NVARCHAR( 20),
   @cFromLoc      NVARCHAR( 10),
   @cToLoc        NVARCHAR( 10),
   @cPickSlipNo   NVARCHAR( 10),
   @cPickSlipType NVARCHAR( 1)  OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nQTY              INT
   DECLARE @nPickQTY          INT 
   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cExternOrderKey   NVARCHAR( 10)
   DECLARE @cZone             NVARCHAR( 18)

   SET @nQTY = 0
	SET @nErrNo = 0
	SET @cErrMsg = ''
	SET @nPickQTY = 0

   -- Get PickHeader info
   SELECT TOP 1
      @cOrderKey = OrderKey,
      @cExternOrderKey = ExternOrderKey,
      @cZone = Zone
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo

   -- Validate PickSlipNo
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 64801
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid PSNO
      GOTO Fail
   END

   -- Cross dock PickSlip
   IF @cZone IN ('XD', 'LB', 'LP')
   BEGIN
      -- Check diff PickSlip type
      IF @cPickSlipType <> '' AND @cPickSlipType <> 'X'
      BEGIN
         SET @nErrNo = 64802
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff PSType
         GOTO Fail
      END
      
      -- Check diff storer
      IF EXISTS( SELECT TOP 1 1
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = RKL.Orderkey)
         WHERE RKL.PickSlipNo = @cPickSlipNo
           AND O.StorerKey <> @cStorerKey)
      BEGIN
         SET @nErrNo = 64803
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff storer
         GOTO Fail
      END
      
      -- Check order cancel
      IF EXISTS( SELECT TOP 1 1
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = RKL.Orderkey)
         WHERE RKL.PickSlipNo = @cPickSlipNo
           AND (O.Status = 'CANC' 
           OR O.SOStatus = 'CANC'))
      BEGIN
         SET @nErrNo = 64804
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Order cancel
         GOTO Fail
      END

      -- Check pickslip in wave
      IF @cWaveKey <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.WaveDetail WD WITH (NOLOCK) ON (RKL.OrderKey = WD.OrderKey)
            WHERE RKL.PickSlipNo = @cPickSlipNo
               AND WD.WaveKey = @cWaveKey)
         BEGIN
            SET @nErrNo = 64805
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PS not in Wave
            GOTO Fail
         END
      END

      -- Check pickslip in load
      IF @cLoadKey <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (RKL.OrderKey = LPD.OrderKey)
            WHERE RKL.PickSlipNo = @cPickSlipNo
               AND LPD.LoadKey = @cLoadKey)
         BEGIN
            SET @nErrNo = 64806
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PS not in Load
            GOTO Fail
         END
      END

      -- Check pickslip for country
      IF @cCountry <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.Orders O WITH (NOLOCK) ON (RKL.OrderKey = O.OrderKey)
            WHERE RKL.PickSlipNo = @cPickSlipNo
               AND O.C_Country = @cCountry)
         BEGIN
            SET @nErrNo = 64807
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PSNotOnCountry
            GOTO Fail
         END
      END

      -- Check pickslip in zone
      IF @cPickZone <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailkey)
               JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            WHERE RKL.PickSlipNo = @cPickSlipNo
               AND LOC.Facility = @cFacility
               AND LOC.PickZone = @cPickZone)
         BEGIN
            SET @nErrNo = 64808
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PSNotInPZone
            GOTO Fail
         END
      END

      -- Check pickslip in LOC range
      IF @cFromLoc <> '' AND @cToLoc <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailkey)
            WHERE RKL.PickSlipNo = @cPickSlipNo
               AND PD.LOC >= @cFromLoc
               AND PD.LOC <= @cToLoc)
         BEGIN
            SET @nErrNo = 64809
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PSNotInFrToLOC
            GOTO Fail
         END
      END

      -- Get PickQTY
      EXEC rdt.rdt_DynamicPick_PickAndPack_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,'X'  -- @cPickSlipType
         ,@cPickSlipNo
         ,@cPickZone
         ,@cFromLoc
         ,@cToLoc
         ,'Total' -- Type
         ,@nPickQTY OUTPUT
         ,@nErrNo   OUTPUT
         ,@cErrMsg  OUTPUT
   END

   -- Discrete PickSlip
   ELSE IF @cOrderKey <> ''
   BEGIN
      -- Check PickSlip type
      IF @cPickSlipType <> '' AND @cPickSlipType <> 'D'
      BEGIN
         SET @nErrNo = 64810
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff PSType
         GOTO Fail
      END

      -- Check storer
      IF NOT EXISTS (SELECT 1 FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND StorerKey = @cStorerKey)
      BEGIN
         SET @nErrNo = 64811
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff storer
         GOTO Fail
      END

      -- Check order cancel
      IF EXISTS (SELECT 1 
         FROM dbo.Orders O WITH (NOLOCK)
         WHERE O.OrderKey = @cOrderKey
            AND (O.Status = 'CANC'
            OR O.SOStatus = 'CANC'))
      BEGIN
         SET @nErrNo = 64812
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Order cancel
         GOTO Fail
      END

      -- Check pickslip in wave
      IF @cWaveKey <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.WaveDetail WITH (NOLOCK) WHERE WaveKey = @cWaveKey AND OrderKey = @cOrderKey)
         BEGIN
            SET @nErrNo = 64813
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PS not in Wave
            GOTO Fail
         END
      END

      -- Check pickslip in load
      IF @cLoadKey <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.LoadPlanDetail WITH (NOLOCK) WHERE LoadKey = @cLoadKey AND OrderKey = @cOrderKey)
         BEGIN
            SET @nErrNo = 64814
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PS not in Load
            GOTO Fail
         END
      END

      -- Check pickslip for country
      IF @cCountry <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.Orders O WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND C_Country = @cCountry)
         BEGIN
            SET @nErrNo = 64815
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PSNotOnCountry
            GOTO Fail
         END
      END

      -- Check pickslip in zone
      IF @cPickZone <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 
            FROM dbo.PickDetail PD WITH (NOLOCK) 
               JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            WHERE PD.OrderKey = @cOrderKey
               AND LOC.Facility = @cFacility
               AND LOC.PickZone = @cPickZone)
         BEGIN
            SET @nErrNo = 64816
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PSNotInPZone
            GOTO Fail
         END
      END

      -- Check pickslip in LOC range
      IF @cFromLoc <> '' AND @cToLoc <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 
            FROM dbo.PickDetail PD WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
               AND LOC >= @cFromLoc
               AND LOC <= @cToLoc)
         BEGIN
            SET @nErrNo = 64817
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PSNotInFrToLOC
            GOTO Fail
         END
      END

      -- Get PickQTY
      EXEC rdt.rdt_DynamicPick_PickAndPack_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,'D'  -- @cPickSlipType
         ,@cPickSlipNo
         ,@cPickZone
         ,@cFromLoc
         ,@cToLoc
         ,'Total' -- Type
         ,@nPickQTY OUTPUT
         ,@nErrNo   OUTPUT
         ,@cErrMsg  OUTPUT
   END

   -- Conso PickSlip
   ELSE IF @cExternOrderKey <> ''
   BEGIN
      -- Check diff PickSlip type
      IF @cPickSlipType <> '' AND @cPickSlipType <> 'C'
      BEGIN
         SET @nErrNo = 64818
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff PSType
         GOTO Fail
      END

      -- Check diff storer
      IF EXISTS( SELECT TOP 1 1 
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN dbo.Orders O (NOLOCK) ON (LPD.OrderKey = O.OrderKey)    
         WHERE LPD.LoadKey = @cLoadKey 
            AND O.StorerKey <> @cStorerKey)
      BEGIN
         SET @nErrNo = 64819
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff storer
         GOTO Fail
      END

      -- Check order cancel
      IF EXISTS( SELECT TOP 1 1 
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN dbo.Orders O (NOLOCK) ON (LPD.OrderKey = O.OrderKey)    
         WHERE LPD.LoadKey = @cLoadKey  
            AND (O.Status = 'CANC'
            OR O.SOStatus = 'CANC'))
      BEGIN
         SET @nErrNo = 64820
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Order cancel
         GOTO Fail
      END

      -- Check pickslip in wave
      IF @cWaveKey <> ''
      BEGIN
         IF NOT EXISTS( SELECT 1
            FROM WaveDetail WD WITH (NOLOCK)
               JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (WD.OrderKey = LPD.OrderKey)
            WHERE WD.WaveKey = @cWaveKey
               AND LPD.LoadKey = @cExternOrderKey)
         BEGIN
            SET @nErrNo = 64821
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PS not in Wave
            GOTO Fail
         END
      END

      -- Check pickslip in load
      IF @cLoadKey <> ''
      BEGIN
         IF @cLoadKey <> @cExternOrderKey
         BEGIN
            SET @nErrNo = 64822
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PS not in Load
            GOTO Fail
         END
      END

      -- Check pickslip for country
      IF @cCountry <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN dbo.Orders O (NOLOCK) ON (LPD.OrderKey = O.OrderKey)    
            WHERE LPD.LoadKey = @cLoadKey  
               AND O.C_Country = @cCountry)
         BEGIN
            SET @nErrNo = 64823
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PSNotOnCountry
            GOTO Fail
         END
      END
      
      -- Check pickslip in zone
      IF @cPickZone <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) 
               JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            WHERE LPD.LoadKey = @cLoadKey 
               AND LOC.Facility = @cFacility
               AND LOC.PickZone = @cPickZone)
         BEGIN
            SET @nErrNo = 64824
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PSNotInPZone
            GOTO Fail
         END
      END
      
      -- Check PSNO in LOC range
      IF @cFromLoc <> '' AND @cToLoc <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) 
            WHERE LPD.LoadKey = @cLoadKey 
               AND PD.LOC >= @cFromLoc
               AND PD.LOC <= @cToLoc)
         BEGIN
            SET @nErrNo = 64825
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PSNotInFrToLOC
            GOTO Fail
         END
      END

      -- Get PickQTY
      EXEC rdt.rdt_DynamicPick_PickAndPack_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,'C'  -- @cPickSlipType
         ,@cPickSlipNo
         ,@cPickZone
         ,@cFromLoc
         ,@cToLoc
         ,'Total' -- Type
         ,@nPickQTY OUTPUT
         ,@nErrNo   OUTPUT
         ,@cErrMsg  OUTPUT
   END

   IF @nPickQTY = 0
   BEGIN
      SET @nErrNo = 64826
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PSNoQTYToPick
      GOTO Fail
   END

   -- No zone and LOC range
   IF @cPickZone = '' AND @cFromLOC = ''
   BEGIN
      -- Check PickSlip locked by others
      IF EXISTS( SELECT TOP 1 1 
         FROM rdt.rdtDynamicPickLog WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
            AND AddWho <> SUSER_NAME())
      BEGIN
         SET @nErrNo = 64827
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PSNO locked
         GOTO Fail
      END
   END

   -- Zone
   ELSE IF @cPickZone <> '' AND @cFromLOC = ''
   BEGIN
      -- Check PickSlip locked by others
      IF EXISTS( SELECT TOP 1 1 
         FROM rdt.rdtDynamicPickLog L WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
            AND ((Zone = '' AND FromLOC = '')
            OR (Zone = @cPickZone)
            OR (Zone = '' AND EXISTS( 
               SELECT 1 
               FROM LOC WITH (NOLOCK) 
               WHERE Facility = @cFacility
                  AND PickZone = @cPickZone 
                  AND LOC.LOC BETWEEN L.FromLOC AND L.ToLOC)))
            AND AddWho <> SUSER_NAME())
      BEGIN
         SET @nErrNo = 64828
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PSNO locked
         GOTO Fail
      END
   END
   
   -- LOC range
   ELSE IF @cPickZone = '' AND @cFromLOC <> ''
   BEGIN
      -- Check PickSlip locked by others
      IF EXISTS( SELECT TOP 1 1 
         FROM rdt.rdtDynamicPickLog L WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo 
            AND ((Zone = '' AND FromLOC = '')
            OR (Zone <> '' AND FromLOC = '' AND EXISTS( 
               SELECT 1 
               FROM LOC WITH (NOLOCK) 
               WHERE Facility = @cFacility 
                  AND PickZone = L.Zone 
                  AND LOC.LOC BETWEEN L.FromLOC AND L.ToLOC)))
            OR (Zone = '' AND FromLOC <> '' AND @cFromLOC >= L.FromLOC AND @cToLOC <= L.ToLOC)
            AND AddWho <> SUSER_NAME())
      BEGIN
         SET @nErrNo = 64829
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PSNO locked
         GOTO Fail
      END
   END

   -- Remember PickSlip type
   IF @cPickSlipType = '' 
   BEGIN
      IF @cZone IN ('XD', 'LB', 'LP')
         SET @cPickSlipType = 'X'

      ELSE IF @cOrderKey <> ''
         SET @cPickSlipType = 'D'

      ELSE IF @cExternOrderKey <> ''
         SET @cPickSlipType = 'C'
   
      ELSE 
      BEGIN
         SET @nErrNo = 64830
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid PSType
         GOTO Fail
      END
   END
   
Fail:

END

GO