SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************************/
/* Store procedure: rdt_1653ExtUpd08                                                */
/* Copyright      : Maersk                                                          */
/*                                                                                  */
/* Called from: rdtfnc_TrackNo_SortToPallet                                         */
/*                                                                                  */
/* Purpose: Delete unscanned orders when close pallet                               */
/*                                                                                  */
/* Modifications log:                                                               */
/* Date        Rev  Author   Purposes                                               */
/* 2023-07-26  1.0  James    WMS-23079. Created                                     */
/* 2023-10-31  1.1  Leong    JSM-184393 - Bug fix.                                  */
/************************************************************************************/

CREATE   PROC [RDT].[rdt_1653ExtUpd08] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cTrackNo       NVARCHAR( 40),
   @cOrderKey      NVARCHAR( 20),
   @cPalletKey     NVARCHAR( 20),
   @cMBOLKey       NVARCHAR( 10),
   @cLane          NVARCHAR( 20),
   @tExtValidVar   VariableTable READONLY,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess       INT
   DECLARE @nRowRef        INT
   DECLARE @cPickdetailkey NVARCHAR( 10)
   DECLARE @curDelPD       CURSOR
   DECLARE @nTranCount     INT
   DECLARE @cUserName      NVARCHAR( 18)

   SELECT @cUserName = UserName
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1653ExtUpd08

   IF @nStep = 2
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SET @curDelPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT PickDetailKey
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         AND   [Status] = '4'
         OPEN @curDelPD
         FETCH NEXT FROM @curDelPD INTO @cPickdetailkey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            DELETE PickDetail
            WHERE PickDetailKey = @cPickdetailkey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 204301
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Del ShtPickError'
               GOTO RollBackTran
            END

            FETCH NEXT FROM @curDelPD INTO @cPickdetailkey
         END
      END
   END

   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
         EXEC isp_Carrier_Middleware_Interface
             '' -- @cOrderKey
            ,@cMBOLKey
            ,@nFunc
            ,'' -- @nCartonNo
            ,@nStep
            ,@bSuccess  OUTPUT
            ,@nErrNo    OUTPUT
            ,@cErrMsg   OUTPUT
         IF @bSuccess = 0
         BEGIN
            SET @nErrNo = 204302
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ShipLabel fail
            GOTO RollBackTran
         END

         DECLARE @curDelEcomLog  CURSOR
         SET @curDelEcomLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT RowRef FROM rdt.rdtECOMMLog EL WITH (NOLOCK)
         WHERE EXISTS ( SELECT 1 FROM MBOLDETAIL MD WITH (NOLOCK)
                        WHERE EL.Orderkey = MD.OrderKey
                        AND   MD.MbolKey = @cMBOLKey)
         OPEN @curDelEcomLog
         FETCH NEXT FROM @curDelEcomLog INTO @nRowRef
         WHILE @@FETCH_STATUS = 0
         BEGIN
            DELETE rdt.rdtECOMMLOG WHERE RowRef = @nRowRef

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 204303
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'DelEcommFail'
               GOTO RollBackTran
            END

            FETCH NEXT FROM @curDelEcomLog INTO @nRowRef
         END

         DECLARE @tWave TABLE ( WaveKey    NVARCHAR( 10))
         DECLARE @tOrd TABLE ( OrderKey    NVARCHAR( 10))
         DECLARE @tPDOrd TABLE ( OrderKey    NVARCHAR( 10))
         DECLARE @tShtOrd TABLE ( OrderKey    NVARCHAR( 10))
         DECLARE @curPick  CURSOR
         DECLARE @curPackD CURSOR
         DECLARE @curPackH CURSOR
         DECLARE @curOrd   CURSOR
         DECLARE @curTL2   CURSOR
         DECLARE @curWave  CURSOR
         DECLARE @curShtOrd      CURSOR
         DECLARE @curDelPick     CURSOR
         DECLARE @cPickSlipNo    NVARCHAR( 10)
         DECLARE @cLabelNo       NVARCHAR( 20)
         DECLARE @cLabelLine     NVARCHAR( 5)
         DECLARE @nCartonNo      INT
         DECLARE @ctOrderKey     NVARCHAR( 10)
         DECLARE @cTransmitLogKey   NVARCHAR( 10)
         DECLARE @cWaveDetailKey    NVARCHAR( 10)
         DECLARE @cShtOrderKey      NVARCHAR( 10)

         -- Delete any unscanned orders
         INSERT INTO @tWave (WaveKey)
         SELECT DISTINCT O.UserDefine09
         FROM dbo.ORDERS O WITH (NOLOCK)
         JOIN dbo.WAVE W WITH (NOLOCK) ON (O.UserDefine09 = W.WaveKey) -- JSM-184393
         WHERE O.MBOLKey = @cMBOLKey

         INSERT INTO @tOrd (OrderKey)
         SELECT DISTINCT O.OrderKey
         FROM dbo.Orders O WITH (NOLOCK)
         JOIN dbo.WAVEDETAIL WD WITH (NOLOCK) ON ( O.OrderKey = WD.OrderKey)
         JOIN @tWave W ON ( WD.WaveKey = W.WaveKey)
         WHERE ISNULL( O.MBOLKey, '') = ''
         AND   O.[Status] < '9'

         -- only delete short pick line (status = 4)
         SET @curPick = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT PD.PickDetailKey
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN @tOrd O ON ( PD.OrderKey = O.OrderKey)
         WHERE PD.[Status] = '4'
         OPEN @curPick
         FETCH NEXT FROM @curPick INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            DELETE FROM PickDetail
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 204304
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Delete Pick Err
               GOTO RollBackTran
            END

            FETCH NEXT FROM @curPick INTO @cPickDetailKey
         END

         -- Delete any short pick line which already scanned onto this pallet
         INSERT INTO @tPDOrd (OrderKey)
         SELECT DISTINCT UserDefine01
         FROM dbo.PALLETDETAIL WITH (NOLOCK)
         WHERE PalletKey = @cPalletKey

         SET @curDelPick = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT PickDetailKey
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)
         JOIN @tPDOrd PDO ON ( PD.OrderKey = PDO.OrderKey)
         WHERE PD.[Status] = '4'
         AND   O.[Status] < '9'
         OPEN @curDelPick
         FETCH NEXT FROM @curDelPick INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            DELETE FROM dbo.PickDetail
            WHERE PickDetailKey = @cPickdetailkey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 204305
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Delete Pick Err
               GOTO RollBackTran
            END

            FETCH NEXT FROM @curDelPick INTO @cPickDetailKey
         END

         -- Delete any packing date which don't have any allocation/picking
         INSERT INTO @tShtOrd(OrderKey)
         SELECT O.OrderKey
         FROM dbo.ORDERS O WITH (NOLOCK)
         JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON ( O.OrderKey = OD.OrderKey)
         JOIN @tWave W ON ( O.UserDefine09 = W.WaveKey)
         WHERE O.Status < '9'
         GROUP BY O.OrderKey
         HAVING SUM( OD.QtyAllocated + OD.QtyPicked) = 0

         SET @curPackD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT PD.PickSlipNo, PD.CartonNo, PD.LabelNo, PD.LabelLine
         FROM dbo.PackDetail PD WITH (NOLOCK)
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
         JOIN @tShtOrd O ON ( PH.OrderKey = O.OrderKey)
         OPEN @curPackD
         FETCH NEXT FROM @curPackD INTO @cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine
         WHILE @@FETCH_STATUS = 0
         BEGIN

            DELETE FROM PackDetail
            WHERE PickSlipNo = @cPickSlipNo
             AND   CartonNo = @nCartonNo
             AND   LabelNo = @cLabelNo
             AND   LabelLine = @cLabelLine

             IF @@ERROR <> 0
             BEGIN
               SET @nErrNo = 204306
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Delete Pack Err
               GOTO RollBackTran
            END

            DELETE FROM PackInfo
            WHERE PickSlipNo = @cPickSlipNo
            AND   CartonNo = @nCartonNo

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 204307
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Delete PackIf Err
               GOTO RollBackTran
            END

            FETCH NEXT FROM @curPackD INTO @cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine
         END

         SET @curPackH = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT PH.PickSlipNo
         FROM dbo.PackHeader PH WITH (NOLOCK)
         JOIN @tShtOrd O ON ( PH.OrderKey = O.OrderKey)
         OPEN @curPackH
         FETCH NEXT FROM @curPackH INTO @cPickSlipNo
         WHILE @@FETCH_STATUS = 0
         BEGIN
            DELETE FROM PackHeader
            WHERE PickSlipNo = @cPickSlipNo

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 204308
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Delete Packh Err
               GOTO RollBackTran
            END

            FETCH NEXT FROM @curPackH INTO @cPickSlipNo
         END

         SET @curTL2 = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT TransmitlogKey
         FROM dbo.TRANSMITLOG2 TL WITH (NOLOCK)
         JOIN @tShtOrd O ON ( TL.key1 = O.OrderKey)
         AND  TL.key3 = @cStorerKey
         WHERE TL.tablename IN ('WSCRSOREQMW', 'WSCRSOREQILS')
         OPEN @curTL2
         FETCH NEXT FROM @curTL2 INTO @cTransmitLogKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            DELETE FROM TRANSMITLOG2 WHERE transmitlogkey = @cTransmitLogKey

           IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 204309
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Delete Packh Err
               GOTO RollBackTran
            END

            FETCH NEXT FROM @curTL2 INTO @cTransmitLogKey
         END

         SET @curShtOrd = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT O.OrderKey
         FROM dbo.ORDERS O WITH (NOLOCK)
         JOIN @tShtOrd SO ON ( O.OrderKey = SO.OrderKey)
         OPEN @curShtOrd
         FETCH NEXT FROM @curShtOrd INTO @cShtOrderKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE dbo.ORDERS SET
               UserDefine04 = 'SHORT',
               EditWho = @cUserName,
               EditDate = GETDATE()
            WHERE OrderKey = @cShtOrderKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 204311
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Delete WavDtl Er
               GOTO RollBackTran
            END

            FETCH NEXT FROM @curShtOrd INTO @cShtOrderKey
         END

         SET @curWave = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT WD.WavedetailKey
         FROM dbo.WAVEDETAIL WD WITH (NOLOCK)
         JOIN @tShtOrd O ON ( WD.OrderKey = O.OrderKey)
         OPEN @curWave
         FETCH NEXT FROM @curWave INTO @cWaveDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            DELETE FROM WaveDetail
            WHERE WaveDetailKey = @cWaveDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 204310
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Delete WavDtl Er
               GOTO RollBackTran
            END

            FETCH NEXT FROM @curWave INTO @cWaveDetailKey
         END
      END
   END

   GOTO Quit

   RollBackTran:
         ROLLBACK TRAN rdt_1653ExtUpd08
   Quit:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN
END

GO