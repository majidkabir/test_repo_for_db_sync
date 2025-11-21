SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLStation_Assign_LoadCarton                          */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 11-09-2017 1.0  Ung      WMS-2964 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_PTLStation_Assign_LoadCarton] (
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

   DECLARE @cLoadKey        NVARCHAR(10)
   DECLARE @cStation        NVARCHAR(10)
   DECLARE @cIPAddress      NVARCHAR(40)
   DECLARE @cPosition       NVARCHAR(10)
   DECLARE @cCartonID       NVARCHAR(20)
   DECLARE @cLOC            NVARCHAR(10)      
   DECLARE @nTotalLoad INT
   DECLARE @nTotalCarton    INT
   DECLARE @curPD           CURSOR

   SET @nTranCount = @@TRANCOUNT

   /***********************************************************************************************
                                                POPULATE
   ***********************************************************************************************/
   IF @cType = 'POPULATE-IN'
   BEGIN
      -- Get total 
      SELECT @nTotalLoad = COUNT(1) 
      FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
      
      SELECT @nTotalCarton = COUNT(1) 
      FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         AND CartonID <> ''

      -- Get carton not yet assign
      IF @nTotalLoad > @nTotalCarton
      BEGIN
         -- Get consignee not yet assign
         SELECT TOP 1 
            @cLoadKey = LoadKey, 
            @cStation = Station, 
            @cPosition = Position
         FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND CartonID = ''

   	   EXEC rdt.rdtSetFocusField @nMobile, 4 -- Carton ID
   	   
   	   SET @cFieldAttr01 = 'O' -- LoadKey
      END
      ELSE
      BEGIN
         SET @cLoadKey = ''
         SET @cStation = ''
         SET @cPosition = ''
         SET @cCartonID = ''

   	   EXEC rdt.rdtSetFocusField @nMobile, 1 -- LoadKey
      END

		-- Prepare next screen var
		SET @cOutField01 = @cLoadKey
		SET @cOutField02 = @cStation
		SET @cOutField03 = @cPosition
		SET @cOutField04 = @cCartonID
		SET @cOutField05 = CAST( @nTotalLoad AS NVARCHAR(5))
		SET @cOutField06 = CAST( @nTotalCarton AS NVARCHAR(5))

		-- Go to load consignee carton screen
		SET @nScn = 4492
   END
      
   IF @cType = 'POPULATE-OUT'
   BEGIN
      -- Enable field
      SET @cFieldAttr01 = '' -- LoadKey
      SET @cFieldAttr04 = '' -- CartonID

		-- Go to station screen
   END

   
   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Screen mapping
      SET @cLoadKey = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END
      SET @cStation = @cOutField02
      SET @cPosition = @cOutField03
      SET @cCartonID = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END

      -- Get total 
      SELECT @nTotalLoad = COUNT(1) 
      FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
      
      SELECT @nTotalCarton = COUNT(1) 
      FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         AND CartonID <> ''
         
      -- Check finish assign
      IF @nTotalCarton > 0 AND @nTotalLoad = @nTotalCarton AND @cLoadKey = '' AND @cCartonID = ''
      BEGIN
         SET @cFieldAttr01 = '' -- LoadKey
         SET @cFieldAttr04 = '' -- CartonID
         GOTO Quit
      END

      -- LoadKey enabled
      IF @cFieldAttr01 = ''
      BEGIN
   		-- Check blank
   		IF @cLoadKey = '' 
         BEGIN
            SET @nErrNo = 114601
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LoadKey
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- LoadKey
            GOTO Quit
         END

         -- Check load assigned
         IF EXISTS( SELECT 1 FROM rdt.rdtPTLStationLog WITH (NOLOCK) WHERE LoadKey = @cLoadKey AND CartonID <> '')
         BEGIN
            SET @nErrNo = 114602
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Load Assigned
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- LoadKey
            SET @cOutField01 = ''
            GOTO Quit
         END

         -- Get load info
         DECLARE @cChkFacility NVARCHAR( 5)
         SELECT @cChkFacility = @cFacility
         FROM LoadPlan WITH (NOLOCK) 
         WHERE LoadKey = @cLoadKey

         -- Check LoadKey valid
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 114603
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad LoadKey
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- LoadKey
            SET @cOutField01 = ''
            GOTO Quit
         END

         -- Check facility
         IF @cChkFacility <> @cFacility
         BEGIN
            SET @nErrNo = 114604
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderKey
            SET @cOutField01 = ''
            GOTO Quit
         END
         
         -- Check load no task
         IF NOT EXISTS( SELECT TOP 1 1 
            FROM LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
               JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            WHERE LPD.LoadKey = @cLoadKey
               AND O.StorerKey = @cStorerKey
               AND O.Facility = @cFacility
               AND O.Status <> 'CANC' 
               AND O.SOStatus <> 'CANC' 
               AND PD.Status < '4'
               AND PD.QTY > 0)
         BEGIN
            SET @nErrNo = 114605
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Load no task
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- LoadKey
            SET @cOutField01 = ''
            GOTO Quit
         END
         
         -- Save assign
         INSERT INTO rdt.rdtPTLStationLog (Station, IPAddress, Position, CartonID, Method, LoadKey, StorerKey)
         VALUES (@cStation, @cIPAddress, @cPosition, '', @cMethod, @cLoadKey, @cStorerKey)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 114606
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- LoadKey
            SET @cOutField01 = ''
            GOTO Quit
         END
         SET @cOutField01 = @cLoadKey
            
         SET @nTotalLoad = @nTotalLoad + 1

         -- Get carton not yet assign
         SELECT TOP 1 
            @cStation = Station, 
            @cIPAddress =  IPAddress, 
            @cPosition = Position, 
            @cCartonID = ''
         FROM rdt.rdtPTLStationLog WITH (NOLOCK)
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND CartonID = ''
         ORDER BY Station, Position 

         -- Prepare current screen var
         SET @cOutField01 = @cLoadKey
         SET @cOutField02 = @cStation
         SET @cOutField03 = @cPosition
         SET @cOutField04 = @cCartonID
         SET @cOutField05 = CAST( @nTotalLoad AS NVARCHAR(5))
         SET @cOutField06 = CAST( @nTotalCarton AS NVARCHAR(5))

         -- Enable disable field
         SET @cFieldAttr01 = 'O' -- LoadKey
         SET @cFieldAttr04 = ''  -- CartonID

         -- Stay in current page
         SET @nErrNo = -1 
         GOTO Quit
      END

      -- CartonID field enabled
      IF @cFieldAttr04 = ''
      BEGIN
         -- Check blank tote
         IF @cCartonID = ''
         BEGIN
            SET @nErrNo = 114607
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
            SET @nErrNo = 114608
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonID used
            EXEC rdt.rdtSetFocusField @nMobile, 5 -- CartonID
            SET @cOutField05 = ''
            GOTO Quit
         END
         SET @cOutField04 = @cCartonID

         -- Save assign
         UPDATE rdt.rdtPTLStationLog SET
            CartonID = @cCartonID
         WHERE Station = @cStation
            AND Position = @cPosition
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 114609
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log fail
            GOTO Quit
         END
      END

      -- Get Total
      SELECT @nTotalLoad = COUNT(1) 
      FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
      
      SELECT @nTotalCarton = COUNT(1) 
      FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5) 
         AND CartonID <> ''

      -- Check finish assign
      IF @nTotalLoad > 0 AND @nTotalLoad = @nTotalCarton
      BEGIN
         -- Enable field
         SET @cFieldAttr01 = '' -- LoadKey
         SET @cFieldAttr04 = '' -- CartonID
         
         GOTO Quit
      END

      -- Get carton not yet assign
      SELECT TOP 1 
         @cLoadKey = LoadKey, 
         @cStation = Station,  
         @cPosition = Position
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         AND CartonID = ''
      ORDER BY Position 

      -- Prepare current screen var
      SET @cOutField01 = @cLoadKey
      SET @cOutField02 = @cStation
      SET @cOutField03 = @cPosition
      SET @cOutField04 = '' -- CartonID
      SET @cOutField05 = CAST( @nTotalLoad AS NVARCHAR(5))
      SET @cOutField06 = CAST( @nTotalCarton AS NVARCHAR(5))
      
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