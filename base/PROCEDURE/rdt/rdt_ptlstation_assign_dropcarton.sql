SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure:   rdt_PTLStation_Assign_DropCarton                         */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 02-01-2018 1.0  NLT013   UWP-17015 Created                                 */
/******************************************************************************/

CREATE PROC rdt.rdt_PTLStation_Assign_DropCarton (
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

   DECLARE 
      @cLoadKey               NVARCHAR(10),
      @cStation               NVARCHAR(10),
      @cIPAddress             NVARCHAR(40),
      @cPosition              NVARCHAR(10),
      @cCartonID              NVARCHAR(20),
      @cLOC                   NVARCHAR(10),
      @nTotalLoad             INT,
      @nTotalCarton           INT,
      @curPD                  CURSOR,
      @curPTLAssign           CURSOR,
      @cWaveKey               NVARCHAR(10),
      @cWaveKeyTemp           NVARCHAR(10),
      @cDropID                NVARCHAR(20),
      @cOrderKey              NVARCHAR(10),
      @cPairPosition          NVARCHAR(10),
      @cPairLocation          NVARCHAR(10),
      @cPickConfirmStatus     NVARCHAR(1),
      @nRowCount              INT
   
   SET @nTranCount = @@TRANCOUNT

   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'
   IF @cPickConfirmStatus NOT IN ( '3', '5')
      SET @cPickConfirmStatus = '5'

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
            @cDropID = pkd.DropID, 
            @cStation = st.Station, 
            @cPosition = st.Position
         FROM rdt.rdtPTLStationLog st WITH (NOLOCK) 
         INNER JOIN dbo.PICKDETAIL pkd WITH (NOLOCK) 
            ON st.StorerKey = pkd.StorerKey
            AND st.OrderKey = pkd.OrderKey
         WHERE st.Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND st.CartonID = ''

         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Carton ID
         
         SET @cFieldAttr01 = 'O' -- LoadKey
      END
      ELSE
      BEGIN
         SET @cDropID   = ''
         SET @cStation  = ''
         SET @cPosition = ''
         SET @cCartonID = ''

         EXEC rdt.rdtSetFocusField @nMobile, 1 -- LoadKey
      END

      -- Prepare next screen var
      SET @cOutField01 = @cDropID
      SET @cOutField02 = @cStation
      SET @cOutField03 = @cPosition
      SET @cOutField04 = @cCartonID
      SET @cOutField05 = CAST( @nTotalLoad AS NVARCHAR(5))
      SET @cOutField06 = CAST( @nTotalCarton AS NVARCHAR(5))

      SET @cFieldAttr03 = 'O' -- LOC

      -- Go to Drop carton screen
      SET @nScn = 6390
   END
      
   IF @cType = 'POPULATE-OUT'
   BEGIN
      -- Enable field
      SET @cFieldAttr01 = '' -- cDropID
      SET @cFieldAttr04 = '' -- CartonID

      -- Go to station screen
   END

   
   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Screen mapping
      SET @cDropID = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END
      SET @cStation = @cOutField02
      --SET @cLoc     = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END 
      SET @cCartonID = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END

      -- Get total 
      SELECT @nTotalLoad = COUNT(1) 
      FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
      
      SELECT @nTotalCarton = COUNT(1) 
      FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         AND CartonID <> ''

      -- Drop ID enabled
      IF @cFieldAttr01 = ''
      BEGIN
         -- Check blank
         IF @cDropID = '' 
         BEGIN
            SET @nErrNo = 213051
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID Needed
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- DropID
            GOTO Quit
         END
         
         IF NOT EXISTS (SELECT 1 FROM dbo.PICKDETAIL (NOLOCK) WHERE DropID = @cDropID AND Status IN (@cPickConfirmStatus, '3')  ) 
         BEGIN
            SET @nErrNo = 213052
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidDropID
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- DropID
            GOTO Quit
         END
         
         IF EXISTS( SELECT 1 FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
                    WHERE Station = @cStation1 ) 
         BEGIN
               IF EXISTS ( SELECT 1 FROM rdt.rdtPTLStationLog st WITH (NOLOCK) 
                                    INNER JOIN dbo.PICKDETAIL pkd WITH (NOLOCK) 
                                       ON st.StorerKey = pkd.StorerKey
                                       AND st.OrderKey = pkd.OrderKey
                               WHERE st.Station =  @cStation1
                               AND pkd.DropId <> @cDropID ) 
               BEGIN
                  SET @nErrNo = 213053
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DiffDropID
                  EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey
                  GOTO Quit
               END
         END

         -- Check load no task
         IF NOT EXISTS( SELECT TOP 1 1 
            FROM LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
            JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            WHERE PD.DropID = @cDropID
               AND O.StorerKey = @cStorerKey
               AND O.Facility = @cFacility
               AND O.Status <> 'CANC' 
               AND O.SOStatus <> 'CANC' 
               AND PD.Status IN ('3', @cPickConfirmStatus)
               AND PD.CaseID = ''
               AND PD.QTY > 0)
         BEGIN
            SET @nErrNo = 213054
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPickTask
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- DropID
            SET @cOutField01 = ''
            GOTO Quit
         END

         SELECT @cWaveKey = wvd.WaveKey
         FROM dbo.WAVEDETAIL wvd WITH(NOLOCK)
         INNER JOIN dbo.PickDetail pkd WITH(NOLOCK)
            ON wvd.OrderKey = pkd.OrderKey
         WHERE pkd.DropID = @cDropID
         
         SET @curPTLAssign = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT OrderKey 
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE DropID = @cDropID
            AND CaseID = ''
         GROUP BY OrderKey 
         ORDER BY SUM(Qty) DESC
   
         OPEN @curPTLAssign
         FETCH NEXT FROM @curPTLAssign INTO @cOrderKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
         
            SELECT @cIPAddress = IPAddress,
                   @cPosition  = DevicePosition,
                   @cLoc       = Loc
            FROM dbo.DeviceProfile D
            WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND DevicePosition NOT IN ( SELECT st.Position 
                                          FROM rdt.rdtPTLStationLog st WITH (NOLOCK) 
                                          INNER JOIN dbo.PickDetail pkd WITH(NOLOCK)
                                             ON st.StorerKey = pkd.StorerKey
                                             AND st.OrderKey = pkd.OrderKey
                                        WHERE pkd.DropID = @cDropID )
            ORDER BY D.Loc
            
            -- Save assign
            INSERT INTO rdt.rdtPTLStationLog (Station, IPAddress, Position, CartonID, Method, WaveKey, OrderKey, StorerKey)
            VALUES (@cStation1, @cIPAddress, '', '', @cMethod, @cWaveKey, @cOrderKey, @cStorerKey)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 213055
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPTLLogFail
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- DropID
               SET @cOutField01 = ''
               GOTO Quit
            END

            FETCH NEXT FROM @curPTLAssign INTO @cOrderKey
         END
         
         SET @cOutField01 = @cDropID
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

         SELECT @nTotalLoad = COUNT(1) 
         FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
      
         SELECT @nTotalCarton = COUNT(1) 
         FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND CartonID <> ''

         -- Prepare current screen var
         SET @cOutField01 = @cDropID
         SET @cOutField02 = @cStation
         SET @cOutField03 = @cPosition
         SET @cOutField04 = @cCartonID
         SET @cOutField05 = CAST( @nTotalLoad AS NVARCHAR(5))
         SET @cOutField06 = CAST( @nTotalCarton AS NVARCHAR(5))

         -- Enable disable field
         SET @cFieldAttr01 = 'O' -- WaveKey
         SET @cFieldAttr04 = ''  -- CartonID

         -- Stay in current page
         SET @nErrNo = -1 
         GOTO Quit
      END

      -- Position Field enabled
      IF @cFieldAttr03 = '' 
      BEGIN
         IF @cLoc = '' 
         BEGIN
            SET @nErrNo = 213056
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PTLLocNeeded
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartonID
            SET @cOutField03 = ''
            GOTO Quit
         END
         
         IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK) 
                         WHERE StorerKey = @cStorerKey
                         AND DeviceID = @cStation 
                         AND Loc = @cLoc ) 
         BEGIN
            SET @nErrNo = 213057
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidPTLLoc
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartonID
            SET @cOutField03= ''
            GOTO Quit
         END
      END
      
      --SET @cOutField03 = @cLoc

      SELECT @cWaveKey = wvd.WaveKey
      FROM dbo.WAVEDETAIL wvd WITH(NOLOCK)
      INNER JOIN dbo.PickDetail pkd WITH(NOLOCK)
         ON wvd.OrderKey = pkd.OrderKey
      WHERE pkd.DropID = @cDropID

      -- CartonID field enabled
      IF @cFieldAttr04 = ''
      BEGIN
         -- Check blank tote
         IF @cCartonID = ''
         BEGIN
            SET @nErrNo = 213058
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedCartonID
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartonID
            SET @cOutfield03 = @cLoc 
            SET @cOutField05 = ''
            GOTO Quit
         END

         SET @cOutField04 = @cCartonID

         --Check Carton id
         --1. check if the carton id is an existing one, if it is, check if it belongs to current wave
         SELECT @cWaveKeyTemp = wvd.WaveKey
         FROM dbo.WAVEDETAIL wvd WITH(NOLOCK)
         INNER JOIN dbo.PickDetail pkd WITH(NOLOCK)
            ON wvd.OrderKey = pkd.OrderKey
         WHERE ISNULL(pkd.CaseID, '') = @cCartonID
            AND pkd.Status = @cPickConfirmStatus

         IF @cWaveKeyTemp IS NOT NULL AND TRIM(@cWaveKeyTemp) <> ''
         BEGIN
            IF @cWaveKeyTemp <> @cWaveKey
            BEGIN
               SET @nErrNo = 213063
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonDiffWave
               GOTO Quit
            END
         END

         SELECT TOP 1 @cOrderKey = OrderKey
         FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND Station = @cStation 
         AND CartonID = '' 
         ORDER BY RowRef

         SET @cLoc = ''
         SET @cPosition = ''

         SELECT TOP 1 @cLoc = dp.Loc,
             @cPosition = dp.DevicePosition
         FROM dbo.DeviceProfile dp WITH (NOLOCK)
         WHERE dp.StorerKey = @cStorerKey
            AND dp.DeviceID = @cStation
         AND dp.DeviceType = 'STATION'
            AND NOT EXISTS (SELECT 1
                           FROM rdt.rdtPTLStationLog ptl WITH (NOLOCK)
                           INNER JOIN dbo.PICKDETAIL pkd WITH (NOLOCK)
                              ON ptl.StorerKey = pkd.StorerKey
                              AND ptl.OrderKey = pkd.OrderKey
                           WHERE ptl.StorerKey = @cStorerKey
                              AND pkd.DropID = @cDropID
                       AND ptl.Station = dp.DeviceID
                              AND ptl.StorerKey = dp.StorerKey
                              AND ptl.Position = dp.DevicePosition)

         IF @cLoc IS NULL OR TRIM(@cLoc) = ''
         BEGIN
            SET @nErrNo = 213062
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLocAvaiable
            GOTO Quit
         END

         IF EXISTS ( SELECT 1 FROM rdt.rdtPTLStationLog st WITH(NOLOCK)
                     INNER JOIN dbo.PickDetail pkd WITH(NOLOCK)
                        ON st.OrderKey = pkd.OrderKey
                        AND st.StorerKey = pkd.StorerKey
                     WHERE pkd.DropID = @cDropID
                        AND st.StorerKey = @cStorerKey
                        AND st.CartonID = @cCartonID ) 
         BEGIN
            SET @nErrNo = 213060
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonAssigned
            GOTO Quit
         END
         
         -- Save assign
         UPDATE rdt.rdtPTLStationLog SET
             CartonID = @cCartonID
            ,Position = @cPosition
         WHERE Station = @cStation
            AND OrderKey = @cOrderKey 
         
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 213061
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDLogFail
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

      SET @cFieldAttr03 = 'O' -- Loc

      -- Prepare current screen var
      SET @cOutField01 = @cDropID
      SET @cOutField02 = @cStation
      SET @cOutField03 = @cPosition
      SET @cOutField04 = '' -- CartonID
      SET @cOutField05 = CAST( @nTotalLoad AS NVARCHAR(5))
      SET @cOutField06 = CAST( @nTotalCarton AS NVARCHAR(5))

      EXEC rdt.rdtSetFocusField @nMobile, 4 -- Location 
      
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