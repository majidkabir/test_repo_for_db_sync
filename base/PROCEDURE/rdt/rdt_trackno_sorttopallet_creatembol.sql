SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_TrackNo_SortToPallet_CreateMbol                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Called from: rdtfnc_TrackNo_SortToLane                               */
/*                                                                      */
/* Purpose: Create Pallet and MBOL record                               */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2022-09-15  1.0  James    WMS-20667. Created                         */
/* 2023-01-09  1.1  SYCHUA   JSM-115662 Fix to reset MBOLKEY value when */
/*                           error if MBOLKEY is generated (SY01)       */
/************************************************************************/

CREATE PROC [RDT].[rdt_TrackNo_SortToPallet_CreateMbol] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cTrackNo       NVARCHAR( 40),
   @cOrderKey      NVARCHAR( 20),
   @cPalletKey     NVARCHAR( 20),
   @cMBOLKey       NVARCHAR( 10) OUTPUT,
   @cLane          NVARCHAR( 20),
   @cLabelNo       NVARCHAR( 20),
   @tCreateMBOLVar VariableTable READONLY,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cCreateMbolSP  NVARCHAR( 20)

   -- Get storer config
   SET @cCreateMbolSP = rdt.RDTGetConfig( @nFunc, 'SortToPallet_CreateMbolSP', @cStorerKey)
   IF @cCreateMbolSP = '0'
      SET @cCreateMbolSP = ''

   /***********************************************************************************************
                                              Custom get mbolkey
   ***********************************************************************************************/
   -- Check confirm SP blank
   IF @cCreateMbolSP <> ''
   BEGIN
      -- Confirm SP
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cCreateMbolSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
         ' @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey OUTPUT, @cLane, ' +
         ' @cLabelNo, @tCreateMBOLVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '
      SET @cSQLParam =
         ' @nMobile        INT,           ' +
         ' @nFunc          INT,           ' +
         ' @cLangCode      NVARCHAR( 3),  ' +
         ' @nStep          INT,           ' +
         ' @nInputKey      INT,           ' +
         ' @cFacility      NVARCHAR( 5) , ' +
         ' @cStorerKey     NVARCHAR( 15), ' +
         ' @cTrackNo       NVARCHAR( 40), ' +
         ' @cOrderKey      NVARCHAR( 10), ' +
         ' @cPalletKey     NVARCHAR( 20), ' +
         ' @cMBOLKey       NVARCHAR( 10) OUTPUT, ' +
         ' @cLane          NVARCHAR( 20), ' +
         ' @cLabelNo       NVARCHAR( 20), ' +
         ' @tCreateMBOLVar VariableTable READONLY, ' +
         ' @nErrNo         INT           OUTPUT, ' +
         ' @cErrMsg        NVARCHAR(250) OUTPUT  '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
         @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey OUTPUT, @cLane,
         @cLabelNo, @tCreateMBOLVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

      GOTO Quit
   END

   /***********************************************************************************************
                                      Standard create mbol
   ***********************************************************************************************/
   DECLARE @nTranCount     INT
   DECLARE @bSuccess       INT
   DECLARE @nCtnCnt1       INT
   DECLARE @cPalletLineNumber          NVARCHAR( 5)
   DECLARE @cSortToPalletNotCreateMBOL NVARCHAR( 1)
   DECLARE @cExternOrderKey            NVARCHAR( 50)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @dOrderDate     DATETIME
   DECLARE @dDeliveryDate  DATETIME
   DECLARE @curDel         CURSOR
   DECLARE @resetMBOLFlag  INT   --SY01

   SET @resetMBOLFlag = 0        --SY01
   SET @cSortToPalletNotCreateMBOL = rdt.RDTGetConfig( @nFunc, 'SortToPalletNotCreateMBOL', @cStorerKey)

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_CreateMbol -- For rollback or commit only our own transaction

   -- Pallet
   IF NOT EXISTS( SELECT 1 FROM Pallet WITH (NOLOCK) WHERE PalletKey = @cPalletKey AND Status = '0')
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.PALLET WITH (NOLOCK) WHERE PalletKey = @cPalletKey AND Status = '9')
      BEGIN
         SET @curDel = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT PalletLineNumber
         FROM dbo.PalletDetail WITH (NOLOCK)
         WHERE PalletKey = @cPalletKey
         OPEN @curDel
         FETCH NEXT FROM @curDel INTO @cPalletLineNumber
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE PALLETDETAIL SET ArchiveCop = '9'
            WHERE PalletKey = @cPalletKey
            AND PalletLineNumber = @cPalletLineNumber

            DELETE FROM PALLETDETAIL
            WHERE PalletKey = @cPalletKey
            AND PalletLineNumber = @cPalletLineNumber

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 191301
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Del PltDtl Err
               GOTO RollBackTran_CreateMbol
            END

            FETCH NEXT FROM @curDel INTO @cPalletLineNumber
         END

         UPDATE PALLET SET ArchiveCop = '9' WHERE PalletKey = @cPalletKey

         DELETE FROM PALLET WHERE PalletKey = @cPalletKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 191302
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Del PltHdr Err
            GOTO RollBackTran_CreateMbol
         END

      END

      INSERT INTO dbo.Pallet (PalletKey, StorerKey, Status)
      VALUES (@cPalletKey, @cStorerKey, '0')
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 191303
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PalletFail
         GOTO RollBackTran_CreateMbol
      END
   END

   -- PalletDetail
   IF NOT EXISTS( SELECT 1 FROM PalletDetail WITH (NOLOCK) WHERE PalletKey = @cPalletKey AND CaseID = @cLabelNo)
   BEGIN
      SELECT TOP 1 @cSKU = SKU
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   LabelNo = @cTrackNo
      ORDER BY 1

      IF ISNULL( @cSKU, '') = ''
         SELECT TOP 1 @cSKU = SKU
         FROM dbo.PackDetail PD WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   EXISTS ( SELECT 1 FROM dbo.CartonTrack CT WITH (NOLOCK)
                        WHERE PD.LabelNo = CT.LabelNo
                        AND   CT.TrackingNo = @cTrackNo)
         ORDER BY 1

      IF ISNULL( @cSKU, '') = ''
         SET @cSKU = ''

      INSERT INTO dbo.PalletDetail
         (PalletKey, PalletLineNumber, CaseID, StorerKey, SKU, LOC, QTY, Status, UserDefine01, UserDefine02)
      VALUES
         (@cPalletKey, '0', @cLabelNo, @cStorerKey, @cSKU, 'HM-QI', 0, '0', @cOrderKey, @cTrackNo)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 191304
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PLDtl Fail
         GOTO RollBackTran_CreateMbol
      END
   END

   IF @cMBOLKey = ''
      -- 1 Mbol 1 Pallet
      SELECT @cMBOLKey = MbolKey
      FROM dbo.MBOL WITH (NOLOCK)
  WHERE ExternMbolKey = @cPalletKey
      AND   [Status] = '0'

   IF @cSortToPalletNotCreateMBOL = '0'
   BEGIN
      -- Insert MBOL
      IF NOT EXISTS( SELECT 1 FROM dbo.MBOL WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND [Status] = '0')
      BEGIN
         SELECT @bSuccess = 0
         SET @resetMBOLFlag = 1   --SY01
         EXECUTE nspg_GetKey
                  'MBOL',
                  10,
                  @cMBOLKey OUTPUT,
                  @bSuccess OUTPUT,
                  @nErrNo   OUTPUT,
                  @cErrMsg  OUTPUT

         IF @bSuccess <> 1
         BEGIN
            SET @nErrNo = 191305
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
            IF @resetMBOLFlag = 1     --SY01
               SET @cMBOLKey = ''     --SY01
            GOTO RollBackTran_CreateMbol
         END

         INSERT INTO dbo.MBOL (MBOLKey, ExternMBOLKey, Facility, Status) VALUES (@cMBOLKey, @cPalletKey, @cFacility, '0')
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 191306
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS MBOL Fail
            IF @resetMBOLFlag = 1     --SY01
               SET @cMBOLKey = ''     --SY01
            GOTO RollBackTran_CreateMbol
         END
      END

      -- Insert MBOLDetail
      IF NOT EXISTS( SELECT 1 FROM dbo.MBOLDetail WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND OrderKey = @cOrderKey)
      BEGIN
         -- Check MBOL shipped (temporary workaround, instead of changing ntrMBOLDetailAdd trigger)
         IF EXISTS( SELECT 1 FROM dbo.MBOL WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND Status = '9')
         BEGIN
            SET @nErrNo = 191307
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL Shipped
            IF @resetMBOLFlag = 1     --SY01
               SET @cMBOLKey = ''     --SY01
            GOTO RollBackTran_CreateMbol
         END

         SELECT @cLoadKey = LoadKey,
                  @dOrderDate = OrderDate,
                  @cExternOrderKey = ExternOrderKey,
                  @dDeliveryDate = DeliveryDate
         FROM dbo.ORDERS WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         SELECT @nCtnCnt1 = CtnCnt1
         FROM dbo.PackHeader WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         INSERT INTO dbo.MBOLDetail
            (MBOLKey, MBOLLineNumber, OrderKey, LoadKey, AddWho, AddDate, EditWho, EditDate, Weight, Cube,
               OrderDate, ExternOrderKey, DeliveryDate, CtnCnt1, CtnCnt2, CtnCnt3, CtnCnt4, CtnCnt5,
               UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, UserDefine09, UserDefine10)
         VALUES
            (@cMBOLKey, '00000', @cOrderKey, @cLoadKey, 'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE(), 0, 0,
               @dOrderDate, @cExternOrderKey, @dDeliveryDate, @nCtnCnt1, 0, 0, 0, 0,
               '', '', '', '', '', '', '')
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 191308
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS MBDtl Fail
            IF @resetMBOLFlag = 1     --SY01
               SET @cMBOLKey = ''     --SY01
            GOTO RollBackTran_CreateMbol
         END
      END
   END

   COMMIT TRAN rdt_CreateMbol

   GOTO Quit_CreateMbol

   RollBackTran_CreateMbol:
      ROLLBACK TRAN -- Only rollback change made here
   Quit_CreateMbol:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

   Quit:
END

GO