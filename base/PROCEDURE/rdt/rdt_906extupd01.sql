SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_906ExtUpd01                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 29-Mar-2019 1.0  James       WMS-8002 Created                        */
/* 06-Jul-2021 1.1  YeeKung     WMS-17278 Add Reasonkey (yeekung01)     */
/************************************************************************/

CREATE PROC [RDT].[rdt_906ExtUpd01] (
   @nMobile      INT, 
   @nFunc        INT, 
   @cLangCode    NVARCHAR( 3), 
   @nStep        INT, 
   @nInputKey    INT, 
   @cStorerKey   NVARCHAR( 15),  
   @cRefNo       NVARCHAR( 10), 
   @cPickSlipNo  NVARCHAR( 10), 
   @cLoadKey     NVARCHAR( 10), 
   @cOrderKey    NVARCHAR( 10), 
   @cDropID      NVARCHAR( 20), 
   @cSKU         NVARCHAR( 20),  
   @nQty         INT,  
   @cOption      NVARCHAR( 1),  
   @nErrNo       INT OUTPUT,  
   @cErrMsg      NVARCHAR( 20) OUTPUT, 
   @cID          NVARCHAR( 18) = '',
   @cTaskDetailKey   NVARCHAR( 18) = '',
   @cReasonCode  NVARCHAR(20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount INT
   DECLARE @nRowRef    INT
   DECLARE @nPQTY      INT

   IF @nFunc = 906 -- PPA by TaskdetailKey
   BEGIN
      IF @nStep = 3 -- SKU, QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT @cPickSlipNo = PH.PickHeaderKey,
                   @cLoadKey = O.LoadKey,
                   @cOrderKey = O.OrderKey,
                   @nPQTY = SUM( PD.Qty) 
            FROM dbo.PickHeader PH WITH (NOLOCK) 
            JOIN dbo.Orders O WITH (NOLOCK) ON ( PH.OrderKey = O.OrderKey)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( O.OrderKey = PD.OrderKey)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey)
            JOIN dbo.Taskdetail TD WITH (NOLOCK) ON ( PD.TaskDetailKey = TD.TaskDetailKey)
            WHERE TD.TaskDetailKey = @cTaskDetailKey 
            AND   PD.SKU = @cSKU
            GROUP BY PH.PickHeaderKey, O.LoadKey, O.Orderkey

            DECLARE CUR_PPA CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT RowRef
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE TaskDetailKey = @cTaskDetailKey
            OPEN CUR_PPA
            FETCH NEXT FROM CUR_PPA INTO @nRowRef
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE rdt.rdtPPA WITH (ROWLOCK) SET
                  PickSlipNo = @cPickSlipNo,
                  LoadKey = @cLoadKey, 
                  OrderKey = @cOrderKey,
                  PQty = @nPQTY
               WHERE RowRef = @nRowRef

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 137051
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PPA Fail
                  GOTO RollBackTran
               END

               FETCH NEXT FROM CUR_PPA INTO @nRowRef
            END
            CLOSE CUR_PPA
            DEALLOCATE CUR_PPA

            UPDATE dbo.TaskDetail WITH (ROWLOCK) SET 
               Status = '9'
            WHERE TaskDetailKey = @cTaskDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 137052
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TASK Fail
               GOTO RollBackTran
            END
         END
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_906ExtUpd01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO