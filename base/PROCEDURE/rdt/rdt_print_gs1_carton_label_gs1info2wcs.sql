SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_Print_GS1_Carton_Label_GS1Info2WCS              */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Insert PackDetail after each scan of Case ID                */  
/*                                                                      */  
/* Called from: rdtfnc_Scan_And_Pack                                    */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author    Purposes                                  */  
/* 21-Jan-2010 1.0  ChewKP     Created                                  */  
/* 03-Aug-2010 1.1  Vicky     Revamp Error Message (Vicky02)            */   
/* 03-Jun-2010 1.2  ChewKP    SOS#173479 Add in @b_LocFilter flag       */  
/*                            (ChewKP01)                                */ 
/* 31-Mar-2011 1.0  Shong     TCP Printing Features for Bartender       */   
/* 27-Jul-2011 1.3  James     SOS221977 - Skip to create XML file if    */
/*                            nothing is selected (james01)             */
/************************************************************************/  
CREATE PROC [RDT].[rdt_Print_GS1_Carton_Label_GS1Info2WCS] (
 @nMobile INT
,@cFacility NVARCHAR(5)
,@cStorerKey NVARCHAR(15)
,@cDropID NVARCHAR(18)
,@cMBOLKey NVARCHAR(10)
,@cLoadKey NVARCHAR(10)
,@cFilePath1 NVARCHAR(50)
,@cPrepackByBOM NVARCHAR(1)
,@cUserName NVARCHAR(18)
,@cPrinter NVARCHAR(20)
,@cLangCode NVARCHAR(3)
,@nCaseCnt INT	-- (Vicky01)
,@nErrNo INT OUTPUT
,@cErrMsg NVARCHAR(20) OUTPUT	-- screen limitation, 20 char max
,@b_LocFilter INT = 0 -- (ChewKP01)
) AS  
BEGIN
    SET NOCOUNT ON  
    SET QUOTED_IDENTIFIER OFF  
    SET ANSI_NULLS OFF  
    SET CONCAT_NULL_YIELDS_NULL OFF  
    
    DECLARE @b_success       INT
           ,@n_err           INT
           ,@c_errmsg        NVARCHAR(255)  
    
    DECLARE @cPickHeaderKey  NVARCHAR(10)
           ,@cLabelLine      NVARCHAR(5)
           ,@cComponentSku   NVARCHAR(20)
           ,@nComponentQTY   INT
           ,@nTranCount      INT
           ,@cYYYY           NVARCHAR(4)
           ,@cMM             NVARCHAR(2)
           ,@cDD             NVARCHAR(2)
           ,@cHH             NVARCHAR(2)
           ,@cMI             NVARCHAR(2)
           ,@cSS             NVARCHAR(2)
           ,@cDateTime       NVARCHAR(17)
           ,@cSPID           NVARCHAR(5)
           ,@cFileName       NVARCHAR(215)
           ,@cWorkFilePath   NVARCHAR(120)
           ,@cMoveFilePath   NVARCHAR(120)
           ,@cFilePath       NVARCHAR(120)
           ,@nSumQtyPicked   INT
           ,@nSumQtyPacked   INT
           ,@nMax_CartonNo   INT	-- (Vicky02)
           ,@nCartonNo       INT
           ,@cLabelNo        NVARCHAR(20)   
    
    
    DECLARE @cMS             NVARCHAR(3)
           ,@dTempDateTime   DATETIME  
    
    DECLARE @n_debug         INT  

    -- SHONG01         
    DECLARE @c_TCP_Authority NVARCHAR(1)   

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
           
    SET @n_debug = 0  
    
    IF @n_debug = 1
    BEGIN
        DECLARE @d_starttime  DATETIME
               ,@d_endtime    DATETIME
               ,@d_step1      DATETIME
               ,@d_step2      DATETIME
               ,@d_step3      DATETIME
               ,@d_step4      DATETIME
               ,@d_step5      DATETIME
               ,@c_col1       NVARCHAR(20)
               ,@c_col2       NVARCHAR(20)
               ,@c_col3       NVARCHAR(20)
               ,@c_col4       NVARCHAR(20)
               ,@c_col5       NVARCHAR(20)
               ,@c_TraceName  NVARCHAR(80)  
        
        SET @c_col1 = '' 
        --SET @c_col1 = @cOrderKey
        --SET @c_col2 = @cSKU
        --SET @c_col3 = @nQTY  
        SET @c_col4 = @cPrinter  
        
        SET @d_starttime = GETDATE()  
        
        SET @c_TraceName = 'rdt_Print_GS1_Carton_Label_GS1Info2WCS'
    END  
    
    SET @nTranCount = @@TRANCOUNT 
    
    BEGIN TRAN 
    SAVE TRAN GS1_Carton_Label_GS1Info2WCS  
    
    
    BEGIN
        SET @d_step1 = GETDATE()  
        
        SET @dTempDateTime = GETDATE()  
        
        SET @cYYYY = RIGHT('0' + ISNULL(RTRIM(DATEPART(yyyy ,@dTempDateTime)) ,'') ,4)  
        SET @cMM = RIGHT('0' + ISNULL(RTRIM(DATEPART(mm ,@dTempDateTime)) ,'') ,2)  
        SET @cDD = RIGHT('0' + ISNULL(RTRIM(DATEPART(dd ,@dTempDateTime)) ,'') ,2)  
        SET @cHH = RIGHT('0' + ISNULL(RTRIM(DATEPART(hh ,@dTempDateTime)) ,'') ,2)  
        SET @cMI = RIGHT('0' + ISNULL(RTRIM(DATEPART(mi ,@dTempDateTime)) ,'') ,2)  
        SET @cSS = RIGHT('0' + ISNULL(RTRIM(DATEPART(ss ,@dTempDateTime)) ,'') ,2)  
        
        SET @cDateTime = @cYYYY + @cMM + @cDD + @cHH + @cMI + @cSS   
        
        SET @cSPID = @@SPID  
        SET @cFilename = ISNULL(RTRIM(@cLoadkey) ,'') + '_' + ISNULL(RTRIM(@cDropID) ,'') 
            + '_' + ISNULL(RTRIM(@cDateTime) ,'') + '.XML'  
        SET @cFilePath = ISNULL(RTRIM(@cFilePath1) ,'')   
        SET @cWorkFilePath = ISNULL(RTRIM(@cFilePath) ,'') + 'Working' 
        
        -- Clear the XML record  
        DELETE FROM   RDT.RDTGSICartonLabel_XML WITH (ROWLOCK)
        WHERE  [SPID] = @@SPID  
        
        IF @n_debug = 1
        BEGIN
            SET @d_step2 = GETDATE() - @d_step2  
            SET @c_col1 = 'WRITE TO XML START'  
            SET @d_endtime = GETDATE()  
            INSERT INTO TraceInfo
            VALUES
              (
                RTRIM(@c_TraceName)
               ,@d_starttime
               ,@d_endtime
               ,CONVERT(CHAR(12) ,@d_endtime - @d_starttime ,114)
               ,CONVERT(CHAR(12) ,@d_step1 ,114)
               ,CONVERT(CHAR(12) ,@d_step2 ,114)
               ,CONVERT(CHAR(12) ,@d_step3 ,114)
               ,CONVERT(CHAR(12) ,@d_step4 ,114)
               ,CONVERT(CHAR(12) ,@d_step5 ,114) 
                --,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)
               ,@c_Col1
               ,SUBSTRING(@cFilename ,1 ,20)
               ,SUBSTRING(@cFilename ,21 ,20)
               ,SUBSTRING(@cFilename ,41 ,20)
               ,CONVERT(VARCHAR(20) ,@nCartonNo)
              )  
            
            SET @d_step1 = NULL  
            SET @d_step2 = NULL  
            SET @d_step3 = NULL  
            SET @d_step4 = NULL  
            SET @d_step5 = NULL  
            
            SET @d_step3 = GETDATE()
        END  
        
        EXEC dbo.isp_GS1Info2WCS 
             @cLoadKey
            ,@cDropID
            ,''
            ,0
            ,0
            ,@b_Success OUTPUT
            ,@b_LocFilter -- (ChewKP01)  
        
        -- (Vicky01) - Start  
        IF @b_Success <> 1
        BEGIN
            SET @nErrNo = 70667  
            SET @cErrMsg = rdt.rdtgetmessage(70667 ,@cLangCode ,'DSP') --'GenWCSFail'  
            GOTO RollBackTran
        END 
        -- (Vicky01) - End  
        
        
        IF @n_debug = 1
        BEGIN
            SET @d_step3 = GETDATE() - @d_step3  
            SET @c_col1 = 'WRITE TO XML END'  
            SET @d_endtime = GETDATE()  
            INSERT INTO TraceInfo
            VALUES
              (
                RTRIM(@c_TraceName)
               ,@d_starttime
               ,@d_endtime
               ,CONVERT(CHAR(12) ,@d_endtime - @d_starttime ,114)
               ,CONVERT(CHAR(12) ,@d_step1 ,114)
               ,CONVERT(CHAR(12) ,@d_step2 ,114)
               ,CONVERT(CHAR(12) ,@d_step3 ,114)
               ,CONVERT(CHAR(12) ,@d_step4 ,114)
               ,CONVERT(CHAR(12) ,@d_step5 ,114) 
                --,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)
               ,@c_Col1
               ,SUBSTRING(@cFilename ,1 ,20)
               ,SUBSTRING(@cFilename ,21 ,20)
               ,SUBSTRING(@cFilename ,41 ,20)
               ,CONVERT(VARCHAR(20) ,@nCartonNo)
              )  
            
            SET @d_step1 = NULL  
            SET @d_step2 = NULL  
            SET @d_step3 = NULL  
            SET @d_step4 = NULL  
            SET @d_step5 = NULL  
            
            SET @d_step4 = GETDATE()
        END  
        
        IF @b_Success = 1
        BEGIN
         IF EXISTS (SELECT 1 FROM RDT.RDTGSICartonLabel_XML WITH (NOLOCK) WHERE [SPID] = @@SPID)   -- (james01)
         BEGIN
         
            -- Check the last char of the file path consists of '\'  
            IF SUBSTRING(ISNULL(RTRIM(@cFilePath) ,'') ,LEN(ISNULL(RTRIM(@cFilePath) ,'')) ,1) <> '\'
                SET @cFilePath = ISNULL(RTRIM(@cFilePath) ,'') + '\'  
            
            SET @cMoveFilePath = ISNULL(RTRIM(@cFilePath) ,'') 

      
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
                       
               IF @nErrNo <> 0
               BEGIN
                   SET @nErrNo = 66281  
                   SET @cErrMsg = rdt.rdtgetmessage(66281 ,@cLangCode ,'DSP') --'GSILBLCrtFail'  
                   GOTO RollBackTran
               END  
               IF @n_debug = 1
               BEGIN
                   SET @d_step4 = GETDATE() - @d_step4  
                   SET @c_col1 = 'Print GSI Label'  
                   SET @d_endtime = GETDATE()  
                   INSERT INTO TraceInfo
                   VALUES
                     (
                       RTRIM(@c_TraceName)
                      ,@d_starttime
                      ,@d_endtime
                      ,CONVERT(CHAR(12) ,@d_endtime - @d_starttime ,114)
                      ,CONVERT(CHAR(12) ,@d_step1 ,114)
                      ,CONVERT(CHAR(12) ,@d_step2 ,114)
                      ,CONVERT(CHAR(12) ,@d_step3 ,114)
                      ,CONVERT(CHAR(12) ,@d_step4 ,114)
                      ,CONVERT(CHAR(12) ,@d_step5 ,114) 
                       --,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)
                      ,@c_Col1
                      ,SUBSTRING(@cFilename ,1 ,20)
                      ,SUBSTRING(@cFilename ,21 ,20)
                      ,SUBSTRING(@cFilename ,41 ,20)
                      ,CONVERT(VARCHAR(20) ,@nCartonNo)
                     )  
                   
                   SET @d_step1 = NULL  
                   SET @d_step2 = NULL  
                   SET @d_step3 = NULL  
                   SET @d_step4 = NULL  
                   SET @d_step5 = NULL
               END
           END 
         END
        END
    END 
    
    GOTO Quit 
    
    RollBackTran: 
    ROLLBACK TRAN GS1_Carton_Label_GS1Info2WCS 
    
    Quit:  
    WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
          COMMIT TRAN GS1_Carton_Label_GS1Info2WCS
END

GO