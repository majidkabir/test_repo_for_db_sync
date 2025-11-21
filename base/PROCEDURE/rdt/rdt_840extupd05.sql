SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtUpd05                                     */
/* Purpose: Trigger HM related interface and misc update                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2017-11-02 1.0  James      WMS3212. Created                          */
/* 2021-04-01 1.1 YeeKung    WMS-16717 Add serialno and serialqty      */
/*                            Params (yeekung01)                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtUpd05] (
   @nMobile     INT,
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3), 
   @nStep       INT, 
   @nInputKey   INT, 
   @cStorerkey  NVARCHAR( 15), 
   @cOrderKey   NVARCHAR( 10), 
   @cPickSlipNo NVARCHAR( 10), 
   @cTrackNo    NVARCHAR( 20), 
   @cSKU        NVARCHAR( 20), 
   @nCartonNo   INT,
   @cSerialNo   NVARCHAR( 30), 
   @nSerialQTY  INT,  
   @nErrNo      INT           OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF 

   DECLARE @nTranCount        INT, 
           @nExpectedQty      INT,
           @nPackedQty        INT, 
           @cReportType       NVARCHAR( 10),
           @cPrintJobName     NVARCHAR( 50), 
           @cDataWindow       NVARCHAR( 50),
           @cTargetDB         NVARCHAR( 20), 
           @cPrinter          NVARCHAR( 10), 
           @cPrinter_Paper    NVARCHAR( 10), 
           @cLoadKey          NVARCHAR( 10),
           @cShipperKey       NVARCHAR( 15),
           @cTrackingNo       NVARCHAR( 20),
           @cExternOrderKey   NVARCHAR( 30),
           @cGUIExtOrderKey   NVARCHAR( 30),
           @cInvoiceNo        NVARCHAR( 10),
           @cPrintData        NVARCHAR( MAX),
           @cLabels           NVARCHAR( MAX),
           @cVBErrMsg         NVARCHAR( MAX),
           @nOriginalQty   INT,
           @nPickQty       INT,
           @nPackQty       INT,
           @nRowRef        INT,

          @cWorkingFilePath  NVARCHAR( 250),
          @cFilePath         NVARCHAR( 250),
          @cDelFilePath      NVARCHAR( 250),
          @cFileName         NVARCHAR( 100),
          @cPrintFilePath    NVARCHAR( 250),
          @cChkFilePath      NVARCHAR( 250),
          @cCMD              NVARCHAR( 1000),
          @cFileType         NVARCHAR( 10),
          @cPrintServer      NVARCHAR( 50),
          @cStringEncoding   NVARCHAR( 30),
          @cLineNumber       NVARCHAR( 6),
          @cCarrierName      NVARCHAR( 30),
          @cKeyName          NVARCHAR( 30),
          @cKey2             NVARCHAR( 30),
          @nReturnCode       INT,
          @isExists          INT,
          @bSuccess          INT,
          @nSeasonCodeDiff   INT,
          @nShortPack        INT,
          @nShortAlloc       INT 

   DECLARE @c_AlertMessage       NVARCHAR(512), 
           @c_NewLineChar        NVARCHAR(2), 
           @c_PrintErrmsg        NVARCHAR(250), 
           @b_success            INT,
           @n_Err                INT

   DECLARE @cErrMsg01        NVARCHAR( 20),
           @cErrMsg02        NVARCHAR( 20)

   SET @cErrMsg01 = ''
   SET @cErrMsg02 = ''

   IF @nStep = 4
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK) 
                      JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)
                      WHERE C.ListName = 'HMORDTYPE'
                      AND   C.Short = 'S'
                      AND   O.OrderKey = @cOrderkey
                      AND   O.StorerKey = @cStorerKey)
         -- No need continue process if not customer orders
         GOTO QuickQuit

      SET @nTranCount = @@TRANCOUNT  
      BEGIN TRAN  -- Begin our own transaction  
      SAVE TRAN rdt_840ExtUpd05 -- For rollback or commit only our own transaction  

      SET @nSeasonCodeDiff = 0
      SET @nShortPack = 0
      SET @nShortAlloc = 0

      -- Get the related printing info, path, file type, etc
      SELECT @cWorkingFilePath = UDF01,
             @cFileType = UDF02,
             @cPrintServer = UDF03,
             @cStringEncoding = UDF04,
             @cPrintFilePath = Notes   -- foxit program
      FROM dbo.CODELKUP WITH (NOLOCK) 
      WHERE ListName = 'PrintLabel' 
      AND   Code = 'FilePath'
      AND   Storerkey = @cStorerKey
      AND   (( ISNULL( code2, '') = '') OR ( code2 = 'PDF'))

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 116660
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Setup CODEKLP'  
         GOTO RollBackTran
      END

      SELECT @cGUIExtOrderKey = BuyerPO
      FROM dbo.ORDERS WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey
      AND   StorerKey = @cStorerkey

      -- The Order and Invoice will be 1:1 relationship 
      SELECT TOP 1 @cInvoiceNo = InvoiceNo
      FROM dbo.GUIDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
      AND   ExternOrderKey = @cGUIExtOrderKey
      ORDER BY 1

      -- Construct print file
      SET @cFileName = RTRIM( @cGUIExtOrderKey) + '-' + RTRIM( @cInvoiceNo) + '.' + @cFileType
      SET @cFilePath = RTRIM( @cWorkingFilePath) + '\' + @cFileName
      SET @cDelFilePath = 'DEL ' + RTRIM( @cWorkingFilePath) + '\' + @cFileName

      -- Compare SeasonCode (pickdetail.lotattable01, orderdetail.lottable01)
      CREATE TABLE #PD_Lot01 (
         ROWREF      INT IDENTITY(1,1) NOT NULL,
         Lottable01  NVARCHAR(18)  NULL)

      INSERT INTO #PD_Lot01 ( Lottable01)
      SELECT DISTINCT LA.Lottable01
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON ( PD.LOT = LA.LOT)
      WHERE PD.OrderKey = @cOrderKey
      AND   PD.Status < '9'

      -- If different, delete invoice and trigger order status I
      IF EXISTS ( SELECT 1 FROM dbo.ORDERDETAIL OD WITH (NOLOCK)
                  WHERE OD.StorerKey = @cStorerKey
                  AND   OD.OrderKey = @cOrderKey
                  AND   OD.Status < '9'                  
                  AND   NOT EXISTS ( SELECT 1 FROM #PD_Lot01 L1 WHERE L1.Lottable01 = OD.Lottable01))
         SET @nSeasonCodeDiff = 1

      IF EXISTS ( SELECT 1 FROM dbo.OrderDetail WITH (NOLOCK) 
                  WHERE OrderKey = @cOrderKey
                  AND   StorerKey = @cStorerkey
                  GROUP BY OrderKey
                  HAVING SUM( EnteredQty) <> SUM( QtyAllocated + QtyPicked))
         SET @nShortAlloc = 1

      SELECT @nOriginalQty = ISNULL( SUM( OriginalQty), 0)
      FROM dbo.Orders O WITH (NOLOCK)
      JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON ( O.OrderKey = OD.OrderKey)
      WHERE O.OrderKey = @cOrderKey
      AND   O.StorerKey = @cStorerkey

      SELECT @nPackQty = ISNULL( SUM( QTY), 0)
      FROM dbo.PackDetail PD WITH (NOLOCK)
      JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
      WHERE PH.OrderKey = @cOrderKey
      AND   PH.StorerKey = @cStorerkey

      --SELECT @nPickQty = ISNULL( SUM( QTY), 0)
      --FROM dbo.PickDetail WITH (NOLOCK)
      --WHERE OrderKey = @cOrderKey
      --AND   StorerKey = @cStorerkey

      -- Compare packed qty to order qty to check if short qty
      IF @nOriginalQty > @nPackQty    
         SET @nShortPack = 1

      -- Short pick/pack or partial allocate need trigger order value recalculate
      IF @nShortAlloc = 1 OR @nShortPack = 1
      BEGIN
         -- Insert transmitlog2 here (trigger S272)
         SET @bSuccess = 1
         EXEC ispGenTransmitLog2 
             @c_TableName        = 'WSOrdRecalculate'
            ,@c_Key1             = @cOrderKey
            ,@c_Key2             = ''
            ,@c_Key3             = @cStorerkey
            ,@c_TransmitBatch    = ''
            ,@b_Success          = @bSuccess    OUTPUT
            ,@n_err              = @nErrNo      OUTPUT
            ,@c_errmsg           = @cErrMsg     OUTPUT      

         IF @bSuccess <> 1    
            GOTO RollBackTran

         UPDATE dbo.Orders WITH (ROWLOCK) SET
            SOStatus = 'PENDGET',
            Trafficcop = NULL,
            EditDate = GETDATE(),
            EditWho = sUSER_sNAME()
         WHERE StorerKey = @cStorerkey
         AND   OrderKey = @cOrderKey
         AND   SOStatus <> 'PENDGET'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 116653
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD PGET FAIL'
            GOTO RollBackTran
         END      
      END

      -- only pick=pack, season code same and fully allocated then only trigger RR1
      IF @nSeasonCodeDiff = 0 AND @nShortPack = 0 AND @nShortAlloc = 0
      BEGIN
         -- Same tracking no might be reused
         -- So it get rejected when insert TL2
         -- Get a unique key2 for rowref + key2 + storerkey
         EXECUTE nspg_getkey
		      @KeyName       = 'WSCRSOREQMP', 
		      @fieldlength   = 5,
		      @keystring     = @cKey2      OUTPUT,
		      @b_Success     = @bSuccess   OUTPUT,
		      @n_err         = @nErrNo     OUTPUT,
		      @c_errmsg      = @cErrMsg    OUTPUT,
            @b_resultset   = 0,
            @n_batch       = 1

         IF @bSuccess <> 1    
            GOTO RollBackTran

         -- Insert transmitlog2 here
         EXECUTE ispGenTransmitLog2 
            @c_TableName      = 'WSCRSOREQMP', 
            @c_Key1           = @cOrderKey, 
            @c_Key2           = @cKey2, 
            @c_Key3           = @cStorerkey, 
            @c_TransmitBatch  = '', 
            @b_Success        = @bSuccess   OUTPUT,    
            @n_err            = @nErrNo     OUTPUT,    
            @c_errmsg         = @cErrMsg    OUTPUT    

         IF @bSuccess <> 1    
            GOTO RollBackTran
      END

      IF @nSeasonCodeDiff = 1 OR @nShortPack = 1 OR @nShortAlloc = 1
      BEGIN
         -- Abnormal scenario: short pack, partial allocate or season code different
         -- then need delete invoice data and invoice pdf file and trigger interface

         -- Delete GUI where  GUI.ExternOrderKey = Orders.ExternOrderKey
         DECLARE CUR_DEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT LineNumber
         FROM dbo.GUIDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey 
         AND   ExternOrderKey = @cGUIExtOrderKey
         AND   InvoiceNo = @cInvoiceNo
         OPEN CUR_DEL
         FETCH NEXT FROM CUR_DEL INTO @cLineNumber
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            DELETE FROM dbo.GUIDetail 
            WHERE InvoiceNo = @cInvoiceNo 
            AND   ExternOrderkey = @cGUIExtOrderKey 
            AND   Storerkey = @cStorerKey 
            AND   LineNumber = @cLineNumber

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 116651
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL INVOICE ER
               CLOSE CUR_DEL
               DEALLOCATE CUR_DEL
               GOTO RollBackTran  
            END

            FETCH NEXT FROM CUR_DEL INTO @cLineNumber
         END
         CLOSE CUR_DEL
         DEALLOCATE CUR_DEL

         DELETE FROM dbo.GUI 
         WHERE Storerkey = @cStorerKey
         AND   InvoiceNo = @cInvoiceNo
         AND   ExternOrderKey = @cGUIExtOrderKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 116652
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL INVOICE ER
            GOTO RollBackTran  
         END

         -- Delete invoice pdf
         --EXEC master.dbo.xp_fileexist @cFilePath, @isExists OUTPUT

         SET @cChkFilePath = 'DIR ' + @cFilePath
         EXEC @isExists=XP_CMDSHELL @cChkFilePath

         --If @Exists=0, then the file exists. This saves having to declare and query a temp table, 
         --but requires that you know the file name and extension.
         IF @isExists = 0
            EXEC xp_cmdshell @cDelFilePath, no_output

         -- Insert transmitlog3 here (Trigger status I)
         SET @bSuccess = 1
         EXEC ispGenTransmitLog3 
             @c_TableName        = 'HHPCKCFMLG'
            ,@c_Key1             = @cOrderKey
            ,@c_Key2             = ''
            ,@c_Key3             = @cStorerkey
            ,@c_TransmitBatch    = ''
            ,@b_Success          = @bSuccess    OUTPUT
            ,@n_err              = @nErrNo      OUTPUT
            ,@c_errmsg           = @cErrMsg     OUTPUT      

         IF @bSuccess <> 1    
            GOTO RollBackTran
      END

      -- As for HM india use paper pick, pickdetail status will not update before using packing
      -- so after finish the packing need do pack confirm no matter short pack or not.
      IF rdt.RDTGetConfig( @nFunc, 'AutoPackConfirm', @cStorerKey) = '1'
      BEGIN
         -- Trigger pack confirm
         UPDATE dbo.PackHeader WITH (ROWLOCK) SET
            STATUS = '9',
            EditWho = 'rdt.' + sUser_sName(),
            EditDate = GETDATE()
         WHERE PickSlipNo = @cPickSlipNo
         AND   [Status] < '9'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 116654
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Packcfm fail
            GOTO RollBackTran  
         END
      END

      GOTO CommitTrans
   
      RollBackTran:  
            ROLLBACK TRAN rdt_840ExtUpd05  

      CommitTrans:  
         WHILE @@TRANCOUNT > @nTranCount  
            COMMIT TRAN  

      IF @nSeasonCodeDiff = 0 AND @nShortPack = 0 AND @nShortAlloc = 0
      BEGIN
         -- Check if invoice pdf file exists
         --EXEC master.dbo.xp_fileexist @cFilePath, @isExists OUTPUT

         SET @cChkFilePath = 'DIR ' + @cFilePath
         EXEC @isExists=XP_CMDSHELL @cChkFilePath

         --If @Exists=0, then the file exists. This saves having to declare and query a temp table, 
         --but requires that you know the file name and extension.
         IF @isExists <> 0
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg01 = rdt.rdtgetmessage( 116655, @cLangCode, 'DSP') -- No invoice
            SET @cErrMsg02 = rdt.rdtgetmessage( 116656, @cLangCode, 'DSP') -- Proceed to hospital

            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg01, @cErrMsg02

            SET @nErrNo = 0
            GOTO QuickQuit
         END

         SELECT @cPrinter = Printer_Paper
         FROM rdt.rdtMobRec WITH (NOLOCK)
         WHERE Mobile = @nMobile

         -- Check if valid printer 
         IF ISNULL( @cPrinter, '') = ''
         BEGIN
            SET @nErrNo = 116659
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No Printer'  
            GOTO QuickQuit
         END

         -- Print command
         SET @nReturnCode = 0
         --SET @cCMD = '""' + @cPrintFilePath + '" /t "' + @cWorkingFilePath + '\' + @cFileName + '" "' + @cPrintServer + '"'
         SET @cCMD = '""' + @cPrintFilePath + '" /t "' + @cWorkingFilePath + '\' + @cFileName + '" "' + @cPrinter + '"'

         DECLARE @tCMDError TABLE(
            ErrMsg NVARCHAR(250)
         )

         -- Send print command
         INSERT INTO @tCMDError
         EXEC @nReturnCode = xp_cmdshell @cCMD

         IF @nReturnCode <> 0
         BEGIN
            SET @c_NewLineChar =  master.dbo.fnc_GetCharASCII(13) + master.dbo.fnc_GetCharASCII(10)   

            SELECT TOP 1 @c_PrintErrmsg = Errmsg FROM @tCMDError

            -- Send Alert message
            SET @c_AlertMessage = 'ERROR in printing label with invoice #: ' + @cInvoiceNo + @c_NewLineChar   
            SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'EEROR: ' + RTRIM( @c_PrintErrmsg) + @c_NewLineChar   
            SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'PRINT CMD: ' + RTRIM( @cCMD) + @c_NewLineChar   
            SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'By User: ' + sUser_sName() + @c_NewLineChar   
            SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'DateTime: ' + CONVERT(NVARCHAR(20), GETDATE())  +  @c_NewLineChar   

            EXEC nspLogAlert  
                 @c_modulename         = 'rdt_840ExtUpd05'       
               , @c_AlertMessage       = @c_AlertMessage     
               , @n_Severity           = '5'         
               , @b_success            = @b_success     OUTPUT         
               , @n_err                = @nErrNo         OUTPUT           
               , @c_errmsg             = @cErrmsg        OUTPUT        
               , @c_Activity           = 'Print_Invoice'  
               , @c_Storerkey          = @cStorerkey      
               , @c_SKU                = ''            
               , @c_UOM                = ''            
               , @c_UOMQty             = ''         
               , @c_Qty                = ''  
               , @c_Lot                = ''           
               , @c_Loc                = ''            
               , @c_ID                 = ''               
               , @c_TaskDetailKey      = ''  
               , @c_UCCNo              = @cInvoiceNo        

            SET @nErrNo = 116662
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Print Error'  
            GOTO QuickQuit
         END

         -- If insert RDTPrintJob
         INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Printer, NoOfCopy, Mobile, TargetDB, JobType)
         VALUES('PRINT_INVOICE', 'INVOICE', '9', 'rdt_840ExtUpd05', '1', @cInvoiceNo, @cPrinter, 1, 0, '', 'DIRECTPRN')

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 116663
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins Job Fail'  
            GOTO QuickQuit
         END
      END
   END

   QuickQuit:


GO