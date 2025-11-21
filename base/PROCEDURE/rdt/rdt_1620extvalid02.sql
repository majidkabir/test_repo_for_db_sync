SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1620ExtValid02                                  */
/* Purpose: Cluster Pick Extended Validate SP for EAGLE                 */
/*          Make sure pickslip no exists before proceed picking         */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 10-Dec-2015 1.0  James      SOS356971 - Created                      */
/* 30-Nov-2017 1.1  James      WMS3572-Validate dropid format if dropid */
/*                             keyed in (james01)                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_1620ExtValid02] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerkey       NVARCHAR( 15), 
   @cWaveKey         NVARCHAR( 10), 
   @cLoadKey         NVARCHAR( 10), 
   @cOrderKey        NVARCHAR( 10), 
   @cLoc             NVARCHAR( 10), 
   @cDropID          NVARCHAR( 20), 
   @cSKU             NVARCHAR( 20), 
   @nQty             INT, 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cPickSlipNo          NVARCHAR( 10), 
           @cORD_StorerKey       NVARCHAR( 15), 
           @nMultiStorer         INT,
           @cPaperPrinter        NVARCHAR( 10),
           @cLabelPrinter        NVARCHAR( 10),
           @cReportType          NVARCHAR( 10),
           @cPrintJobName        NVARCHAR( 50),
           @cDataWindow          NVARCHAR( 50),
           @cTargetDB            NVARCHAR( 10)           

   SET @nErrNo = 0

   SET @nMultiStorer = 0
   IF EXISTS (SELECT 1 FROM dbo.StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerKey)
      SET @nMultiStorer = 1

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 3
      BEGIN
         IF @nMultiStorer = 1
            SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey =  @cOrderKey
      
         SET @cPickSlipNo = ''

         IF ISNULL( @cOrderKey, '') <> '' -- By LoadKey
         BEGIN
            -- check discrete first
            SELECT TOP 1 @cPickSlipNo = PickHeaderKey
            FROM dbo.PickHeader PH WITH (NOLOCK)
            WHERE PH.OrderKey = @cOrderKey
               AND PH.Status = '0'

            IF ISNULL( @cPickSlipNo, '') <> ''
               GOTO Quit
         END
         
         IF ISNULL(@cLoadKey, '') <> ''   -- By LoadKey
         BEGIN
            SELECT @cPickSlipNo = PickHeaderKey
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE ExternOrderKey = @cLoadKey
            AND   Status = '0'

            IF ISNULL( @cPickSlipNo, '') <> ''
               GOTO Quit            
         END
         
         IF ISNULL(@cWaveKey, '') <> ''   -- By WaveKey
         BEGIN
            SELECT @cPickSlipNo = PickHeaderKey
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE WaveKey = @cWaveKey
            AND   Status = '0'

            IF ISNULL( @cPickSlipNo, '') <> ''
               GOTO Quit            
         END

         -- Check if pickslip printed
         IF ISNULL(@cPickSlipNo, '') = ''
         BEGIN
            SET @nErrNo = 95501
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKSLIPNotPrinted
            GOTO Quit
         END            
      END
      
      IF @nStep = 7
      BEGIN
         IF @cDropID = '' OR SUBSTRING( @cDropID, 1, 2) <> 'ID'
         BEGIN
            IF EXISTS (SELECT 1 FROM rdt.rdtReport WITH (NOLOCK)
                       WHERE StorerKey = @cStorerKey
                       AND   ReportType = 'CARTONLBL')
            BEGIN
               SELECT @cLabelPrinter = Printer 
               FROM RDT.RDTMOBREC WITH (NOLOCK) 
               WHERE Mobile = @nMobile

               IF ISNULL(@cLabelPrinter, '') = ''
               BEGIN
                  SET @nErrNo = 95502
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLabelPrinter
                  GOTO Quit
               END
            END
         END
         ELSE  -- @cDropID <> '' (james01)
         BEGIN
            IF SUBSTRING(@cDropID, 1, 2) + SUBSTRING(@cDropID, 3, 10) <> 'ID' + @cOrderKey
            BEGIN
               SET @nErrNo = 95503
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKSLIPNotPrinted
               GOTO Quit
            END   
         END
      END
   END

QUIT:

GO