SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_DynamicPick_PickAndPack_GetNextLOC              */
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
/* 18-Jun-2008 1.0  UngDH    	  Created                                 */
/* 18-Sep-2008 1.1  Shong       Performance Tuning                      */ 
/* 08-Dec-2011 1.2  Ung         SOS230234 Change status from 4 to 3     */
/* 19-Apr-2013 1.3  Ung         SOS276057 Add PickSlipNo6               */
/* 17-Jul-2013 1.4  Ung         SOS283844 Add PickSlipNo7-9             */
/*                              Sort by Logical, LOC, SKU, L1-4, PSNO   */
/* 07-Jan-2014 1.5  Ung         Performance tuning                      */
/* 03-Nov-2015 1.6  Ung         Performance tuning                      */
/* 28-Jul-2016 1.7  Ung         SOS375224 Add LoadKey, Zone optional    */
/* 16-Apr-2018 1.8  James       Bug fix on logicalloc variable          */
/*                              lenght declaration (james01)            */
/************************************************************************/

CREATE PROC [RDT].[rdt_DynamicPick_PickAndPack_GetNextLOC] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cFacility       NVARCHAR( 5),
   @cStorerKey      NVARCHAR( 15),
   @cPickZone       NVARCHAR( 10),
   @cFromLoc        NVARCHAR( 10),
   @cToLoc          NVARCHAR( 10),
   @cPickSlipType   NVARCHAR( 1),
   @cPickSlipNo1    NVARCHAR( 10),
   @cPickSlipNo2    NVARCHAR( 10),
   @cPickSlipNo3    NVARCHAR( 10),
   @cPickSlipNo4    NVARCHAR( 10),
   @cPickSlipNo5    NVARCHAR( 10),
   @cPickSlipNo6    NVARCHAR( 10),
   @cPickSlipNo7    NVARCHAR( 10),
   @cPickSlipNo8    NVARCHAR( 10),
   @cPickSlipNo9    NVARCHAR( 10),
   @cCurrLOC        NVARCHAR( 10),   
   @cNextLOC        NVARCHAR( 10)  OUTPUT,
   @nErrNo     	  INT            OUTPUT, 
   @cErrMsg    	  NVARCHAR( 20)  OUTPUT  -- screen limitation, 20 char max   
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQL1     NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)
   DECLARE @cOrder    NVARCHAR( 1000)
   DECLARE @nRowCount INT
   
   SET @nErrNo = 0
   SET @cErrMsg = ''

   -- Get logical LOC
   DECLARE @cCurrLogicalLOC NVARCHAR(18)
   SET @cCurrLogicalLOC = ''
   SELECT @cCurrLogicalLOC = LogicalLocation FROM LOC WITH (NOLOCK) WHERE LOC = @cCurrLOC

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
         ' SELECT TOP 1 ' + 
         '    @cNextLOC = PD.LOC ' + 
         ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' + 
         '    JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailkey) ' + 
         '    JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
         '    JOIN @tPickSlip t ON (RKL.PickSlipNo = t.PickSlipNo) ' + 
         ' WHERE PD.Status < ''3'' ' + 
         '    AND PD.QTY > 0 '

   -- Discrete PickSlip
   ELSE IF @cPickSlipType = 'D'
      SET @cSQL = @cSQL +
         ' SELECT TOP 1 ' + 
         '    @cNextLOC = PD.LOC ' + 
         ' FROM dbo.PickHeader PH WITH (NOLOCK) ' + 
         '    JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey) ' + 
         '    JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
         '    JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo) ' + 
         ' WHERE PD.Status < ''3'' ' + 
         '    AND PD.QTY > 0 '

   ELSE IF @cPickSlipType = 'C'
      SET @cSQL = @cSQL +
         ' SELECT TOP 1 ' + 
         '    @cNextLOC = PD.LOC ' + 
         ' FROM dbo.PickHeader PH WITH (NOLOCK) ' + 
         '    JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey) ' + 
         '    JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey) ' + 
         '    JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
         '    JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo) ' + 
         ' WHERE PD.Status < ''3'' ' + 
         '    AND PD.QTY > 0 '

   IF @cPickZone <> ''
      SET @cSQL  = @cSQL  + ' AND LOC.PickZone = @cPickZone '
   
   IF @cFromLOC <> ''
      SET @cSQL = @cSQL +
         ' AND LOC.LOC BETWEEN @cFromLoc AND @cToLoc ' + 
         ' AND PD.LOC BETWEEN  @cFromLoc AND @cToLoc '

   SET @cOrder = 
      ' ORDER BY LOC.LogicalLocation, LOC.LOC ' + 
      ' SET @nRowCount = @@ROWCOUNT ' 

   SET @cSQL1 = @cSQL +
      ' AND (LOC.LogicalLocation > @cCurrLogicalLOC ' + 
      ' OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC)) ' + @cOrder       

   SET @cSQL = @cSQL + @cOrder
   
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
      '@cCurrLOC        NVARCHAR(10), ' + 
      '@cCurrLogicalLOC NVARCHAR(18), ' + -- (james01)
      '@cNextLOC        NVARCHAR(10) OUTPUT, ' + 
      '@nRowCount       INT          OUTPUT  ' 

   EXEC sp_ExecuteSQL @cSQL1, @cSQLParam, -- With CurrLOC
      @cPickSlipNo1    = @cPickSlipNo1, 
      @cPickSlipNo2    = @cPickSlipNo2, 
      @cPickSlipNo3    = @cPickSlipNo3, 
      @cPickSlipNo4    = @cPickSlipNo4, 
      @cPickSlipNo5    = @cPickSlipNo5, 
      @cPickSlipNo6    = @cPickSlipNo6, 
      @cPickSlipNo7    = @cPickSlipNo7, 
      @cPickSlipNo8    = @cPickSlipNo8, 
      @cPickSlipNo9    = @cPickSlipNo9, 
      @cPickZone       = @cPickZone, 
      @cFromLOC        = @cFromLOC, 
      @cToLOC          = @cToLOC, 
      @cCurrLOC        = @cCurrLOC, 
      @cCurrLogicalLOC = @cCurrLogicalLOC, 
      @cNextLOC        = @cNextLOC  OUTPUT, 
      @nRowCount       = @nRowCount OUTPUT

      -- If no more next LOC then start search from first loc till last loc. Coz user might skip LOC
      IF @nRowCount = 0
      BEGIN
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, -- Without CurrLOC
            @cPickSlipNo1    = @cPickSlipNo1, 
            @cPickSlipNo2    = @cPickSlipNo2, 
            @cPickSlipNo3    = @cPickSlipNo3, 
            @cPickSlipNo4    = @cPickSlipNo4, 
            @cPickSlipNo5    = @cPickSlipNo5, 
            @cPickSlipNo6    = @cPickSlipNo6, 
            @cPickSlipNo7    = @cPickSlipNo7, 
            @cPickSlipNo8    = @cPickSlipNo8, 
            @cPickSlipNo9    = @cPickSlipNo9, 
            @cPickZone       = @cPickZone, 
            @cFromLOC        = @cFromLOC, 
            @cToLOC          = @cToLOC, 
            @cCurrLOC        = @cCurrLOC, 
            @cCurrLogicalLOC = @cCurrLogicalLOC, 
            @cNextLOC        = @cNextLOC  OUTPUT, 
            @nRowCount       = @nRowCount OUTPUT

         -- If really no more LOC, prompt error
         IF @nRowCount = 0
         BEGIN   	
            SET @nErrNo = 64551
            SET @cErrMsg = rdt.rdtgetmessage( 64551, @cLangCode, 'DSP') -- 'No more PKLOC'
            GOTO Quit
         END      	
      END

