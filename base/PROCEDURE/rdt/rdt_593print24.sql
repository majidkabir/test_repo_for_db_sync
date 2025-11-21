SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_593Print24                                      */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: Farbory scan pallet id, generate pack & pack cfm            */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2018-10-18  1.0  James    WMS-7985 Created                           */
/* 2019-04-10  1.1  James    Remove gen pack by uom (james01)           */
/* 2019-08-27  1.2  Ung      WMS-10180 Support ID with multi orders     */
/*                           Clean up source                            */
/************************************************************************/

CREATE PROC [RDT].[rdt_593Print24] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR( 20),
   @cParam2    NVARCHAR( 20),
   @cParam3    NVARCHAR( 20),
   @cParam4    NVARCHAR( 20),
   @cParam5    NVARCHAR( 20),
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount        INT
   DECLARE @bSuccess          INT

   DECLARE @cID               NVARCHAR( 18)
   DECLARE @cPalletType       NVARCHAR( 30)

   DECLARE @cAllowMixPallet   NVARCHAR( 1)
   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cKeyName          NVARCHAR( 20)
   DECLARE @cCounter          NVARCHAR( 10)
   DECLARE @cNewPalletID      NVARCHAR( 18)

   DECLARE @cWeight           NVARCHAR( 10)
   DECLARE @cLength           NVARCHAR( 10)
   DECLARE @cWidth            NVARCHAR( 10)
   DECLARE @cHeight           NVARCHAR( 10)

   DECLARE @fWeight           FLOAT
   DECLARE @fHeight           FLOAT
   DECLARE @fLength           FLOAT
   DECLARE @fWidth            FLOAT

   -- Screen mapping
   SET @cID = @cParam1
   SET @cPalletType = @cParam2
   SET @cWeight = @cParam3
   SET @cHeight = @cParam4

   -- Check blank
   IF @cID = ''
   BEGIN
      SET @nErrNo = 134751
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan Pallet ID
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- ID
      GOTO Quit
   END

   -- Get pallet info
   DECLARE @cStatus NVARCHAR( 10)
   SELECT TOP 1
      @cStatus = Status
   FROM dbo.PickDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND ID = @cID
   ORDER BY 1 DESC   -- Max status. Return 0 or 3 not scanned. >= 5 scanned

   -- Check pallet valid
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 134752
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Pallet
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- ID
      GOTO Quit
   END

   -- Check pallet status
   IF @cStatus >= '5'
   BEGIN
      SET @nErrNo = 134753
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet Scanned
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- ID
      GOTO Quit
   END

   -- Decide mix pallet
   IF EXISTS( SELECT 1
      FROM dbo.PickDetail PD (NOLOCK)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      WHERE PD.StorerKey = @cStorerKey
         AND PD.ID = @cID
         AND SKU.BUSR1 = 'N')
      SET @cAllowMixPallet = '0'
   ELSE
      SET @cAllowMixPallet = '1'

   IF @cAllowMixPallet = '0'
   BEGIN
      -- Check mix SKU in pallet
      IF EXISTS( SELECT 1
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND ID = @cID
            AND Status <> '4'
            AND QTY > 0
         GROUP BY ID
         HAVING COUNT( DISTINCT SKU) > 1)
      BEGIN
         SET @nErrNo = 134754
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pls Split ID
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- ID
         GOTO Quit
      END
   END
   ELSE
   BEGIN
      -- Check no UCC on ID
      IF EXISTS( SELECT TOP 1 1 
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND ID = @cID
            AND Status <> '4'
            AND QTY > 0
            AND DropID = '')
      BEGIN
         SET @nErrNo = 134755
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No UCC on ID
         GOTO RollBackTran
      END
   END

   -- Check blank
   IF @cPalletType = ''
   BEGIN
      SET @nErrNo = 134756
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedPalletType
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- Pallet Type
      GOTO Quit
   END

   -- Check pallet type
   IF NOT EXISTS( SELECT 1 
      FROM dbo.CodelkUp WITH (NOLOCK)
      WHERE ListName = 'PALLETTYPE'
         AND Code = @cPalletType
         AND Storerkey = @cStorerKey)
   BEGIN
      SET @nErrNo = 134757
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PltTyp
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- Pallet Type
      GOTO Quit
   END

   IF @cAllowMixPallet = '0'
   BEGIN
      -- Check weight valid
      IF RDT.rdtIsValidQTY( @cWeight, 21) = 0
      BEGIN
         SET @nErrNo = 134758
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Weight
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- Weight
         GOTO Quit
      END

      -- Check height valid
      IF RDT.rdtIsValidQTY( @cHeight, 21) = 0
      BEGIN
         SET @nErrNo = 134759
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Height
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- Height
         GOTO Quit
      END
   END

   SET @cKeyName = RTRIM( @cStorerKey) + '_ID'

   -- Generate new ID
   EXECUTE nspg_getkey
		@KeyName       = @cKeyName,
		@fieldlength   = 9,
		@keystring     = @cCounter  OUTPUT,
		@b_Success     = @bSuccess   OUTPUT,
		@n_err         = @nErrNo     OUTPUT,
		@c_errmsg      = @cErrMsg    OUTPUT,
      @b_resultset   = 0,
      @n_batch       = 1
   IF @bSuccess <> 1 OR ISNULL( @cCounter, '') = ''
   BEGIN
      SET @nErrNo = 134760
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Getkey fail
      GOTO Quit
   END
   
   -- Add pallet prefix 
   SELECT @cNewPalletID = '3' + @cCounter


   /***********************************************************************************************
                                            Pick and pack cartons 
   ***********************************************************************************************/
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_593Print24

   -- Create pallet
   IF NOT EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK) WHERE PalletKey = @cNewPalletID)
   BEGIN
      IF @cAllowMixPallet = '0'
      BEGIN
         -- Get pallet info
         SELECT 
            @cLength = ISNULL( UDF01, 0),
            @cWidth = ISNULL( UDF02, 0)
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE LISTNAME = 'FabN-M L&W'
            AND Code = @cPalletType
            AND Storerkey = @cStorerKey

         SET @fLength = ISNULL( RDT.rdtFormatFloat( @cLength), 0)
         SET @fWidth = ISNULL( RDT.rdtFormatFloat( @cWidth), 0)

         SET @fWeight = ISNULL( RDT.rdtFormatFloat( @cWeight), 0)
         SET @fHeight = ISNULL( RDT.rdtFormatFloat( @cHeight), 0)
      END
      ELSE
      BEGIN
         DECLARE @nUCCCount         INT = 0
         DECLARE @fContentWeight    FLOAT = 0
         DECLARE @fEmptyBoxWgt      FLOAT = 0
         DECLARE @fWoodenCrateWgt   FLOAT = 0

         -- Calculate pallet info
         SELECT 
            @nUCCCount = COUNT( DISTINCT DropID), 
            @fContentWeight = ISNULL( SUM( SKU.STDGrossWGT * PD.QTY), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         WHERE PD.StorerKey = @cStorerKey
            AND PD.ID = @cID
            AND PD.Status <= '3'
            AND PD.QTY > 0

         -- Get pallet info
         SELECT @fEmptyBoxWgt = UDF03,
                @fWoodenCrateWgt = UDF04,
                @fLength = Short,
                @fWidth = Long, 
                @fHeight = Notes
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = 'FABWeight'
            AND @nUCCCount BETWEEN UDF01 AND UDF02

         SET @fWeight = @fContentWeight + (@fEmptyBoxWgt * @nUCCCount) + @fWoodenCrateWgt
      END

      INSERT INTO dbo.Pallet (PalletKey, StorerKey, Status, GrossWgt, PalletType, Length, Width, Height)
      VALUES (@cNewPalletID, @cStorerKey, '0', @fWeight, @cPalletType, @fLength, @fWidth, @fHeight)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 134761
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PLT Fail
         GOTO RollBackTran
      END
   END

   -- Loop orders on PickDetail
   DECLARE @curOrder CURSOR 
   SET @curOrder = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT DISTINCT OrderKey
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ID = @cID
         AND Status <= '3'
         AND QTY > 0
   OPEN @curOrder
   FETCH NEXT FROM @curOrder INTO @cOrderKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      /*
         Update PickDetail, PackDetail, UCC. 
         Create PickHeader, PackHeader, PickingInfo. 
         Auto scan-in, pack confirm
      */
      EXEC rdt.rdt_593Print24_Confirm
          @nMobile         = @nMobile    
         ,@nFunc           = @nFunc      
         ,@nStep           = @nStep      
         ,@cLangCode       = @cLangCode  
         ,@cStorerKey      = @cStorerKey 
         ,@cID             = @cID        
         ,@cOrderKey       = @cOrderKey   
         ,@cAllowMixPallet = @cAllowMixPallet 
         ,@cNewPalletID    = @cNewPalletID 
         ,@nErrNo          = @nErrNo   OUTPUT
         ,@cErrMsg         = @cErrMsg  OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran
      
      FETCH NEXT FROM @curOrder INTO @cOrderKey
   END

   COMMIT TRAN rdt_593Print24
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

   /***********************************************************************************************
                                           Print pallet label
   ***********************************************************************************************/
   DECLARE @cPalletLabel NVARCHAR( 10)
   SET @cPalletLabel = rdt.RDTGetConfig( @nFunc, 'PalletLabel', @cStorerkey)
   IF @cPalletLabel = '0'
      SET @cPalletLabel = ''

   IF @cPalletLabel <> ''
   BEGIN
      DECLARE @cLabelPrinter NVARCHAR( 10)
      DECLARE @cPaperPrinter NVARCHAR( 10)
      DECLARE @cFacility     NVARCHAR( 5)
      DECLARE @cPickSlipNo   NVARCHAR( 10)

      -- Get session info
      SELECT
         @cFacility = Facility,
         @cLabelPrinter = Printer,
         @cPaperPrinter = Printer_Paper
      FROM rdt.rdtMobrec WITH (NOLOCK)
      WHERE Mobile = @nMobile

      -- Get random OrderKey
      SELECT @cPickSlipNo = PickheaderKey FROM dbo.PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey      

      -- Common params
      DECLARE @tPalletLabel AS VariableTable
      INSERT INTO @tPalletLabel (Variable, Value) VALUES
         ( '@cPickSlipNo', @cPickSlipNo),
         ( '@cID',         @cID)

      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
         @cPalletLabel, -- Report type
         @tPalletLabel, -- Report params
         'rdt_593Print24',
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT

	   IF @nErrNo <> 0
         GOTO Quit
   END

   /***********************************************************************************************
                                             Message screen
   ***********************************************************************************************/
   DECLARE @cErrMsg1 NVARCHAR( 20)
   DECLARE @cErrMsg2 NVARCHAR( 20)
   DECLARE @cErrMsg3 NVARCHAR( 20)
   DECLARE @cErrMsg4 NVARCHAR( 20)
   DECLARE @cErrMsg5 NVARCHAR( 20)
   DECLARE @cErrMsg6 NVARCHAR( 20)
   DECLARE @cErrMsg7 NVARCHAR( 20)

   SET @cErrMsg1 = rdt.rdtgetmessage( 134761, @cLangCode, 'DSP') --Pallet ID:
   SET @cErrMsg2 = @cID
   SET @cErrMsg3 = ''
   SET @cErrMsg4 = rdt.rdtgetmessage( 134762, @cLangCode, 'DSP') --Pallet Weight:
   SET @cErrMsg5 = ISNULL( @fWeight, 0) --Weight:
   SET @cErrMsg6 = ''
   IF @cPalletLabel <> ''
      SET @cErrMsg7 = rdt.rdtgetmessage( 134763, @cLangCode, 'DSP') --Label Printed
   ELSE
      SET @cErrMsg7 = ''

   EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
      @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5, @cErrMsg6, @cErrMsg7

   SET @nErrNo = 0
   SET @cErrMsg = ''

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_593Print24
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END



GO