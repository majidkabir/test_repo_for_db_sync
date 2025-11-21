SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtExtPrintJACKW02                                  */
/* Purpose: Extended printing for Jack Will TNT label                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-08-14 1.0  James      SOS#316568 Created                        */  
/* 2014-12-18 1.1  James      SOS#327809 If pick = pack for orders then */
/*                            only confirm packheader (james01)         */
/* 2015-09-29 1.2  James      SOS353616 - Add print NDD label  (james02)*/
/* 2015-10-21 1.3  James      Add Incoterm 3 to print NDD label(james03)*/
/************************************************************************/

CREATE PROC [RDT].[rdtExtPrintJACKW02] (
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR( 3), 
   @nStep           INT, 
   @nInputKey       INT, 
   @cStorerkey      NVARCHAR( 15), 
   @cOrderkey       NVARCHAR( 10), 
   @cSku            NVARCHAR( 20), 
   @cToteNo         NVARCHAR( 18), 
   @cDropIDType     NVARCHAR( 10), 
   @cPrevOrderkey   NVARCHAR( 10), 
   @nErrNo          INT   OUTPUT, 
   @cErrMsg         NVARCHAR( 215)  OUTPUT 
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

   DECLARE @nTranCount     INT, 
           @nDebug         INT 

   DECLARE @cRoute         NVARCHAR( 10), 
           @cPickSlipNo    NVARCHAR( 10), 
           @nCartonNo      INT, 
           @nPrintErrNo    INT, 
           @bSuccess       INT, 
           @cLabelNo       NVARCHAR( 20), 
           @cPrinter       NVARCHAR( 10), 
           @cPrinter_Paper NVARCHAR( 10), 
           @cReportType    NVARCHAR( 10), 
           @cDataWindow    NVARCHAR( 50), 
           @cTargetDB      NVARCHAR( 20), 
           @cPrintJobName  NVARCHAR( 50), 
           @cDocumentFilePath NVARCHAR( 1000), 
           @cIncoTerm      NVARCHAR( 10), 
           @nUnpicked      INT, 
           @nTotalPickQty  INT, 
           @nTotalPackQty  INT  

   DECLARE @cOptional_Parm3   NVARCHAR( 20)

   set @nDebug = 0
   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdtExtPrintJACKW02

   IF @nFunc <> 1712
      GOTO Quit

   SELECT @cPrinter = Printer, @cPrinter_Paper = Printer_Paper FROM rdt.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

   SELECT @cIncoTerm = IncoTerm FROM dbo.Orders WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND OrderKey = @cOrderkey

   IF ISNULL(@cPrinter, '') = ''      
      GOTO Quit      

   SELECT @cPickSlipNo = PickSlipno 
   FROM dbo.PackHeader WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   OrderKey = @cOrderKey

   -- Skip printing is incoterm = 'CC'
   IF @cIncoTerm <> 'CC'
   BEGIN
      /********************************  
         CALL METAPACK & PRINT Label   
      *********************************/ 
      DECLARE CUR_PRINT CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT DISTINCT CartonNo, LabelNo 
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   PickSlipNo = @cPickSlipno
      AND   DropID = @cToteNo
      ORDER BY 1
      OPEN CUR_PRINT
      FETCH NEXT FROM CUR_PRINT INTO @nCartonNo, @cLabelNo
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         EXEC [dbo].isp_WS_Metapack_AllocationService 
            @nMobile, 
            @cPickSlipNo, 
            @nCartonNo, 
            @cLabelNo, 
            @cDocumentFilePath   OUTPUT, 
            @bSuccess            OUTPUT, 
            @nErrNo              OUTPUT, 
            @cErrMsg             OUTPUT 

         IF @bSuccess <> 1 
         BEGIN  
            CLOSE CUR_PRINT
            DEALLOCATE CUR_PRINT
            GOTO PRINT_MANIFEST
         END     

         FETCH NEXT FROM CUR_PRINT INTO @nCartonNo, @cLabelNo
      END
      CLOSE CUR_PRINT
      DEALLOCATE CUR_PRINT

      SET @nUnpicked = 0  
      SELECT @nUnpicked = Count(1)  
      FROM  dbo.PICKDETAIL PK WITH (nolock)  
      WHERE PK.Orderkey = @cOrderkey  
      AND   PK.Status < '5'   
      AND   PK.Qty > 0     

      -- (james01)
      SELECT @nTotalPickQty = SUM(ISNULL(PK.Qty,0))   
      FROM  dbo.PICKDETAIL PK WITH (nolock)  
      WHERE PK.Orderkey = @cOrderkey  
              
      SELECT @nTotalPackQty = SUM(ISNULL(PD.Qty,0))  
      FROM  dbo.PACKDETAIL PD WITH (NOLOCK)  
      JOIN  dbo.PACKHEADER PH WITH (NOLOCK) ON (PD.PickslipNo = PH.PickSlipNo AND PH.Orderkey = @cOrderkey)  

      -- If all item picks and pick = pack then pack confirm
      IF @nUnpicked = 0 AND (@nTotalPickQty = @nTotalPackQty)
      BEGIN  
         UPDATE dbo.PACKHeader WITH (ROWLOCK)  
         SET   Status = '9', ArchiveCop=NULL   
         WHERE Orderkey = @cOrderkey  
         AND   Status = '0'  

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 57101  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackHdrFail'  
            GOTO RollBackTran  
         END  
      END

      -- Stamp label printed for tote
      UPDATE DROPID WITH (ROWLOCK)  
        SET LabelPrinted = 'Y',  
            PickSlipNo = CASE WHEN ISNULL( PickSlipno, '') = '' THEN @cPickSlipno ELSE PickSlipno END -- (james01)
      WHERE Dropid = @cToteNo                  

      IF @@ERROR <> 0   
      BEGIN  
         SET @nErrNo = 57102  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIdFailed'  
         GOTO RollBackTran  
      END     
   END
   ELSE  -- Click & Collect label
   BEGIN
      SET @cReportType = 'CCBAGLABEL'                
      SET @cPrintJobName = 'PRINT_BAGLABEL'        

      SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
             @cTargetDB = ISNULL(RTRIM(TargetDB), '')   
      FROM RDT.RDTReport WITH (NOLOCK)   
      WHERE StorerKey = @cStorerKey
      AND ReportType = @cReportType  

      IF ISNULL(RTRIM(@cDataWindow),'') = ''    
      BEGIN    
         SET @nErrNo = 57103    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LabelNOTSetup'    
         GOTO RollBackTran    
      END    
       
      IF ISNULL(RTRIM(@cTargetDB),'') = ''    
      BEGIN    
         SET @nErrNo = 57104    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NoManfstTgetDB'  
         GOTO RollBackTran    
      END    

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
         @cOrderkey,  
         ' ',        
         ' '         

      IF @nErrNo <> 0
      BEGIN    
         SET @nErrNo = 57105    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Print Lbl Fail'  
         GOTO RollBackTran    
      END    

      SET @nUnpicked = 0  
      SELECT @nUnpicked = Count(1)  
      FROM  dbo.PICKDETAIL PK WITH (nolock)  
      WHERE PK.Orderkey = @cOrderkey  
      AND   PK.Status < '5'   
      AND   PK.Qty > 0     
     
      IF @nUnpicked = 0  
      BEGIN  
         UPDATE dbo.PACKHeader WITH (ROWLOCK)  
         SET   Status = '9', ArchiveCop=NULL   
         WHERE Orderkey = @cOrderkey  
         AND   Status = '0'  

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 57106  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackHdrFail'  
            GOTO RollBackTran  
         END  

         UPDATE DROPID WITH (ROWLOCK)  
           SET LabelPrinted = 'Y'  
         WHERE Dropid = @cToteNo  

         IF @@ERROR <> 0   
         BEGIN  
            SET @nErrNo = 57107  
            SET @cErrMsg = rdt.rdtgetmessage( 70136, @cLangCode, 'DSP') --'UpdDropIdFailed'  
            GOTO RollBackTran  
         END     
      END   --@nUnpicked = 0
   END

   -- Print NDD label (james02)/(james03)
   IF @cIncoTerm IN ('3', '19') AND 
      EXISTS ( SELECT 1 FROM rdt.rdtReport WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   ReportType = 'NDDLABEL')   
   BEGIN
      SET @cReportType = 'NDDLABEL'                
      SET @cPrintJobName = 'PRINT_NDDLABEL'        
        
      SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
             @cTargetDB = ISNULL(RTRIM(TargetDB), '')   
      FROM RDT.RDTReport WITH (NOLOCK)   
      WHERE StorerKey = @cStorerKey  
      AND ReportType = @cReportType                  
        
      IF ISNULL(RTRIM(@cDataWindow),'') = ''    
      BEGIN    
         SET @nErrNo = 57108    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NDDLblNOTSetup'    
         GOTO RollBackTran    
      END    
       
      IF ISNULL(RTRIM(@cTargetDB),'') = ''    
      BEGIN    
         SET @nErrNo = 57109    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NoManfstTgetDB'  
         GOTO RollBackTran    
      END    

      --(Kc06) - start  
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
         @cOrderkey

      IF @nErrNo <> 0             
         GOTO RollBackTran  
   END

   PRINT_MANIFEST:
   /********************************  
      PRINT Manifest Report   
   *********************************/  
   -- If report setup only need to print
   IF EXISTS ( SELECT 1 FROM rdt.rdtReport WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   ReportType = 'BAGMANFEST')
   BEGIN
      SET @cReportType = 'BAGMANFEST'                
      SET @cPrintJobName = 'PRINT_BAGMANFEST'        
        
      SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
             @cTargetDB = ISNULL(RTRIM(TargetDB), '')   
      FROM RDT.RDTReport WITH (NOLOCK)   
      WHERE StorerKey = @cStorerKey  
      AND ReportType = @cReportType                  
        
      IF ISNULL(RTRIM(@cDataWindow),'') = ''    
      BEGIN    
         SET @nErrNo = 57110    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ManfstNOTSetup'    
         GOTO RollBackTran    
      END    
       
      IF ISNULL(RTRIM(@cTargetDB),'') = ''    
      BEGIN    
         SET @nErrNo = 57111    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NoManfstTgetDB'  
         GOTO RollBackTran    
      END    

      -- (james13)
      IF rdt.RDTGetConfig( @nFunc, 'SkipParkTote', @cStorerKey) IN ('', '0')
         SET @cOptional_Parm3 = ' '
      ELSE
         SET @cOptional_Parm3 = @cToteNo

      --(Kc06) - start  
      SET @nErrNo = 0  
      EXEC RDT.rdt_BuiltPrintJob   
         @nMobile,  
         @cStorerKey,  
         @cReportType,  
         @cPrintJobName,  
         @cDataWindow,  
         @cPrinter_Paper,  
         @cTargetDB,  
         @cLangCode,  
         @nErrNo  OUTPUT,  
         @cErrMsg OUTPUT,  
         @cStorerKey,  
         @cOrderkey,
         @cOptional_Parm3          
        
      IF @nErrNo <> 0             
         GOTO RollBackTran  
      ELSE
      BEGIN  
         UPDATE DROPID WITH (ROWLOCK)  
           SET ManifestPrinted = 'Y'  
         WHERE Dropid = @cToteNo     

         IF @@ERROR <> 0   
         BEGIN  
            SET @nErrNo = 57112  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIdFailed'  
            GOTO RollBackTran  
         END     
      END  
   END
   GOTO Quit

   RollBackTran:
   ROLLBACK TRAN rdtExtPrintJACKW02
   
QUIT:
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
         COMMIT TRAN rdtExtPrintJACKW02

GO