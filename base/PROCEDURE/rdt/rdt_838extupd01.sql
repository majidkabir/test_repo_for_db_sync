SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtUpd01                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 13-05-2016 1.0  Ung         SOS368666 Created                        */
/* 06-12-2016 1.1  Ung         WMS-458 Change parameter                 */
/* 24-05-2017 1.2  Ung         WMS-1919 Change parameter                */
/* 04-04-2019 1.3  Ung         WMS-8134 Add PackData1..3 parameter      */
/************************************************************************/

CREATE PROC [RDT].[rdt_838ExtUpd01] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cPickSlipNo      NVARCHAR( 10),
   @cFromDropID      NVARCHAR( 20),
   @nCartonNo        INT,
   @cLabelNo         NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cUCCNo           NVARCHAR( 20),
   @cCartonType      NVARCHAR( 10),
   @cCube            NVARCHAR( 10),
   @cWeight          NVARCHAR( 10),
   @cRefNo           NVARCHAR( 20),
   @cSerialNo        NVARCHAR( 30),
   @nSerialQTY       INT,
   @cOption          NVARCHAR( 1),
   @cPackDtlRefNo    NVARCHAR( 20), 
   @cPackDtlRefNo2   NVARCHAR( 20), 
   @cPackDtlUPC      NVARCHAR( 30), 
   @cPackDtlDropID   NVARCHAR( 20), 
   @cPackData1       NVARCHAR( 30), 
   @cPackData2       NVARCHAR( 30), 
   @cPackData3       NVARCHAR( 30), 
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLabelLine NVARCHAR(5)
   DECLARE @nTranCount INT

   SET @nTranCount = @@TRANCOUNT

   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 3 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Without ToDropID
            IF @cPackDtlDropID = ''
               GOTO Quit
               
            -- New carton without SKU QTY
            IF @nCartonNo = 0
               GOTO Quit
         
            -- PackDetail need to update
            IF EXISTS( SELECT 1
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
                  AND CartonNo = @nCartonNo
                  AND LabelNo = @cLabelNo
                  AND DropID <> @cPackDtlDropID)
            BEGIN
               -- Handling transaction
               BEGIN TRAN  -- Begin our own transaction
               SAVE TRAN rdt_838ExtUpd01 -- For rollback or commit only our own transaction
            
               DECLARE @curPD CURSOR
               SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT LabelLine
                  FROM dbo.PackDetail WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo
                     AND CartonNo = @nCartonNo
                     AND LabelNo = @cLabelNo
                     AND DropID <> @cPackDtlDropID
            
               -- Loop PickDetail
               OPEN @curPD
               FETCH NEXT FROM @curPD INTO @cLabelLine
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  -- Update Packdetail
                  UPDATE dbo.PackDetail WITH (ROWLOCK) SET
                     DropID = @cPackDtlDropID, 
                     EditWho = 'rdt.' + SUSER_SNAME(),
                     EditDate = GETDATE(),
                     ArchiveCop = NULL
                  WHERE PickSlipNo = @cPickSlipNo
                     AND CartonNo = @nCartonNo
                     AND LabelNo = @cLabelNo
                     AND LabelLine = @cLabelLine
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 100403
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
                     GOTO RollBackTran
                  END
               
                  FETCH NEXT FROM @curPD INTO @cLabelLine
               END
         
               COMMIT TRAN rdt_838ExtUpd01
            END
         END
      END
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_838ExtUpd01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO