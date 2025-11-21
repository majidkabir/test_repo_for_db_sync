SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLPiece_Assign_DropID                                */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 09-07-2018 1.0  Ung      WMS-5489 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_PTLPiece_Assign_DropID] (
   @nMobile          INT, 
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cFacility        NVARCHAR( 5), 
   @cStorerKey       NVARCHAR( 15),  
   @cStation         NVARCHAR( 10),  
   @cMethod          NVARCHAR( 1),
   @cType            NVARCHAR( 15), --POPULATE-IN/POPULATE-OUT/CHECK
   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,   
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,   
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,   
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,   
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,   
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,  
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,  
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,  
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,  
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,  
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT, 
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT, 
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT, 
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT, 
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT, 
   @nScn             INT           OUTPUT,
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cDropID      NVARCHAR(20)
   DECLARE @nTotalDropID INT
   DECLARE @cIPAddress   NVARCHAR(40)
   DECLARE @cPosition    NVARCHAR(10)

   /***********************************************************************************************
                                                POPULATE
   ***********************************************************************************************/
   IF @cType = 'POPULATE-IN'
   BEGIN
      -- Get stat
      SELECT @nTotalDropID = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND Method = @cMethod AND SourceKey <> ''
      
		-- Prepare next screen var
		SET @cOutField01 = ''
		SET @cOutField02 = CAST( @nTotalDropID AS NVARCHAR(5))

		-- Go to batch screen
		SET @nScn = 4602
   END
      
/*
   IF @cType = 'POPULATE-OUT'
   BEGIN

		-- Go to station screen
   END
*/
   
   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Screen mapping
      SET @cDropID = @cInField01
      
      -- Get total
      SELECT @nTotalDropID = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND SourceKey <> ''
      
      -- Check finish assign
      IF @cDropID = '' AND @nTotalDropID > 0
      BEGIN
         GOTO Quit
      END
      
      -- Check blank
		IF @cDropID = '' 
      BEGIN
         SET @nErrNo = 126001
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need DropID
         GOTO Quit
      END
   
      -- Check DropID valid
      IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cDropID)
      BEGIN
         SET @nErrNo = 126002
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad DropID
         SET @cOutField01 = ''
         GOTO Quit
      END
   
      -- Check DropID assigned
      IF EXISTS( SELECT 1 
         FROM rdt.rdtPTLPieceLog WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND Method = @cMethod
            AND SourceKey = @cDropID)
      BEGIN
         SET @nErrNo = 126003
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDAssigned
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Get position not yet assign
      SET @cIPAddress = ''
      SET @cPosition = ''
      SELECT TOP 1
         @cIPAddress = DP.IPAddress, 
         @cPosition = DP.DevicePosition
      FROM dbo.DeviceProfile DP WITH (NOLOCK)
      WHERE DP.DeviceType = 'STATION'
         AND DP.DeviceID = @cStation
         AND NOT EXISTS( SELECT 1
            FROM rdt.rdtPTLPieceLog Log WITH (NOLOCK)
            WHERE Log.Station = @cStation
               AND Log.Position = DP.DevicePosition)
      ORDER BY DP.LogicalPos, DP.DevicePosition

      -- Check enuf position in station
      IF @cPosition = ''
      BEGIN
         SET @nErrNo = 126004
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not enuf Pos
         SET @cOutField01 = ''
         GOTO Quit
      END 

      -- Save assign
      INSERT rdt.rdtPTLPieceLog (Station, IPAddress, Position, Method, SourceKey)
      SELECT @cStation, @cIPAddress, @cPosition, @cMethod, @cDropID
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 126005
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log fail
         GOTO Quit
      END

      -- Get total
      SELECT @nTotalDropID = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND Method = @cMethod AND SourceKey <> ''

      -- Prepare current screen var
      SET @cOutField01 = '' -- DropID
      SET @cOutField02 = CAST( @nTotalDropID AS NVARCHAR(5))
      
      -- Stay in current screen
      SET @nErrNo = -1 

   END

Quit:

END

GO