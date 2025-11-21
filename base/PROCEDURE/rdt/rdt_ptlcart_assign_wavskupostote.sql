SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLCart_Assign_WavSKUPosTote                          */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 06-05-2015 1.0  Ung      SOS336312 Created                                 */
/* 26-01-2018 1.1  Ung      Change to PTL.Schema                              */
/* 28-02-2022 1.2  Ung      WMS-19007 Add tote ID format                      */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_PTLCart_Assign_WavSKUPosTote] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cCartID          NVARCHAR( 10),
   @cPickZone        NVARCHAR( 10),
   @cMethod          NVARCHAR( 1),
   @cPickSeq         NVARCHAR( 1),
   @cDPLKey          NVARCHAR( 10),
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

   DECLARE @bSuccess    INT
   DECLARE @nTranCount  INT
   DECLARE @nRowCount   INT
   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)

   DECLARE @cWaveKey    NVARCHAR(10)
   DECLARE @cSKU        NVARCHAR(30)
   DECLARE @cPosition   NVARCHAR(10)
   DECLARE @cToteID     NVARCHAR(20)
   DECLARE @nTotalTote  INT

   SET @nTranCount = @@TRANCOUNT

   /***********************************************************************************************
                                                POPULATE
   ***********************************************************************************************/
   IF @cType = 'POPULATE-IN'
   BEGIN
      -- Get work info
      SET @cWaveKey = ''
      SELECT TOP 1 @cWaveKey = WaveKey FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID
      SELECT @nTotalTote = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID

		-- Prepare next screen var
		SET @cOutField01 = @cCartID
		SET @cOutField02 = @cPickZone
		SET @cOutField03 = @cWaveKey
		SET @cOutField04 = '' -- SKU
		SET @cOutField05 = '' -- Position
		SET @cOutField06 = '' -- ToteID
		SET @cOutField07 = CAST( @nTotalTote AS NVARCHAR(5)) --TotalTote

      IF @cWaveKey = ''
      BEGIN
         -- Enable disable field
         SET @cFieldAttr03 = ''  -- WaveKey
         SET @cFieldAttr04 = 'O' -- SKU
         SET @cFieldAttr05 = 'O' -- Position
         SET @cFieldAttr06 = 'O' -- ToteID

   	   EXEC rdt.rdtSetFocusField @nMobile, 3 -- WaveKey
      END
      ELSE
      BEGIN
         -- Disable field
         SET @cFieldAttr03 = 'O' -- WaveKey
         SET @cFieldAttr04 = ''  -- SKU
         SET @cFieldAttr05 = ''  -- Position
         SET @cFieldAttr06 = ''  -- ToteID

   	   EXEC rdt.rdtSetFocusField @nMobile, 4 -- SKU
      END

		-- Go to Wave SKU Pos Tote screen
		SET @nScn = 4184
   END

   IF @cType = 'POPULATE-OUT'
   BEGIN
      -- Enable field
      SET @cFieldAttr03 = '' -- WaveKey
      SET @cFieldAttr04 = '' -- OrderKey
      SET @cFieldAttr05 = '' -- Position
      SET @cFieldAttr06 = '' -- ToteID

		-- Go to cart screen
   END


   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Screen mapping
      SET @cWaveKey  = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END
      SET @cSKU      = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END
      SET @cPosition = CASE WHEN @cFieldAttr05 = '' THEN @cInField05 ELSE @cOutField05 END
      SET @cToteID   = CASE WHEN @cFieldAttr06 = '' THEN @cInField06 ELSE @cOutField06 END

      -- Get TotalTote
      SELECT @nTotalTote = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID

      -- Check finish assign
      IF @nTotalTote > 0 AND @cWaveKey <> '' AND @cSKU = '' AND @cPosition = '' AND @cToteID = ''
      BEGIN
         -- Enable field
         SET @cFieldAttr03 = '' -- WaveKey
         SET @cFieldAttr04 = '' -- SKU
         SET @cFieldAttr05 = '' -- Position
         SET @cFieldAttr06 = '' -- ToteID

         GOTO Quit
      END

      -- WaveKey field enabled
      IF @cFieldAttr03 = ''
      BEGIN
   		-- Check blank
   		IF @cWaveKey = ''
         BEGIN
            SET @nErrNo = 54251
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need WaveKey
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- WaveKey
            GOTO Quit
         END

         -- Check wave valid
         IF NOT EXISTS( SELECT 1 FROM WaveDetail WITH (NOLOCK) WHERE WaveKey = @cWaveKey)
         BEGIN
            SET @nErrNo = 54252
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad WaveKey
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- WaveKey
            SET @cOutField03 = ''
            GOTO Quit
         END

         -- Prepare current screen var
         SET @cOutField03 = @cWaveKey
         SET @cOutField04 = ''  -- SKU
         SET @cOutField05 = ''  -- Position
         SET @cOutField06 = ''  -- ToteID
         SET @cOutField07 = '0' -- TotalTote

         -- Enable / Disable field
         SET @cFieldAttr03 = 'O' -- WaveKey
         SET @cFieldAttr04 = ''  -- SKU
         SET @cFieldAttr05 = ''  -- Position
         SET @cFieldAttr06 = ''  -- ToteID

         -- Remain in current screen
         SET @nErrNo = -1
         GOTO Quit
      END

      -- Check blank
		IF @cSKU = ''
      BEGIN
         SET @nErrNo = 54253
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SKU
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- SKU
         GOTO Quit
      END

      -- Label decoding
      DECLARE @cDecodeLabelNo NVARCHAR(20)
      SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)
      IF @cDecodeLabelNo = '0'
         SET @cDecodeLabelNo = ''

      IF @cDecodeLabelNo <> ''
      BEGIN
         DECLARE
            @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
            @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
            @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
            @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
            @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20)

         SET @c_oFieled01 = @cSKU

         EXEC dbo.ispLabelNo_Decoding_Wrapper
             @c_SPName     = @cDecodeLabelNo
            ,@c_LabelNo    = @cSKU
            ,@c_Storerkey  = @cStorerKey
            ,@c_ReceiptKey = ''
            ,@c_POKey      = ''
            ,@c_LangCode   = @cLangCode
            ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU
            ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE
            ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR
            ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE
            ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY
            ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- CO#
            ,@c_oFieled07  = @c_oFieled07 OUTPUT   -- Lottable01
            ,@c_oFieled08  = @c_oFieled08 OUTPUT   -- Lottable02
            ,@c_oFieled09  = @c_oFieled09 OUTPUT   -- Lottable03
            ,@c_oFieled10  = @c_oFieled10 OUTPUT   -- Lottable04
            ,@b_Success    = @bSuccess    OUTPUT
            ,@n_ErrNo      = @nErrNo      OUTPUT
            ,@c_ErrMsg     = @cErrMsg     OUTPUT

         IF @nErrNo <> 0
            GOTO Quit

         SET @cSKU = @c_oFieled01
      END

      -- Get SKU/UPC
      DECLARE @nSKUCnt INT
      DECLARE @cSKUCode NVARCHAR(20)
      SET @nSKUCnt = 0

      EXEC RDT.rdt_GetSKUCNT
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU
         ,@nSKUCnt     = @nSKUCnt   OUTPUT
         ,@bSuccess    = @bSuccess  OUTPUT
         ,@nErr        = @nErrNo    OUTPUT
         ,@cErrMsg     = @cErrMsg   OUTPUT

      -- Check SKU valid
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 54254
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- SKU
         SET @cOutField04 = ''
         GOTO Quit
      END

      IF @nSKUCnt = 1
         EXEC rdt.rdt_GetSKU
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cSKU      OUTPUT
            ,@bSuccess    = @bSuccess  OUTPUT
            ,@nErr        = @nErrNo    OUTPUT
            ,@cErrMsg     = @cErrMsg   OUTPUT

      -- Check barcode return multi SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 54255
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- SKU
         SET @cOutField04 = ''
         GOTO Quit
      END

      -- Check SKU assigned
      IF @cPickZone = ''
         SELECT @nErrNo = 1
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)
         WHERE WaveKey = @cWaveKey
            AND SKU = @cSKU
      ELSE
         SELECT @nErrNo = 1
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)
         WHERE WaveKey = @cWaveKey
            AND SKU = @cSKU
            AND (PickZone = @cPickZone OR PickZone = '')
      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 54256
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU assigned
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- SKU
         SET @cOutField04 = ''
         GOTO Quit
      END

      -- Check SKU in wave
      SET @nErrNo = 1
      IF @cPickZone = ''
         SELECT TOP 1 @nErrNo = 0
         FROM Orders O WITH (NOLOCK)
            JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
            JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         WHERE O.UserDefine09 = @cWaveKey
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.Status < '4'
            AND PD.QTY > 0
            AND O.Status <> 'CANC'
            AND O.SOStatus <> 'CANC'
      ELSE
         SELECT TOP 1 @nErrNo = 0
         FROM Orders O WITH (NOLOCK)
            JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
            JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         WHERE O.UserDefine09 = @cWaveKey
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.Status < '4'
            AND PD.QTY > 0
            AND O.Status <> 'CANC'
            AND O.SOStatus <> 'CANC'
            AND LOC.PickZone = @cPickZone
      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 54257
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NotInWave
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- SKU
         SET @cOutField04 = ''
         GOTO Quit
      END
      SET @cOutField04 = @cSKU

      -- Check position blank
      IF @cPosition = ''
      BEGIN
         SET @nErrNo = 54258
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Position
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- Position
         SET @cOutField05 = ''
         GOTO Quit
      END

      -- Check position valid
      IF NOT EXISTS( SELECT 1
         FROM dbo.DeviceProfile WITH (NOLOCK)
         WHERE DeviceType = 'CART'
            AND DeviceID = @cCartID
            AND DevicePosition = @cPosition)
      BEGIN
         SET @nErrNo = 54259
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Position
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- Position
         SET @cOutField05 = ''
         GOTO Quit
      END

      -- Check position assigned
      IF EXISTS( SELECT 1
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)
         WHERE CartID = @cCartID
            AND Position = @cPosition)
      BEGIN
         SET @nErrNo = 54260
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pos assigned
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- Position
         SET @cOutField05 = ''
         GOTO Quit
      END
      SET @cOutField05 = @cPosition

      -- Check blank tote
      IF @cToteID = ''
      BEGIN
         SET @nErrNo = 54261
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ToteID
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- ToteID
         SET @cOutField06 = ''
         GOTO Quit
      END

      -- Check format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ToteID', @cToteID) = 0
      BEGIN
         SET @nErrNo = 54265
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- ToteID
         SET @cOutField06 = ''
         GOTO Quit
      END

      -- Check tote assigned
      IF EXISTS( SELECT 1
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)
         WHERE CartID = @cCartID
            AND ToteID = @cToteID)
      BEGIN
         SET @nErrNo = 54262
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Assigned
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- ToteID
         SET @cOutField06 = ''
         GOTO Quit
      END
      SET @cOutField06 = @cToteID

      DECLARE @cIPAddress NVARCHAR(40)
      DECLARE @cLOC NVARCHAR(10)
      DECLARE @nQTY INT

      -- Get position info
      SELECT @cIPAddress = IPAddress
      FROM DeviceProfile WITH (NOLOCK)
      WHERE DeviceType = 'CART'
         AND DeviceID = @cCartID
         AND DevicePosition = @cPosition

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN rdt_PTLCart_Assign_WavSKUPosTote

      -- Save assign
      INSERT INTO rdt.rdtPTLCartLog (CartID, Position, ToteID, DeviceProfileLogKey, Method, PickZone, PickSeq, WaveKey, StorerKey, SKU)
      VALUES (@cCartID, @cPosition, @cToteID, @cDPLKey, @cMethod, @cPickZone, @cPickSeq, @cWaveKey, @cStorerKey, @cSKU)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 54263
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
         GOTO RollBackTran
      END

      -- Insert PTLTran
      DECLARE @curPD CURSOR
      IF @cPickZone = ''
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PD.LOC, PD.SKU, SUM( PD.QTY)
            FROM Orders O WITH (NOLOCK)
               JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
            WHERE O.UserDefine09 = @cWaveKey
               AND PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSKU
               AND PD.Status < '4'
               AND PD.QTY > 0
               AND O.Status <> 'CANC'
               AND O.SOStatus <> 'CANC'
            GROUP BY PD.LOC, PD.SKU
      ELSE
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT LOC.LOC, PD.SKU, SUM( PD.QTY)
            FROM Orders O WITH (NOLOCK)
               JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
               JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            WHERE O.UserDefine09 = @cWaveKey
               AND PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSKU
               AND PD.Status < '4'
               AND PD.QTY > 0
               AND O.Status <> 'CANC'
               AND O.SOStatus <> 'CANC'
               AND LOC.PickZone = @cPickZone
            GROUP BY LOC.LOC, PD.SKU

      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         INSERT INTO PTL.PTLTran (
            IPAddress, DeviceID, DevicePosition, Status, PTLType,
            DeviceProfileLogKey, DropID, SourceKey, Storerkey, SKU, LOC, ExpectedQTY, QTY)
         VALUES (
            @cIPAddress, @cCartID, @cPosition, '0', 'CART',
            @cDPLKey, '', @cWaveKey, @cStorerKey, @cSKU, @cLOC, @nQTY, 0)

         IF @@ERROR <> ''
         BEGIN
            SET @nErrNo = 54264
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --INS PTL Fail
            GOTO RollBackTran
         END
         FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY
      END

      SET @nTotalTote = @nTotalTote + 1

      -- Prepare current screen var
      SET @cOutField04 = '' -- SKU
      SET @cOutField05 = '' -- Position
      SET @cOutField06 = '' -- ToteID
      SET @cOutField07 = CAST( @nTotalTote AS NVARCHAR(5))

      EXEC rdt.rdtSetFocusField @nMobile, 4 -- SKU

      -- Stay in current page
      SET @nErrNo = -1

      COMMIT TRAN rdt_PTLCart_Assign_WavSKUPosTote
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLCart_Assign_WavSKUPosTote

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO