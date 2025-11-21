SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_VerifySKUExUpd02                                */
/* Copyright      : LF Logistic                                         */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 18-11-2019  1.0  Ung          WMS-10643 Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_VerifySKUExUpd02]
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @cStorerKey      NVARCHAR( 15),
   @cSKU            NVARCHAR( 20),
   @cType           NVARCHAR( 10),
   @cVerifySKUInfo  NVARCHAR( 20) OUTPUT,
   @cWeight         NVARCHAR( 10) OUTPUT,
   @cCube           NVARCHAR( 10) OUTPUT,
   @cLength         NVARCHAR( 10) OUTPUT,
   @cWidth          NVARCHAR( 10) OUTPUT,
   @cHeight         NVARCHAR( 10) OUTPUT,
   @cInnerPack      NVARCHAR( 10) OUTPUT,
   @cCaseCount      NVARCHAR( 10) OUTPUT,
   @cPalletCount    NVARCHAR( 10) OUTPUT,
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount   INT
   DECLARE @cStyle       NVARCHAR( 20)
   DECLARE @nSTDGrossWgt FLOAT = 0
   DECLARE @nSTDCube     FLOAT = 0

   SET @nTranCount = @@TRANCOUNT

   -- Update weight or cube
   IF @cWeight <> '' OR @cCube <> ''
   BEGIN
      -- Get SKU info
      SELECT @cStyle = Style 
      FROM SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey 
         AND SKU = @cSKU

      -- Calc value
      IF @cWeight <> '' SET @nSTDGrossWgt = CAST( @cWeight AS FLOAT)
      IF @cCube   <> '' SET @nSTDCube     = CAST( @cCube AS FLOAT)

      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_VerifySKUExUpd02 -- For rollback or commit only our own transaction

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
            STDGrossWGT = CASE WHEN @cWeight <> '' THEN @nSTDGrossWgt ELSE STDGrossWGT END, 
            STDCube = CASE WHEN @cCube <> '' THEN @nSTDCube ELSE STDCube END, 
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME()
         FROM SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey 
            AND SKU = @cSKU
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 146051
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD SKU Fail
            GOTO RollBackTran
         END

         FETCH NEXT FROM @curSKU INTO @cSKU
      END
      
      COMMIT TRAN rdt_VerifySKUExUpd02
   END
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_VerifySKUExUpd02
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO