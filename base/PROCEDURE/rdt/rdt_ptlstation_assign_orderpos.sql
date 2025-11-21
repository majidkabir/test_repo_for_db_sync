SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLStation_Assign_OrderPos                            */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 25-09-2020 1.0 YeeKung     WMS-14910 Created                               */
/******************************************************************************/

CREATE PROC [RDT].[rdt_PTLStation_Assign_OrderPos] (
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

   DECLARE @nTranCount     INT
   DECLARE @nTotalOrder    INT

   DECLARE @cOrderKey      NVARCHAR(10)
   DECLARE @cStation       NVARCHAR(10)
   DECLARE @cIPAddress     NVARCHAR(40)
   DECLARE @cPosition      NVARCHAR(10)
   DECLARE @cCartonID      NVARCHAR(20)

   DECLARE @cChkFacility   NVARCHAR(5)
   DECLARE @cChkStorerKey  NVARCHAR(15)
   DECLARE @cChkStatus     NVARCHAR(10)
   DECLARE @cChkSOStatus   NVARCHAR(10)
   DECLARE @cOrderType     NVARCHAR(10)
   DECLARE @nSuccess       INT

   SET @nTranCount = @@TRANCOUNT
      
   /***********************************************************************************************
                                                POPULATE
   ***********************************************************************************************/
   IF @cType = 'POPULATE-IN'
   BEGIN
      -- Get total 
      SELECT @nTotalOrder = COUNT(1) 
      FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)


      SET @cOrderKey = ''
      SET @cStation = ''
      SET @cPosition = ''
      SET @cCartonID = ''

      SET @cFieldAttr01=''
      SET @cFieldAttr02='o'
      SET @cFieldAttr03=''
      SET @cFieldAttr04='o'

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderKey

		-- Prepare next screen var
		SET @cOutField01 = @cOrderKey
		SET @cOutField02 = @cStation
		SET @cOutField03 = @cPosition
		SET @cOutField04 = @cCartonID
		SET @cOutField05 = CAST( @nTotalOrder AS NVARCHAR(5))
		SET @cOutField06 = ''

		-- Go to order pos carton screen
		SET @nScn = 4491
   END

   IF @cType = 'POPULATE-OUT'
   BEGIN
      UPDATE DeviceProfile WITH (ROWLOCK)
      SET status=0
      WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
      and devicetype='station'

      IF @@ERROR<>0
      BEGIN
         SET @nErrNo = 159511
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdDPFail
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderKey
         GOTO Quit
      END

		-- Go to station screen
		SET @cFieldAttr01 = '' -- OrderKey
      SET @cFieldAttr02 = '' -- OrderKey
		SET @cFieldAttr03 = '' -- position
      SET @cFieldAttr04 = '' -- position
      SET @cFieldAttr05 = '' -- position
   END


   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Screen mapping
      SET @cOrderKey = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END
      SET @cStation = @cOutField02
      SET @cPosition = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END
      SET @cCartonID = @cOutField04

      -- Get total 
      SELECT @nTotalOrder = COUNT(1) 
      FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)

      IF  @nTotalOrder <>0 and @cOrderKey = '' 
      BEGIN 
         SET @cFieldAttr01 = ' ' -- OrderKey
         SET @cFieldAttr02 = ' ' -- Position    
         SET @cFieldAttr03 = ' ' -- Position 
         SET @cFieldAttr04 = ' ' -- Position   
         GOTO Quit  
      END
      
      -- OrderKey enable
      IF @cFieldAttr01 = '' 
      BEGIN
   
         SET @cChkFacility = ''
         SET @cChkStorerKey = ''
         SET @cChkStatus = ''
         SET @cChkSOStatus = ''
            
         -- Get order info
         SELECT 
            @cChkFacility = Facility, 
            @cChkStorerKey = StorerKey, 
            @cChkStatus = Status, 
            @cChkSOStatus = SOStatus,
            @cOrderType =Type
         FROM Orders WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         
         -- Check order valid
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 159501
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad OrderKey
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderKey
            SET @cOutField01 = ''
            GOTO Quit
         END
   
         -- Check storer
         IF @cStorerKey <> @cChkStorerKey
         BEGIN
            SET @nErrNo = 159502
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderKey
            SET @cOutField01 = ''
            GOTO Quit
         END
   
         -- Check facility
         IF @cFacility <> @cChkFacility
         BEGIN
            SET @nErrNo = 159503
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderKey
            SET @cOutField01 = ''
            GOTO Quit
         END
               
         -- Check order CANC
         IF @cChkStatus = 'CANC' OR @cChkSOStatus = 'CANC' 
         BEGIN
            SET @nErrNo = 159504
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order CANCEL
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderKey
            SET @cOutField01 = ''
            GOTO Quit
         END
         
         -- Check order status
         IF @cChkStatus = '0'
         BEGIN
            SET @nErrNo = 159505
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order NotAlloc
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderKey
            SET @cOutField01 = ''
            GOTO Quit
         END
         
         -- Check order status
         IF @cChkStatus >= '5'
         BEGIN
            SET @nErrNo = 159506
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order picked
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderKey
            SET @cOutField01 = ''
            GOTO Quit
         END
   
         -- Check order assigned
         IF EXISTS( SELECT 1 FROM rdt.rdtPTLStationLog WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND CartonID <> '')
         BEGIN
            SET @nErrNo = 159507
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderAssigned
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderKey
            SET @cOutField01 = ''
            GOTO Quit
         END
   
         -- Check order have task
         IF NOT EXISTS( SELECT 1 
            FROM Orders O WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.Status < '4'
               AND PD.QTY > 0
               AND O.Status <> 'CANC'
               AND O.SOStatus <> 'CANC')
         BEGIN
            SET @nErrNo = 159508
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order no task
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderKey
            SET @cOutField01 = ''
            GOTO Quit
         END
         SET @cOutField01 = @cOrderKey
   
         SET @cStation = ''
         SET @cIPAddress = ''
         SET @cPosition = ''
         
         -- Get position not yet assign
         SELECT TOP 1 
            @cStation = DP.DeviceID, 
            @cIPAddress = DP.IPAddress, 
            @cPosition = DP.DevicePosition
         FROM DeviceProfile DP WITH (NOLOCK)
            LEFT JOIN rdt.rdtPTLStationLog L WITH (NOLOCK) ON (DP.DeviceID = L.Station AND DP.IPAddress = L.IPAddress AND DP.DevicePosition = L.Position)
         WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND DeviceType = 'STATION'
            AND DeviceID <> ''
            AND Position IS NULL
         ORDER BY DP.DeviceID, DP.IPAddress, DP.logicalname
         
         -- Check station blank
         IF @cStation = ''
         BEGIN
            SET @nErrNo = 159509
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMorePosition
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- Station
            SET @cOutField02 = ''
            GOTO Quit
         END
   
         SET @cOutField02 = @cStation
         SET @cOutField03 = @cPosition
      END
      
      DECLARE @cLOC NVARCHAR(10)
      DECLARE @cSKU NVARCHAR(20)
      DECLARE @nQTY INT
      
      -- Get position info
      SELECT 
         @cIPAddress = IPAddress, 
         @cLOC = LOC
      FROM DeviceProfile WITH (NOLOCK)
      WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         AND DeviceType = 'STATION'
         AND DeviceID <> ''
         AND DevicePosition = @cPosition
      order by logicalname

      IF (@cCartonID ='')
      BEGIN
            IF @cOrdertype='IC'
            BEGIN
               EXEC isp_getucckey 
               @cStorerkey ,
               8,
               @cCartonID output ,
               @nSuccess output  ,
               @nErrNo output,
               @cErrMsg Output ,
               '0'  ,
               '1',
               '1'  

               IF @nErrNo<>0
                  GOTO QUIT
            END
            ELSE
            BEGIN
               EXEC isp_getucckey 
               @cStorerkey ,
               10,
               @cCartonID output ,
               @nSuccess output  ,
               @nErrNo output,
               @cErrMsg Output ,
               '0'  ,
               '1',
               '0'  
               
               IF @nErrNo<>0
                  GOTO QUIT
            END
      END
      
      -- OrderKey enabled
      IF @cFieldAttr01 = ''
      BEGIN
         
         declare @cwavekey nvarchar(10)

         SELECT @cwavekey=WaveKey
         FROM Orders O WITH (NOLOCK)  
            JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)  
            -- JOIN rdt.rdtPTLStationLog PTL WITH (NOLOCK) ON ( PTL.OrderKey = PD.OrderKey AND PTL.WaveKey = PD.WaveKey )  
         WHERE PD.StorerKey = @cStorerKey  
            AND PD.Orderkey=@cOrderkey     
            AND PD.Status <= '5'    
            AND PD.CaseID = ''    
            AND PD.QTY > 0    
            AND PD.Status <> '4'    
            AND O.Status <> 'CANC'    
            AND O.SOStatus <> 'CANC'

         -- Save assign 
         INSERT INTO rdt.rdtPTLStationLog (Station, IPAddress, Position, LOC, CartonID, Method, OrderKey, StorerKey,WaveKey)
         VALUES (@cStation, @cIPAddress, @cPosition, @cLOC, @cCartonID, @cMethod, @cOrderKey, @cStorerKey,@cwavekey)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 159510
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
            GOTO Quit
         END
      END

      -- Get total 
      SELECT @nTotalOrder = COUNT(1) 
      FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
      
      SET @cOrderKey = ''
      SET @cStation = ''
      SET @cPosition = ''
      SET @cCartonID = ''

   	EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderKey
   	   
   	SET @cFieldAttr01 = '' -- OrderKey

      -- Prepare current screen var
      SET @cOutField01 = @cOrderKey
      SET @cOutField02 = @cStation
      SET @cOutField03 = @cPosition
      SET @cOutField04 = @cCartonID
		SET @cOutField05 = CAST( @nTotalOrder AS NVARCHAR(5))
      SET @cOutField06 = ''
      
      -- Stay in current page
      SET @nErrNo = -1 
   END

Quit:

END

GO