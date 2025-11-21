SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_868ExtUpd05                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: Print pdf file                                              */
/*                                                                      */
/* Called from: rdtfnc_PickAndPack                                      */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-05-14 1.0  James      WMS-13125. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_868ExtUpd05] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT,
   @nInputKey   INT,
   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cOrderKey   NVARCHAR( 10),
   @cLoadKey    NVARCHAR( 10),
   @cDropID     NVARCHAR( 20),
   @cSKU        NVARCHAR( 20),
   @cADCode     NVARCHAR( 18),
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nSumPackQTY       INT
   DECLARE @nSumPickQTY       INT
   DECLARE @cDocType          NVARCHAR( 1)
   DECLARE @cPickSlipNo       NVARCHAR( 10)
   DECLARE @cTrackingNo       NVARCHAR( 30)
   DECLARE @cShipperKey       NVARCHAR( 15)
   DECLARE @cWinPrinter       NVARCHAR(128)  
   DECLARE @cLabelPrinter     NVARCHAR( 10)
   DECLARE @cFilePath         NVARCHAR(100)       
   DECLARE @cPrintFilePath    NVARCHAR(100)      
   DECLARE @cPrintCommand     NVARCHAR(MAX)    
   DECLARE @cReportType       NVARCHAR( 10)
   DECLARE @cFilePrefix       NVARCHAR( 30)
   DECLARE @cPrinterName      NVARCHAR(100)   
   DECLARE @cWinPrinterName   NVARCHAR(100)   
   DECLARE @cFileName         NVARCHAR( 50)    

   IF @nFunc = 868 -- Pick and pack
   BEGIN
      IF @nStep = 7 -- Capture packinfo
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT @cPickSlipNo = V_PickSlipNo
            FROM RDT.RDTMOBREC WITH (NOLOCK)
            WHERE Mobile = @nMobile
            
            SELECT @nSumPackQTY = ISNULL(SUM(QTY)  , 0)
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
               AND StorerKey = @cStorerKey

            SELECT @nSumPickQTY = ISNULL(SUM(QTY), 0)
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE Orderkey = @cOrderKey
            AND   StorerKey = @cStorerKey

            IF @nSumPackQTY = @nSumPickQTY
            BEGIN
               UPDATE dbo.PackHeader WITH (ROWLOCK) SET
                  STATUS = '9'
                  --ArchiveCop = NULL
               WHERE PickSlipNo = @cPickSlipNo

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 163101
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PackCfm Fail'
                  GOTO Quit
               END
            END
         END
      END
   END

Quit:


GO