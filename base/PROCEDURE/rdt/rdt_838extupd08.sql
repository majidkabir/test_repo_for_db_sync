SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtUpd08                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 27-07-2020 1.0  Chermaine   WMS-14153 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_838ExtUpd08] (
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
   DECLARE @cPackDetailCartonID  NVARCHAR( 20)

   SET @nTranCount = @@TRANCOUNT

   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 4 -- Weight,Cube
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
                          
            -- New carton without SKU QTY
            IF @nCartonNo = 0
               GOTO Quit
         
            SET @cPackDetailCartonID = rdt.RDTGetConfig( @nFunc, 'PackDetailCartonID', @cStorerKey)
                  
            IF @cPackDetailCartonID = 'RefNo'
            BEGIN
               -- Handling transaction
               BEGIN TRAN  -- Begin our own transaction
               SAVE TRAN rdt_838ExtUpd08 -- For rollback or commit only our own transaction
               
               --INSERT INTO traceInfo (TraceName,col1,col2,col3,col4)
               --VALUES('cc838',@cRefNo,@cLabelNo,@cLabelLine,@nQTY)
            
                  -- Update Packdetail
                  UPDATE dbo.PackDetail WITH (ROWLOCK) SET
                     DropID = @cRefNo, 
                     EditWho = 'rdt.' + SUSER_SNAME(),
                     EditDate = GETDATE(),
                     ArchiveCop = NULL
                  WHERE PickSlipNo = @cPickSlipNo
                     AND CartonNo = @nCartonNo
                     --AND LabelNo = @cLabelNo
                     --AND LabelLine = @cLabelLine
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 100403
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
                     GOTO RollBackTran
                  END
               END
         
               COMMIT TRAN rdt_838ExtUpd08
            END
         END
      END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_838ExtUpd08 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO