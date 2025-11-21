SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store procedure: rdt_PTLPiece_Assign_DropID05                              */  
/* Copyright      : LFLogistics                                               */  
/*                                                                            */  
/* Date       Rev  Author   Purposes                                          */  
/* 2022-06-29 1.0  James    WMS-20016. Created                                */  
/******************************************************************************/  
  
CREATE PROC [RDT].[rdt_PTLPiece_Assign_DropID05] (  
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
  
   DECLARE @cDropID      NVARCHAR( 20)  
   DECLARE @nTotalDropID INT  
   DECLARE @cIPAddress   NVARCHAR( 40)  
   DECLARE @cPosition    NVARCHAR( 10)  
   DECLARE @cOrderKey    NVARCHAR( 10)
   DECLARE @cWaveKey     NVARCHAR( 10)
   DECLARE @cAssignedStation  NVARCHAR( 10)
   DECLARE @cLogicalName NVARCHAR( 10)
   
   /***********************************************************************************************  
                                                POPULATE  
   ***********************************************************************************************/  
   IF @cType = 'POPULATE-IN'  
   BEGIN  
      -- Get stat  
      SELECT @nTotalDropID = COUNT( DISTINCT SourceKey) 
      FROM rdt.rdtPTLPieceLog WITH (NOLOCK) 
      WHERE Station = @cStation 
      AND   Method = @cMethod 
      AND   SourceKey <> ''  
        
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
         SET @nErrNo = 187951  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need DropID  
         GOTO Quit  
      END  
     
      -- Check DropID valid  
      IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cDropID)  
      BEGIN  
         SET @nErrNo = 187952  
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
         SET @nErrNo = 187953  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDAssigned  
         SET @cOutField01 = ''  
         GOTO Quit  
      END  
      
      SELECT TOP 1 @cOrderKey = OrderKey
      FROM dbo.PICKDETAIL WITH (NOLOCK)
      WHERE Storerkey = @cStorerKey
      AND   DropID = @cDropID
      AND   [Status] = '3'
      ORDER BY 1
      
      SELECT TOP 1 
         @cWaveKey = W.WaveKey, 
         @cAssignedStation = W.UserDefine01
      FROM dbo.WAVEDETAIL WD WITH (NOLOCK)
      JOIN dbo.WAVE W WITH (NOLOCK) ON ( WD.WaveKey = W.WaveKey)
      WHERE WD.OrderKey = @cOrderKey
      ORDER BY 1
      
      IF @cStation <> @cAssignedStation
      BEGIN  
      	INSERT INTO tRACEiNFO (TraceName, TimeIn, Col1, Col2, Col3, Col4, Col5) VALUES 
      	('803', GETDATE(), @cStation, @cDropID, @cOrderKey, @cWaveKey, @cAssignedStation)
         SET @nErrNo = 187954  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff station  
         SET @cOutField01 = ''  
         GOTO Quit  
      END  
      
      DECLARE @curInsPtlLog  CURSOR
      SET @curInsPtlLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT DISTINCT OrderKey
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE Storerkey = @cStorerKey
      AND   DropID = @cDropID
      AND   [Status] = '3'
      OPEN @curInsPtlLog
      FETCH NEXT FROM @curInsPtlLog INTO @cOrderKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
      	IF NOT EXISTS ( SELECT 1 
      	                FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
      	                WHERE Station = @cStation
      	                AND   Method = @cMethod
      	                AND   SourceKey = @cDropID
      	                AND   OrderKey = @cOrderKey)
         BEGIN
         	-- Check if same orderkey already populated with position
         	-- 1 orders 1 position
            SET @cIPAddress = ''  
            SET @cPosition = ''  
         	SELECT TOP 1
               @cIPAddress = IPAddress,   
               @cPosition = Position, 
               @cLogicalName = CartonID  
         	FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
         	WHERE Station = @cStation
      	   AND   Method = @cMethod
      	   AND   OrderKey = @cOrderKey
         	ORDER BY 1
         	
         	IF @@ROWCOUNT = 0
         	BEGIN
               -- Get position not yet assign  
               SELECT TOP 1  
                  @cIPAddress = DP.IPAddress,   
                  @cPosition = DP.DevicePosition, 
                  @cLogicalName = LogicalName  
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
                  SET @nErrNo = 187955  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not enuf Pos  
                  SET @cOutField01 = ''  
                  GOTO Quit  
               END   
      
               IF @cLogicalName = ''
               BEGIN  
                  SET @nErrNo = 187956  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LogicalNameReq  
                  SET @cOutField01 = ''  
                  GOTO Quit  
               END   
         	END
         	
            -- Save assign  
            INSERT rdt.rdtPTLPieceLog (Station, IPAddress, Position, Method, SourceKey, OrderKey, WaveKey, CartonID)  
            VALUES    
            (@cStation, @cIPAddress, @cPosition, @cMethod, @cDropID, @cOrderKey, @cWaveKey, @cLogicalName)
        
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 187957  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log fail  
               GOTO Quit  
            END  
         END
         
      	FETCH NEXT FROM @curInsPtlLog INTO @cOrderKey
      END      

      -- Get total  
      SELECT @nTotalDropID = COUNT( DISTINCT SourceKey) 
      FROM rdt.rdtPTLPieceLog WITH (NOLOCK) 
      WHERE Station = @cStation 
      AND   Method = @cMethod 
      AND   SourceKey <> ''  
  
      -- Prepare current screen var  
      SET @cOutField01 = '' -- DropID  
      SET @cOutField02 = CAST( @nTotalDropID AS NVARCHAR(5))  
        
      -- Stay in current screen  
      SET @nErrNo = -1   
  
   END  
  
Quit:  
  
END  

GO