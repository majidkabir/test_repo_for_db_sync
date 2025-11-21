SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/      
/* Store procedure: rdt_PTLPiece_Assign_DropID01                              */      
/* Copyright      : LFLogistics                                               */      
/*                                                                            */      
/* Date       Rev  Author   Purposes                                          */      
/* 2020-07-17 1.0  James    WMS-12226 Created                                 */    
/* 2020-11-02 1.1  YeeKung  Quick Fixed order cannot be assigned (yeekung01)  */    
/* 2021-11-26 1.2  James    Perf tuning (james01)                             */  
/* 2023-06-06 1.3  James    WMS-22665 Enhance the way to lookup device name   */
/*                          instead of hardcoded (james02)                    */
/* 2023-10-03 1.4  JihHaur  JSM-181474 bugfix for same orders but different   */
/*                          dropid (JH01)                                     */
/******************************************************************************/      
      
CREATE   PROC [RDT].[rdt_PTLPiece_Assign_DropID01] (      
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
   DECLARE @nRowCOUNT    INT --(yeekung01)  
   DECLARE @cPrefix      NVARCHAR( 10)
   DECLARE @nPosStart    INT
   DECLARE @nPosLength   INT
      
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
         SET @nErrNo = 158551      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need DropID      
         GOTO Quit      
      END      
         
      -- Check DropID valid      
      IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cDropID AND [Status] < '9')      
      BEGIN      
         SET @nErrNo = 158552      
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
         SET @nErrNo = 158553      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDAssigned      
         SET @cOutField01 = ''      
         GOTO Quit      
      END      
  
      DECLARE @tWaveKey TABLE ( WaveKey    NVARCHAR( 10) NOT NULL PRIMARY KEY)  
      DECLARE @tDropID  TABLE ( DropID     NVARCHAR( 20) NOT NULL PRIMARY KEY)  
       
      INSERT INTO @tWaveKey ( WaveKey)  
      SELECT DISTINCT WaveKey   
      FROM dbo.PickDetail WITH (NOLOCK)    
      WHERE DropID = @cDropID  
      AND   [Status] <> '4'  
      AND   (WaveKey <> '' AND WaveKey IS NOT NULL)  
        
      INSERT INTO @tDropID ( DropID)  
      SELECT DISTINCT DeviceID + DevicePosition   
      FROM dbo.DeviceProfile WITH (NOLOCK)    
      WHERE StorerKey = @cStorerKey AND devicetype='STATION'  
           
      IF EXISTS ( -- means there is sortation done already  
         SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)    
                  WHERE EXISTS ( SELECT 1 FROM @tWaveKey W  WHERE W.WaveKey = PD.WaveKey)   
                  AND   EXISTS ( SELECT 1 FROM @tDropID D  WHERE D.DropID  = PD.DropID))   
      BEGIN    
         SET @cChkStation = LEFT( @cStation, 5) + '%'    
             
         --if records > 0 == means if sorting to same cart    
         IF EXISTS (    
            SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)    
            WHERE EXISTS ( SELECT 1 FROM @tWaveKey W  WHERE W.WaveKey = PD.WaveKey)    
            AND   EXISTS ( SELECT 1 FROM @tDropID D  WHERE D.DropID  = PD.DropID)              
            AND   PD.DropID NOT LIKE @cChkStation)    
         BEGIN      
            SET @nErrNo = 158556      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong Cart      
            SET @cOutField01 = ''      
            GOTO Quit      
         END         
      END    
    
      -- Check dropid scanned onto the same cart must only have 1 wavekey    
      SELECT TOP 1 @cWaveKey = O.UserDefine09    
      FROM dbo.ORDERS O WITH (NOLOCK)    
      WHERE EXISTS ( SELECT 1 FROM rdt.rdtPTLPieceLog PTL WITH (NOLOCK)    
                     WHERE PTL.OrderKey = O.OrderKey    
               
                     AND   PTL.Station = @cStation)    
      AND   O.StorerKey = @cStorerKey    
      ORDER BY 1    
          
      IF @@ROWCOUNT > 0    
      BEGIN    
         SELECT @cWaveKey2cHK = O.UserDefine09    
         FROM dbo.PICKDETAIL PD WITH (NOLOCK)    
         JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)    
         WHERE PD.Storerkey = @cStorerKey    
         AND   PD.DropID = @cDropID           AND   PD.[Status] < '9'    
         GROUP BY O.UserDefine09    
          
         IF @@ROWCOUNT > 1    
         BEGIN      
            SET @nErrNo = 158557      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID >1 Wave      
            SET @cOutField01 = ''      
            GOTO Quit      
         END      
          
         IF ISNULL( @cWaveKey2cHK, '') <> ISNULL( @cWaveKey, '')    
         BEGIN      
            SET @nErrNo = 158558      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Different Wave      
            SET @cOutField01 = ''      
            GOTO Quit      
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
             
         SET @nRowCOUNT=@@ROWCOUNT /*(JH01)*/

         -- Check if this dropid had assigned with position before    
         IF @nRowCOUNT = 0  /*(JH01)   @@ROWCOUNT = 0  */
         BEGIN    
         	SELECT 
         	   @cPrefix = Code,
         	   @nPosStart = Short,
         	   @nPosLength = Long
         	FROM dbo.CODELKUP WITH (NOLOCK) 
         	WHERE LISTNAME = 'PTLPREFMAP' 
         	AND   Storerkey = @cStorerKey
         	AND   code2 = @nFunc
         	
         	IF @cPrefix <> '' AND CAST( @nPosStart AS INT) > 0 AND CAST( @nPosLength AS INT) > 0
            BEGIN
               SELECT TOP 1 @cPosition = SUBSTRING( DropID, @nPosStart, @nPosLength)    
               FROM dbo.PICKDETAIL WITH (NOLOCK)    
               WHERE OrderKey = @cOrderKey    
               AND   DropID LIKE RTRIM( @cPrefix) + '%'    
               ORDER BY 1 
            END
            ELSE
            BEGIN
               SELECT TOP 1 @cPosition = SUBSTRING( DropID, 6, 2)    
               FROM dbo.PICKDETAIL WITH (NOLOCK)    
               WHERE OrderKey = @cOrderKey    
               AND   DropID LIKE 'CART%'    
               ORDER BY 1    
            END
              
            SET @nRowCOUNT=@@ROWCOUNT --(yeekung01)  
    
            SELECT TOP 1      
               @cIPAddress = IPAddress    
            FROM dbo.DeviceProfile WITH (NOLOCK)      
            WHERE DeviceType = 'STATION'      
            AND   DeviceID = @cStation      
            ORDER BY 1    
         END    
             
         -- Get new position    
         IF @nRowCOUNT = 0    
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
            GOTO Quit      
         END     
    
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
            INSERT INTO rdt.rdtPTLPieceLog (Station, IPAddress, Position, Method, SourceKey, OrderKey, SKU)     
            VALUES      
            (@cStation, @cIPAddress, @cPosition, @cMethod, @cDropID, @cOrderKey, @cSKU)    
            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 158555      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log fail      
               GOTO Quit      
            END      
                
            FETCH NEXT FROM @curSKU INTO  @cSKU    
         END    
         CLOSE @curSKU    
         DEALLOCATE @curSKU    
    
         FETCH NEXT FROM @curOrder INTO @cOrderKey    
      END    
          
      -- Get total      
      SELECT @nTotalDropID = COUNT( DISTINCT SourceKey) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND Method = @cMethod AND SourceKey <> ''      
      
      -- Prepare current screen var      
      SET @cOutField01 = '' -- DropID      
      SET @cOutField02 = CAST( @nTotalDropID AS NVARCHAR(5))      
            
      -- Stay in current screen      
      SET @nErrNo = -1       
      
   END      
      
Quit:      
      
END      
    

GO