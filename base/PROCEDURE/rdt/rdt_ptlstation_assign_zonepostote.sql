SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure: rdt_PTLStation_Assign_ZonePosTote                         */  
/* Copyright      : LFLogistics                                               */  
/*                                                                            */  
/* Date       Rev  Author   Purposes                                          */  
/* 2021-03-01 1.0  James    WMS-15658. Created                                */  
/******************************************************************************/  
  
CREATE PROC [RDT].[rdt_PTLStation_Assign_ZonePosTote] (  
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
   DECLARE @nTotalLOC      INT
   DECLARE @cOrderKey      NVARCHAR( 10)  
   DECLARE @cStation       NVARCHAR( 10)  
   DECLARE @cIPAddress     NVARCHAR( 40)  
   DECLARE @cPosition      NVARCHAR( 10)  
   DECLARE @cCartonID      NVARCHAR( 20)  
   DECLARE @cWaveKey       NVARCHAR( 10)
   DECLARE @cLoc           NVARCHAR( 10)
   
   DECLARE @cChkFacility   NVARCHAR(5)  
   DECLARE @cChkStorerKey  NVARCHAR(15)  
   DECLARE @cChkStatus     NVARCHAR(10)  
   DECLARE @cChkSOStatus   NVARCHAR(10)  
   DECLARE @cConsigneeKey  NVARCHAR(15)
   DECLARE @cPTLStationLogQueue NVARCHAR( 1)

   SET @nTranCount = @@TRANCOUNT  
        
   /***********************************************************************************************  
                                                POPULATE  
   ***********************************************************************************************/  
   IF @cType = 'POPULATE-IN'  
   BEGIN  
      SELECT TOP 1 @cStation = Station   
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)   
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
      AND   CartonID = ''
      ORDER BY 1
      
      -- Prepare next screen var  
      SET @cOutField01 = ''  
      SET @cOutField02 = @cStation  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
      SET @cOutField05 = ''  
  
      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Go to order pos carton screen  
      SET @nScn = 4498  
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
      SET @cPTLStationLogQueue = rdt.RDTGetConfig( @nFunc, 'PTLStationLogQueue', @cStorerKey)
      
      -- Screen mapping  
      SET @cWaveKey = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END  
      SET @cStation = @cOutField02  
      --SET @cPosition = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END  
      SET @cLoc = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END
      SET @cCartonID = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END  
  
      -- Get total   
      SELECT @nTotalLOC = COUNT(1)   
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)   
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
        
      SELECT @nTotalCarton = COUNT(1)   
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)   
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
      AND   CartonID <> ''  

      -- Check finish assign  
      IF @nTotalCarton > 0 AND @nTotalLOC = @nTotalCarton AND @cLoc = '' AND @cCartonID = ''  
      BEGIN  
         SET @cFieldAttr01 = '' -- WaveKey  
         SET @cFieldAttr03 = '' -- Location  
         SET @cFieldAttr04 = '' -- CartonID  
         GOTO Quit  
      END  
      
      -- OrderKey enable  
      IF @cFieldAttr01 = ''  
      BEGIN  
         -- Check blank  
         IF @cWaveKey = ''   
         BEGIN  
            SET @nErrNo = 166051  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need WaveKey  
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey  
            SET @cOutField01 = ''  
            GOTO Quit  
         END  

         IF NOT EXISTS ( SELECT 1 
                         FROM rdt.rdtPTLStationLog WITH (NOLOCK)
                         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
                         AND   WaveKey = @cWaveKey)
         BEGIN  
            IF @cPTLStationLogQueue = '1'
            BEGIN
               IF NOT EXISTS ( SELECT 1 
                               FROM rdt.rdtPTLStationLogQueue (NOLOCK) 
                               WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
                               AND   WaveKey = @cWaveKey)
               BEGIN
                  SET @nErrNo = 166063  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid WaveKey  
                  EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey  
                  SET @cOutField01 = ''  
                  GOTO Quit
               END
               ELSE
               BEGIN
                  INSERT INTO rdt.rdtPTLStationLog ( Station, IPAddress, Position, LOC, Method, CartonID, 
                  OrderKey, LoadKey, WaveKey, PickSlipNo, BatchKey, ConsigneeKey, ShipTo, StorerKey, MaxTask, 
                  UserDefine01, UserDefine02, UserDefine03, SourceKey, SourceType, CreatedPTLTran, SKU, ItemClass) 
                  SELECT Station, IPAddress, Position, LOC, Method, '' AS CartonID, 
                  OrderKey, LoadKey, WaveKey, PickSlipNo, BatchKey, ConsigneeKey, ShipTo, StorerKey, MaxTask, 
                  UserDefine01, UserDefine02, UserDefine03, SourceKey, SourceType, CreatedPTLTran, SKU, ItemClass
                  FROM rdt.rdtPTLStationLogQueue WITH (NOLOCK) 
                  WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
                  AND   WaveKey = @cWaveKey
                  AND   DataPopulated = '0'

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 166064  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CopyLogDataErr   
                     EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey  
                     SET @cOutField01 = ''  
                     GOTO Quit
                  END
                  
                  UPDATE rdt.rdtPTLStationLogQueue WITH (ROWLOCK) SET 
                     DataPopulated = '1',
                     EditWho = SUSER_SNAME(),
                     EditDate = GETDATE()
                  WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
                  AND   WaveKey = @cWaveKey
                  
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 166065  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CopyLogDataErr   
                     EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey  
                     SET @cOutField01 = ''  
                     GOTO Quit
                  END
               END
            END
            ELSE
            BEGIN
               SET @nErrNo = 166052  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid WaveKey  
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey  
               SET @cOutField01 = ''  
               GOTO Quit
            END
         END  
         
         -- Check order have task  
         IF NOT EXISTS( SELECT 1   
            FROM Orders O WITH (NOLOCK)  
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( O.OrderKey = PD.OrderKey)  
            WHERE O.UserDefine09 = @cWaveKey  
            AND   PD.Storerkey = @cStorerKey
            AND   PD.[Status] IN ( '0', '3', '5')
            AND   PD.[Status] <> '4'  
            AND   PD.QTY > 0  
            AND   O.Status <> 'CANC'  
            AND   O.SOStatus <> 'CANC')  
         BEGIN  
            SET @nErrNo = 166053  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wave no task  
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderKey  
            SET @cOutField01 = ''  
            GOTO Quit  
         END  
         SET @cOutField01 = @cWaveKey  
         SET @cFieldAttr01 = 'O'

         SELECT TOP 1 @cStation = DeviceID   
         FROM dbo.DeviceProfile WITH (NOLOCK)    
         WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
         ORDER BY 1

         SET @cOutField02 = @cStation  
      END  

      -- Location enable
      IF @cFieldAttr03 = ''
      BEGIN
         -- Check Location blank
         IF @cLoc = ''
         BEGIN
            SET @nErrNo = 166054
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Location
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- Location
            SET @cOutField03 = ''
            GOTO Quit
         END

         -- Check Location valid
         IF NOT EXISTS( SELECT 1
            FROM dbo.DeviceProfile WITH (NOLOCK)
            WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
            AND   DeviceType = 'STATION'
            AND   DeviceID <> ''
            AND   Loc = @cLoc)
         BEGIN
            SET @nErrNo = 166055
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Location
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- Location
            SET @cOutField03 = ''
            GOTO Quit
         END

         -- 1 Location 1 Position
         SELECT TOP 1 @cPosition = Position
         FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
         AND   IPAddress = @cIPAddress  
         AND   LOC = @cLoc
         AND   StorerKey = @cStorerKey
         AND   ISNULL( CartonID, '') <> ''
         ORDER BY 1
         
         -- Check position assigned
         IF EXISTS ( SELECT 1   
            FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
            WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
            AND   IPAddress = @cIPAddress  
            AND   Position = @cPosition
            AND   StorerKey = @cStorerKey
            AND   ISNULL( CartonID, '') <> '')   
         BEGIN
            SET @nErrNo = 166056
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pos assigned
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- Location
            SET @cOutField03 = ''
            GOTO Quit
         END
         SET @cOutField03 = @cLoc
      END
      
      -- CartonID enable  
      IF @cFieldAttr04 = ''  
      BEGIN  
         -- Check blank carton  
         IF @cCartonID = ''  
         BEGIN  
            SET @nErrNo = 166057  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CartonID  
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartonID  
            GOTO Quit  
         END  
  
         -- Check barcode format  
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'CartonID', @cCartonID) = 0  
         BEGIN  
            SET @nErrNo = 166058  
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
            SET @nErrNo = 166059  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Carton Assigned  
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartonID  
            SET @cOutField04 = ''  
            GOTO Quit  
         END  
         /*
         IF NOT EXISTS ( SELECT 1 
                         FROM Orders O WITH (NOLOCK)  
                         JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( O.OrderKey = PD.OrderKey)  
                         WHERE O.UserDefine09 = @cWaveKey  
                         AND   PD.DropID = @cCartonID
                         AND   PD.Storerkey = @cStorerKey
                         AND   PD.[Status] IN ( '0', '3', '5')
                         AND   PD.[Status] <> '4'  
                         AND   PD.QTY > 0  
                         AND   O.Status <> 'CANC'  
                         AND   O.SOStatus <> 'CANC')
         BEGIN  
            SET @nErrNo = 166060  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Carton No Task  
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartonID  
            SET @cOutField04 = ''  
            GOTO Quit  
         END  
         */
         SET @cOutField04 = @cCartonID  
      END  
        
      DECLARE @cSKU NVARCHAR(20)  
      DECLARE @nQTY INT  
        
      -- Get position info  
      SELECT   
         @cIPAddress = IPAddress,   
         @cPosition = DevicePosition  
      FROM DeviceProfile WITH (NOLOCK)  
      WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
      AND   DeviceType = 'STATION'  
      AND   DeviceID <> ''  
      AND   LOC = @cLoc  
      
      SELECT TOP 1 @cOrderKey = O.OrderKey,
                   @cConsigneeKey = O.ConsigneeKey
      FROM Orders O WITH (NOLOCK)  
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( O.OrderKey = PD.OrderKey)  
      WHERE O.UserDefine09 = @cWaveKey  
      --AND   PD.DropID = @cCartonID
      AND   PD.Storerkey = @cStorerKey
      AND   PD.[Status] IN ( '0', '3', '5')
      AND   PD.[Status] <> '4'  
      AND   PD.QTY > 0  
      AND   O.Status <> 'CANC'  
      AND   O.SOStatus <> 'CANC'
      ORDER BY 1
      
      IF NOT EXISTS ( SELECT 1  
                      FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
                      WHERE StorerKey = @cStorerKey 
                      AND   Station = @cStation
                      AND   Position = @cPosition
                      AND   CartonID = CartonID)
      BEGIN
         INSERT INTO rdt.rdtPTLStationLog (Station, IPAddress, Position, CartonID, Method, WaveKey, OrderKey, ConsigneeKey, StorerKey, SourceKey, LOC)
         VALUES (@cStation, @cIPAddress, @cPosition, @cCartonID, @cMethod, @cWaveKey, @cOrderKey, @cConsigneeKey, @cStorerKey, @cWaveKey, @cLoc)

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 166061  
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
            SET @nErrNo = 166062  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail  
            GOTO Quit  
         END  
      END
      
      -- Get total   
      SELECT @nTotalLOC = COUNT(1)   
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)   
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
        
      SELECT @nTotalCarton = COUNT(1)   
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)   
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
         AND CartonID <> ''  
  
      -- Get carton not yet assign  
      IF @nTotalLOC > @nTotalCarton  
      BEGIN  
       EXEC rdt.rdtSetFocusField @nMobile, 3 -- Location  
         
       SET @cOutField01 = @cWaveKey
       SET @cOutField02 = @cStation
       SET @cOutField03 = ''
       SET @cOutField04 = ''
       SET @cOutField05 = @nTotalCarton
       
       SET @cFieldAttr01 = 'O' -- WaveKey  
       
       EXEC rdt.rdtSetFocusField @nMobile, 3 -- Location  
      END  
      ELSE  
      BEGIN  
          SET @cOutField01 = @cWaveKey
          SET @cOutField02 = @cStation
          SET @cOutField03 = ''
          SET @cOutField04 = ''
          SET @cOutField05 = @nTotalCarton

         EXEC rdt.rdtSetFocusField @nMobile, 3 -- Location
      END  
        
      -- Stay in current page  
      SET @nErrNo = -1   
   END  
  
Quit:  
  
END  

GO