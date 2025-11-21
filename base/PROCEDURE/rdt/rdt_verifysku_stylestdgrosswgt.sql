SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_VerifySKU_StyleSTDGrossWgt                      */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 07-10-2019  1.0  Ung          WMS-10643 Created                      */
/************************************************************************/
            
CREATE PROCEDURE [RDT].[rdt_VerifySKU_StyleSTDGrossWgt]
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT, 
   @nInputKey   INT, 
   @cFacility   NVARCHAR( 3), 
   @cStorerKey  NVARCHAR( 15),
   @cSKU        NVARCHAR( 20),
   @cType       NVARCHAR( 15),
   @cLabel      NVARCHAR( 30)  OUTPUT, 
   @cShort      NVARCHAR( 10)  OUTPUT, 
   @cValue      NVARCHAR( MAX) OUTPUT, 
   @nErrNo      INT            OUTPUT,
   @cErrMsg     NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount   INT
   DECLARE @nSTDGrossWgt FLOAT

   SET @nTranCount = @@TRANCOUNT
   
   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Get NetWgt
      SELECT @nSTDGrossWgt = ISNULL( SKU.STDGrossWgt, 0)
      FROM SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey 
         AND SKU = @cSKU
         
      -- Check not setup
      IF @nSTDGrossWgt = 0
         SET @nErrNo = -1 --Need setup
      ELSE
         SET @cValue = rdt.rdtFormatFloat( @nSTDGrossWgt)
   END

   /***********************************************************************************************
                                                 UPDATE
   ***********************************************************************************************/
   -- Check SKU setting
   IF @cType = 'UPDATE'
   BEGIN
      -- Check blank
      IF @cValue = ''
      BEGIN
         SET @nErrNo = 144701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need GrossWgt
         GOTO Quit
      END
      
      -- Check valid
      IF rdt.rdtIsValidQTY( @cValue, 21) = 0
      BEGIN
         SET @nErrNo = 144702
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Wgt
         GOTO Quit
      END
      
      -- Get Pack info
      /*
      DECLARE @nCaseCNT FLOAT
      SELECT @nCaseCNT = PACK.CaseCNT
      FROM SKU WITH (NOLOCK)
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey 
         AND SKU = @cSKU
      */
      
      -- Calc value
      SET @nSTDGrossWgt = CAST( @cValue AS FLOAT)
      /*
      IF @nCaseCNT > 0
         SET @nSTDGrossWgt = ROUND( @nSTDGrossWgt / @nCaseCNT, 3)
      ELSE
         SET @nSTDGrossWgt = 0
      */
      
      -- Get SKU info
      DECLARE @cStyle NVARCHAR( 20)
      SELECT @cStyle = Style 
      FROM SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey 
         AND SKU = @cSKU

      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_VerifySKU_StyleSTDGrossWgt -- For rollback or commit only our own transaction

      -- Update
      DECLARE @curSKU CURSOR
      SET @curSKU = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT SKU
         FROM SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey 
            AND Style = @cStyle
      OPEN @curSKU
      FETCH NEXT FROM @curSKU INTO @cSKU
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE SKU SET
            STDGrossWGT = @nSTDGrossWgt
         FROM SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey 
            AND SKU = @cSKU
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 144703
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD SKU Fail
            GOTO RollBackTran
         END

         FETCH NEXT FROM @curSKU INTO @cSKU
      END
      
      COMMIT TRAN rdt_VerifySKU_StyleSTDGrossWgt
   END   
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_VerifySKU_StyleSTDGrossWgt
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO