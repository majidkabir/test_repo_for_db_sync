SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/        
/* Store procedure: rdt_840ExtUpd06                                     */        
/* Purpose: Trigger HM related interface and misc update                */        
/*          Copy from rdt_840ExtUpd05 and abandon cmdshell method       */        
/* Modifications log:                                                   */        
/*                                                                      */        
/* Date       Rev  Author     Purposes                                  */        
/* 2018-10-09 1.0  James      Created                                   */        
/* 2019-03-15 1.1  James      WMS8270-Add Myntra interface (james01)    */        
/* 2019-08-20 1.2  James      WMS-10299 Move file after print (james02) */        
/* 2019-09-27 1.3  James      WMS-10765 Auto compute weight (james03)   */        
/* 2020-10-01 1.4  James      WMS-15345 Add config to decide whether    */        
/*                            need delete invoice (james04)             */        
/* 2021-03-17 1.5  James      WMS-16580 Add checking on certain orders  */    
/*                            cannot split carton when packing (james05)*/    
/* 2021-04-01 1.6 YeeKung     WMS-16717 Add serialno and serialqty      */    
/*                            Params (yeekung01)                        */    
/* 2021-07-30 1.7  James      WMS16847-Season code enhance (james06)    */    
/*                            Remove pdf printing                       */    
/* 2022-12-07 1.8  James      WMS-21324 Add print param (james07)       */  
/* 2022-12-19 1.9  James      WMS-21295 Add print SSCC label (james08)  */
/* 2023-01-04 2.0  James      WMS-21465 Change the Orders.BuyerPO       */
/*                            linkage to Orders.ExternOrderKey =        */
/*                            GUI.ExternOrderkey (james09)              */
/* 2023-01-09 2.1  James      WMS-21295 Move orders not check for single*/
/*                            carton (james10)                          */
/* 2023-03-02 2.2  James      WMS-21803 Only customer orders need delete*/
/*                            invoice and send interface (james11)      */
/*                            Insert msg prompt when delete invoice     */
/************************************************************************/        
        
