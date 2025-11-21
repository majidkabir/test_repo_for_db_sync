SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************************************/
/* Store procedure: rdt_Outbound_PalletTempCapture_Confirm                                           */
/* Copyright      : Maersk                                                                      */
/*                                                                                              */
/* Date        Rev   Author         Purposes                                                    */
/* 2024-12-05  1.0.0 PXL009         FCR-1398 Temp Capture                                       */
/************************************************************************************************/

CREATE   PROC [RDT].[rdt_Outbound_PalletTempCapture_Confirm] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT, 
   @nInputKey     INT,
   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @cMBOLKey      NVARCHAR( 10),
   @cPalletID     NVARCHAR( 20),
   @cSKU          NVARCHAR( 20),
   @cItemClass    NVARCHAR( 10),
   @nTemperature  DECIMAL(5 ,2),
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL       NVARCHAR( MAX)
   DECLARE @cSQLParam  NVARCHAR( MAX)
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT

   -- Get RDT storer configure
   DECLARE @cConfirmSP NVARCHAR(20)
   SET @cConfirmSP = [RDT].[rdtGetConfig]( @nFunc, 'ConfirmSP', @cStorerKey)
   IF @cConfirmSP = '0'
      SET @cConfirmSP = ''
   
   /***********************************************************************************************
                                              Custom confirm
   ***********************************************************************************************/
   IF @cConfirmSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cConfirmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,' + 
            ' @cMBOLKey, @cPalletID, @cSKU, @cItemClass, @nTemperature,' + 
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile       INT,                 '+
            '@nFunc         INT,                 '+
            '@cLangCode     NVARCHAR( 3),        '+
            '@nStep         INT,                 '+
            '@nInputKey     INT,                 '+
            '@cStorerKey    NVARCHAR( 15),       '+
            '@cFacility     NVARCHAR( 5),        '+
            '@cMBOLKey      NVARCHAR( 10),       '+
            '@cPalletID     NVARCHAR( 20),       '+
            '@cSKU          NVARCHAR( 20),       '+
            '@cItemClass    NVARCHAR( 10),       '+
            '@nTemperature  DECIMAL(5 ,2),       '+
            '@nErrNo        INT           OUTPUT,'+
            '@cErrMsg       NVARCHAR( 20) OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,
            @cMBOLKey, @cPalletID, @cSKU, @cItemClass, @nTemperature,
            @nErrNo OUTPUT, @cErrMsg OUTPUT

         GOTO Quit
      END
   END

   /***********************************************************************************************
                                             Standard confirm
   ***********************************************************************************************/

   BEGIN TRAN
   SAVE TRAN rdt_Out_PltTempCap_Cfm

   DECLARE @cNewTemperatureLogID NVARCHAR( 10)
   DECLARE @bSuccess       INT

   EXECUTE dbo.nspg_GetKey
      'TemperatureLogID',
      10 ,
      @cNewTemperatureLogID   OUTPUT,
      @bSuccess               OUTPUT,
      @nErrNo                 OUTPUT,
      @cErrMsg                OUTPUT

   IF @bSuccess <> 1
   BEGIN
      SET @nErrNo = 230251
      SET @cErrMsg = [RDT].[rdtGetMessage]( @nErrNo, @cLangCode, N'DSP')  --230251 - Get TemperatureLogID Fail
     GOTO RollBackTran
   END

   INSERT INTO [dbo].[TemperatureLog]([TemperatureLogID],[StorerKey],[Facility],[MbolKey],[ReceiptKey],[PalletId],[Temperature],[TempCheckPoint],[CheckDate],[CheckUser],[EditDate],[EditWho])
   VALUES(@cNewTemperatureLogID, @cStorerKey, @cFacility, @cMBOLKey, NULL, @cPalletID, @nTemperature, N'L', GETDATE(), SUSER_NAME(), GETDATE(), SUSER_NAME())
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 230252
      SET @cErrMsg = [RDT].[rdtGetMessage]( @nErrNo, @cLangCode, N'DSP')  --230252 - Insert TemperatureLog Fail
      GOTO RollBackTran
   END

   COMMIT TRAN rdt_Out_PltTempCap_Cfm
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_Out_PltTempCap_Cfm
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
END

GO