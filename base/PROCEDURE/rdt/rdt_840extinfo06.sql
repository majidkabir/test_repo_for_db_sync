SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtInfo06                                    */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-10-26 1.0  James      WMS-13919. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtInfo06] (
   @nMobile       INT,
   @nFunc         INT, 
   @cLangCode     NVARCHAR( 3), 
   @nStep         INT, 
   @nAfterStep    INT, 
   @nInputKey     INT, 
   @cStorerkey    NVARCHAR( 15), 
   @cOrderKey     NVARCHAR( 10), 
   @cPickSlipNo   NVARCHAR( 10), 
   @cTrackNo      NVARCHAR( 20), 
   @cSKU          NVARCHAR( 20), 
   @nCartonNo     INT,
   @cExtendedInfo NVARCHAR( 20) OUTPUT,
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE  @nPickQty         INT,
            @nOriginalQty     INT

   DECLARE @cErrMsg01        NVARCHAR( 20),
           @cErrMsg02        NVARCHAR( 20),
           @cErrMsg03        NVARCHAR( 20)

   
   IF @nFunc = 840 -- Pack by track no
   BEGIN
      IF @nStep = 4 -- Carton Type/Weight
      BEGIN
         IF @nInputKey = 1  
         BEGIN
            SET @nPickQty = 0
            SELECT @nPickQty = ISNULL( SUM( QTY), 0)
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
            AND   StorerKey = @cStorerkey
         
            SET @nOriginalQty = 0
            SELECT @nOriginalQty = ISNULL( SUM( OriginalQty), 0) 
            FROM dbo.ORDERDETAIL WITH (NOLOCK)
            WHERE Orderkey = @cOrderkey

            IF @nOriginalQty <> @nPickQty
            BEGIN
               SET @cExtendedInfo = rdt.rdtgetmessage( 160201, @cLangCode, 'DSP') --ORDERS SHORT PICK

               --SET @cErrMsg1 = rdt.rdtgetmessage( 160201, @cLangCode, 'DSP') --Orders Short Pick
               --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1 

               SET @nErrNo = 0
               SET @cErrMsg = ''
               GOTO Quit
            END
         END
      END
   END

   QUIT:

GO