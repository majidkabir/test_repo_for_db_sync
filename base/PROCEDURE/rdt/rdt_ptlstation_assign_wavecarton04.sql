SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
/******************************************************************************/  
/* Store procedure: rdt_PTLStation_Assign_WaveCarton04                        */  
/* Copyright      : LFLogistics                                               */  
/*                                                                            */  
/* Date       Rev  Author   Purposes                                          */  
/* 15-08-2024 1.0  yeekung  FCR-609 Created                                   */  
/* 23-09-2024 1.1  yeekung  UWP-24488 Add Light on carton field (yeekung01)   */
/* 26-10-2024 1.2  yeekung  INC7378172 Fix the Duplicate carton in same wave  */
/* 20-12-2024 1.3  yeekung  FCR-1484 remove multi ppl scan same wave          */
/******************************************************************************/  
  
CREATE   PROC [RDT].[rdt_PTLStation_Assign_WaveCarton04] (  
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
   DECLARE @cSuggestLOC     NVARCHAR(10)  
   DECLARE @nTotalLoad INT  
   DECLARE @nTotalCarton    INT  
   DECLARE @curPD           CURSOR  
          ,@cWaveKey        NVARCHAR(10)  
          ,@cOrderKey       NVARCHAR(10)  
          ,@cPairStation    NVARCHAR(10)  
          ,@cPairPosition   NVARCHAR(10)  
          ,@cPairLocation   NVARCHAR(10) 
   DECLARE  @cLightMode     NVARCHAR( 4),   
            @cLight         NVARCHAR( 1),
            @bSuccess       INT
  
  
   DECLARE @curPTLAssign CURSOR  
  
   SET @nTranCount = @@TRANCOUNT  

   SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey) 
  
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

      SELECT @cLight  = V_String27
      FROM RDT.RDTMobrec (NOLOCK)
      WHERE Mobile = @nMobile
  
      -- Get carton not yet assign  
      IF @nTotalLoad > @nTotalCarton  
      BEGIN  
         -- Get carton not yet assign  
         SELECT TOP 1  
            @cStation = Station,  
            @cIPAddress =  DP.IPAddress,  
            @cPosition = DP.DevicePosition,  
            @cCartonID = '',  
            @cSuggestLOC = PTL.LOC  
         FROM rdt.rdtPTLStationLog PTL WITH (NOLOCK)  
            JOIN DeviceProfile DP (nolock) ON PTL.Position = DP.DevicePosition AND PTL.Station = DP.DeviceID 
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
            AND CartonID = ''  
         ORDER BY CAST(DP.logicalpos AS INT)
  
         SELECT @nTotalLoad = COUNT(1)  
         FROM rdt.rdtPTLStationLog WITH (NOLOCK)  
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
  
         SELECT @nTotalCarton = COUNT(1)  
         FROM rdt.rdtPTLStationLog WITH (NOLOCK)  
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
            AND CartonID <> ''  


         IF @cLight = '1' 
         BEGIN
               
            EXEC PTL.isp_PTL_LightUpLoc 
               @n_Func           = @nFunc
               ,@n_PTLKey         = 0
               ,@c_DisplayValue   = 'LOC' 
               ,@b_Success        = @bSuccess    OUTPUT    
               ,@n_Err            = @nErrNo      OUTPUT  
               ,@c_ErrMsg         = @cErrMsg     OUTPUT
               ,@c_DeviceID       = @cStation
               ,@c_DevicePos      = @cPosition
               ,@c_DeviceIP       = @cIPAddress  
               ,@c_LModMode       = @cLightMode
            IF @nErrNo <> 0
               GOTO Quit
         END   
      END  
      ELSE  
      BEGIN  
         SET @cWaveKey = ''  
         SET @cStation = ''  
         SET @cPosition = ''  
         SET @cCartonID = ''  
  
       EXEC rdt.rdtSetFocusField @nMobile, 1 -- LoadKey  
      END  
  
      -- Prepare current screen var  
      SET @cOutField01 = @cWaveKey  
      SET @cOutField02 = @cStation  
      SET @cOutField03 = @cSuggestLOC  
      SET @cOutField04 = @cLOC  
      SET @cOutField05 = CAST( @nTotalLoad AS NVARCHAR(5))  
      SET @cOutField06 = @cCartonID  
      SET @cOutField07 = CAST( @nTotalCarton AS NVARCHAR(5))  
  
      -- Go to load consignee carton screen  
      SET @nScn = 6391  
   END  
  
   IF @cType = 'POPULATE-OUT'  
   BEGIN  
      -- Enable field  
      SET @cFieldAttr01 = '' -- cWaveKey  
      SET @cFieldAttr04 = '' -- CartonID  
  
  -- Go to station screen  
   END  
  
  
   /***********************************************************************************************  
                                                 CHECK  
   ***********************************************************************************************/  
   IF @cType = 'CHECK'  
   BEGIN  
      -- Screen mapping  
      SET @cWaveKey = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END  
      SET @cStation = @cOutField02  
      SET @cSuggestLOC = @cOutField03  
      SET @cLoc     = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END  
      SET @cCartonID = CASE WHEN @cFieldAttr06 = '' THEN @cInField06 ELSE @cOutField06 END  
  
      -- Get total  
      SELECT @nTotalLoad = COUNT(1)  
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)  
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
  
      SELECT @nTotalCarton = COUNT(1)  
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)  
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
         AND CartonID <> ''  


      SELECT @cLight  = V_String27
      FROM RDT.RDTMobrec (NOLOCK)
      WHERE Mobile = @nMobile
  
      -- WaveKey enabled  
      IF @cFieldAttr01 = ''  
      BEGIN  
     -- Check blank  
         IF @cWaveKey = ''  
         BEGIN  
            SET @nErrNo = 222651  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WaveKeyReq  
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey  
            GOTO Quit  
         END  
  
         IF NOT EXISTS (SELECT 1 FROM dbo.Wave (NOLOCK) WHERE WaveKey = @cWaveKey )  
         BEGIN  
            SET @nErrNo = 222652  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidWaveKey  
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey  
            GOTO Quit  
         END  
  
         ---- Check load assigned  
         --IF EXISTS( SELECT 1 FROM rdt.rdtPTLStationLog WITH (NOLOCK) WHERE WaveKey = @cWaveKey AND CartonID <> '' and Station NOT IN (@cStation1 ))  
         --BEGIN  
         --   SET @nErrNo = 222653  
         --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WaveKey Assigned
         --   EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey  
         --   GOTO Quit  
         --END 

          
         -- Check load no task  
         IF NOT EXISTS( SELECT TOP 1 1  
            FROM LoadPlanDetail LPD WITH (NOLOCK)  
               JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)  
               JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)  
            WHERE O.UserDefine09 = @cWaveKey  
               AND O.StorerKey = @cStorerKey  
               AND O.Facility = @cFacility  
               AND O.Status <> 'CANC'  
               AND O.SOStatus <> 'CANC'  
               AND PD.Status  <= '5'
               AND PD.CaseID = ''  
               AND PD.QTY > 0)  
         BEGIN  
            SET @nErrNo = 222655  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wave no task  
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey  
            SET @cOutField01 = ''  
            GOTO Quit  
         END   
  
         IF EXISTS( SELECT 1 FROM rdt.rdtPTLStationLog WITH (NOLOCK)  
                    WHERE Station IN (@cStation1 ) )  
         BEGIN  
            IF EXISTS ( SELECT 1 FROM rdt.rdtPTLStationLog WITH (NOLOCK)  
                              WHERE Station =  @cStation1  
                              AND WaveKey <> @cWaveKey )  
            BEGIN  
               SET @nErrNo = 222654  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WaveNotSame  
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey  
               GOTO Quit  
            END  
         END  
  
            --Check finish assign  
         IF @nTotalCarton > 0 AND @nTotalLoad = @nTotalCarton  AND @cCartonID = ''  
         BEGIN  

            IF @cLight = '1' 
            BEGIN
               -- Off all lights
               EXEC PTL.isp_PTL_TerminateModule
                  @cStorerKey
                  ,@nFunc
                  ,@cStation1
                  ,'STATION'
                  ,@bSuccess    OUTPUT
                  ,@nErrNo       OUTPUT
                  ,@cErrMsg      OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit
            END   
   
            SET @cFieldAttr01 = '' -- cWaveKey  
            GOTO Quit  
         END  

         IF NOT EXISTS (   SELECT 1 FROM rdt.rdtPTLStationLog WITH (NOLOCK)  
                              WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
                              AND WaveKey = @cWaveKey )
         BEGIN
 
            -- Check load no task  
            IF NOT EXISTS( SELECT TOP 1 1  
               FROM LoadPlanDetail LPD WITH (NOLOCK)  
                  JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)  
                  JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)  
               WHERE O.UserDefine09 = @cWaveKey  
                  AND O.StorerKey = @cStorerKey  
                  AND O.Facility = @cFacility  
                  AND O.Status <> 'CANC'  
                  AND O.SOStatus <> 'CANC'  
                  AND PD.Status  <= '5'
                  AND PD.CaseID = ''  
                  AND PD.QTY > 0)  
            BEGIN  
               SET @nErrNo = 222655  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wave no task  
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey  
               SET @cOutField01 = ''  
               GOTO Quit  
            END  

            SET @curPTLAssign = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT WD.OrderKey --, SUM(PD.QTY) AS Qty  
            FROM dbo.WaveDetail WD WITH (NOLOCK)  
            INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = WD.OrderKey  
            WHERE WD.Wavekey = @cWaveKey  
               AND PD.UOM <>'2'
            GROUP BY WD.OrderKey  
            ORDER BY SUM(Qty) DESC  
   
            OPEN @curPTLAssign  
            FETCH NEXT FROM @curPTLAssign INTO @cOrderKey  
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
   
               SELECT TOP 1 @cIPAddress = IPAddress,  
                     @cPosition  = DevicePosition,  
                     @cLoc       = Loc  
               FROM dbo.DeviceProfile D  
               WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
               AND DevicePosition NOT IN ( SELECT Position FROM rdt.rdtPTLStationLog WITH (NOLOCK)  
                                          WHERE WaveKey = @cWaveKey )  
               AND Facility = @cFacility
               ORDER BY CAST(D.logicalpos AS INT)
   
               -- Save assign  
               INSERT INTO rdt.rdtPTLStationLog (Station, IPAddress, Position, CartonID, Method, WaveKey, OrderKey, StorerKey,loc)  
               VALUES (@cStation1, @cIPAddress, @cPosition, '', @cMethod, @cWaveKey, @cOrderKey, @cStorerKey,@cLoc)  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 222656  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail  
                  EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey  
                  SET @cOutField01 = ''  
                  GOTO Quit  
               END  
   
               FETCH NEXT FROM @curPTLAssign INTO @cOrderKey  
   
            END  
   
            SET @cOutField01 = @cWaveKey  
   
            SET @nTotalLoad = @nTotalLoad + 1  
         END
  
         -- Get carton not yet assign  
         SELECT TOP 1  
            @cStation = Station,  
            @cIPAddress =  DP.IPAddress,  
            @cPosition = DP.DevicePosition,  
            @cCartonID = '',  
            @cSuggestLOC = PTL.LOC  
         FROM rdt.rdtPTLStationLog PTL WITH (NOLOCK)  
            JOIN DeviceProfile DP (nolock) ON PTL.Position = DP.DevicePosition AND PTL.Station = DP.DeviceID 
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
            AND CartonID = ''  
         ORDER BY CAST(DP.logicalpos AS INT)
  
         SELECT @nTotalLoad = COUNT(1)  
         FROM rdt.rdtPTLStationLog WITH (NOLOCK)  
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
  
         SELECT @nTotalCarton = COUNT(1)  
         FROM rdt.rdtPTLStationLog WITH (NOLOCK)  
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
            AND CartonID <> ''  
  
         -- Prepare current screen var  
         SET @cOutField01 = @cWaveKey  
         SET @cOutField02 = @cStation  
         SET @cOutField03 = @cSuggestLOC  
         SET @cOutField04 = ''  
         SET @cOutField05 = CAST( @nTotalLoad AS NVARCHAR(5))  
         SET @cOutField06 = ''  
         SET @cOutField07 = CAST( @nTotalCarton AS NVARCHAR(5))  
  
         -- Enable disable field  
         SET @cFieldAttr01 = 'O' -- WaveKey  
         SET @cFieldAttr04 = ''  -- CartonID  
         SET @cFieldAttr06 = ''  -- CartonID  


         IF @cLight = '1' 
         BEGIN
               
            EXEC PTL.isp_PTL_LightUpLoc 
               @n_Func           = @nFunc
               ,@n_PTLKey         = 0
               ,@c_DisplayValue   = 'LOC' 
               ,@b_Success        = @bSuccess    OUTPUT    
               ,@n_Err            = @nErrNo      OUTPUT  
               ,@c_ErrMsg         = @cErrMsg     OUTPUT
               ,@c_DeviceID       = @cStation
               ,@c_DevicePos      = @cPosition
               ,@c_DeviceIP       = @cIPAddress  
               ,@c_LModMode       = @cLightMode
            IF @nErrNo <> 0
               GOTO Quit
         END   
  
         -- Stay in current page  
         SET @nErrNo = -1  
         GOTO Quit  
      END  
  
      -- Position Field enabled  
      IF @cFieldAttr04 = ''  
      BEGIN  
         IF @cLoc = ''  
         BEGIN  
            SET @nErrNo = 222657  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LocReq  
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartonID  
            SET @cOutField04 = ''  
            GOTO Quit  
         END  
  
         IF @cSuggestLOC <> @cLoc   
         BEGIN  
            SET @nErrNo = 222658  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidLoc  
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartonID  
            SET @cOutField04 = ''  
            GOTO Quit  
         END  

         IF @cLight = '1' 
         BEGIN

            SELECT TOP 1  
               @cStation = Station,  
               @cIPAddress =  DP.IPAddress,  
               @cPosition = DP.DevicePosition
            FROM rdt.rdtPTLStationLog PTL WITH (NOLOCK)  
               JOIN DeviceProfile DP (nolock) ON PTL.Position = DP.DevicePosition AND PTL.Station = DP.DeviceID 
            WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
               AND CartonID = '' 
               AND  PTL.LOC  =  @cLoc
            ORDER BY CAST(DP.logicalpos AS INT)
               
         END   
      END  

      SET @cOutfield03 = @cSuggestLOC 
      SET @cOutField04 = @cLoc  
  
      -- CartonID field enabled  
      IF @cFieldAttr06 = ''  
      BEGIN  
         -- Check blank tote  
         IF @cCartonID = ''  
         BEGIN  
            SET @nErrNo = 222659  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CartonID  
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- CartonID  
            SET @cOutField05 = ''  
            GOTO Quit  
         END  
  
         -- Check barcode format
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'CartonID', @cCartonID) = 0
         BEGIN
            SET @nErrNo = 222663
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- CartonID  
            SET @cOutField05 = ''  
            GOTO Quit
         END
  
         SELECT TOP 1 @cOrderKey = OrderKey  
         FROM rdt.rdtPTLStationLog WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
            AND Station = @cStation  
            AND CartonID = ''  
         ORDER BY RowRef  
  
         SELECT TOP 1 @cPosition = DevicePosition  
         FROM DeviceProfile WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
            AND DeviceID = @cStation  
            AND Loc = @cLoc  
  
         IF EXISTS ( SELECT 1 FROM rdt.rdtPTLStationLog  
                     WHERE StorerKey = @cStorerKey  
                     AND WaveKey = @cWaveKey  
                     AND Position = @cPosition  
                     AND CartonID <> '' )  
         BEGIN  
            SET @nErrNo = 222660  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LocAssigned  
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- CartonID  
            GOTO Quit  
         END  
  
         IF EXISTS ( SELECT 1 FROM rdt.rdtPTLStationLog  
                     WHERE StorerKey = @cStorerKey  
                     AND WaveKey = @cWaveKey  
                     AND CartonID = @cCartonID )  
         BEGIN  
            SET @nErrNo = 222661  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonIDAssign  
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- CartonID  
            GOTO Quit  
         END  

         DECLARE @cSQL NVARCHAR(MAX)
         DECLARE @cSQLParam NVARCHAR(MAX)
         DECLARE @tVar           VariableTable
         DECLARE @cAssignExtValSP NVARCHAR( 20)
         SET @cAssignExtValSP = rdt.RDTGetConfig( @nFunc, 'AssignExtValSP', @cStorerKey)
         IF @cAssignExtValSP = '0'
            SET @cAssignExtValSP = ''

         IF @cAssignExtValSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cAssignExtValSP AND type = 'P')
            BEGIN
               DECLARE @cCurrentSP NVARCHAR( 60)
               SET @cCurrentSP = OBJECT_NAME( @@PROCID)

               INSERT INTO @tVar (Variable, Value) VALUES
                  ('@cWaveKey',     @cWaveKey),
                  ('@cPosition',    @cPosition),
                  ('@cCartonID',    @cCartonID)

               SET @cSQL = 'EXEC rdt.' + RTRIM( @cAssignExtValSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                  ' @cStation, @cMethod, @cCurrentSP, @tVar, ' +
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT,@cType '
               SET @cSQLParam =
                  ' @nMobile     INT,           ' +
                  ' @nFunc       INT,           ' +
                  ' @cLangCode   NVARCHAR( 3),  ' +
                  ' @nStep       INT,           ' +
                  ' @nInputKey   INT,           ' +
                  ' @cFacility   NVARCHAR( 5) , ' +
                  ' @cStorerKey  NVARCHAR( 10), ' +
                  ' @cStation    NVARCHAR( 1),  ' +
                  ' @cMethod     NVARCHAR( 15), ' +
                  ' @cCurrentSP  NVARCHAR( 60),  ' +
                  ' @tVar        VariableTable READONLY, ' +
                  ' @nErrNo      INT           OUTPUT, ' +
                  ' @cErrMsg     NVARCHAR(250) OUTPUT, ' +
                  ' @cType       NVARCHAR(15)           '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
                  @cStation, @cMethod, @cCurrentSP, @tVar,
                  @nErrNo OUTPUT, @cErrMsg OUTPUT,@cType

               IF @nErrNo <> 0
                  GOTO Quit
            END
         END
  
         -- Save assign  
         UPDATE rdt.rdtPTLStationLog SET  
             CartonID = @cCartonID   
         WHERE Station = @cStation  
            AND OrderKey = @cOrderKey 
            AND Position = @cPosition 
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 222662  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log fail  
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- CartonID  
            GOTO Quit  
         END 

         -- Off all lights  
         EXEC  PTL.isp_PTL_TerminateModuleSingle  
            @cStorerKey  
            ,@nFunc  
            ,@cStation  
            ,@cPosition  
            ,@bSuccess    OUTPUT  
            ,@nErrNo       OUTPUT  
            ,@cErrMsg      OUTPUT  
         IF @nErrNo <> 0  
            GOTO Quit   
  
  
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
         SET @cFieldAttr06 = '' -- CartonID  

         IF @cLight = '1' 
         BEGIN
            -- Off all lights
            EXEC PTL.isp_PTL_TerminateModule
               @cStorerKey
               ,@nFunc
               ,@cStation1
               ,'STATION'
               ,@bSuccess    OUTPUT
               ,@nErrNo       OUTPUT
               ,@cErrMsg      OUTPUT
            IF @nErrNo <> 0
               GOTO Quit
         END  
  
         GOTO Quit  
      END  
  
      -- Get carton not yet assign  
      SELECT TOP 1  
         @cStation = Station,  
         @cIPAddress =  DP.IPAddress,  
         @cPosition = DP.DevicePosition,  
         @cCartonID = '',  
         @cSuggestLOC = PTL.LOC  
      FROM rdt.rdtPTLStationLog PTL WITH (NOLOCK)  
         JOIN DeviceProfile DP (nolock) ON PTL.Position = DP.DevicePosition AND PTL.Station = DP.DeviceID 
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
         AND CartonID = ''  
      ORDER BY CAST(DP.logicalpos AS INT)
  
      -- Prepare current screen var  
      SET @cOutField01 = @cWaveKey  
      SET @cOutField02 = @cStation  
      SET @cOutField03 = @cSuggestLOC  
      SET @cOutField04 = ''  
      SET @cOutField05 = CAST( @nTotalLoad AS NVARCHAR(5))  
      SET @cOutField06 = ''  
      SET @cOutField07 = CAST( @nTotalCarton AS NVARCHAR(5))  

      EXEC rdt.rdtSetFocusField @nMobile, 4 -- Location  


      IF @cLight = '1' 
      BEGIN
            
         EXEC PTL.isp_PTL_LightUpLoc
            @n_Func           = @nFunc
            ,@n_PTLKey         = 0
            ,@c_DisplayValue   = 'LOC' 
            ,@b_Success        = @bSuccess    OUTPUT    
            ,@n_Err            = @nErrNo      OUTPUT  
            ,@c_ErrMsg         = @cErrMsg     OUTPUT
            ,@c_DeviceID       = @cStation
            ,@c_DevicePos      = @cPosition
            ,@c_DeviceIP       = @cIPAddress  
            ,@c_LModMode       = @cLightMode
         IF @nErrNo <> 0
            GOTO Quit
      END  
  
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