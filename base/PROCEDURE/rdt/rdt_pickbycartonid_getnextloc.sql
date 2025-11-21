SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PickByCartonID_GetNextLOC                             */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2019-03-18  1.0  Ung      WMS-8284 Created                                 */
/* 2019-10-24  1.1  Ung      WMS-10821 Add PickDetail filter                  */
/* 2022-04-04  1.2  Ung      WMS-18892 Wave optional                          */
/*                           Add PickConfirmStatus                            */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_PickByCartonID_GetNextLOC] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cWaveKey      NVARCHAR( 10),
   @cPWZone       NVARCHAR( 10),
   @cCartonID1    NVARCHAR( 20),
   @cCartonID2    NVARCHAR( 20),
   @cCartonID3    NVARCHAR( 20),
   @cCartonID4    NVARCHAR( 20),
   @cCartonID5    NVARCHAR( 20),
   @cCartonID6    NVARCHAR( 20),
   @cCartonID7    NVARCHAR( 20),
   @cCartonID8    NVARCHAR( 20),
   @cCartonID9    NVARCHAR( 20),
   @cCurrLOC      NVARCHAR( 10),   
   @cNextLOC      NVARCHAR( 10)  OUTPUT,
   @nErrNo     	INT            OUTPUT, 
   @cErrMsg    	NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowCount         INT
   DECLARE @cSQL              NVARCHAR( MAX)
   DECLARE @cSQLParam         NVARCHAR( MAX)

   DECLARE @cCurrLogicalLOC   NVARCHAR(18)
   DECLARE @cPickFilter       NVARCHAR( MAX) = ''
   DECLARE @cPickConfirmStatus NVARCHAR( 1)
   DECLARE @tCartonID         VariableTable   
   
   SET @nErrNo = 0
   SET @cErrMsg = ''

   -- Get storer config
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'

   -- Get logical LOC
   SET @cCurrLogicalLOC = ''
   SELECT @cCurrLogicalLOC = LogicalLocation FROM LOC WITH (NOLOCK) WHERE LOC = @cCurrLOC

   -- Get pick filter
   SELECT @cPickFilter = ISNULL( Long, '')
   FROM CodeLKUP WITH (NOLOCK) 
   WHERE ListName = 'PickFilter'
      AND Code = @nFunc 
      AND StorerKey = @cStorerKey
      AND Code2 = @cFacility
   
   IF @cCartonID1 <> '' INSERT INTO @tCartonID (Value) VALUES (@cCartonID1) 
   IF @cCartonID2 <> '' INSERT INTO @tCartonID (Value) VALUES (@cCartonID2) 
   IF @cCartonID3 <> '' INSERT INTO @tCartonID (Value) VALUES (@cCartonID3) 
   IF @cCartonID4 <> '' INSERT INTO @tCartonID (Value) VALUES (@cCartonID4) 
   IF @cCartonID5 <> '' INSERT INTO @tCartonID (Value) VALUES (@cCartonID5) 
   IF @cCartonID6 <> '' INSERT INTO @tCartonID (Value) VALUES (@cCartonID6) 
   IF @cCartonID7 <> '' INSERT INTO @tCartonID (Value) VALUES (@cCartonID7) 
   IF @cCartonID8 <> '' INSERT INTO @tCartonID (Value) VALUES (@cCartonID8) 
   IF @cCartonID9 <> '' INSERT INTO @tCartonID (Value) VALUES (@cCartonID9)

   -- Get next LOC
   /*
   IF @cPWZone = ''
      SELECT TOP 1 
         @cNextLOC = PD.LOC
      FROM WaveDetail WD WITH (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (WD.OrderKey = PD.OrderKey)
         JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         JOIN @tCartonID t ON (PD.CaseID = t.CartonID)
      WHERE WD.WaveKey = @cWaveKey
         -- AND LOC.PutawayZone = @cPWZone
         AND LOC.LocationType <> 'OTHER'
         AND PD.Status < '5'
         AND PD.Status <> '4'
         AND PD.QTY > 0
         AND (LOC.LogicalLocation > @cCurrLogicalLOC
         OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))
      ORDER BY LOC.LogicalLocation, LOC.LOC
   ELSE
      SELECT TOP 1 
         @cNextLOC = PD.LOC
      FROM WaveDetail WD WITH (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (WD.OrderKey = PD.OrderKey)
         JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         JOIN @tCartonID t ON (PD.CaseID = t.CartonID)
      WHERE WD.WaveKey = @cWaveKey
         AND LOC.PutawayZone = @cPWZone
         AND LOC.LocationType <> 'OTHER'
         AND PD.Status < '5'
         AND PD.Status <> '4'
         AND PD.QTY > 0
         AND (LOC.LogicalLocation > @cCurrLogicalLOC
         OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))
      ORDER BY LOC.LogicalLocation, LOC.LOC
   */
   SET @cSQL = 
      ' SELECT TOP 1 ' + 
         ' @cNextLOC = PD.LOC ' + 
      ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
         ' JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
         ' JOIN @tCartonID t ON (PD.CaseID = t.Value) ' + 
         CASE WHEN @cWaveKey <> '' THEN ' JOIN WaveDetail WD WITH (NOLOCK) ON (WD.OrderKey = PD.OrderKey) ' ELSE '' END + 
      ' WHERE PD.Status < @cPickConfirmStatus ' + 
         ' AND PD.Status <> ''4'' ' + 
         ' AND PD.QTY > 0 ' + 
         CASE WHEN @cWaveKey <> '' THEN ' AND WD.WaveKey = @cWaveKey ' ELSE '' END + 
         CASE WHEN @cPWZone = '' THEN '' ELSE ' AND LOC.PutawayZone = @cPWZone ' END + 
         CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END + 
         ' AND (LOC.LogicalLocation > @cCurrLogicalLOC ' + 
         ' OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC)) ' + 
      ' ORDER BY LOC.LogicalLocation, LOC.LOC ' + 
      ' SET @nRowCount = @@ROWCOUNT '
   
   SET @cSQLParam = 
      ' @cWaveKey          NVARCHAR( 10), ' + 
      ' @cPWZone           NVARCHAR( 10), ' + 
      ' @cCurrLOC          NVARCHAR( 10), ' + 
      ' @cCurrLogicalLOC   NVARCHAR( 18), ' +  
      ' @cPickConfirmStatus NVARCHAR( 1), ' + 
      ' @tCartonID         VariableTable READONLY, ' + 
      ' @cNextLOC          NVARCHAR( 10) OUTPUT,   ' +
      ' @nRowCount         INT           OUTPUT    ' 

   EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cWaveKey, @cPWZone, @cCurrLOC, @cCurrLogicalLOC, @cPickConfirmStatus, @tCartonID, 
      @cNextLOC  OUTPUT,
      @nRowCount OUTPUT 

   -- If no more next LOC then start search entire putaway zone, coz user might skip LOC
   IF @nRowCount = 0
   BEGIN
      /*
      IF @cPWZone = ''
   	   SELECT TOP 1 
   	      @cNextLOC = PD.LOC
         FROM WaveDetail WD WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (WD.OrderKey = PD.OrderKey)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tCartonID t ON (PD.CaseID = t.CartonID)
         WHERE WD.WaveKey = @cWaveKey
            -- AND LOC.PutawayZone = @cPWZone
            AND LOC.LocationType <> 'OTHER'
            AND PD.Status < '5'
            AND PD.Status <> '4'
            AND PD.QTY > 0
   	   ORDER BY LOC.LogicalLocation, LOC.LOC  	
      ELSE
   	   SELECT TOP 1 
   	      @cNextLOC = PD.LOC
         FROM WaveDetail WD WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (WD.OrderKey = PD.OrderKey)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tCartonID t ON (PD.CaseID = t.CartonID)
         WHERE WD.WaveKey = @cWaveKey
            AND LOC.PutawayZone = @cPWZone
            AND LOC.LocationType <> 'OTHER'
            AND PD.Status < '5'
            AND PD.Status <> '4'
            AND PD.QTY > 0
   	   ORDER BY LOC.LogicalLocation, LOC.LOC  	
      */
      SET @cSQL = 
   	   ' SELECT TOP 1 ' +
   	      ' @cNextLOC = PD.LOC ' +
         ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +
            ' JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' +
            ' JOIN @tCartonID t ON (PD.CaseID = t.Value) ' +
            CASE WHEN @cWaveKey <> '' THEN ' JOIN WaveDetail WD WITH (NOLOCK) ON (WD.OrderKey = PD.OrderKey) ' ELSE '' END + 
         ' WHERE PD.Status < @cPickConfirmStatus ' + 
            ' AND PD.Status <> ''4'' ' +
            ' AND PD.QTY > 0 ' +
            CASE WHEN @cWaveKey <> '' THEN ' AND WD.WaveKey = @cWaveKey ' ELSE '' END + 
            CASE WHEN @cPWZone = '' THEN '' ELSE ' AND LOC.PutawayZone = @cPWZone ' END + 
            CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END + 

   	   ' ORDER BY LOC.LogicalLocation, LOC.LOC ' +
         ' SET @nRowCount = @@ROWCOUNT '

      SET @cSQLParam = 
         ' @cWaveKey    NVARCHAR( 10), ' + 
         ' @cPWZone     NVARCHAR( 10), ' + 
         ' @cPickConfirmStatus NVARCHAR( 1), ' + 
         ' @tCartonID   VariableTable READONLY, ' + 
         ' @cNextLOC    NVARCHAR( 10) OUTPUT,   ' +
         ' @nRowCount   INT           OUTPUT    ' 

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cWaveKey, @cPWZone, @cPickConfirmStatus, @tCartonID, 
         @cNextLOC  OUTPUT,
         @nRowCount OUTPUT 
            
      -- If really no more LOC, prompt error
      IF @nRowCount = 0
      BEGIN   	
         SET @nErrNo = 136401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more PKLOC
         GOTO Quit
      END      	
   END   
   
Quit:
   SET @cNextLOC = CASE WHEN @cNextLOC <> '' THEN @cNextLOC ELSE @cCurrLOC END
   	
END


GO