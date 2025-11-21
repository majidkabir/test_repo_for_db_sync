SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/    
/* Store procedure: rdt_PackSummaryPrint_GSILabel                       */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Comfirm Pick                                                */    
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2010-08-18 1.0  ChewKP   Created                                     */    
/* 2010-09-03 1.0  AQSKC    Change filename = PRINTER + DATE + UPC      */    
/*                          (Kc01)                                      */   
/* 2011-03-21 1.0  Shong    TCP Printing Features for Bartender         */   
/************************************************************************/    
CREATE PROC [RDT].[rdt_PackSummaryPrint_GSILabel] (
   @nMobile INT
  ,@cFacility NVARCHAR(5)
  ,@cStorerKey NVARCHAR(15)
  ,@cPickSlipType NVARCHAR(10)
  ,@cPickSlipNo NVARCHAR(10)	-- can be conso ps# or discrete ps#; depends on pickslip type
  ,@cBuyerPO NVARCHAR(20)
  ,@cFilePath1 NVARCHAR(20)
  ,@cFilePath2 NVARCHAR(20)
  ,@cUserName NVARCHAR(18)
  ,@cGS1TemplatePath_Final NVARCHAR(120)
  ,@cLangCode NVARCHAR(3)
  ,@nCartonNo INT
  ,@cPrinter NVARCHAR(20)
  ,@nErrNo INT OUTPUT
  ,@cErrMsg NVARCHAR(20) OUTPUT -- screen limitation, 20 char max
)      
AS      
BEGIN
    SET NOCOUNT ON      
    SET QUOTED_IDENTIFIER OFF      
    SET ANSI_NULLS OFF      
    SET CONCAT_NULL_YIELDS_NULL OFF      
    
    DECLARE @nTranCount     INT      
    
    DECLARE @cOrderkey      NVARCHAR(10)
           ,@cYYYY          NVARCHAR(4)
           ,@cMM            NVARCHAR(2)
           ,@cDD            NVARCHAR(2)
           ,@cHH            NVARCHAR(2)
           ,@cMI            NVARCHAR(2)
           ,@cSS            NVARCHAR(2)
           ,@cDateTime      NVARCHAR(17)
           ,@cSPID          NVARCHAR(5)
           ,@dTempDateTime  DATETIME
           ,@cMS            NVARCHAR(3)
           ,@cLabelNo       NVARCHAR(20)
           ,@cUPC           NVARCHAR(30) --(KC01)
           ,@cFilePath      NVARCHAR(120)
           ,@cFileName      NVARCHAR(215)
           ,@cWorkFilePath  NVARCHAR(120)
           ,@cMoveFilePath  NVARCHAR(120) 
    
    
    -- Initialize Variable    
    SET @nTranCount = @@TRANCOUNT      
    SET @cOrderkey = ''    
    SET @cYYYY = ''    
    SET @cMM = ''    
    SET @cDD = ''    
    SET @cHH = ''    
    SET @cMI = ''    
    SET @cSS = ''    
    SET @cDateTime = ''    
    SET @cSPID = ''    
    SET @dTempDateTime = ''    
    SET @cMS = ''    
    SET @cLabelNo = ''    
    SET @cFilePath = ''    
    SET @cFileName = ''    
    SET @cWorkFilePath = ''    
    SET @cMoveFilePath = ''    
    SET @cUPC = '' --(KC01)    
    
    BEGIN TRAN 
    SAVE TRAN PackPrintLabel 
    
    -- Get Orderkey     
    SELECT TOP 1 @cOrderkey = Orderkey
    FROM   dbo.PickDetail WITH (NOLOCK)
    WHERE  Pickslipno = @cPickSlipNo 
    
    -- Get LabelNo    
    SELECT @cLabelNo = LabelNo
          ,@cUPC = UPC --(KC01)
    FROM   dbo.PackDetail WITH (NOLOCK)
    WHERE  Pickslipno = @cPickSlipNo
    AND    CartonNo = @nCartonNo   
    
    
    SET @dTempDateTime = GETDATE()    
    
    SET @cYYYY = RIGHT('0' + ISNULL(RTRIM(DATEPART(yyyy ,@dTempDateTime)) ,'') ,4)    
    SET @cMM = RIGHT('0' + ISNULL(RTRIM(DATEPART(mm ,@dTempDateTime)) ,'') ,2)    
    SET @cDD = RIGHT('0' + ISNULL(RTRIM(DATEPART(dd ,@dTempDateTime)) ,'') ,2)    
    SET @cHH = RIGHT('0' + ISNULL(RTRIM(DATEPART(hh ,@dTempDateTime)) ,'') ,2)    
    SET @cMI = RIGHT('0' + ISNULL(RTRIM(DATEPART(mi ,@dTempDateTime)) ,'') ,2)    
    SET @cSS = RIGHT('0' + ISNULL(RTRIM(DATEPART(ss ,@dTempDateTime)) ,'') ,2)    
    SET @cMS = RIGHT('0' + ISNULL(RTRIM(DATEPART(ms ,@dTempDateTime)) ,'') ,3)    
    
    SET @cDateTime = @cYYYY + @cMM + @cDD + @cHH + @cMI + @cSS + @cMS    
    
    SET @cSPID = @@SPID 
    --(Kc01)
    --SET @cFilename = ISNULL(RTRIM(@cPrinter), '') + '_' + @cDateTime + '_' + ISNULL(RTRIM(@cLabelNo), '') + '.XML'    
    SET @cFilename = ISNULL(RTRIM(@cPrinter) ,'') + '_' + @cDateTime + '_' + 
        ISNULL(RTRIM(@cUPC) ,'') + '.XML'    
    SET @cFilePath = ISNULL(RTRIM(@cFilePath1) ,'') + ISNULL(RTRIM(@cFilePath2) ,'')    
    SET @cWorkFilePath = ISNULL(RTRIM(@cFilePath) ,'') + 'Working' 
    
    -- Clear the XML record    
    DELETE 
    FROM   RDT.RDTGSICartonLabel_XML WITH (ROWLOCK)
    WHERE  [SPID] = @@SPID    

      -- SHONG01         
      DECLARE @c_TCP_IP        NVARCHAR(20),
              @c_TCP_Port      NVARCHAR(10),
              @c_BatchNo       NVARCHAR(20),
              @c_TCP_Authority NVARCHAR(1), 
              @b_success       INT, 
              @n_err           INT,    
              @c_errmsg        NVARCHAR(250)
   
              
      SET @c_BatchNo = ABS(CAST(CAST(NEWID() AS VARBINARY(5)) AS Bigint))    
      
      -- SHONG01
      -- Get Printer TCP 
      SELECT @b_success = 0  
   
      SET @c_TCP_IP = ''
      SET @c_TCP_Port = ''
      
      SELECT @c_TCP_IP   = Long, 
             @c_TCP_Port = Short
      FROM CODELKUP c (NOLOCK)
      WHERE c.LISTNAME = 'TCPPrinter' 
      AND c.Code = @cPrinter
      
      IF IsNull(RTRIM(@c_TCP_IP),'') = ''
      BEGIN
         SET @nErrNo = 69494  
         SET @cErrMsg = 'TCPPrinterBlk'  
         GOTO RollBackTran 
      END
          
    EXEC dbo.isp_GSICartonLabel 
         ''
        ,@cOrderKey
        ,@cGS1TemplatePath_Final
        ,@cPrinter
        ,@cFileName
        ,@nCartonNo
        ,'' 
    
    -- Check the last char of the file path consists of '\'    
    IF SUBSTRING(ISNULL(RTRIM(@cFilePath) ,'') ,LEN(ISNULL(RTRIM(@cFilePath) ,'')) ,1) <> '\'
        SET @cFilePath = ISNULL(RTRIM(@cFilePath) ,'') + '\'    
    
    SET @cMoveFilePath = ISNULL(RTRIM(@cFilePath) ,'') 

   SELECT @b_success = 0  
   SET @c_TCP_Authority = '0'
   EXECUTE dbo.nspGetRight 
      @cFacility,   -- facility 
      @cStorerkey,  -- Storerkey  
      NULL,          -- Sku  
      'BartenderTCP',-- Configkey  
      @b_success    output,  
      @c_TCP_Authority  output,   
      @n_err        output,  
      @c_errmsg     output  

   IF @c_TCP_Authority = '1'
   BEGIN
      EXECUTE [RDT].[rdt_TCP_GSILabel] 
      @@SPID,
      @cPrinter, 
      @nErrNo OUTPUT, 
      @cErrMsg OUTPUT  
   END
   ELSE
   BEGIN
       EXECUTE [RDT].[rdt_PrintGSILabel] 
       @@SPID, 
       @cWorkFilePath, 
       @cMoveFilePath, 
       @cFileName, 
       @cLangCode, 
       @nErrNo OUTPUT,    
       @cErrMsg OUTPUT
   END    
    
    IF @nErrNo <> 0
    BEGIN
        SET @nErrNo = 70966    
        SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'GSILBLCrtFail'    
        GOTO RollBackTran
    END 
    
    GOTO Quit 
    
    RollBackTran: 
    ROLLBACK TRAN PackPrintLabel 
    
    Quit:      
    WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started      
          COMMIT TRAN PackPrintLabel
END      

GO