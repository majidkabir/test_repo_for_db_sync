SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Inbound_IDTempCap_Confirm                       */
/* Copyright      : Maersk                                              */
/* Customer       : BRITISH EGYPTIAN                                    */
/*                                                                      */
/* Purpose: Close working batch                                         */
/*                                                                      */
/* Date       Rev    Author      Purposes                               */
/* 2024-12-06 1.0.0  NLT013      FCR-1398 Created                       */
/************************************************************************/

CREATE   PROC [RDT].[rdt_Inbound_IDTempCap_Confirm] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18),
   @cFacility        NVARCHAR(5),
   @cStorerKey       NVARCHAR(15),
   @cReceiptKey      NVARCHAR(10),
   @cID              NVARCHAR(18),
   @fTemperature     DECIMAL(5,2),
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE 
      @cSQL                NVARCHAR( MAX),
      @cSQLParam           NVARCHAR( MAX),
      @bSuccess            INT,
      @nTranCount          INT,
      @cTemperatureLogID   NVARCHAR( 10)

   -- Get RDT storer configure
   DECLARE @cConfirmSP NVARCHAR(30)
   SET @cConfirmSP = rdt.RDTGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)
   IF @cConfirmSP = '0'
      SET @cConfirmSP = ''

   /***********************************************************************************************
                                              Custom confirm
   ***********************************************************************************************/
   -- Check confirm SP blank
   IF @cConfirmSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cConfirmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
            ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, ' +
            ' @cReceiptKey, @cID, @fTemperature, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            ' @nMobile       INT,           ' +
            ' @nFunc         INT,           ' +
            ' @cLangCode     NVARCHAR( 18), ' +
            ' @cUserName     NVARCHAR( 18), ' +
            ' @cFacility     NVARCHAR( 5),  ' +
            ' @cStorerKey    NVARCHAR( 15), ' +
            ' @cReceiptKey   NVARCHAR( 10), ' +
            ' @cID           NVARCHAR( 18), ' +
            ' @fTemperature  DECIMAL(7,2),  ' +
            ' @nErrNo        INT           OUTPUT, ' +
            ' @cErrMsg       NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey,
            @cReceiptKey, @cID, @fTemperature,
            @nErrNo OUTPUT, @cErrMsg OUTPUT

         GOTO Quit
      END
   END

   /***********************************************************************************************
                                             Standard confirm
   ***********************************************************************************************/

   SET @nTranCount = @@TRANCOUNT  
    IF @nTranCount = 0
   BEGIN
        BEGIN TRANSACTION
   END
   ELSE
   BEGIN
        SAVE TRANSACTION rdt_Inbound_IDTempCap_Confirm
   END

   EXECUTE dbo.nspg_GetKey  
            'TemperatureLogID',  
            10 ,  
            @cTemperatureLogID OUTPUT,  
            @bSuccess         OUTPUT,  
            @nErrNo            OUTPUT,  
            @cErrMsg           OUTPUT  

   IF @bSuccess <> 1  
   BEGIN  
      SET @nErrNo = 230452
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKeyFail
      GOTO RollBackTran  
   END  

   BEGIN TRY
      INSERT INTO dbo.TemperatureLog
         (TemperatureLogID, Facility, StorerKey, ReceiptKey, MbolKey, PalletID, Temperature, TempCheckPoint, CheckUser, EditDate, EditWho )
      VALUES
        (@cTemperatureLogID, @cFacility, @cStorerKey, @cReceiptKey, NULL, @cID, @fTemperature, 'R', @cUserName, GETDATE(), @cUserName )
		
   END TRY
   BEGIN CATCH
      SET @nErrNo = 230453
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --AddTmpLogFail
      GOTO RollBackTran
   END CATCH

   GOTO Quit

   RollBackTran:
   BEGIN
      IF @nTranCount > 0
      BEGIN
         IF XACT_STATE() <> -1  
         BEGIN
            ROLLBACK TRANSACTION rdt_Inbound_IDTempCap_Confirm
         END
      END
      ELSE
      BEGIN
         ROLLBACK TRANSACTION
      END
   END

   Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRANSACTION
END

GO