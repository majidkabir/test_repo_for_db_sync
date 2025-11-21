SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/******************************************************************************/
/* Store procedure: rdt_1663ExtUpd11                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2022-10-20 1.0  yeekung  WMS-21051. Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1663ExtUpd11](
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cPalletKey    NVARCHAR( 20),
   @cPalletLOC    NVARCHAR( 10),
   @cMBOLKey      NVARCHAR( 10),
   @cTrackNo      NVARCHAR( 20),
   @cOrderKey     NVARCHAR( 10),
   @cShipperKey   NVARCHAR( 15),
   @cCartonType   NVARCHAR( 10),
   @cWeight       NVARCHAR( 10),
   @cOption       NVARCHAR( 1),
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess       INT
   DECLARE @nTranCount     INT
   DECLARE @cTableName     NVARCHAR( 30)
   DECLARE @nPackSKU       NVARCHAR( 20)
   DECLARE @nCartonNo      INT
   DECLARE @nQTY           INT
   DECLARE @nPackQTY       INT = 0
   DECLARE @fCube          FLOAT = 0
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @nSKUWeight     Float = 0
   DECLARE @nSKUCube       FLOAT = 0
   DECLARE @fWeight        FLOAT = 0

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1663ExtUpd11 -- For rollback or commit only our own transaction

   IF @nFunc = 1663 -- TrackNoToPallet
   BEGIN
      IF  @nStep = 3    -- Carton type
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Sephora B2C orders, one orders one trackingno one carton
            SET @nCartonNo = 1

            SELECT @cPickSlipNo = PickSlipNo
            FROM dbo.PackHeader WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   OrderKey = @cOrderKey

            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 193101
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No PickSlip
               GOTO RollBackTran
            END

            SELECT @nQTY = ISNULL( SUM( Qty), 0)
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo

            SELECT @cCartonType=cartontype
            FROM dbo.packinfo WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo

            DECLARE @curSKU CURSOR

            SET @curSKU  = CURSOR FOR
            SELECT ISNULL( SUM( Qty), 0),SKU
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            GROUP BY SKU

            OPEN @curSKU
            FETCH NEXT FROM @curSKU INTO @nPackQTY,@nPackSKU
            WHILE @@FETCH_STATUS = 0
            BEGIN
               SELECT @nSKUWeight= @nSKUWeight + (STDGROSSWGT *@nPackQTY),
                        @nSKUCube = @nSKUCube + (stdcube *@nPackQTY)
               FROM sku (NOLOCK)
               where sku=@nPackSKU
               AND storerkey=@cStorerKey

               FETCH NEXT FROM @curSKU INTO @nPackQTY,@nPackSKU
            END

            CLOSE @curSKU
            DEALLOCATE @curSKU

            SELECT @fCube = CZ.[Cube],
                   @fWeight = cartonweight
            FROM dbo.CARTONIZATION CZ WITH (NOLOCK)
            JOIN dbo.Storer ST WITH (NOLOCK) ON ( CZ.CartonizationGroup = ST.CartonGroup)
            WHERE ST.StorerKey = @cStorerKey
            AND   CZ.CartonType = @cCartonType

            SET @fWeight = @fWeight+@nSKUWeight

            IF EXISTS (SELECT 1 
                        FROM codelkup (nolock)
                        where listname='AEOCARTON'
                        AND Storerkey=@cStorerkey
                        AND code = @cCartonType
                        And long='BOX')
            BEGIN
               SET @fCube = @fCube 
            END
            ELSE
            BEGIN
               SET @fCube = @nSKUCube
            END

            IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
            BEGIN
               INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, Qty, Weight, Cube, CartonType)
               VALUES (@cPickSlipNo, @nCartonNo, @nQTY, CAST( @fWeight AS FLOAT), @fCube, @cCartonType)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 193102
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail
                  GOTO RollBackTran
               END
            END
            ELSE
            BEGIN
               UPDATE dbo.PackInfo SET
                  CartonType = @cCartonType,
                  Weight = CAST( @fWeight AS FLOAT),
                  Cube = @fCube
               WHERE PickSlipNo = @cPickSlipNo
               AND   CartonNo = @nCartonNo

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 193103
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackInfFail
                  GOTO RollBackTran
               END
               END
         END   -- Carton type
      END
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1663ExtUpd11
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO