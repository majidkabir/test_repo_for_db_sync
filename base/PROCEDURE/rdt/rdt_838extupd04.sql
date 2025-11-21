SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtUpd04                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: When repack, release carton tracking no (except 1st carton) */
/*          update pickdetail.caseid                                    */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 12-10-2018 1.0  James       WMS-6654 Created                         */
/* 04-04-2019 1.1  Ung         WMS-8134 Add PackData1..3 parameter      */
/************************************************************************/

CREATE PROC [RDT].[rdt_838ExtUpd04] (
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

   DECLARE @cLabelLine     NVARCHAR( 5)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cCarrierName   NVARCHAR( 15)
   DECLARE @cUserName      NVARCHAR( 18)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @nTranCount     INT

   SET @nTranCount = @@TRANCOUNT

   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 7 -- Repack
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT @cUserName = UserName
            FROM RDT.RDTMOBREC WITH (NOLOCK)
            WHERE Mobile = @nMobile

            -- Get PickHeader info
            SELECT @cOrderKey = OrderKey
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE PickHeaderKey = @cPickSlipNo

            SELECT @cCarrierName = ShipperKey
            FROM dbo.ORDERS WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey

            SELECT TOP 1 @cLabelNo = LabelNo
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            AND   CartonNo = @nCartonNo
            AND   SKU = ''
            AND   QTY = 0
            ORDER BY 1

            -- 1st carton, no need release tracking no
            IF @nCartonNo > 1 AND 
               EXISTS ( SELECT 1 FROM dbo.CartonTrack WITH (NOLOCK)
                        WHERE TrackingNo = @cLabelNo
                        AND   CarrierName = @cCarrierName)
            BEGIN
               UPDATE dbo.CartonTrack WITH (ROWLOCK) SET 
                  LabelNo = '',
                  CarrierRef2 = ''
               WHERE CarrierName = @cCarrierName   
               AND   TrackingNo = @cLabelNo

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 130901
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd Trk# Err
                  GOTO RollBackTran
               END
            END

            DECLARE CUR CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT PICKDETAILKEY
            FROM dbo.PICKDETAIL WITH (NOLOCK)
            WHERE Storerkey = @cStorerKey
            AND   OrderKey = @cOrderKey
            AND   CaseID = @cLabelNo
            AND   Status < '9'
            OPEN CUR
            FETCH NEXT FROM CUR INTO @cPickDetailKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE dbo.PICKDETAIL WITH (ROWLOCK) SET 
                  CaseID = '',
                  EditWho = @cUserName,
                  EditDate = GETDATE(),
                  TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 130902
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd CaseID Err
                  GOTO RollBackTran
               END

               FETCH NEXT FROM CUR INTO @cPickDetailKey
            END
            CLOSE CUR
            DEALLOCATE CUR
         END
      END
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_838ExtUpd04 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO