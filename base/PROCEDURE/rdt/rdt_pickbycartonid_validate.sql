SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PickByCartonID_Validate                               */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2019-03-18  1.0  Ung      WMS-8284 Created                                 */
/* 2019-10-24  1.1  Ung      WMS-10821 Add PickDetail filter                  */
/* 2022-04-04  1.2  Ung      WMS-18892 Wave optional                          */
/*                           Add PickConfirmStatus                            */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_PickByCartonID_Validate] (
   @nMobile       INT,             
   @nFunc         INT,             
   @cLangCode     NVARCHAR( 3),    
   @nStep         INT,             
   @nInputKey     INT,             
   @cFacility     NVARCHAR( 5),     
   @cStorerKey    NVARCHAR( 15),  
	@cWaveKey      NVARCHAR( 10),
   @cPWZone       NVARCHAR( 10),
   @cCartonID     NVARCHAR( 20),
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL              NVARCHAR( MAX)
   DECLARE @cSQLParam         NVARCHAR( MAX)
   DECLARE @nRowCount         INT
   DECLARE @nQTY              INT
   DECLARE @nPickQTY          INT 
   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cExternOrderKey   NVARCHAR( 10)
   DECLARE @cZone             NVARCHAR( 18)
   DECLARE @cPickFilter       NVARCHAR( MAX) = ''
   DECLARE @cPickConfirmStatus NVARCHAR( 1)

   SET @nQTY = 0
	SET @nErrNo = 0
	SET @cErrMsg = ''
	SET @nPickQTY = 0

   -- Get storer config
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'

   -- Check carton ID in wave
   IF @cWaveKey <> ''
   BEGIN
      IF NOT EXISTS( SELECT TOP 1 1
         FROM WaveDetail WD WITH (NOLOCK)
            JOIN PickDetail PD WITH (NOLOCK) ON (WD.OrderKey = PD.OrderKey)
         WHERE WD.WaveKey = @cWaveKey
            AND PD.CaseID = @cCartonID)
      BEGIN
         SET @nErrNo = 136351
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- CTNIDNotInWave
         GOTO Fail
      END
   END

   /*
   IF @cPWZone = ''
   BEGIN
      -- Check QTY to pick
      IF NOT EXISTS( SELECT TOP 1 1
         FROM WaveDetail WD WITH (NOLOCK)
            JOIN PickDetail PD WITH (NOLOCK) ON (WD.OrderKey = PD.OrderKey)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         WHERE WD.WaveKey = @cWaveKey
            -- AND LOC.PutawayZone = @cPWZone
            AND LOC.LocationType <> 'OTHER'
            AND PD.CaseID = @cCartonID
            AND PD.Status < '5'
            AND PD.Status <> '4'
            AND PD.QTY > 0)
      BEGIN
         SET @nErrNo = 136352
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No QTY To Pick
         GOTO Fail
      END
   END
   ELSE
   BEGIN
      -- Check QTY to pick
      IF NOT EXISTS( SELECT TOP 1 1
         FROM WaveDetail WD WITH (NOLOCK)
            JOIN PickDetail PD WITH (NOLOCK) ON (WD.OrderKey = PD.OrderKey)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         WHERE WD.WaveKey = @cWaveKey
            AND LOC.PutawayZone = @cPWZone
            AND LOC.LocationType <> 'OTHER'
            AND PD.CaseID = @cCartonID
            AND PD.Status < '5'
            AND PD.Status <> '4'
            AND PD.QTY > 0)
      BEGIN
         SET @nErrNo = 136353
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No QTY To Pick
         GOTO Fail
      END
   END
   */
   -- Get pick filter
   SELECT @cPickFilter = ISNULL( Long, '')
   FROM CodeLKUP WITH (NOLOCK) 
   WHERE ListName = 'PickFilter'
      AND Code = @nFunc 
      AND StorerKey = @cStorerKey
      AND Code2 = @cFacility

	SET @nRowCount = 0
   SET @cSQL = 
      ' SELECT TOP 1 @nRowCount = 1 ' + 
      ' FROM PickDetail PD WITH (NOLOCK) ' + 
         ' JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
         CASE WHEN @cWaveKey <> '' THEN ' JOIN WaveDetail WD WITH (NOLOCK) ON (WD.OrderKey = PD.OrderKey) ' ELSE '' END + 
      ' WHERE PD.CaseID = @cCartonID ' + 
         ' AND PD.Status < @cPickConfirmStatus ' + 
         ' AND PD.Status <> ''4'' ' + 
         ' AND PD.QTY > 0 ' + 
         CASE WHEN @cWaveKey <> '' THEN ' AND WD.WaveKey = @cWaveKey ' ELSE '' END + 
         CASE WHEN @cPWZone = '' THEN '' ELSE ' AND LOC.PutawayZone = @cPWZone ' END + 
         CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END

   SET @cSQLParam = 
      ' @cWaveKey    NVARCHAR( 10), ' + 
      ' @cCartonID   NVARCHAR( 20), ' +
      ' @cPWZone     NVARCHAR( 10), ' +
      ' @cPickConfirmStatus NVARCHAR( 1), ' + 
      ' @nRowCount   INT OUTPUT     ' 

   EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cWaveKey, @cCartonID, @cPWZone, @cPickConfirmStatus, 
      @nRowCount OUTPUT

   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 136353
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No QTY To Pick
      GOTO Fail
   END

   -- Check replenish not yet done
   /*
   IF EXISTS( SELECT TOP 1 1
      FROM WaveDetail WD WITH (NOLOCK)
         JOIN PickDetail PD WITH (NOLOCK) ON (WD.OrderKey = PD.OrderKey)
         JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
      WHERE WD.WaveKey = @cWaveKey
         AND LOC.LocationType = 'OTHER'
         AND PD.CaseID = @cCartonID
         AND PD.Status < '5'
         AND PD.Status <> '4'
         AND PD.QTY > 0)
   */
   /*
	SET @nRowCount = 0
   SET @cSQL = 
      ' SELECT TOP 1 @nRowCount = 1 ' + 
      ' FROM WaveDetail WD WITH (NOLOCK) ' + 
         ' JOIN PickDetail PD WITH (NOLOCK) ON (WD.OrderKey = PD.OrderKey) ' + 
         ' JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
      ' WHERE WD.WaveKey = @cWaveKey ' + 
         ' AND PD.CaseID = @cCartonID ' + 
         ' AND PD.Status < ''5'' ' + 
         ' AND PD.Status <> ''4'' ' + 
         ' AND PD.QTY > 0 ' + 
         CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END
   
      SET @cSQLParam = 
         ' @cWaveKey    NVARCHAR( 10), ' + 
         ' @cCartonID   NVARCHAR( 20), ' +
         ' @nRowCount   INT OUTPUT     ' 

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cWaveKey, @cCartonID, 
         @nRowCount OUTPUT
   
   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 136354
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ReplenNotDone
      GOTO Fail
   END
   */
Fail:

END

GO