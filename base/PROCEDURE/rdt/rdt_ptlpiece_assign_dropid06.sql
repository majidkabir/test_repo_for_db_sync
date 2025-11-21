SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/      
/* Store procedure: rdt_PTLPiece_Assign_DropID06                              */      
/* Copyright      : MAERSK                                                    */      
/*                                                                            */      
/* Date       Rev  Author   Purposes                                          */      
/* 2023-02-10 1.0  James    Addhoc. Created                                   */      
/* 2023-07-02 1.1  JHU151   FCR-477                                           */
/* 2024-08-01 1.2  James    Perf tuning (james01)                             */
/******************************************************************************/      
      
CREATE   PROC [RDT].[rdt_PTLPiece_Assign_DropID06] (      
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
   DECLARE @cOrderKey    NVARCHAR( 10)    
   DECLARE @cSKU         NVARCHAR( 20)    
   DECLARE @cChkStation  NVARCHAR( 10)    
   DECLARE @cWaveKey     NVARCHAR( 10)    
   DECLARE @cWaveKey2cHK NVARCHAR( 10)    
   DECLARE @nCnt         INT    
   DECLARE @nTranCount   INT    
    
   SET @nTranCount = @@TRANCOUNT    
    
   BEGIN TRAN    
   SAVE TRAN rdt_PTLPiece_Assign_DropID06    
      
   /***********************************************************************************************      
                                                POPULATE      
   ***********************************************************************************************/      
   IF @cType = 'POPULATE-IN'      
   BEGIN      
      -- Get stat      
      SELECT @nTotalDropID = COUNT( DISTINCT SourceKey) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND Method = @cMethod AND SourceKey <> ''      
            
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
   IF @cType = N'POPULATE-OUT'
   BEGIN
      DECLARE @cUnAssign      NVARCHAR( 1)
      SET @cUnAssign = rdt.rdtGetConfig( @nFunc, 'UNASSIGNPTLDROPID', @cStorerKey)    
      IF @cUnAssign = '1'    
      BEGIN
         IF @nStep = 4
         BEGIN
            IF @nInputKey = 1
            BEGIN
               UPDATE dbo.PICKDETAIL WITH(ROWLOCK)
               SET DropID = ''
               WHERE Storerkey = @cStorerKey
               AND DropID LIKE RTRIM(@cStation) + '%' 
               AND ISNULL(RTRIM(@cStation),'') <> ''
            END         
         END
      END
   END 
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
         GOTO RollBackTran      
      END      
            
      -- Check blank      
      IF @cDropID = ''       
      BEGIN      
         SET @nErrNo = 158551      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need DropID      
         GOTO RollBackTran      
      END      
         
      -- Check DropID valid      
      IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cDropID AND [Status] < '9')      
      BEGIN      
         SET @nErrNo = 158552      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad DropID      
         SET @cOutField01 = ''      
         GOTO RollBackTran      
      END      
         
      -- Check DropID assigned      
      IF EXISTS( SELECT 1       
         FROM rdt.rdtPTLPieceLog WITH (NOLOCK)       
         WHERE StorerKey = @cStorerKey      
            AND Method = @cMethod      
            AND SourceKey = @cDropID)      
      BEGIN      
         SET @nErrNo = 158553      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDAssigned      
         SET @cOutField01 = ''      
         GOTO RollBackTran      
      END      

      DECLARE @tDP TABLE ( DP  NVARCHAR(30))
      DECLARE @tWaveKey TABLE ( WaveKey  NVARCHAR(10))

      INSERT INTO @tDP ( DP)
      SELECT DeviceID + DevicePosition 
      FROM dbo.DeviceProfile WITH (NOLOCK)    
      WHERE StorerKey = @cStorerKey 
      AND   DeviceType = 'STATION'

      INSERT INTO @tWaveKey ( WaveKey)
      SELECT DISTINCT WaveKey 
      FROM dbo.PickDetail WITH (NOLOCK)    
      WHERE Storerkey = @cStorerKey
      AND   DropID = @cDropID
      AND   [Status] < '9'

      IF EXISTS ( -- means there is sortation done already    
         SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)    
         JOIN @tWaveKey WaveKey ON ( PD.WaveKey = WaveKey.WaveKey)
         JOIN @tDP DP ON ( PD.DropID = DP.DP)
         WHERE PD.Storerkey = @cStorerKey
         AND   PD.Status < '9')
      BEGIN    
         SET @cChkStation = LEFT( @cStation, 5) + '%'    
             
         --if records > 0 == means if sorting to same cart    
         IF EXISTS (    
            SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)    
            JOIN @tWaveKey WaveKey ON ( PD.WaveKey = WaveKey.WaveKey)
            JOIN @tDP DP ON ( PD.DropID = DP.DP)
            WHERE Storerkey = @cStorerKey
            AND   PD.DropID NOT LIKE @cChkStation
            AND   PD.Status < '9')
         BEGIN      
            SET @nErrNo = 158556      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong Cart      
            SET @cOutField01 = ''      
            GOTO RollBackTran      
         END         
      END    
    
      -- Check dropid scanned onto the same cart must only have 1 wavekey    
      SELECT @cWaveKey = O.UserDefine09    
      FROM dbo.PICKDETAIL PD WITH (NOLOCK)    
      JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)    
      WHERE PD.Storerkey = @cStorerKey    
      AND   PD.DropID LIKE RTRIM( @cStation) + '%'    
      AND   PD.[Status] < '9'    
      GROUP BY O.UserDefine09    
          
      SET @nCnt = @@ROWCOUNT    
          
      IF @nCnt > 1    
      BEGIN      
         SET @nErrNo = 158557      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Cart >1 Wave      
         SET @cOutField01 = ''      
         GOTO RollBackTran      
      END     
    
      IF @nCnt = 1    
      BEGIN    
         SELECT @cWaveKey2cHK = O.UserDefine09    
         FROM dbo.PICKDETAIL PD WITH (NOLOCK)    
         JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)    
         WHERE PD.Storerkey = @cStorerKey    
         AND   PD.DropID = @cDropID    
         AND   PD.[Status] < '9'    
         GROUP BY O.UserDefine09    
          
         IF @@ROWCOUNT > 1    
         BEGIN      
            SET @nErrNo = 158558      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID >1 Wave      
            SET @cOutField01 = ''      
            GOTO RollBackTran      
         END      
          
         IF ISNULL( @cWaveKey2cHK, '') <> ISNULL( @cWaveKey, '')    
         BEGIN      
            SET @nErrNo = 158559      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Different Wave      
            SET @cOutField01 = ''      
            GOTO RollBackTran      
         END           
      END    
                
      -- Loop orders      
      DECLARE @cPreassignPos NVARCHAR(10)      
      DECLARE @curOrder CURSOR      
      SET @curOrder = CURSOR FOR      
      SELECT PD.OrderKey       
      FROM dbo.PICKDETAIL PD WITH (NOLOCK)       
      JOIN dbo.Orders O WITH (NOLOCK) ON ( O.OrderKey = PD.OrderKey)    
      WHERE PD.Storerkey = @cStorerKey     
      AND   PD.DropID = @cDropID    
      AND   PD.Status <= '5'    
      AND   PD.QTY > 0    
      AND   PD.Status <> '4'    
      AND   O.Status <> 'CANC'     
      AND   O.SOStatus <> 'CANC'    
      GROUP BY PD.OrderKey    
      ORDER BY PD.OrderKey      
      OPEN @curOrder      
      FETCH NEXT FROM @curOrder INTO @cOrderKey      
      WHILE @@FETCH_STATUS = 0      
      BEGIN      
         -- Get position not yet assign      
         SET @cIPAddress = ''      
         SET @cPosition = ''      
         SET @cWaveKey = ''    
    
         SELECT TOP 1 @cWaveKey = WaveKey    
         FROM dbo.PICKDETAIL WITH (NOLOCK)    
         WHERE OrderKey = @cOrderKey    
         ORDER BY 1    
             
         IF ISNULL( @cWaveKey, '') = ''    
            SELECT @cWaveKey = UserDefine09    
            FROM dbo.Orders WITH (NOLOCK)    
            WHERE OrderKey = @cOrderKey    
    
         SELECT TOP 1     
            @cIPAddress = IPAddress,     
            @cPosition = Position    
         FROM RDT.rdtPTLPieceLog WITH (NOLOCK)    
         WHERE Station = @cStation    
         AND   OrderKey = @cOrderKey   -- 1 Station 1 orderkey    
         AND   Method = @cMethod    
         ORDER BY 1    
             
         SET @nCnt = @@ROWCOUNT    
            
         -- Check if this dropid had assigned with position before    
         IF @nCnt = 0    
         BEGIN    
            SELECT TOP 1 @cPosition = SUBSTRING( PD.DropID, 6, 2)    
            FROM dbo.PICKDETAIL PD WITH (NOLOCK)    
            WHERE PD.OrderKey = @cOrderKey    
            AND   PD.WaveKey = @cWaveKey
            AND   EXISTS ( SELECT 1 FROM dbo.DeviceProfile DP WITH (NOLOCK)
                           WHERE DP.DeviceType = 'STATION'    
                           AND   DP.DeviceID = @cStation      
                           AND   DP.DevicePosition = PD.DropID)
            ORDER BY 1    
                
            SET @nCnt = @@ROWCOUNT    
                
            IF @nCnt > 0    
               SELECT TOP 1      
                  @cIPAddress = IPAddress    
               FROM dbo.DeviceProfile WITH (NOLOCK)      
               WHERE DeviceType = 'STATION'      
               AND   DeviceID = @cStation      
               ORDER BY 1    
         END    
             
         -- Get new position    
         IF @nCnt = 0    
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
               -- User will sort halfway and unassign cart     
               -- rdtPTLPieceLog will be empty and will get same position for diff orderkey    
               AND NOT EXISTS ( SELECT 1     
                  FROM dbo.PICKDETAIL PD WITH (NOLOCK)     
                  WHERE DP.DeviceID + DP.DevicePosition = PD.DropID    
                  AND   PD.WaveKey = @cWaveKey)    
            ORDER BY DP.LogicalPos, DP.DevicePosition      
      
         -- Check enuf position in station      
         IF @cPosition = ''      
         BEGIN      
            SET @nErrNo = 158554      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not enuf Pos      
            SET @cOutField01 = ''      
            GOTO RollBackTran      
         END       
    
         SELECT @cWaveKey = UserDefine09    
         FROM dbo.ORDERS WITH (NOLOCK)    
         WHERE OrderKey = @cOrderKey    
    
         DECLARE @curSKU CURSOR      
         SET @curSKU = CURSOR FOR      
         SELECT Sku       
         FROM dbo.PICKDETAIL WITH (NOLOCK)       
         WHERE Storerkey = @cStorerKey     
         AND   DropID = @cDropID    
         AND   Status <= '5'    
         AND   QTY > 0    
         AND   Status <> '4'    
         AND   OrderKey = @cOrderKey     
         GROUP BY SKU    
         ORDER BY SKU    
         OPEN @curSKU    
         FETCH NEXT FROM @curSKU INTO @cSKU    
         WHILE @@FETCH_STATUS = 0    
         BEGIN    
                
            -- Save assign      
            INSERT INTO rdt.rdtPTLPieceLog (Station, IPAddress, Position, Method, SourceKey, OrderKey, SKU, WaveKey)     
            VALUES      
            (@cStation, @cIPAddress, @cPosition, @cMethod, @cDropID, @cOrderKey, @cSKU, @cWaveKey)    
            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 158555      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log fail      
               GOTO RollBackTran      
            END      
                
            FETCH NEXT FROM @curSKU INTO  @cSKU    
         END    
         CLOSE @curSKU    
         DEALLOCATE @curSKU    
    
         FETCH NEXT FROM @curOrder INTO @cOrderKey    
      END    
    
      IF EXISTS ( SELECT 1 FROM rdt.rdtPTLPieceLog GROUP BY Station HAVING COUNT( DISTINCT WaveKey) > 1)    
      BEGIN      
         SET @nErrNo = 158580      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Different Wave      
         GOTO RollBackTran      
      END    
                
      -- Get total      
      SELECT @nTotalDropID = COUNT( DISTINCT SourceKey) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND Method = @cMethod AND SourceKey <> ''      
      
      -- Prepare current screen var      
      SET @cOutField01 = '' -- DropID      
      SET @cOutField02 = CAST( @nTotalDropID AS NVARCHAR(5))      
            
      -- Stay in current screen      
      SET @nErrNo = -1       
      
   END      
    
   GOTO Quit    
    
RollBackTran:    
      ROLLBACK TRAN rdt_PTLPiece_Assign_DropID06    
      
Quit:      
   WHILE @@TRANCOUNT > @nTranCount    
      COMMIT TRAN    
      
END 

GO