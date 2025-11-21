SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1829ExtUpd01                                          */
/* Purpose: Validate Pallet DropID                                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2017-Jul-19 1.0  James    WMS2289 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1829ExtUpd01] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR(3),
   @nStep        INT,
   @nInputKey    INT, 
   @cStorerKey   NVARCHAR(15),
   @cParam1      NVARCHAR(20),
   @cParam2      NVARCHAR(20),
   @cParam3      NVARCHAR(20),
   @cParam4      NVARCHAR(20),
   @cParam5      NVARCHAR(20),
   @cUCCNo       NVARCHAR(20),
   @nErrNo       INT          OUTPUT,
   @cErrMsg      NVARCHAR(20) OUTPUT
)
AS
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cReceiptGroup  NVARCHAR( 20)
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @nTranCount     INT
   DECLARE @nRowref        INT

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_1829ExtUpd01

   SET @nErrNo = 0
   SET @cReceiptGroup = @cParam1

   SELECT @cFacility = Facility FROM RDT.RDTMobRec WITH (NOLOCK) WHERE MOBILE = @nMobile

   IF @nStep = 4 -- End pre sort
   BEGIN
      DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT ROWREF FROM RDT.rdtPreReceiveSort2Log WITH (NOLOCK)
      WHERE UDF01 = @cReceiptGroup
      AND   StorerKey = @cStorerKey
      AND   [Status] < '9'
      OPEN CUR_UPD
      FETCH NEXT FROM CUR_UPD INTO @nRowref
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE RDT.rdtPreReceiveSort2Log WITH (ROWLOCK) SET 
            [Status] = '9',
            EditDate = GETDATE(),
            EditWho = sUser_sName() + '*'
         WHERE RowRef = @nRowRef

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 114801
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Rel Loc Fail

            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD
            GOTO RollBackTran
         END

         FETCH NEXT FROM CUR_UPD INTO @nRowref
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD
   END
         
   GOTO Quit

   RollBackTran:
         ROLLBACK TRAN rdt_1829ExtUpd01
   Quit:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN


GO