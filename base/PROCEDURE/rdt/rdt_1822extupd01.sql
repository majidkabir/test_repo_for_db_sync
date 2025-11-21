SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1822ExtUpd01                                    */
/*                                                                      */
/* Purpose: Update pickdetail (pick confirm)                            */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2019-06-20  1.0  James       WMS-9480 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_1822ExtUpd01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
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
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cGroupKey      NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @nTranCount     INT

   -- Variable mapping
   SELECT @cGroupKey = Value FROM @tExtUpdate WHERE Variable = '@cGroupKey'

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1822ExtUpd01

   IF @nStep = 1 -- GroupKey
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT PD.PickDetailKey
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.TaskDetail TD WITH (NOLOCK) ON ( PD.TaskDetailKey = TD.TaskDetailKey)
         WHERE TD.GroupKey = @cGroupKey
         AND   TD.Status = '9'
         AND   TD.StorerKey = @cStorerKey
         AND   PD.Status = '0'
         ORDER BY 1
         OPEN CUR_UPD
         FETCH NEXT FROM CUR_UPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
               Status = '5'
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 140751
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PickCfm Fail
               CLOSE CUR_UPD
               DEALLOCATE CUR_UPD
               GOTO RollBackTran
            END

            FETCH NEXT FROM CUR_UPD INTO @cPickDetailKey
         END
         CLOSE CUR_UPD
         DEALLOCATE CUR_UPD
      END
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_1822ExtUpd01

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_1822ExtUpd01

END

GO