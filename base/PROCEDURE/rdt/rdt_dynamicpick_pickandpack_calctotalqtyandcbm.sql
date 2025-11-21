SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_DynamicPick_PickAndPack_CalcTotalQTYAndCBM      */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Setup print job                                             */
/*                                                                      */
/* Called from: rdtfnc_DynamicPick_PickAndPack                          */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 21-Jun-2008 1.0  MaryVong    Created                                 */
/* 08-Dec-2011 1.1  Ung         SOS230234 Change status from 4 to 3     */
/* 19-Apr-2013 1.2  Ung         SOS276057 Add PickSlipNo6               */
/* 17-Jul-2013 1.3  Ung         SOS283844 Add PickSlipNo7-9             */
/* 28-Jul-2016 1.4  Ung         SOS375224 Add LoadKey, Zone optional    */
/************************************************************************/

CREATE PROC [RDT].[rdt_DynamicPick_PickAndPack_CalcTotalQTYAndCBM] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cPickZone     NVARCHAR( 10),
   @cFromLOC      NVARCHAR( 10),
   @cToLOC        NVARCHAR( 10),
   @cPickSlipType NVARCHAR( 1),
   @cPickSlipNo1  NVARCHAR( 10),
   @cPickSlipNo2  NVARCHAR( 10),
   @cPickSlipNo3  NVARCHAR( 10),
   @cPickSlipNo4  NVARCHAR( 10),
   @cPickSlipNo5  NVARCHAR( 10),
   @cPickSlipNo6  NVARCHAR( 10),
   @cPickSlipNo7  NVARCHAR( 10),
   @cPickSlipNo8  NVARCHAR( 10),
   @cPickSlipNo9  NVARCHAR( 10),
   @nTotalPickQTY INT           OUTPUT,
   @cTotalCBM     NVARCHAR( 20) OUTPUT
)
AS
BEGIN

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)

   SET @nTotalPickQTY = 0
   SET @cTotalCBM     = ''

   -- Performance tuning
   SET @cSQL = 
      ' DECLARE @tPickSlip TABLE (PickSlipNo NVARCHAR(10)) ' + 
      ' IF @cPickSlipNo1 <> '''' INSERT INTO @tPickSlip (PickSlipNo) VALUES (@cPickSlipNo1) ' + 
      ' IF @cPickSlipNo2 <> '''' INSERT INTO @tPickSlip (PickSlipNo) VALUES (@cPickSlipNo2) ' + 
      ' IF @cPickSlipNo3 <> '''' INSERT INTO @tPickSlip (PickSlipNo) VALUES (@cPickSlipNo3) ' + 
      ' IF @cPickSlipNo4 <> '''' INSERT INTO @tPickSlip (PickSlipNo) VALUES (@cPickSlipNo4) ' + 
      ' IF @cPickSlipNo5 <> '''' INSERT INTO @tPickSlip (PickSlipNo) VALUES (@cPickSlipNo5) ' + 
      ' IF @cPickSlipNo6 <> '''' INSERT INTO @tPickSlip (PickSlipNo) VALUES (@cPickSlipNo6) ' + 
      ' IF @cPickSlipNo7 <> '''' INSERT INTO @tPickSlip (PickSlipNo) VALUES (@cPickSlipNo7) ' + 
      ' IF @cPickSlipNo8 <> '''' INSERT INTO @tPickSlip (PickSlipNo) VALUES (@cPickSlipNo8) ' + 
      ' IF @cPickSlipNo9 <> '''' INSERT INTO @tPickSlip (PickSlipNo) VALUES (@cPickSlipNo9) '
   
   -- Cross dock PickSlip
   IF @cPickSlipType = 'X'
      SET @cSQL = @cSQL +
         ' SELECT ' + 
         '    @nTotalPickQTY = SUM(PD.QTY), ' + 
         '    @cTotalCBM     = SUM(PD.QTY * SKU.STDCube) ' + 
         ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' + 
         '    JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailkey) ' + 
         '    JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU) ' + 
         '    JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
         '    JOIN @tPickSlip t ON (RKL.PickSlipNo = t.PickSlipNo) ' + 
         ' WHERE PD.Status < ''3'' ' + 
         '    AND PD.QTY > 0 '

   -- Discrete PickSlip
   ELSE IF @cPickSlipType = 'D'
      SET @cSQL = @cSQL +
         ' SELECT ' + 
         '    @nTotalPickQTY = SUM(PD.QTY), ' + 
         '    @cTotalCBM     = SUM(PD.QTY * SKU.STDCube) ' + 
         ' FROM dbo.PickHeader PH WITH (NOLOCK) ' + 
         '    JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey) ' + 
         '    JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU) ' + 
         '    JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
         '    JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo) ' + 
         ' WHERE PD.Status < ''3'' ' + 
         '    AND PD.QTY > 0 '

   ELSE IF @cPickSlipType = 'C'
      SET @cSQL = @cSQL +
         ' SELECT ' + 
         '    @nTotalPickQTY = SUM(PD.QTY), ' + 
         '    @cTotalCBM     = SUM(PD.QTY * SKU.STDCube) ' + 
         ' FROM dbo.PickHeader PH WITH (NOLOCK) ' + 
         '    JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey) ' + 
         '    JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey) ' + 
         '    JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU) ' + 
         '    JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
         '    JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo) ' + 
         ' WHERE PD.Status < ''3'' ' + 
         '    AND PD.QTY > 0 '

   IF @cPickZone <> ''
      SET @cSQL = @cSQL + ' AND LOC.PickZone = @cPickZone '

   IF @cFromLOC <> ''
      SET @cSQL = @cSQL +
         ' AND LOC.LOC BETWEEN @cFromLoc AND @cToLoc ' + 
         ' AND PD.LOC BETWEEN  @cFromLoc AND @cToLoc '

   SET @cSQLParam = 
      '@cPickSlipNo1    NVARCHAR(10), ' + 
      '@cPickSlipNo2    NVARCHAR(10), ' + 
      '@cPickSlipNo3    NVARCHAR(10), ' + 
      '@cPickSlipNo4    NVARCHAR(10), ' + 
      '@cPickSlipNo5    NVARCHAR(10), ' + 
      '@cPickSlipNo6    NVARCHAR(10), ' + 
      '@cPickSlipNo7    NVARCHAR(10), ' + 
      '@cPickSlipNo8    NVARCHAR(10), ' + 
      '@cPickSlipNo9    NVARCHAR(10), ' + 
      '@cPickZone       NVARCHAR(10), ' + 
      '@cFromLOC        NVARCHAR(10), ' + 
      '@cToLOC          NVARCHAR(10), ' + 
      '@nTotalPickQTY   INT OUTPUT,   ' + 
      '@cTotalCBM       NVARCHAR( 20) OUTPUT '
      
   EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
      @cPickSlipNo1  = @cPickSlipNo1, 
      @cPickSlipNo2  = @cPickSlipNo2, 
      @cPickSlipNo3  = @cPickSlipNo3, 
      @cPickSlipNo4  = @cPickSlipNo4, 
      @cPickSlipNo5  = @cPickSlipNo5, 
      @cPickSlipNo6  = @cPickSlipNo6, 
      @cPickSlipNo7  = @cPickSlipNo7, 
      @cPickSlipNo8  = @cPickSlipNo8, 
      @cPickSlipNo9  = @cPickSlipNo9, 
      @cPickZone     = @cPickZone, 
      @cFromLOC      = @cFromLOC, 
      @cToLOC        = @cToLOC, 
      @nTotalPickQTY = @nTotalPickQTY OUTPUT, 
      @cTotalCBM     = @cTotalCBM     OUTPUT
      
/*
   BEGIN
      -- Zone and LOC range
      IF @cPickZone <> '' AND @cFromLOC <> ''
         SELECT
            @nTotalPickQTY = SUM(PD.QTY),
            @cTotalCBM     = SUM(PD.QTY * SKU.STDCube)
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailkey)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickSlip t ON (RKL.PickSlipNo = t.PickSlipNo)
         WHERE LOC.PickZone = @cPickZone
            AND LOC.LOC BETWEEN @cFromLOC AND @cToLOC
            AND PD.LOC BETWEEN @cFromLOC AND @cToLOC
            AND PD.Status < '3'
            AND PD.QTY > 0

      -- Zone
      ELSE IF @cPickZone <> ''
         SELECT
            @nTotalPickQTY = SUM(PD.QTY),
            @cTotalCBM     = SUM(PD.QTY * SKU.STDCube)
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailkey)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickSlip t ON (RKL.PickSlipNo = t.PickSlipNo)
         WHERE LOC.PickZone = @cPickZone
            AND PD.Status < '3'
            AND PD.QTY > 0

      -- LOC range
      ELSE IF @cFromLOC <> ''
         SELECT
            @nTotalPickQTY = SUM(PD.QTY),
            @cTotalCBM     = SUM(PD.QTY * SKU.STDCube)
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailkey)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickSlip t ON (RKL.PickSlipNo = t.PickSlipNo)
         WHERE LOC.LOC BETWEEN @cFromLOC AND @cToLOC
            AND PD.LOC BETWEEN @cFromLOC AND @cToLOC
            AND PD.Status < '3'
            AND PD.QTY > 0
            
      -- No zone and LOC range
      ELSE
         SELECT
            @nTotalPickQTY = SUM(PD.QTY),
            @cTotalCBM     = SUM(PD.QTY * SKU.STDCube)
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailkey)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            JOIN @tPickSlip t ON (RKL.PickSlipNo = t.PickSlipNo)
         WHERE PD.Status < '3'
            AND PD.QTY > 0
   END

   -- Discrete PickSlip
   ELSE IF @cPickSlipType = 'D'
   BEGIN
      -- Zone and LOC range
      IF @cPickZone <> '' AND @cFromLOC <> ''
         SELECT
            @nTotalPickQTY = SUM(PD.QTY),
            @cTotalCBM     = SUM(PD.QTY * SKU.STDCube)
         FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
         WHERE LOC.PickZone = @cPickZone
            AND LOC.LOC BETWEEN @cFromLOC AND @cToLOC
            AND PD.LOC BETWEEN @cFromLOC AND @cToLOC
            AND PD.Status < '3'
            AND PD.QTY > 0

      -- Zone
      ELSE IF @cPickZone <> ''
         SELECT
            @nTotalPickQTY = SUM(PD.QTY),
            @cTotalCBM     = SUM(PD.QTY * SKU.STDCube)
         FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
         WHERE LOC.PickZone = @cPickZone
            AND PD.Status < '3'
            AND PD.QTY > 0

      -- LOC range
      ELSE IF @cFromLOC <> ''
         SELECT
            @nTotalPickQTY = SUM(PD.QTY),
            @cTotalCBM     = SUM(PD.QTY * SKU.STDCube)
         FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
         WHERE LOC.LOC BETWEEN @cFromLOC AND @cToLOC
            AND PD.LOC BETWEEN @cFromLOC AND @cToLOC
            AND PD.Status < '3'
            AND PD.QTY > 0

      -- No zone and LOC range
      ELSE
         SELECT
            @nTotalPickQTY = SUM(PD.QTY),
            @cTotalCBM     = SUM(PD.QTY * SKU.STDCube)
         FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
         WHERE PD.Status < '3'
            AND PD.QTY > 0
   END

   -- Conso PickSlip
   ELSE IF @cPickSlipType = 'C'
   BEGIN
      -- Zone and LOC range
      IF @cPickZone <> '' AND @cFromLOC <> ''
         SELECT
            @nTotalPickQTY = SUM(PD.QTY),
            @cTotalCBM     = SUM(PD.QTY * SKU.STDCube)
         FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
         WHERE LOC.PickZone = @cPickZone
            AND LOC.LOC BETWEEN @cFromLOC AND @cToLOC
            AND PD.LOC BETWEEN @cFromLOC AND @cToLOC
            AND PD.Status < '3'
            AND PD.QTY > 0

      -- Zone
      ELSE IF @cPickZone <> ''
         SELECT
            @nTotalPickQTY = SUM(PD.QTY),
            @cTotalCBM     = SUM(PD.QTY * SKU.STDCube)
         FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
         WHERE LOC.PickZone = @cPickZone
            AND PD.Status < '3'
            AND PD.QTY > 0

      -- LOC range
      ELSE IF @cFromLOC <> ''
         SELECT
            @nTotalPickQTY = SUM(PD.QTY),
            @cTotalCBM     = SUM(PD.QTY * SKU.STDCube)
         FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
         WHERE LOC.LOC BETWEEN @cFromLOC AND @cToLOC
            AND PD.LOC BETWEEN @cFromLOC AND @cToLOC
            AND PD.Status < '3'
            AND PD.QTY > 0

      -- No zone and LOC range
      ELSE
         SELECT
            @nTotalPickQTY = SUM(PD.QTY),
            @cTotalCBM     = SUM(PD.QTY * SKU.STDCube)
         FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
         WHERE PD.Status < '3'
            AND PD.QTY > 0
   END
*/
   IF @nTotalPickQTY IS NULL  SET @nTotalPickQTY = 0
   IF @cTotalCBM     IS NULL  SET @cTotalCBM     = 0

END

GO