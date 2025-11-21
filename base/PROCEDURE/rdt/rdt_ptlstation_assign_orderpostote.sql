SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure: rdt_PTLStation_Assign_OrderPosTote                        */  
/* Copyright      : LFLogistics                                               */  
/*                                                                            */  
/* Date       Rev  Author   Purposes                                          */  
/* 2020-01-31 1.0  James    WMS-11214. Created                                */  
/******************************************************************************/  
  
CREATE PROC [RDT].[rdt_PTLStation_Assign_OrderPosTote] (  
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
   DECLARE @nTotalCarton   INT  
  
   DECLARE @cOrderKey      NVARCHAR(10)  
   DECLARE @cStation       NVARCHAR(10)  
   DECLARE @cIPAddress     NVARCHAR(40)  
   DECLARE @cPosition      NVARCHAR(10)  
   DECLARE @cCartonID      NVARCHAR(20)  
  
   DECLARE @cChkFacility   NVARCHAR(5)  
   DECLARE @cChkStorerKey  NVARCHAR(15)  
   DECLARE @cChkStatus     NVARCHAR(10)  
   DECLARE @cChkSOStatus   NVARCHAR(10)  
  
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
        
      SELECT @nTotalCarton = COUNT(1)   
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)   
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
      AND   CartonID <> ''  
  
      -- Get carton not yet assign  
      IF @nTotalOrder > @nTotalCarton  
      BEGIN  
         -- Get order not yet assign  
         SELECT TOP 1  
            @cOrderKey = OrderKey,   
            @cStation = Station,   
            @cPosition = Position  
         FROM rdt.rdtPTLStationLog WITH (NOLOCK)   
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
         AND   CartonID = ''  
  
         -- Custom carton ID  
         SET @cCartonID = ''  
         EXEC rdt.rdt_PTLStation_CustomCartonID @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'NEW',   
            @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, '', '', 0,   
            @nErrNo OUTPUT, @cErrMsg OUTPUT, @cCartonID OUTPUT  
         IF @nErrNo <> 0  
            GOTO Quit  
           
       EXEC rdt.rdtSetFocusField @nMobile, 4 -- Carton ID  
         
       SET @cFieldAttr01 = 'O'  
       -- SET @cFieldAttr04 = CASE WHEN @cCartonID = '' THEN '' ELSE 'O' END  
      END  
      ELSE  
      BEGIN  
         SET @cOrderKey = ''  
         SET @cStation = ''  
         SET @cPosition = ''  
         SET @cCartonID = ''  
  
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderKey  
      END  
  
      -- Prepare next screen var  
      SET @cOutField01 = @cOrderKey  
      SET @cOutField02 = @cStation  
      SET @cOutField03 = @cPosition  
      SET @cOutField04 = @cCartonID  
      SET @cOutField05 = CAST( @nTotalOrder AS NVARCHAR(5))  
      SET @cOutField06 = CAST( @nTotalCarton AS NVARCHAR(5))  
  
      -- Go to order pos carton screen  
      SET @nScn = 4497  
   END  
     
  
   IF @cType = 'POPULATE-OUT'  
   BEGIN  
      -- Go to station screen  
      SET @cFieldAttr01 = '' -- OrderKey  
      SET @cFieldAttr04 = '' -- CartonID  
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
      SET @cCartonID = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END  
  
      -- Get total   
      SELECT @nTotalOrder = COUNT(1)   
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)   
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
        
      SELECT @nTotalCarton = COUNT(1)   
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)   
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
      AND   CartonID <> ''  
           
      -- Check finish assign  
      IF @nTotalCarton > 0 AND @nTotalOrder = @nTotalCarton AND @cOrderKey = '' AND @cCartonID = ''  
      BEGIN  
         SET @cFieldAttr01 = '' -- OrderKey  
         SET @cFieldAttr03 = '' -- Position  
         SET @cFieldAttr04 = '' -- CartonID  
         GOTO Quit  
      END  
        
      -- OrderKey enable  
      IF @cFieldAttr01 = ''  
      BEGIN  
         -- Check blank  
         IF @cOrderKey = ''   
         BEGIN  
            SET @nErrNo = 147901  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need OrderKey  
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderKey  
            SET @cOutField01 = ''  
            GOTO Quit  
         END  
     
         SET @cChkFacility = ''  
         SET @cChkStorerKey = ''  
         SET @cChkStatus = ''  
         SET @cChkSOStatus = ''  
              
         -- Get order info  
         SELECT   
            @cChkFacility = Facility,   
            @cChkStorerKey = StorerKey,   
            @cChkStatus = Status,   
            @cChkSOStatus = SOStatus  
         FROM Orders WITH (NOLOCK)  
         WHERE OrderKey = @cOrderKey  
           
         -- Check order valid  
         IF @@ROWCOUNT = 0  
         BEGIN  
            SET @nErrNo = 147902  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad OrderKey  
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderKey  
            SET @cOutField01 = ''  
            GOTO Quit  
         END  
     
         -- Check storer  
         IF @cStorerKey <> @cChkStorerKey  
         BEGIN  
            SET @nErrNo = 147903  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer  
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderKey  
            SET @cOutField01 = ''  
            GOTO Quit  
         END  
     
         -- Check facility  
         IF @cFacility <> @cChkFacility  
         BEGIN  
            SET @nErrNo = 147904  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility  
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderKey  
            SET @cOutField01 = ''  
            GOTO Quit  
         END  
                 
         -- Check order CANC  
         IF @cChkStatus = 'CANC' OR @cChkSOStatus = 'CANC'   
         BEGIN  
            SET @nErrNo = 147905  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order CANCEL  
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderKey  
            SET @cOutField01 = ''  
            GOTO Quit  
         END  
           
         -- Check order status  
         IF @cChkStatus = '0'  
         BEGIN  
            SET @nErrNo = 147906  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order NotAlloc  
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderKey  
            SET @cOutField01 = ''  
            GOTO Quit  
         END  
           
         -- Check order status  
         IF @cChkStatus >= '5'  
         BEGIN  
            SET @nErrNo = 147907  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order picked  
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderKey  
            SET @cOutField01 = ''  
            GOTO Quit  
         END  
     
         -- Check order assigned  
         IF EXISTS( SELECT 1 FROM rdt.rdtPTLStationLog WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND CartonID <> '')  
         BEGIN  
            SET @nErrNo = 147908  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderAssigned  
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderKey  
            SET @cOutField01 = ''  
            GOTO Quit  
         END  
     
         -- Check order have task  
         IF NOT EXISTS( SELECT 1   
            FROM Orders O WITH (NOLOCK)  
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( O.OrderKey = PD.OrderKey)  
            WHERE PD.OrderKey = @cOrderKey  
            AND   PD.Status < '4'  
            AND   PD.QTY > 0  
            AND   O.Status <> 'CANC'  
            AND   O.SOStatus <> 'CANC')  
         BEGIN  
            SET @nErrNo = 147909  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order no task  
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderKey  
            SET @cOutField01 = ''  
            GOTO Quit  
         END  
         SET @cOutField01 = @cOrderKey  
     
         SET @cStation = ''  
         SET @cIPAddress = ''  
           
         -- Get position not yet assign  
         SELECT TOP 1   
            @cStation = DP.DeviceID,   
            @cIPAddress = DP.IPAddress
         FROM DeviceProfile DP WITH (NOLOCK)  
         LEFT JOIN rdt.rdtPTLStationLog L WITH (NOLOCK) 
            ON ( DP.DeviceID = L.Station AND DP.IPAddress = L.IPAddress AND DP.DevicePosition = L.Position)  
         WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
         AND   DeviceType = 'STATION'  
         AND   DeviceID <> ''  
         AND   Position IS NULL  
         ORDER BY DP.DeviceID, DP.IPAddress, DP.DevicePosition  
           
         -- Check station blank  
         IF @cStation = ''  
         BEGIN  
            SET @nErrNo = 147910  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMorePosition  
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderKey  
            SET @cOutField01 = ''  
            GOTO Quit  
         END  
     
         SET @cOutField02 = @cStation  
      END  

      -- Position enable
      IF @cFieldAttr03 = ''
      BEGIN
         -- Check position blank
         IF @cPosition = ''
         BEGIN
            SET @nErrNo = 147911
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Position
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- Position
            SET @cOutField03 = ''
            GOTO Quit
         END

         -- Check position valid
         IF NOT EXISTS( SELECT 1
            FROM dbo.DeviceProfile WITH (NOLOCK)
            WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
            AND   DeviceType = 'STATION'
            AND   DeviceID <> ''
            AND   DevicePosition = @cPosition)
         BEGIN
            SET @nErrNo = 147912
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Position
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- Position
            SET @cOutField03 = ''
            GOTO Quit
         END

         -- Check position assigned
         IF EXISTS ( SELECT 1   
            FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
            WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
            AND   IPAddress = @cIPAddress  
            AND   Position = @cPosition
            AND   StorerKey = @cStorerKey
            AND   ISNULL( OrderKey, '') <> '')   
         BEGIN
            SET @nErrNo = 147913
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pos assigned
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- Position
            SET @cOutField03 = ''
            GOTO Quit
         END
         SET @cOutField03 = @cPosition
      END
      
      -- CartonID enable  
      IF @cFieldAttr04 = ''  
      BEGIN  
         -- Custom carton ID  
         IF @cCartonID = ''  
         BEGIN  
            EXEC rdt.rdt_PTLStation_CustomCartonID @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'NEW',   
               @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, '', '', 0,   
               @nErrNo OUTPUT, @cErrMsg OUTPUT, @cCartonID OUTPUT  
            IF @nErrNo <> 0  
               GOTO Quit  
              
            -- Remain in current screen (so the position can be shown to user)  
            IF @cCartonID <> ''  
            BEGIN  
               SET @cOutField04 = @cCartonID  
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartonID  
                 
               -- SET @cFieldAttr04 = CASE WHEN @cCartonID = '' THEN '' ELSE 'O' END  -- CartonID  
                 
               SET @nErrNo = -1   
               GOTO Quit  
            END  
         END  
              
         -- Check blank carton  
         IF @cCartonID = ''  
         BEGIN  
            SET @nErrNo = 147914  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CartonID  
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartonID  
            GOTO Quit  
         END  
  
         -- Check barcode format  
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'CartonID', @cCartonID) = 0  
         BEGIN  
            SET @nErrNo = 147915  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format  
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartonID  
            SET @cOutField04 = ''  
            GOTO Quit  
         END  
     
         -- Check carton assigned  
         IF EXISTS( SELECT 1  
            FROM rdt.rdtPTLStationLog WITH (NOLOCK)  
            WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
            AND CartonID = @cCartonID)  
         BEGIN  
            SET @nErrNo = 147916  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --carton Assigned  
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartonID  
            SET @cOutField04 = ''  
            GOTO Quit  
         END  
         SET @cOutField04 = @cCartonID  
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
      AND   DeviceType = 'STATION'  
      AND   DeviceID <> ''  
      AND   DevicePosition = @cPosition  
        
      -- OrderKey enabled  
      IF @cFieldAttr01 = ''  
      BEGIN  
         -- Save assign  
         INSERT INTO rdt.rdtPTLStationLog (Station, IPAddress, Position, LOC, CartonID, Method, OrderKey, StorerKey)  
         VALUES (@cStation, @cIPAddress, @cPosition, @cLOC, @cCartonID, @cMethod, @cOrderKey, @cStorerKey)  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 147917  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail  
            GOTO Quit  
         END  
      END  
      ELSE  
      BEGIN  
         UPDATE rdt.rdtPTLStationLog SET  
            CartonID = @cCartonID  
         WHERE Station = @cStation  
            AND Position = @cPosition  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 147918  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail  
            GOTO Quit  
         END  
      END  
  
      -- Get total   
      SELECT @nTotalOrder = COUNT(1)   
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)   
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
        
      SELECT @nTotalCarton = COUNT(1)   
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)   
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
         AND CartonID <> ''  
  
      -- Get carton not yet assign  
      IF @nTotalOrder > @nTotalCarton  
      BEGIN  
         SELECT TOP 1  
            @cOrderKey = OrderKey,   
            @cStation = Station,   
            @cPosition = Position  
         FROM rdt.rdtPTLStationLog WITH (NOLOCK)   
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
         AND   CartonID = ''  
  
         -- Custom carton ID  
         SET @cCartonID = ''  
         EXEC rdt.rdt_PTLStation_CustomCartonID @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'NEW',   
            @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, '', '', 0,   
            @nErrNo OUTPUT, @cErrMsg OUTPUT, @cCartonID OUTPUT  
         IF @nErrNo <> 0  
            GOTO Quit  
           
       EXEC rdt.rdtSetFocusField @nMobile, 4 -- Carton ID  
         
       SET @cFieldAttr01 = 'O' -- OrderKey  
       -- SET @cFieldAttr04 = CASE WHEN @cCartonID = '' THEN '' ELSE 'O' END  -- CartonID  
      END  
      ELSE  
      BEGIN  
         SET @cOrderKey = ''  
         SET @cStation = ''  
         SET @cPosition = ''  
         SET @cCartonID = ''  
  
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderKey  
         
         SET @cFieldAttr01 = '' -- OrderKey  
      END  
        
      -- Prepare current screen var  
      SET @cOutField01 = @cOrderKey  
      SET @cOutField02 = @cStation  
      SET @cOutField03 = @cPosition  
      SET @cOutField04 = @cCartonID  
      SET @cOutField05 = CAST( @nTotalOrder AS NVARCHAR(5))  
      SET @cOutField06 = CAST( @nTotalCarton AS NVARCHAR(5))  
        
      -- Stay in current page  
      SET @nErrNo = -1   
   END  
  
Quit:  
  
END  

GO