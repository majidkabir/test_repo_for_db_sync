SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLStation_Assign_WaveCriteria                        */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 07-03-2016 1.0  Ung      SOS361967 Created                                 */
/******************************************************************************/

CREATE PROC [RDT].[rdt_PTLStation_Assign_WaveCriteria] (
   @nMobile          INT, 
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cFacility        NVARCHAR( 5), 
   @cStorerKey       NVARCHAR( 15),  
   @cStation1        NVARCHAR( 10),  
   @cStation2        NVARCHAR( 10),  
   @cStation3        NVARCHAR( 10),  
   @cStation4        NVARCHAR( 10),  
   @cStation5        NVARCHAR( 10),  
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

   DECLARE @nTranCount  INT

   DECLARE @cCriteria1      NVARCHAR(30)
   DECLARE @cCriteria2      NVARCHAR(30)
   DECLARE @cStation        NVARCHAR(10)
   DECLARE @cIPAddress      NVARCHAR(40)
   DECLARE @cPosition       NVARCHAR(10)
   DECLARE @cCartonID       NVARCHAR(20)
   DECLARE @cLOC            NVARCHAR(10)      
   DECLARE @nTotalCriteria  INT
   DECLARE @nTotalCarton    INT
   DECLARE @nRowRef         INT
   DECLARE @nGroupKey       INT
   DECLARE @curPD           CURSOR

   SET @nTranCount = @@TRANCOUNT

   /***********************************************************************************************
                                                POPULATE
   ***********************************************************************************************/
   IF @cType = 'POPULATE-IN'
   BEGIN
      -- Get total 
      SELECT @nTotalCriteria = COUNT(1) 
      FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
      
      SELECT @nTotalCarton = COUNT(1) 
      FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         AND CartonID <> ''

      -- Get carton not yet assign
      IF @nTotalCriteria > @nTotalCarton
      BEGIN
         -- Loop to stamp 2nd booking without carton ID
         DECLARE @curLog CURSOR
         SET @curLog = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT L1.RowRef, L2.CartonID -- L2.GroupKey
            FROM rdt.rdtPTLStationLog L1 WITH (NOLOCK) 
               JOIN rdt.rdtPTLStationLog L2 WITH (NOLOCK) ON (L1.IPAddress = L2.IPAddress AND L1.Position = L2.Position)
            WHERE L1.Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
               AND L1.CartonID = ''
               AND L2.CartonID <> ''
         OPEN @curLog
         FETCH NEXT FROM @curLog INTO @nRowRef, @cCartonID--, @nGroupKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE rdt.rdtPTLStationLog SET
               CartonID = @cCartonID
               -- GroupKey = @nGroupKey, 
               -- Func = @nFunc
            WHERE RowRef = @nRowRef
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 97951
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail
               GOTO Quit
            END
            FETCH NEXT FROM @curLog INTO @nRowRef, @cCartonID--, @nGroupKey
         END

         -- Recalc total 
         IF @nRowRef > 0
         BEGIN
            SELECT @nTotalCriteria = COUNT(DISTINCT Position) 
            FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
            WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            
            SELECT @nTotalCarton = COUNT(DISTINCT Position) 
            FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
            WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
               AND CartonID <> ''   
         END
      END
      ELSE
      BEGIN
            SELECT @nTotalCriteria = COUNT(DISTINCT Position) 
            FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
            WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            
            SELECT @nTotalCarton = COUNT(DISTINCT Position) 
            FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
            WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
               AND CartonID <> ''   
      END

      -- Get carton not yet assign
      IF @nTotalCriteria > @nTotalCarton
      BEGIN
         SELECT TOP 1
            @cCriteria1 = ShipTo, 
            @cCriteria2 = UserDefine01, 
            @cStation = Station, 
            @cPosition = Position, 
            @cCartonID = CartonID
         FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND CartonID = ''
         ORDER BY Station, Position
      END
      ELSE
      BEGIN
         SET @cCriteria1 = ''
         SET @cCriteria2 = ''
         SET @cStation = ''
         SET @cPosition = ''
         SET @cCartonID = ''
      END

		-- Prepare next screen var
		SET @cOutField01 = @cCriteria1
		SET @cOutField02 = @cCriteria2
		SET @cOutField03 = @cStation
		SET @cOutField04 = @cPosition
		SET @cOutField05 = @cCartonID
		SET @cOutField06 = CAST( @nTotalCriteria AS NVARCHAR(5))
		SET @cOutField07 = CAST( @nTotalCarton AS NVARCHAR(5))

	   EXEC rdt.rdtSetFocusField @nMobile, 5 -- Carton ID

		-- Go to load consignee carton screen
		SET @nScn = 4493
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
      SET @cCriteria1 = @cOutField01
      SET @cCriteria2 = @cOutField02
      SET @cStation = @cOutField03
      SET @cPosition = @cOutField04
      SET @cCartonID = @cInField05

      -- Get total 
      SELECT @nTotalCriteria = COUNT(1) 
      FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
      
      SELECT @nTotalCarton = COUNT(1) 
      FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         AND CartonID <> ''
         
      -- Check finish assign
      IF @nTotalCarton > 0 AND @nTotalCriteria = @nTotalCarton AND @cCartonID = ''
         GOTO Quit

      -- Check blank tote
      IF @cCartonID = ''
      BEGIN
         SET @nErrNo = 97952
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CartonID
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- CartonID
         SET @cOutField05 = ''
         GOTO Quit
      END

      -- Check carton assigned
      IF EXISTS( SELECT 1
         FROM rdt.rdtPTLStationLog WITH (NOLOCK)
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND CartonID = @cCartonID)
      BEGIN
         SET @nErrNo = 97953
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonID used
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- CartonID
         SET @cOutField05 = ''
         GOTO Quit
      END
      SET @cOutField05 = @cCartonID

      -- Save assign
      UPDATE rdt.rdtPTLStationLog SET
         CartonID = @cCartonID
      WHERE Station = @cStation
         AND Position = @cPosition
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 97954
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log fail
         GOTO Quit
      END

      -- Get Total
      SELECT @nTotalCriteria = COUNT(DISTINCT Position) 
      FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
      
      SELECT @nTotalCarton = COUNT(DISTINCT Position) 
      FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5) 
         AND CartonID <> ''

      -- Check finish assign
      IF @nTotalCriteria > 0 AND @nTotalCriteria = @nTotalCarton
         GOTO Quit

      -- Get carton not yet assign
      SELECT TOP 1 
         @cCriteria1 = ShipTo,
         @cCriteria2 = UserDefine01,
         @cStation = Station,  
         @cPosition = Position
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         AND CartonID = ''
      ORDER BY Station, Position 

      -- Prepare current screen var
      SET @cOutField01 = @cCriteria1
      SET @cOutField02 = @cCriteria2
      SET @cOutField03 = @cStation
      SET @cOutField04 = @cPosition
      SET @cOutField05 = '' -- CartonID
      SET @cOutField06 = CAST( @nTotalCriteria AS NVARCHAR(5))
      SET @cOutField07 = CAST( @nTotalCarton AS NVARCHAR(5))
      
      -- Stay in current page
      SET @nErrNo = -1 
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLStation_Assign

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO