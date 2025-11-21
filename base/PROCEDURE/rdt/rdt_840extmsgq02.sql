SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtMsgQ02                                    */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2017-04-11 1.0  James      WMS1647. Created                          */
/* 2019-11-21 1.1  YeeKung    Fix the datediff (yeekung01)              */
/* 2020-03-25 1.2  James      WMS-12662 Add new VAS display (james01)   */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtMsgQ02] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nAfterStep       INT, 
   @nInputKey        INT, 
   @cStorerkey       NVARCHAR( 15), 
   @cOrderKey        NVARCHAR( 10), 
   @cPickSlipNo      NVARCHAR( 10), 
   @cTrackNo         NVARCHAR( 20), 
   @cSKU             NVARCHAR( 20), 
   @nCartonNo        INT,
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE  @nFragileChk   INT,
            @nPackaging    INT,
            @nVAS          INT,
            @cBUSR4        NVARCHAR( 20),
            @cOVAS         NVARCHAR( 20),
            @cUDF01        NVARCHAR( 60),
            @cDescr        NVARCHAR( 250),
            @dOrderDate    DATETIME

   DECLARE @cErrMsg01        NVARCHAR( 20),
           @cErrMsg02        NVARCHAR( 20),
           @cErrMsg03        NVARCHAR( 20),
           @cErrMsg04        NVARCHAR( 20),
           @cErrMsg05        NVARCHAR( 20),
           @cErrMsg06        NVARCHAR( 20),
           @cErrMsg07        NVARCHAR( 20),
           @cErrMsg08        NVARCHAR( 20),
           @cErrMsg09        NVARCHAR( 20),
           @cErrMsg10        NVARCHAR( 20),
           @cErrMsg11        NVARCHAR( 20),
           @cErrMsg12        NVARCHAR( 20),
           @cErrMsg13        NVARCHAR( 20),
           @cErrMsg14        NVARCHAR( 20),
           @cErrMsg15        NVARCHAR( 20)

      SET @cErrMsg01 = ''
      SET @cErrMsg02 = ''
      SET @cErrMsg03 = ''
      SET @cErrMsg04 = ''
      SET @cErrMsg05 = '' 
      SET @cErrMsg06 = ''
      SET @cErrMsg07 = ''
      SET @cErrMsg08 = ''
      SET @cErrMsg09 = ''
      SET @cErrMsg10 = ''
      SET @cErrMsg11 = ''
      SET @cErrMsg12 = ''
      SET @cErrMsg13 = ''
      SET @cErrMsg14 = ''
      SET @cErrMsg15 = ''
         
   IF @nFunc = 840 -- Pack by track no
   BEGIN
      IF @nStep = 1
      BEGIN
         -- (james01)
         IF EXISTS ( SELECT 1 FROM dbo.ORDERDETAIL OD WITH (NOLOCK)
                     JOIN dbo.SKU WITH (NOLOCK) ON ( OD.Sku = SKU.Sku AND OD.StorerKey = SKU.StorerKey)
                     WHERE OD.OrderKey = @cOrderKey
                     AND   OD.StorerKey = @cStorerKey
                     AND   SKU.SUSR3 = '2')
         BEGIN
            SET @cErrMsg01 = rdt.rdtgetmessage( 110106, @cLangCode, 'DSP')

            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg01
            SET @nErrNo = 0   -- Reset error no
         END
      END
      
      IF @nStep = 2
      BEGIN
         SET @nFragileChk = 0
                  
         IF rdt.RDTGetConfig( @nFunc, 'FRAGILECHK', @cStorerKey) = 1 AND
            EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                     WHERE [Stop] = 'Y'
                     AND   OrderKey = @cOrderKey
                     AND   StorerKey = @cStorerKey)
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg01 = rdt.rdtgetmessage( 110101, @cLangCode, 'DSP')
            SET @cErrMsg02 = rdt.rdtgetmessage( 110102, @cLangCode, 'DSP')
            SET @cErrMsg03 = rdt.rdtgetmessage( 110103, @cLangCode, 'DSP')

            SET @nFragileChk = 1
         END

         -- Nothing to display then no need display msg queue
         IF @nFragileChk = 0 
            GOTO Quit

         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg01, @cErrMsg02, @cErrMsg03, @cErrMsg04, @cErrMsg05
         SET @nErrNo = 0   -- Reset error no
      END

      IF @nStep = 3
      BEGIN
         SET @nPackaging = 0
         SET @nVAS = 0

         SET @cErrMsg01 = ''
         SET @cErrMsg02 = ''
         SET @cErrMsg03 = ''
         SET @cErrMsg04 = ''
         SET @cErrMsg05 = '' 
         SET @cErrMsg06 = ''
         SET @cErrMsg07 = ''
         SET @cErrMsg08 = ''
         SET @cErrMsg09 = ''
         SET @cErrMsg10 = ''
         SET @cErrMsg11 = ''
         SET @cErrMsg12 = ''
         SET @cErrMsg13 = ''
         SET @cErrMsg14 = ''
         SET @cErrMsg15 = ''

         SELECT @dOrderDate = ISNULL( OrderDate, 0)
         FROM dbo.Orders WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   OrderKey = @cOrderKey

         SELECT @cBUSR4 = BUSR4,
                @cOVAS = OVAS
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerkey
         AND   SKU = @cSKU

         IF ISNULL( @cBUSR4, '') <> ''
         BEGIN
            SET @cUDF01 = ''
            SET @cDescr = ''

            SELECT @cUDF01 = UDF01, -- campaign end date
                   @cDescr = [Description]
            FROM dbo.CODELKUP WITH (NOLOCK) 
            WHERE Storerkey = @cStorerkey
            AND   LISTNAME = 'PACKAGING'
            AND   Code = @cBUSR4
            AND   Short = '1'

            IF rdt.rdtIsValidDate(@cUDF01) = 1
            BEGIN
            	
            	SET @cUDF01 = CONVERT (DATETIME,@cUDF01,103) --(yeekung01)
            	
               -- check if order date not more than campaign end date
               IF DATEDIFF( dd, @cUDF01, @dOrderDate) <= 0
               BEGIN
                  SET @nErrNo = 0

                  IF ISNULL( @cDescr, '') <> ''
                  BEGIN
                     SET @cErrMsg01 = rdt.rdtgetmessage( 110104, @cLangCode, 'DSP')
                     SET @cErrMsg02 = SUBSTRING( @cDescr, 1, 20)
                  END
                  ELSE
                     SET @cErrMsg01 = rdt.rdtgetmessage( 110104, @cLangCode, 'DSP')

                  SET @nPackaging = 1
               END
            END   -- rdt.rdtIsValidDate(@cUDF01) = 1
         END      -- ISNULL( @cBUSR4, '') <> ''

         IF ISNULL( @cOVAS, '') <> ''
         BEGIN
            SET @cUDF01 = ''
            SET @cDescr = ''

            SELECT @cUDF01 = UDF01, -- campaign end date
                   @cDescr = [Description]
            FROM dbo.CODELKUP WITH (NOLOCK) 
            WHERE Storerkey = @cStorerkey
            AND   LISTNAME = 'VASCode'
            AND   Code = @cOVAS
            AND   Short = '1'            

            IF rdt.rdtIsValidDate(@cUDF01) = 1
            BEGIN

            	SET @cUDF01 = CONVERT (DATETIME,@cUDF01,103) --(yeekung01)

               -- check if order date not more than campaign end date
               IF DATEDIFF( dd, @cUDF01, @dOrderDate) <= 0
               BEGIN
                  SET @nErrNo = 0

                  IF @nPackaging = 0
                  BEGIN
                     IF ISNULL( @cDescr, '') <> ''
                     BEGIN
                        SET @cErrMsg01 = rdt.rdtgetmessage( 110105, @cLangCode, 'DSP')
                        SET @cErrMsg02 = SUBSTRING( @cDescr, 1, 20)
                     END
                     ELSE
                        SET @cErrMsg01 = rdt.rdtgetmessage( 110105, @cLangCode, 'DSP')
                  END
                  ELSE -- IF @nPackaging = 1
                  BEGIN
                     IF ISNULL( @cDescr, '') <> ''
                     BEGIN
                        SET @cErrMsg04 = rdt.rdtgetmessage( 110105, @cLangCode, 'DSP')
                        SET @cErrMsg05 = SUBSTRING( @cDescr, 1, 20)
                     END
                     ELSE
                        SET @cErrMsg04 = rdt.rdtgetmessage( 110105, @cLangCode, 'DSP')
                  END

                  SET @nVAS = 1
               END
            END   -- rdt.rdtIsValidDate(@cUDF01) = 1
         END      -- IF ISNULL( @cOVAS, '') <> ''

         -- Nothing to display then no need display msg queue
         IF @nPackaging = 0 AND @nVAS = 0
            GOTO Quit
         
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
         @cErrMsg01, @cErrMsg02, @cErrMsg03, @cErrMsg04, @cErrMsg05, 
         @cErrMsg06, @cErrMsg07, @cErrMsg08, @cErrMsg09, @cErrMsg10, 
         @cErrMsg11, @cErrMsg12, @cErrMsg13, @cErrMsg14, @cErrMsg15
         SET @nErrNo = 0   -- Reset error no
      END
   END

QUIT:

GO