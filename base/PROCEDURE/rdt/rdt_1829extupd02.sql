SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1829ExtUpd02                                          */
/* Purpose: Update rdtPreReceiveSort2Log as ucc counted                       */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2018-Jan-24 1.0  James    WMS3653 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1829ExtUpd02] (
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

   DECLARE @cReceiptKey    NVARCHAR( 10)
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cUserName      NVARCHAR( 18)
   DECLARE @nTranCount     INT
   DECLARE @nRowref        INT

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_1829ExtUpd02

   SET @nErrNo = 0
   SET @cReceiptKey = @cParam1

   SELECT @cFacility = Facility, @cUserName = UserName FROM RDT.RDTMobRec WITH (NOLOCK) WHERE MOBILE = @nMobile

   IF @nStep = 1
   BEGIN
      IF @nInputKey = '0'
      BEGIN
         DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT ROWREF FROM RDT.rdtPreReceiveSort2Log WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   StorerKey = @cStorerKey
         AND   [Status] = '1'
         AND   EditWho = @cUserName
         OPEN CUR_UPD
         FETCH NEXT FROM CUR_UPD INTO @nRowref
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            UPDATE RDT.rdtPreReceiveSort2Log WITH (ROWLOCK) SET 
               [Status] = '5',
               EditDate = GETDATE(),
               EditWho = @cUserName
            WHERE RowRef = @nRowRef

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 118901
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd PreRcv Err

               CLOSE CUR_UPD
               DEALLOCATE CUR_UPD
               GOTO RollBackTran
            END

            FETCH NEXT FROM CUR_UPD INTO @nRowref
         END
         CLOSE CUR_UPD
         DEALLOCATE CUR_UPD
      END
   END

   IF @nStep = 4
   BEGIN
      IF @nInputKey = '1'
      BEGIN
         DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT ROWREF FROM RDT.rdtPreReceiveSort2Log WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   StorerKey = @cStorerKey
         AND   [Status] = '5'
         AND   EditWho = @cUserName
         OPEN CUR_UPD
         FETCH NEXT FROM CUR_UPD INTO @nRowref
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            UPDATE RDT.rdtPreReceiveSort2Log WITH (ROWLOCK) SET 
               [Status] = '9',
               EditDate = GETDATE(),
               EditWho = @cUserName
            WHERE RowRef = @nRowRef

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 118902
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd PreRcv Err

               CLOSE CUR_UPD
               DEALLOCATE CUR_UPD
               GOTO RollBackTran
            END

            FETCH NEXT FROM CUR_UPD INTO @nRowref
         END
         CLOSE CUR_UPD
         DEALLOCATE CUR_UPD
      END
   END

   GOTO Quit

   RollBackTran:
         ROLLBACK TRAN rdt_1829ExtUpd02
   Quit:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN


GO