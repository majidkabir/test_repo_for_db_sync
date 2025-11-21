SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtExtPrintJACKW01                                  */
/* Purpose: Extended printing for Jack Will TNT label                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-08-14 1.0  James      SOS#316568 Created                        */  
/************************************************************************/

CREATE PROC [RDT].[rdtExtPrintJACKW01] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15),   
   @cCaseID          NVARCHAR( 18), 
   @cLOC             NVARCHAR( 10), 
   @cSKU             NVARCHAR( 20), 
   @cConsigneekey    NVARCHAR( 15), 
   @nQTY             INT, 
   @cToToteNo        NVARCHAR( 18), 
   @cSuggPTSLOC      NVARCHAR( 10), 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

   DECLARE @nTranCount     INT, 
           @nDebug         INT 

   DECLARE @cRoute         NVARCHAR( 10), 
           @cOrderKey      NVARCHAR( 10),
           @cPickSlipNo    NVARCHAR( 10), 
           @nCartonNo      INT, 
           @nPrintErrNo    INT, 
           @bSuccess       INT, 
           @cLabelNo       NVARCHAR( 20), 
           @cPrinter       NVARCHAR( 10), 
           @cReportType    NVARCHAR( 10), 
           @cDataWindow    NVARCHAR( 50), 
           @cTargetDB      NVARCHAR( 20), 
           @cPrintJobName  NVARCHAR( 50)  

   set @nDebug = 0
   SET @nTranCount = @@TRANCOUNT

   -- Scan Out Start
   BEGIN TRAN
   SAVE TRAN rdtExtPrintJACKW01

   IF @nFunc NOT IN (973, 1711)
      GOTO Quit

   SELECT @cPrinter = Printer FROM rdt.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

   IF ISNULL(@cPrinter, '') = ''      
   BEGIN      
      GOTO Quit      
   END      

   SET @cRoute = ''
   
--   INSERT INTO TRACEINFO (TRACENAME, TIMEIN, COL1, COL2, COL3, COL4, COL5) VALUES 
--   ('PTS', GETDATE(), @cStorerKey, @cCaseID, @cSuggPTSLOC, @cSKU, @cConsigneeKey)
   IF @nFunc = 1711
      SELECT TOP 1 @cRoute = O.Route, @cOrderKey = O.OrderKey 
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      WHERE PD.StorerKey = @cStorerKey
      AND PD.CaseID = @cCaseID
      AND PD.LOC = @cSuggPTSLOC 
      AND PD.SKU = @cSKU
      AND PD.Status = '5'
      AND O.ConsigneeKey = @cConsigneeKey
   ELSE
      SELECT TOP 1 @cRoute = O.Route, @cOrderKey = O.OrderKey 
      FROM dbo.PackDetail PD WITH (NOLOCK) 
      JOIN dbo.PACKHEADER PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
      JOIN dbo.Orders O WITH (NOLOCK) ON PH.OrderKey = O.OrderKey
      JOIN dbo.DropID D WITH (NOLOCK) ON (PD.DROPID = D.DROPID AND D.LoadKey = O.LOADKEY)
      WHERE PD.Dropid = @cToToteNo 
      AND PD.Storerkey = @cStorerKey 
      AND O.USERDEFINE01 = '' 
      AND O.Status NOT IN ('9', 'CANC')

   IF ISNULL( @cRoute, '') <> 'TNT' 
   BEGIN
      SET @cReportType = 'SORTLABEL'      
      SET @cPrintJobName = 'PRINT_SORTLABEL'      

      SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),      
             @cTargetDB = ISNULL(RTRIM(TargetDB), '')      
      FROM RDT.RDTReport WITH (NOLOCK)      
      WHERE StorerKey = @cStorerKey      
      AND   ReportType = @cReportType      

      IF ISNULL(@cDataWindow, '') = ''  OR  ISNULL(@cTargetDB, '') = '' 
         GOTO Quit

      SET @nErrNo = 0      
      EXEC RDT.rdt_BuiltPrintJob      
         @nMobile,      
         @cStorerKey,      
         @cReportType,      
         @cPrintJobName,      
         @cDataWindow,      
         @cPrinter,      
         @cTargetDB,      
         @cLangCode,      
         @nErrNo  OUTPUT,      
         @cErrMsg OUTPUT,      
         @cStorerKey,      
         @cToToteNo      

      IF @nErrNo <> 0
         GOTO RollBackTran
      ELSE 
      BEGIN      
         UPDATE DROPID WITH (ROWLOCK)      
            SET LabelPrinted = 'Y'      
         WHERE Dropid = @cToToteNo  
         AND   LabelPrinted <> 'Y'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 50501
            GOTO RollBackTran
         END
      END
   END
   ELSE
   BEGIN
      SELECT @cPickSlipNo = PickSlipno 
      FROM dbo.PackHeader WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   OrderKey = @cOrderKey

      IF @nDebug = 1
         SELECT 'PickSlipNo', @cPickSlipNo, 'DropID', @cToToteNo

      -- 1 carton 1 TNT label
      SELECT TOP 1 @cLabelNo = LabelNo 
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   PickSlipNo = @cPickSlipno
      AND   DropID = @cToToteNo
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.CartonShipmentDetail WITH (NOLOCK) 
                      WHERE UCCLabelNo = RTRIM( @cLabelNo))
      BEGIN
         SET @nCartonNo = 1
         EXEC [dbo].[isp_WS_TNT_ExpressLabel] 
             @nMobile,         
             @cPickSlipNo,     
             @nCartonNo,       
             @cLabelNo,        
             @bSuccess        OUTPUT,  
             @nErrNo          OUTPUT,  
             @cErrMsg         OUTPUT 
      
         IF @bSuccess <> 1
         BEGIN
            SET @nErrNo = 50503
            GOTO Quit
         END
         ELSE
         BEGIN
            -- Print TNT label
            SET @cReportType = 'SORTTNTLBL'      
            SET @cPrintJobName = 'PRINT_SORTTNTLABEL'      
            
            SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),      
                   @cTargetDB = ISNULL(RTRIM(TargetDB), '')      
            FROM RDT.RDTReport WITH (NOLOCK)      
            WHERE StorerKey = @cStorerKey      
            AND   ReportType = @cReportType      

            IF ISNULL( @cDataWindow, '') <> ''
            BEGIN
               SET @nPrintErrNo = 0      
               EXEC RDT.rdt_BuiltPrintJob      
                  @nMobile,      
                  @cStorerKey,      
                  @cReportType,      
                  @cPrintJobName,      
                  @cDataWindow,      
                  @cPrinter,      
                  @cTargetDB,      
                  @cLangCode,      
                  @nPrintErrNo   OUTPUT,      
                  @cErrMsg       OUTPUT,   
                  @cToToteNo,    
                  @cStorerKey       

               IF @nPrintErrNo <> 0
                  GOTO RollBackTran
               ELSE 
               BEGIN      
                  UPDATE DROPID WITH (ROWLOCK)      
                     SET LabelPrinted = 'Y'      
                  WHERE Dropid = @cToToteNo  
                  AND   LabelPrinted <> 'Y'

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 50502
                     GOTO RollBackTran
                  END
               END
            END
         END
      END
   END
   GOTO Quit
   

   RollBackTran:
   ROLLBACK TRAN rdtExtPrintJACKW01
   
QUIT:
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
         COMMIT TRAN rdtExtPrintJACKW01

GO