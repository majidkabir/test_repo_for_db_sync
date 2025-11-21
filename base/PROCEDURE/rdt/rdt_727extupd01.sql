SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_727ExtUpd01                                     */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Update dropid upon carton reach end of conveyor             */
/*                                                                      */
/* Called from: rdtfnc_GeneralInquiry                                   */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2019-06-28   1.0  James    WMS9394. Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_727ExtUpd01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nAfterStep     INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @tExtUpdate     VariableTable READONLY,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount     INT
   DECLARE @cOption        NVARCHAR( 1)
   DECLARE @cParam1Value   NVARCHAR( 20)
   DECLARE @cDropID        NVARCHAR( 20)
   DECLARE @cDropID2UPD    NVARCHAR( 20)
   DECLARE @cCartonID      NVARCHAR( 20)
   DECLARE @cDropIDStatus  NVARCHAR( 10)


   SET @nErrNo = 0

   -- Variable mapping
   SELECT @cOption = Value FROM @tExtUpdate WHERE Variable = '@cOption'
   SELECT @cParam1Value = Value FROM @tExtUpdate WHERE Variable = '@cParam1Value'
   
   SET @cCartonID = @cParam1Value

   IF @nAfterStep = 3
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF @cOption = '3'
         BEGIN
            SET @nTranCount = @@TRANCOUNT
            BEGIN TRAN
            SAVE TRAN rdt_727ExtUpd01
/*
If @CartonID = DropIDDetail.ChildID where DropIDDetail.DropID = DropID.DropID and DropID.Status = æ0Æ, then UPDATE DropID.Status = æ1Æ. 

THEN check if exists Substring(DropID.DropID, 1, 12) = Substring(@DropID.DropID, 1, 12) and DropID.Status = æ0Æ, UPDATE the DropID.Status = æ1Æ.  (Upon scanned, mark current batch Status = 9, and all earlier batch that not yet marked DropID.Status = 9, if there is any.)
*/
            SET @cDropIDStatus= ''
            SELECT @cDropID = D.DropID
            FROM dbo.DropIDDetail DD WITH (NOLOCK)
            JOIN dbo.DropID D WITH (NOLOCK) ON ( DD.DropID = D.DropID)
            WHERE DD.ChildID = @cCartonID

            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 141351
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --CTN NOT EXISTS
               GOTO RollBackTran
            END

            DECLARE @curD CURSOR  
            SET @curD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT DropID, Status  
            FROM dbo.DropID WITH (NOLOCK) 
            WHERE SUBSTRING( DropID, 1, 12) = SUBSTRING( @cDropID, 1, 12)
            OPEN @curD
            FETCH NEXT FROM @curD INTO @cDropID2UPD, @cDropIDStatus
            WHILE @@FETCH_STATUS = 0
            BEGIN
               IF @cDropIDStatus = '0'
               BEGIN
                  UPDATE dbo.DropID WITH (ROWLOCK) SET 
                     Status = '1'
                  WHERE DropID = @cDropID2UPD

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 141352
                     SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --UPD CTN FAIL
                     GOTO RollBackTran
                  END
               END
               FETCH NEXT FROM @curD INTO @cDropID2UPD, @cDropIDStatus
            END
         END
      END
   END


   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_727ExtUpd01

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_727ExtUpd01

END

GO