/*
   -- Cross dock PickSlip
   IF @cPickSlipType = 'X'
   BEGIN
      -- Zone and LOC range
      IF @cPickZone <> '' AND @cFromLoc <> ''
         SELECT TOP 1 
            @cNextLOC = PD.LOC
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailkey)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickSlip t ON (RKL.PickSlipNo = t.PickSlipNo)
         WHERE LOC.PickZone = @cPickZone
            AND LOC.LOC BETWEEN @cFromLoc AND @cToLoc 
            AND PD.LOC BETWEEN @cFromLoc AND @cToLoc
            AND PD.Status < '3'
            AND PD.QTY > 0
            AND (LOC.LogicalLocation > @cCurrLogicalLOC
            OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))
         ORDER BY LOC.LogicalLocation, LOC.LOC

      -- Zone
      ELSE IF @cPickZone <> ''
         SELECT TOP 1 
            @cNextLOC = PD.LOC
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailkey)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickSlip t ON (RKL.PickSlipNo = t.PickSlipNo)
         WHERE LOC.PickZone = @cPickZone
            AND PD.Status < '3'
            AND PD.QTY > 0
            AND (LOC.LogicalLocation > @cCurrLogicalLOC
            OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))
         ORDER BY LOC.LogicalLocation, LOC.LOC
      
      -- LOC range
      ELSE 
         SELECT TOP 1 
            @cNextLOC = PD.LOC
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailkey)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickSlip t ON (RKL.PickSlipNo = t.PickSlipNo)
         WHERE LOC.LOC BETWEEN @cFromLoc AND @cToLoc 
            AND PD.LOC BETWEEN @cFromLoc AND @cToLoc
            AND PD.Status < '3'
            AND PD.QTY > 0
            AND (LOC.LogicalLocation > @cCurrLogicalLOC
            OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))
         ORDER BY LOC.LogicalLocation, LOC.LOC

      -- If no more next LOC then start search from first loc till last loc. Coz user might skip LOC
      IF @@ROWCOUNT = 0
      BEGIN
         -- Zone and LOC range
         IF @cPickZone <> '' AND @cFromLoc <> ''
      	   SELECT TOP 1 
      	      @cNextLOC = PD.LOC
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailkey)
               JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               JOIN @tPickSlip t ON (RKL.PickSlipNo = t.PickSlipNo)
            WHERE LOC.PickZone = @cPickZone
               AND LOC.LOC BETWEEN @cFromLoc AND @cToLoc 
               AND PD.LOC BETWEEN @cFromLoc AND @cToLoc
      	      AND PD.Status < '3'
      	      AND PD.QTY > 0
      	   ORDER BY LOC.LogicalLocation, LOC.LOC  	
      	   
         -- Zone
         ELSE IF @cPickZone <> ''
      	   SELECT TOP 1 
      	      @cNextLOC = PD.LOC
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailkey)
               JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               JOIN @tPickSlip t ON (RKL.PickSlipNo = t.PickSlipNo)
            WHERE LOC.PickZone = @cPickZone
      	      AND PD.Status < '3'
      	      AND PD.QTY > 0
      	   ORDER BY LOC.LogicalLocation, LOC.LOC  	

         -- LOC range
         ELSE
      	   SELECT TOP 1 
      	      @cNextLOC = PD.LOC
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailkey)
               JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               JOIN @tPickSlip t ON (RKL.PickSlipNo = t.PickSlipNo)
            WHERE LOC.LOC BETWEEN @cFromLoc AND @cToLoc 
               AND PD.LOC BETWEEN @cFromLoc AND @cToLoc
      	      AND PD.Status < '3'
      	      AND PD.QTY > 0
      	   ORDER BY LOC.LogicalLocation, LOC.LOC  	
   
         -- If really no more LOC, prompt error
         IF @@ROWCOUNT = 0
         BEGIN   	
            SET @nErrNo = 64551
            SET @cErrMsg = rdt.rdtgetmessage( 64551, @cLangCode, 'DSP') -- 'No more PKLOC'
            GOTO Quit
         END      	
      END   
   END

   -- Discrete PickSlip
   ELSE IF @cPickSlipType = 'D'
   BEGIN
      -- Zone and LOC range
      IF @cPickZone <> '' AND @cFromLoc <> ''
         SELECT TOP 1 
            @cNextLOC = PD.LOC
         FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
         WHERE LOC.PickZone = @cPickZone
            AND LOC.LOC BETWEEN @cFromLoc AND @cToLoc 
            AND PD.LOC BETWEEN @cFromLoc AND @cToLoc
            AND PD.Status < '3'
            AND PD.QTY > 0
            AND (LOC.LogicalLocation > @cCurrLogicalLOC
            OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))
         ORDER BY LOC.LogicalLocation, LOC.LOC

      -- Zone
      ELSE IF @cPickZone <> ''
         SELECT TOP 1 
            @cNextLOC = PD.LOC
         FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
         WHERE LOC.PickZone = @cPickZone
            AND PD.Status < '3'
            AND PD.QTY > 0
            AND (LOC.LogicalLocation > @cCurrLogicalLOC
            OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))
         ORDER BY LOC.LogicalLocation, LOC.LOC

      -- LOC range
      ELSE
         SELECT TOP 1 
            @cNextLOC = PD.LOC
         FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
         WHERE LOC.LOC BETWEEN @cFromLoc AND @cToLoc 
            AND PD.LOC BETWEEN @cFromLoc AND @cToLoc
            AND PD.Status < '3'
            AND PD.QTY > 0
            AND (LOC.LogicalLocation > @cCurrLogicalLOC
            OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))
         ORDER BY LOC.LogicalLocation, LOC.LOC

      -- If no more next LOC then start search from first loc till last loc. Coz user might skip LOC
      IF @@ROWCOUNT = 0
      BEGIN
         -- Zone and LOC range
         IF @cPickZone <> '' AND @cFromLoc <> ''
      	   SELECT TOP 1 
      	      @cNextLOC = PD.LOC
            FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
            WHERE LOC.PickZone = @cPickZone
               AND LOC.LOC BETWEEN @cFromLoc AND @cToLoc 
               AND PD.LOC BETWEEN @cFromLoc AND @cToLoc
      	      AND PD.Status < '3'
      	      AND PD.QTY > 0
      	   ORDER BY LOC.LogicalLocation, LOC.LOC  	
      	   
         -- Zone
         ELSE IF @cPickZone <> ''
            -- By PickZone
      	   SELECT TOP 1 
      	      @cNextLOC = PD.LOC
            FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
            WHERE LOC.PickZone = @cPickZone
      	      AND PD.Status < '3'
      	      AND PD.QTY > 0
      	   ORDER BY LOC.LogicalLocation, LOC.LOC  	
         
         -- LOC range
         ELSE
      	   SELECT TOP 1 
      	      @cNextLOC = PD.LOC
            FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
            WHERE LOC.LOC BETWEEN @cFromLoc AND @cToLoc 
               AND PD.LOC BETWEEN @cFromLoc AND @cToLoc
      	      AND PD.Status < '3'
      	      AND PD.QTY > 0
      	   ORDER BY LOC.LogicalLocation, LOC.LOC  	
   
         -- If really no more LOC, prompt error
         IF @@ROWCOUNT = 0
         BEGIN   	
            SET @nErrNo = 64551
            SET @cErrMsg = rdt.rdtgetmessage( 64551, @cLangCode, 'DSP') -- 'No more PKLOC'
            GOTO Quit
         END      	
      END   
   END
   
   -- Conso PickSlip
   ELSE IF @cPickSlipType = 'C'
   BEGIN
      -- Zone and LOC range
      IF @cPickZone <> '' AND @cFromLoc <> ''
         SELECT TOP 1 
            @cNextLOC = PD.LOC
         FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
         WHERE LOC.PickZone = @cPickZone
            AND LOC.LOC BETWEEN @cFromLoc AND @cToLoc 
            AND PD.LOC BETWEEN @cFromLoc AND @cToLoc
            AND PD.Status < '3'
            AND PD.QTY > 0
            AND (LOC.LogicalLocation > @cCurrLogicalLOC
            OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))
         ORDER BY LOC.LogicalLocation, LOC.LOC
         
      -- Zone
      ELSE IF @cPickZone <> ''
         SELECT TOP 1 
            @cNextLOC = PD.LOC
         FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
         WHERE LOC.PickZone = @cPickZone
            AND PD.Status < '3'
            AND PD.QTY > 0
            AND (LOC.LogicalLocation > @cCurrLogicalLOC
            OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))
         ORDER BY LOC.LogicalLocation, LOC.LOC

      -- LOC range
      ELSE
         SELECT TOP 1 
            @cNextLOC = PD.LOC
         FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
         WHERE LOC.LOC BETWEEN @cFromLoc AND @cToLoc 
            AND PD.LOC BETWEEN @cFromLoc AND @cToLoc
            AND PD.Status < '3'
            AND PD.QTY > 0
            AND (LOC.LogicalLocation > @cCurrLogicalLOC
            OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))
         ORDER BY LOC.LogicalLocation, LOC.LOC

      -- If no more next LOC then start search from first loc till last loc. Coz user might skip LOC
      IF @@ROWCOUNT = 0
      BEGIN
         -- Zone and LOC range
         IF @cPickZone <> '' AND @cFromLoc <> ''
      	   SELECT TOP 1 
      	      @cNextLOC = PD.LOC
            FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
            WHERE LOC.PickZone = @cPickZone
               AND LOC.LOC BETWEEN @cFromLoc AND @cToLoc 
               AND PD.LOC BETWEEN @cFromLoc AND @cToLoc
      	      AND PD.Status < '3'
      	      AND PD.QTY > 0
      	   ORDER BY LOC.LogicalLocation, LOC.LOC  
      	   
         -- Zone
         ELSE IF @cPickZone <> ''
            -- By PickZone
      	   SELECT TOP 1 
      	      @cNextLOC = PD.LOC
            FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
            WHERE LOC.PickZone = @cPickZone
      	      AND PD.Status < '3'
      	      AND PD.QTY > 0
      	   ORDER BY LOC.LogicalLocation, LOC.LOC  	

         -- LOC range
         ELSE
      	   SELECT TOP 1 
      	      @cNextLOC = PD.LOC
            FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
            WHERE LOC.PickZone = @cPickZone
               AND LOC.LOC BETWEEN @cFromLoc AND @cToLoc 
               AND PD.LOC BETWEEN @cFromLoc AND @cToLoc
      	      AND PD.Status < '3'
      	      AND PD.QTY > 0
      	   ORDER BY LOC.LogicalLocation, LOC.LOC  	
   
         -- If really no more LOC, prompt error
         IF @@ROWCOUNT = 0
         BEGIN   	
            SET @nErrNo = 64551
            SET @cErrMsg = rdt.rdtgetmessage( 64551, @cLangCode, 'DSP') -- 'No more PKLOC'
            GOTO Quit
         END      	
      END   
   END
*/
   
Quit:
   SET @cNextLOC = CASE WHEN @cNextLOC <> '' THEN @cNextLOC ELSE @cCurrLOC END
   	
END


GO