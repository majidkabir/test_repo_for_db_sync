SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838DecodeSP05                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Decode SKU                                                  */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2021-05-04  1.0  yeekung     WMS-16963 Created                       */
/* 2023-03-20  1.1  Ung         WMS-21946 Add SerialNo param            */
/* 2024-10-25  1.2  PXL009      FCR-759 ID and UCC Length Issue         */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_838DecodeSP05]
   @nMobile             INT,
   @nFunc               INT,
   @cLangCode           NVARCHAR( 3),
   @nStep               INT,
   @nInputKey           INT,
   @cFacility           NVARCHAR( 5),
   @cStorerKey          NVARCHAR( 15),
   @cPickSlipNo         NVARCHAR( 10),
   @cFromDropID         NVARCHAR( 20),
   @cBarcode            NVARCHAR( 60),
   @cBarcode2           NVARCHAR( 60),
   @cSKU                NVARCHAR( 20)  OUTPUT,
   @nQTY                INT            OUTPUT,
   @cPackDtlRefNo       NVARCHAR( 20)  OUTPUT,
   @cPackDtlRefNo2      NVARCHAR( 20)  OUTPUT,
   @cPackDtlUPC         NVARCHAR( 30)  OUTPUT,
   @cPackDtlDropID      NVARCHAR( 20)  OUTPUT,
   @cSerialNo           NVARCHAR( 30)  OUTPUT,
   @cFromDropIDDecode   NVARCHAR( 20)  OUTPUT,
   @cToDropIDDecode     NVARCHAR( 20)  OUTPUT,
   @cUCCNo              NVARCHAR( 20)  OUTPUT,
   @nErrNo              INT            OUTPUT,
   @cErrMsg             NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 838
   BEGIN
      IF @nStep = 3  -- SKU QTY
      BEGIN
         IF @nInputKey = 1
         BEGIN

            DECLARE @cSession INT
            DECLARE @clottable02 NVARCHAR(20)
            DECLARE @cLabelNo NVARCHAR(20)
            DECLARE @clabelSKU NVARCHAR(20)
            DECLARE @clabelupc NVARCHAR(60)
            DECLARE @cUpclottable02 NVARCHAR(20)

            IF (LEN(@cBarcode)>20)
            BEGIN
               SET @cSession=SUBSTRING(@cBarcode,1,2)
               SET @csku=SUBSTRING(@cBarcode,3,13)
               SET @clottable02=SUBSTRING(@cBarcode,16,12)+ '-' +SUBSTRING(@cBarcode,28,2)

               SELECT @cLabelNo=V_String3
               FROM rdt.RDTMOBREC (NOLOCK)
               WHERE mobile=@nMobile

               SELECT @clabelSKU=SKU,@clabelupc=upc
               FROM packdetail (NOLOCK)
               WHERE labelno=@cLabelNo
               AND pickslipno=@cPickSlipNo

               SET @cUpclottable02=CASE WHEN ISNULL(@clabelupc,'')<>'' THEN SUBSTRING(@clabelupc,16,12)+ '-' +SUBSTRING(@clabelupc,28,2) ELSE '' end


               IF ISNULL(@cUpclottable02,'')<>''
               BEGIN
                  IF (@cUpclottable02<>@clottable02)
                  BEGIN
                     SET @nErrNo = 167304
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
                     GOTO Quit
                  END
               END

               IF NOT EXISTS (SELECT 1 FROM pickheader PH  WITH (NOLOCK)
                           JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = PH.OrderKey)
                        WHERE ph.PickHeaderKey=@cPickSlipNo
                        AND pd.sku=@cSKU
                        AND pd.storerkey=@cStorerKey)
               BEGIN
                  SET @nErrNo = 167301
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
                  GOTO Quit
               END

               IF NOT EXISTS (SELECT 1 FROM pickheader PH  WITH (NOLOCK)
                        JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = PH.OrderKey)
                        JOIN lotxlocxid lli (NOLOCK) ON pd.lot=lli.lot AND pd.sku=lli.Sku AND pd.Loc=lli.Loc
                        JOIN dbo.LOTATTRIBUTE LA (NOLOCK) ON la.Lot=lli.lot
                        WHERE ph.PickHeaderKey=@cPickSlipNo
                        AND pd.sku=@cSKU
                        AND LA.lottable02=@clottable02
                        AND pd.storerkey=@cStorerKey
                        AND lli.qty>0)
               BEGIN
                  SET @nErrNo = 167302
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid lot
                  GOTO Quit
               END

               IF ISNULL(@clabelSKU,'')<>''
               BEGIN
                  IF @clabelSKU<>@cSKU
                  BEGIN
                     SET @nErrNo = 167303
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid sku
                     GOTO Quit
                  END
               END

               UPDATE rdt.RDTMOBREC WITH (ROWLOCK)
               SET V_String41=@cBarcode
               WHERE mobile=@nMobile
            END

            SELECT @cPackDtlUPC=V_String41
            FROM rdt.RDTMOBREC (NOLOCK)
            WHERE mobile=@nMobile
         END
      END
   END

Quit:

END

GO