SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtVal15                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2022-08-08 1.0  yeekung   WMS-18323  Created                          */
/************************************************************************/

CREATE   PROC [RDT].[rdt_838ExtVal15] (
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

   DECLARE @cLoadKey NVARCHAR( 10)
   DECLARE @cUPC NVARCHAR(30)

   
   DECLARE @cErrMsg1       NVARCHAR( 20), 
           @cErrMsg2       NVARCHAR( 20) 


   DECLARE @nPDQty INT

   DECLARE @tPickZone TABLE 
   (
      PickZone NVARCHAR( 10) PRIMARY KEY CLUSTERED 
   )

   IF @nFunc = 838 -- Pack
   BEGIN
       IF @nStep  = 3
      BEGIN
         IF @nInputKey = 1
         BEGIN
            -- Current carton
            IF @nCartonNo > 0
            BEGIN
               -- Get SKU info
               DECLARE @cSerialNoCapture NVARCHAR( 1)
               SELECT @cSerialNoCapture = SerialNoCapture
               FROM SKU WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND SKU = @cSKU

               -- Non-serial SKU
               IF @cSerialNoCapture <> '1'
               BEGIN
                  -- Get packed SKU info
                  DECLARE @cPackedSKU NVARCHAR( 20)
                  DECLARE @cPackedDropID NVARCHAR( 20)
                  SELECT TOP 1
                     @cPackedSKU = SKU,
                     @cPackedDropID = DropID
                  FROM PackDetail WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo
                     AND CartonNo = @nCartonNo

                  SELECT @cSerialNoCapture = SerialNoCapture
                  FROM SKU WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND SKU = @cPackedSKU

                  -- Check mix non-serial with serial
                  IF @cSerialNoCapture = '1'
                  BEGIN
                     SET @nErrNo = 191902
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Mix SNO SKU
                     GOTO Quit
                  END

                  -- Check mix drop ID
                  IF @cFromDropID <> @cPackedDropID
                  BEGIN
                     SET @nErrNo = 191903
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Mix DropID
                     GOTO Quit
                  END
               END
            END


            IF NOT EXISTS(SELECT 1
                     from pickdetail PD (nolock) JOIN
                           lotattribute L on pd.lot=l.lot and pd.sku=l.sku
                     where pickslipno=@cPickSlipNo
                        AND pd.storerkey=@cStorerKey
                        AND l.sku=@cSKU
                     Group by pd.lot
                     HAVING SUM(pd.qty)>= @nQTY)
            BEGIN
               SET @nErrNo = 191901   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ExceedLot03  
               GOTO quit  
            END
         END
      END
      IF @nStep = 5 -- Print label
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cOption = '1' -- Yes
            BEGIN
               IF @cFromDropID <> ''
               BEGIN
                  -- Check DropID
                  DECLARE @nPickQTY INT
                  DECLARE @nPackQTY INT

                  SELECT @nPickQTY = ISNULL( SUM( QTY), 0)
                  FROM PickDetail WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo
                     AND DropID = @cFromDropID
                     AND Status <= '5'
                     AND Status <> '4'

                  SELECT @nPackQTY = ISNULL( SUM( QTY), 0)
                  FROM PackDetail WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo
                     AND DropID = @cFromDropID

                  -- Check DropID not fully packed
                  IF @nPickQTY <> @nPackQTY
                  BEGIN
                     SET @nErrNo = 191904
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID NotFullPack
                     GOTO Quit
                  END
               END
            END
         END
      END
   END

Quit:

END

GO