CREATE   PROC [RDT].[rdt_840ExtUpd06] (        
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
          @cMoveFileCMD      NVARCHAR( MAX),        
          @cFileType         NVARCHAR( 10),        
          @cPrintServer      NVARCHAR( 50),        
          @cStringEncoding   NVARCHAR( 30),        
          @cLineNumber       NVARCHAR( 6),        
          @cCarrierName      NVARCHAR( 30),        
          @cKeyName          NVARCHAR( 30),        
          @cKey2             NVARCHAR( 30),        
          @nReturnCode       INT,        
          @nFileExists       INT,        
          @bSuccess          INT,        
          @nSeasonCodeDiff   INT,        
          @nShortPack        INT,        
          @nShortAlloc       INT,        
          @cPrinterName      NVARCHAR( 100),        
          @cWinPrinter       NVARCHAR( 128),        
          @cFacility         NVARCHAR( 5),        
          @cORDLabel         NVARCHAR( 10),        
          @cCode             NVARCHAR( 10),        
          @nShortPick        INT = 0,        
          @nInvoiceDel       INT = 0,
          @cErrMsg1          NVARCHAR( 20),
          @cErrMsg2          NVARCHAR( 20),
          @cErrMsg3          NVARCHAR( 20),
          @cErrMsg4          NVARCHAR( 20),
          @cErrMsg5          NVARCHAR( 20)
          
   DECLARE @c_AlertMessage       NVARCHAR(512),        
           @c_NewLineChar        NVARCHAR(2),        
           @c_PrintErrmsg        NVARCHAR(250),        
           @b_success            INT,        
           @n_Err                INT        
        
   DECLARE @cErrMsg01        NVARCHAR( 20),        
           @cErrMsg02        NVARCHAR( 20)        
        
   DECLARE @iHr  INT        
   DECLARE @iObjFileSystem INT        
        
   DECLARE @nMyntra        INT        
   DECLARE @cORD_Status    NVARCHAR( 10)        
   DECLARE @cWinPrinterName   NVARCHAR( 100)        
   DECLARE @cFolder2Move   NVARCHAR( 100)        
   DECLARE @fSKUWeight     REAL        
   DECLARE @fCtnWeight     REAL        
   DECLARE @cPrintCommand  NVARCHAR(MAX)            
   DECLARE @cSeasonSwapInvoiceRev   NVARCHAR( 1)   -- (james04)        
   DECLARE @nTtl_OrdQty    INT     
   DECLARE @nTtl_PckQty    INT     
   DECLARE @cInvoice       NVARCHAR( 10)    
   DECLARE @cSSCCLabel     NVARCHAR( 10)
   DECLARE @nIsMoveOrders  INT = 0
   DECLARE @curDelPD       CURSOR 
   DECLARE @cPickDetailKey NVARCHAR( 10)
               
   SET @nMyntra = 0        
        
   SET @cErrMsg01 = ''        
   SET @cErrMsg02 = ''        
    
   -- (james05)    
   IF @nStep = 3    
   BEGIN    
      IF @nInputKey = 0    
      BEGIN    
      	-- Check if it is Move orders (james10)
         IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)        
                     JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)        
                     WHERE C.ListName = 'HMORDTYPE'        
                     AND   C.Short = 'M'        
                     AND   O.OrderKey = @cOrderkey        
                     AND   O.StorerKey = @cStorerKey)        
            SET @nIsMoveOrders = 1
         
         -- According to India LIT, only customer orders need have below checking (james10)
         IF EXISTS ( SELECT 1 FROM dbo.orders WITH (NOLOCK)    
                     WHERE OrderKey = @cOrderKey    
                     AND   [Type] <> 'R') AND @nIsMoveOrders = 0   
         BEGIN    
            IF @nCartonNo > 1    
            BEGIN    
               SET @nErrNo = 133417      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- Only 1 carton    
               GOTO Quit    
            END    
                
            SELECT @nTtl_OrdQty = ISNULL( SUM( QTY), 0)    
            FROM dbo.PickDetail WITH (NOLOCK)    
            WHERE OrderKey = @cOrderkey    
            AND   [Status] NOT IN ('4', '9')    
    
            SELECT @nTtl_PckQty = ISNULL( SUM( QTY), 0)    
            FROM dbo.PackDetail WITH (NOLOCK)    
            WHERE PickSlipNo = @cPickSlipNo    
    
            -- If order still has something to pack, not allow     
            -- to split carton.     
            IF @nTtl_OrdQty > @nTtl_PckQty    
            BEGIN    
               SET @nErrNo = 133418      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- X FINISH PACK    
               GOTO Quit    
            END    
         END    
      END       
   END    
           
   IF @nStep = 4        
   BEGIN        
      IF @nInputKey = 1        
      BEGIN        
         SELECT @cPrinter = Printer,        
                @cPrinter_Paper = Printer_Paper,        
                @cFacility = Facility        
         FROM rdt.rdtMobRec WITH (NOLOCK)        
         WHERE Mobile = @nMobile    
               
         IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)        
                     JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)        
                     WHERE C.ListName = 'HMORDTYPE'        
                     AND   C.Short = 'S'        
                     AND   O.OrderKey = @cOrderkey        
                     AND   O.StorerKey = @cStorerKey)        
         BEGIN
         	-- Sales orders (customer orders)
            -- Check if myntra orders        
            IF EXISTS ( SELECT 1 FROM dbo.ORDERS WITH (NOLOCK)        
                        WHERE OrderKey = @cOrderKey        
                        AND   StorerKey = @cStorerkey        
              AND   M_STATE like 'MYN%')        
            BEGIN        
               SET @nMyntra = '1'        
            END        
        
            IF @nMyntra = '1'        
               SET @cCode = 'QSFilePath'        
            ELSE        
               SET @cCode = 'FilePath'        
        
            SET @nSeasonCodeDiff = 0        
            SET @nShortPack = 0        
            SET @nShortAlloc = 0        
        
            SET @cFolder2Move = ''        
        
            -- Get the related printing info, path, file type, etc        
            SELECT @cWorkingFilePath = UDF01,        
                   @cFileType = UDF02,        
                   @cPrintServer = UDF03,        
                   @cStringEncoding = UDF04,        
                   @cFolder2Move = UDF05,        
                   @cPrintFilePath = Notes   -- foxit program        
            FROM dbo.CODELKUP WITH (NOLOCK)        
            WHERE ListName = 'PrintLabel'        
            AND   Code = @cCode        
            AND   Storerkey = @cStorerKey        
            AND   (( ISNULL( code2, '') = '') OR ( code2 = 'PDF'))        
        
            IF @@ROWCOUNT = 0        
            BEGIN        
               SET @nErrNo = 133401        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Setup CODEKLP'        
               GOTO RollBackTran        
            END        
        
            SELECT @cGUIExtOrderKey = BuyerPO,        
                   @cORD_Status = [Status],   
                   @cExternOrderKey = ExternOrderKey        
            FROM dbo.ORDERS WITH (NOLOCK)        
            WHERE OrderKey = @cOrderKey        
            AND   StorerKey = @cStorerkey        
        
            -- The Order and Invoice will be 1:1 relationship        
            SELECT TOP 1 @cInvoiceNo = InvoiceNo        
            FROM dbo.GUIDetail WITH (NOLOCK)        
            WHERE StorerKey = @cStorerKey        
            AND   ExternOrderKey = @cExternOrderKey        
            ORDER BY 1        
        
            -- Construct print file        
            SET @cFileName = RTRIM( @cGUIExtOrderKey) + '-' + RTRIM( @cInvoiceNo) + '.' + @cFileType        
            SET @cFilePath = RTRIM( @cWorkingFilePath) + '\' + @cFileName        
            SET @cDelFilePath = 'DEL ' + RTRIM( @cWorkingFilePath) + '\' + @cFileName        
        
            -- Compare SeasonCode (pickdetail.lotattable01, orderdetail.lottable01)        
            CREATE TABLE #PD_Lot01 (        
               ROWREF      INT IDENTITY(1,1) NOT NULL,        
               OrderLineNumber   NVARCHAR( 5),        
               Lottable01        NVARCHAR(18)  NULL)        
        
            CREATE TABLE #OD_Lot01 (        
               ROWREF      INT IDENTITY(1,1) NOT NULL,        
               OrderLineNumber   NVARCHAR( 5),        
               Lottable01        NVARCHAR(18)  NULL)        
        
            INSERT INTO #PD_Lot01 ( OrderLineNumber, Lottable01)        
            SELECT DISTINCT PD.OrderLineNumber, LA.Lottable01        
            FROM dbo.PickDetail PD WITH (NOLOCK)        
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON ( PD.LOT = LA.LOT)        
            WHERE PD.StorerKey = @cStorerKey        
            AND   PD.OrderKey = @cOrderKey        
            AND   PD.Status < '9'        
        
            INSERT INTO #OD_Lot01 ( OrderLineNumber, Lottable01)        
            SELECT OrderLineNumber, Lottable01        
            FROM dbo.ORDERDETAIL OD WITH (NOLOCK)        
            WHERE OD.StorerKey = @cStorerKey        
            AND   OD.OrderKey = @cOrderKey        
            AND   OD.Status < '9'        
        
            -- If different, delete invoice and trigger order status I        
            IF EXISTS ( SELECT 1 FROM #PD_Lot01 PD WITH (NOLOCK)        
                        JOIN #OD_Lot01 OD WITH (NOLOCK) ON ( PD.OrderLineNumber = od.OrderLineNumber)        
                        AND   PD.Lottable01 <> OD.Lottable01)        
               SET @nSeasonCodeDiff = 1        
        
            --IF EXISTS ( SELECT 1 FROM dbo.OrderDetail WITH (NOLOCK)        
            --            WHERE OrderKey = @cOrderKey        
            --           AND   StorerKey = @cStorerkey        
            --            GROUP BY OrderKey        
            --        HAVING SUM( EnteredQty) <> SUM( QtyAllocated + QtyPicked))        
            --   SET @nShortAlloc = 1        
        
            -- Delete any short pick line
            SET @curDelPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT PickDetailKey
            FROM dbo.PICKDETAIL WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
            AND   STATUS = '4'
            AND   Qty = 0
            OPEN @curDelPD
            FETCH NEXT FROM @curDelPD INTO @cPickDetailKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               DELETE FROM dbo.PICKDETAIL
               WHERE PickDetailKey = @cPickDetailKey
               
               IF @@ERROR <> 0
               BEGIN        
                  SET @nErrNo = 133420        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Del Pkdt Err'        
                  GOTO RollBackTran        
               END     
               
               FETCH NEXT FROM @curDelPD INTO @cPickDetailKey	
            END
            
            SELECT @nPickQty = ISNULL( SUM( Qty), 0)
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerkey
            AND   OrderKey = @cOrderKey

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
        
            -- Compare packed qty to order qty to check if short qty        
            IF @nOriginalQty > @nPackQty        
               SET @nShortPack = 1        

            IF @nOriginalQty - @nPickQty <> 0
               SET @nShortAlloc = 1
               
            IF EXISTS ( SELECT 1 
                        FROM dbo.PICKDETAIL WITH (NOLOCK)
                        WHERE OrderKey = @cOrderKey
                        AND   Storerkey = @cStorerkey
                        AND   [Status] = '4')
               SET @nShortPick = 1

            SET @cSeasonSwapInvoiceRev = rdt.RDTGetConfig( @nFunc, 'SeasonSwapInvoiceRev', @cStorerKey)        
                 
            SET @nTranCount = @@TRANCOUNT        
            BEGIN TRAN  -- Begin our own transaction        
            SAVE TRAN rdt_840ExtUpd06 -- For rollback or commit only our own transaction        
        
            -- Auto calculate weight        
            DECLARE @cCartonType NVARCHAR( 10)        
            DECLARE @curPackInfo CURSOR        
            SET @curPackInfo = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR        
               SELECT CartonNo, CartonType         
               FROM PackInfo WITH (NOLOCK)         
               WHERE PickSlipNo = @cPickSlipNo        
            OPEN @curPackInfo         
            FETCH NEXT FROM @curPackInfo INTO @nCartonNo, @cCartonType        
            WHILE @@FETCH_STATUS = 0        
            BEGIN        
               -- Get SKU weight        
               SET @fSKUWeight = 0        
               SELECT @fSKUWeight = ISNULL( SUM( SKU.STDGROSSWGT * PD.QTY), 0)        
               FROM dbo.PackDetail PD WITH (NOLOCK)         
                  JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)        
               WHERE PD.PickSlipNo = @cPickSlipNo        
                  AND PD.CartonNo = @nCartonNo        
        
               -- Get carton weight        
               SET @fCtnWeight = 0        
               SELECT @fCtnWeight = ISNULL( CZ.CartonWeight, 0)        
               FROM Storer S WITH (NOLOCK)        
                  JOIN dbo.Cartonization CZ WITH (NOLOCK) ON (S.CartonGroup = CZ.CartonizationGroup)        
               WHERE S.StorerKey = @cStorerKey        
                  AND CZ.CartonType = @cCartonType        
        
               SET @fCtnWeight = (@fCtnWeight + @fSKUWeight) * 1000        
        
               UPDATE dbo.PackInfo SET        
                  Weight = @fCtnWeight,        
                  EditDate = GETDATE(),        
                  EditWho = 'rdt.' + SUSER_SNAME()        
               WHERE PickSlipNo = @cPickSliPno        
                  AND CartonNo = @nCartonNo        
               IF @@ERROR <> 0        
               BEGIN        
                  SET @nErrNo = 133412        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDPKINFO Failed'        
                  GOTO RollBackTran        
               END        
                    
               FETCH NEXT FROM @curPackInfo INTO @nCartonNo, @cCartonType        
            END        
        
            -- Short pick/pack or partial allocate need trigger order value recalculate        
            IF @nSeasonCodeDiff = 1 OR @nShortAlloc = 1 OR @nShortPack = 1 OR @nShortPick = 1       
            BEGIN        
               IF ( @nSeasonCodeDiff = 1 AND @cSeasonSwapInvoiceRev = '0') OR -- (james04)        
                    @nShortPack = 1 OR         
                    @nShortAlloc = 1        
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
                  --AND   SOStatus <> 'PENDGET'        
        
                  IF @@ERROR <> 0        
                  BEGIN        
                     SET @nErrNo = 133402        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD PGET FAIL'        
                     GOTO RollBackTran        
                  END        
               END        
                    
               ELSE IF @nSeasonCodeDiff = 1 AND @cSeasonSwapInvoiceRev = '1'        
               BEGIN        
                  UPDATE dbo.Orders WITH (ROWLOCK) SET        
                     SOStatus = '0',        
                     Trafficcop = NULL,        
                     EditDate = GETDATE(),        
                     EditWho = sUSER_sNAME()        
                  WHERE StorerKey = @cStorerkey        
                  AND   OrderKey = @cOrderKey        
                  AND   SOStatus <> '0'        
        
                  IF @@ERROR <> 0        
                  BEGIN        
                     SET @nErrNo = 133416        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD PGET FAIL'        
                     GOTO RollBackTran        
                  END        
               END                    
            END        

            -- only pick=pack, season code same and fully allocated then only trigger RR1        
            IF ( @nSeasonCodeDiff = 0 AND @nShortPack = 0 AND @nShortAlloc = 0) OR        
               ( @nSeasonCodeDiff = 1 AND @cSeasonSwapInvoiceRev = '1') OR       
               ( @nSeasonCodeDiff = 0 AND @cSeasonSwapInvoiceRev = '1') -- (james06)       
            BEGIN        
               IF @nMyntra = '1'        
               BEGIN        
                  -- Insert transmitlog2 here        
                  EXECUTE ispGenTransmitLog2        
                     @c_TableName      = 'WSRDTPCKCFM',        
                     @c_Key1           = @cOrderKey,        
                     @c_Key2           = @cORD_Status,        
                     @c_Key3           = @cStorerkey,        
                     @c_TransmitBatch  = '',        
                     @b_Success        = @bSuccess   OUTPUT,        
                     @n_err            = @nErrNo     OUTPUT,        
                     @c_errmsg         = @cErrMsg    OUTPUT        
        
                  IF @bSuccess <> 1        
                     GOTO RollBackTran        
               END        
               ELSE        
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
                     @b_resultset = 0,        
                     @n_batch       = 1        
        
                  IF @bSuccess <> 1        
                     GOTO RollBackTran        
        
                  -- Insert transmitlog2 here        
                  EXECUTE ispGenTransmitLog2        
                     @c_TableName      = 'WSCRSOREQMP',        
                     @c_Key1           = @cOrderKey,        
                     @c_Key2   = @cKey2,        
                     @c_Key3           = @cStorerkey,        
                     @c_TransmitBatch  = '',        
                     @b_Success        = @bSuccess   OUTPUT,        
                     @n_err            = @nErrNo     OUTPUT,        
                     @c_errmsg         = @cErrMsg    OUTPUT        
        
                  IF @bSuccess <> 1        
                     GOTO RollBackTran        
               END        

               IF @nShortPack = 0 AND @nShortAlloc <> 0
                  UPDATE dbo.Orders WITH (ROWLOCK) SET    --(yeekung01)    
                     SOStatus = '0',        
                     Trafficcop = NULL,        
                     EditDate = GETDATE(),        
                     EditWho = sUSER_sNAME()        
                  WHERE StorerKey = @cStorerkey        
                  AND   OrderKey = @cOrderKey        
                  AND   SOStatus = 'PENDGET'          
            END        
        
            IF @nSeasonCodeDiff = 1 OR @nShortPack = 1 OR @nShortAlloc = 1 OR @nShortPick = 1       
            BEGIN        
               -- Abnormal scenario: short pack, partial allocate or season code different        
               -- then need delete invoice data and invoice pdf file and trigger interface        
               IF ( @nSeasonCodeDiff = 1 AND @cSeasonSwapInvoiceRev = '0') OR -- (james04)        
                    @nShortPack = 1 OR         
                    @nShortAlloc = 1 OR 
                    @nShortPick = 1       
               BEGIN        
                  SET @nOriginalQty = 0
                  SELECT @nOriginalQty = SUM( OriginalQty)
                  FROM dbo.OrderDetail WITH (NOLOCK)
                  WHERE OrderKey = @cOrderKey
                  	
                  SET @nPickQty = 0
                  SELECT @nPickQty = SUM( Qty)
                  FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE OrderKey = @cOrderKey
                  AND   [Status] = '5'

                  IF ( @nOriginalQty <> @nPickQty) OR @nShortPick = 1 OR @nShortAlloc = 1
                  BEGIN
                     -- Delete GUI where  GUI.ExternOrderKey = Orders.ExternOrderKey        
                     DECLARE CUR_DEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR        
                     SELECT LineNumber        
                     FROM dbo.GUIDetail WITH (NOLOCK)        
                     WHERE StorerKey = @cStorerKey        
                     AND   ExternOrderKey = @cExternOrderKey        
                     AND   InvoiceNo = @cInvoiceNo        
                     OPEN CUR_DEL        
                     FETCH NEXT FROM CUR_DEL INTO @cLineNumber        
                     WHILE @@FETCH_STATUS <> -1        
                     BEGIN        
                        DELETE FROM dbo.GUIDetail        
                        WHERE InvoiceNo = @cInvoiceNo        
                        AND   ExternOrderkey = @cExternOrderKey        
                        AND   Storerkey = @cStorerKey        
                        AND   LineNumber = @cLineNumber        
        
                        IF @@ERROR <> 0        
                        BEGIN        
                           SET @nErrNo = 133403        
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
                     AND   ExternOrderKey = @cExternOrderKey        
        
                     IF @@ERROR <> 0        
                     BEGIN        
                        SET @nErrNo = 133404        
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL INVOICE ER        
                        GOTO RollBackTran        
                     END        
        
                     -- Delete invoice pdf        
                     EXEC isp_FileExists @cFilePath, @nFileExists OUTPUT, @bSuccess OUTPUT        
        
                     IF @nFileExists = 1        
                        EXEC isp_DeleteFile @cFilePath, @bSuccess OUTPUT      
        
                     IF @bSuccess <> 1        
                     BEGIN        
                        SET @nErrNo = 133405        
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL INVOICE ER        
                        GOTO RollBackTran        
                     END        
                     
                     SET @nInvoiceDel = 1
                  END
        
                  IF @nShortPick = 1 OR @nShortAlloc = 1
                  BEGIN
                     -- Insert transmitlog3 here (Trigger I216 with status I )        
                     SET @bSuccess = 1        
                     EXEC ispGenTransmitLog2        
                         @c_TableName        = 'WSSOPICKI216HM'        
                        ,@c_Key1             = @cOrderKey        
                        ,@c_Key2             = '5'        
                        ,@c_Key3             = @cStorerkey        
                        ,@c_TransmitBatch    = ''        
                        ,@b_Success          = @bSuccess   OUTPUT        
                        ,@n_err              = @nErrNo      OUTPUT        
                        ,@c_errmsg           = @cErrMsg     OUTPUT        
        
                     IF @bSuccess <> 1        
                        GOTO RollBackTran        
                  END
                  
                  -- Insert transmitlog3 here (Trigger status I)        
                  SET @bSuccess = 1        
                  EXEC ispGenTransmitLog3        
                      @c_TableName        = 'HHPCKCFMLG'        
                     ,@c_Key1             = @cOrderKey        
                     ,@c_Key2             = ''        
                     ,@c_Key3        = @cStorerkey        
                     ,@c_TransmitBatch    = ''        
                     ,@b_Success          = @bSuccess   OUTPUT        
                     ,@n_err              = @nErrNo      OUTPUT        
                     ,@c_errmsg           = @cErrMsg     OUTPUT        
        
                  IF @bSuccess <> 1        
                     GOTO RollBackTran        
               END
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
                  SET @nErrNo = 133406        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Packcfm fail        
                  GOTO RollBackTran        
               END        
            END        
        
            IF rdt.RDTGetConfig( @nFunc, 'Grams2KG', @cStorerKey) = '1'        
            BEGIN        
               DECLARE @nW_CartonNo INT        
        
               DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR        
               SELECT CartonNo FROM dbo.PackInfo WITH (NOLOCK)        
               WHERE PickSlipNo = @cPickSlipNo        
               ORDER BY 1        
               OPEN CUR_UPD        
               FETCH NEXT FROM CUR_UPD INTO @nW_CartonNo        
               WHILE @@FETCH_STATUS <> -1        
               BEGIN        
                  UPDATE dbo.PackInfo WITH (ROWLOCK) SET        
                     Weight = Weight/1000,        
                     TrafficCop = NULL        
                  WHERE PickSlipNo = @cPickSlipNo        
                  AND CartonNo = @nW_CartonNo        
        
                  IF @@ERROR <> 0        
                  BEGIN        
                     SET @nErrNo = 133407        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd wgt fail        
                     CLOSE CUR_UPD        
                     DEALLOCATE CUR_UPD        
                     GOTO RollBackTran        
                  END        
        
                  FETCH NEXT FROM CUR_UPD INTO @nW_CartonNo        
               END        
               CLOSE CUR_UPD        
               DEALLOCATE CUR_UPD        
            END        

            IF @nInvoiceDel = 1
            BEGIN
               -- Insert msg prompt
               SET @cErrMsg1 = rdt.rdtgetmessage( 133419, @cLangCode, 'DSP') --AWAIT REVISED INV  
                 
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1  
                                   
               SET @nErrNo = 0
               SET @cErrMsg = ''
            END
            
            GOTO CommitTrans        
        
            RollBackTran:        
                  ROLLBACK TRAN rdt_840ExtUpd06        
        
            CommitTrans:        
               WHILE @@TRANCOUNT > @nTranCount        
                  COMMIT TRAN        

            IF ( @nSeasonCodeDiff = 0 AND @nShortPack = 0 AND @nShortAlloc = 0) OR        
               ( @nSeasonCodeDiff = 1 AND @cSeasonSwapInvoiceRev = '1') OR       
               ( @nSeasonCodeDiff = 0 AND @cSeasonSwapInvoiceRev = '1') -- (james06)    
            BEGIN        
               IF NOT EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)   
                               WHERE PickSlipNo = @cPickSlipNo   
                               AND  [Status] = '9')  
                  GOTO Quit  
               
               SET @cORDLabel = rdt.RDTGetConfig( @nFunc, 'ORDLabel', @cStorerkey)        
               IF @cORDLabel = '0'  
                  SET @cORDLabel = ''  
                 
               IF @cORDLabel <> ''        
               BEGIN        
                  DECLARE @tORDLabel AS VariableTable        
                  INSERT INTO @tORDLabel (Variable, Value) VALUES ( '@cBuyerPO',    @cGUIExtOrderKey)        
                  INSERT INTO @tORDLabel (Variable, Value) VALUES ( '@cOrderKey',   @cOrderKey)        
                  INSERT INTO @tORDLabel (Variable, Value) VALUES ( '@cExternOrderKey',   @cExternOrderKey)  
        
                  -- Print label        
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cPrinter, '',        
                     @cORDLabel, -- Report type        
                     @tORDLabel, -- Report params        
                     'rdt_840ExtUpd06',        
                     @nErrNo  OUTPUT,        
                     @cErrMsg OUTPUT        
        
                  -- No need return error no here to prevent rollback issue  
                  IF @nErrNo <> 0            
                  BEGIN  
                     SET @nErrNo = 0  
                     GOTO Quit  
                  END            
               END        
                
               SET @cInvoice = rdt.RDTGetConfig( @nFunc, 'Invoice', @cStorerkey)        
               IF @cInvoice = '0'  
                  SET @cInvoice = ''  
                 
               IF @cInvoice <> ''        
               BEGIN        
                  DECLARE @tInvoice AS VariableTable        
                  INSERT INTO @tInvoice (Variable, Value) VALUES ( '@cBuyerPO',    @cGUIExtOrderKey)        
                  INSERT INTO @tInvoice (Variable, Value) VALUES ( '@cOrderKey',   @cOrderKey)        
                  INSERT INTO @tInvoice (Variable, Value) VALUES ( '@cExternOrderKey',   @cExternOrderKey)  
                 
                  -- Print label        
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPrinter_Paper,        
                     @cInvoice, -- Report type        
                     @tInvoice, -- Report params        
                     'rdt_840ExtUpd06',        
                     @nErrNo  OUTPUT,        
                     @cErrMsg OUTPUT        
        
        
                  IF @nErrNo <> 0        
                     GOTO Quit        
               END        
            END
         END        
         ELSE
         BEGIN
         	-- Move orders
            SET @cSSCCLabel = rdt.RDTGetConfig( @nFunc, 'SSCCLabel', @cStorerkey)        
            IF @cSSCCLabel = '0'  
               SET @cSSCCLabel = ''  
                 
            IF @cSSCCLabel <> ''        
            BEGIN        
               DECLARE @tSSCCLabel AS VariableTable        
               INSERT INTO @tSSCCLabel (Variable, Value) VALUES ( '@cOrderKey',     @cOrderKey)        
               INSERT INTO @tSSCCLabel (Variable, Value) VALUES ( '@nCartonNo',     @nCartonNo)        
        
               -- Print label        
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cPrinter, '',        
                  @cSSCCLabel, -- Report type        
                  @tSSCCLabel, -- Report params        
                  'rdt_840ExtUpd06',        
                  @nErrNo  OUTPUT,        
                  @cErrMsg OUTPUT        
        
               -- No need return error no here to prevent rollback issue  
               IF @nErrNo <> 0            
               BEGIN  
                  SET @nErrNo = 0  
                  GOTO Quit  
               END                      
            END        
         END
      END        
   END        
        
   Quit:     

GO