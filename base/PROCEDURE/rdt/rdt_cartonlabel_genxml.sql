SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_CartonLabel_GenXML                              */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Insert PackDetail after each scan of Case ID                */
/*                                                                      */
/* Called from: rdtfnc_Print_Carton_Label                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 14-Apr-2010 1.0  ChewKP    Created                                   */
/* 31-Mar-2011 1.1  Shong     TCP Printing Features for Bartender       */  
/*                                                                      */
/************************************************************************/
CREATE PROC [RDT].[rdt_CartonLabel_GenXML] (
          @c_LabelNo      NVARCHAR(20)     = ''
        , @c_OrderKey     NVARCHAR(10)     = ''
        , @c_TemplateID   NVARCHAR(60)  = ''
        , @c_PrinterID    NVARCHAR(215) = ''
        , @c_FileName     NVARCHAR(215) = ''
        , @c_Storerkey    NVARCHAR(18)  = '' 
        , @c_FilePath     NVARCHAR(120)  = ''
		  , @nErrNo               INT          OUTPUT
        , @cErrMsg              NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN

   
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   
   DECLARE   
      @cWorkFilePath     NVARCHAR( 120),
      @cMoveFilePath     NVARCHAR( 120),
      @cFilePath         NVARCHAR( 120),
      @cLangCode         NVARCHAR(   3)
      --@nErrNo            INT,
      --@cErrMsg           NVARCHAR( 20) 
      
   DECLARE    @n_debug		int
		,@nCartonNo         INT

   -- SHONG01         
   DECLARE @c_TCP_IP        NVARCHAR(20),
           @c_TCP_Port      NVARCHAR(10),
           @c_BatchNo       NVARCHAR(20),
           @c_TCP_Authority NVARCHAR(1), 
           @b_success       INT, 
           @n_err           INT,    
           @c_errmsg        NVARCHAR(250), 
           @c_Facility      NVARCHAR(5)
                 
   IF @n_debug = 1
	BEGIN
		DECLARE  @d_starttime    datetime,
				   @d_endtime      datetime,
				   @d_step1        datetime,
				   @d_step2        datetime,
				   @d_step3        datetime,
				   @d_step4        datetime,
				   @d_step5        datetime,
				   @c_col1         NVARCHAR(20),
				   @c_col2         NVARCHAR(20),
				   @c_col3         NVARCHAR(20),
				   @c_col4         NVARCHAR(20),
				   @c_col5         NVARCHAR(20),
				   @c_TraceName    NVARCHAR(80)

		SET @c_col1 = ''
		SET @c_col1 = @c_OrderKey
		--SET @c_col2 = @cSKU
		--SET @c_col3 = @nQTY
		SET @c_col4 = @c_PrinterID

		SET @d_starttime = getdate()

		SET @c_TraceName = 'rdt_CartonLabel_GenXML'
	END

	SET @n_debug = 0

   SET @cWorkFilePath = ISNULL(RTRIM(@c_FilePath), '') + 'Working'
   SET @cMoveFilePath = ISNULL(RTRIM(@c_FilePath), '')
      
   -- Clear the XML record
   DELETE FROM RDT.RDTGSICartonLabel_XML with (rowlock) WHERE [SPID] = @@SPID
   
   IF @n_debug = 1
	BEGIN
	SET @d_step2 = GETDATE() - @d_step2
	  SET @c_col1 = 'GEN UCC LABEL START'
	  SET @d_endtime = GETDATE()
	  INSERT INTO TraceInfo VALUES
		  (RTRIM(@c_TraceName), @d_starttime, @d_endtime
			,CONVERT(CHAR(12),@d_endtime - @d_starttime ,114)
			,CONVERT(CHAR(12),@d_step1,114)
			,CONVERT(CHAR(12),@d_step2,114)
			,CONVERT(CHAR(12),@d_step3,114)
			,CONVERT(CHAR(12),@d_step4,114)
			,CONVERT(CHAR(12),@d_step5,114)
			--,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)
			,@c_Col1
			,SUBSTRING(@c_FileName,1,20)
			,SUBSTRING(@c_FileName,21,20)
			,SUBSTRING(@c_FileName,41,20)
			,CONVERT(VARCHAR(20),@nCartonNo))

	  SET @d_step1 = NULL
	  SET @d_step2 = NULL
	  SET @d_step3 = NULL
	  SET @d_step4 = NULL
	  SET @d_step5 = NULL

	  SET @d_step3 = GETDATE()
   END
		      

	EXEC dbo.isp_CartonLabel
	  @c_LabelNo      
	, @c_OrderKey     
	, @c_TemplateID   
	, @c_PrinterID    
	, @c_FileName     
	, @c_Storerkey    
	, @c_FilePath
				
			
	IF @n_debug = 1
	BEGIN
		SET @d_step3 = GETDATE() - @d_step3
	  SET @c_col1 = 'GEN UCC LABEL END'
	  SET @d_endtime = GETDATE()
	  INSERT INTO TraceInfo VALUES
		  (RTRIM(@c_TraceName), @d_starttime, @d_endtime
			,CONVERT(CHAR(12),@d_endtime - @d_starttime ,114)
			,CONVERT(CHAR(12),@d_step1,114)
			,CONVERT(CHAR(12),@d_step2,114)
			,CONVERT(CHAR(12),@d_step3,114)
			,CONVERT(CHAR(12),@d_step4,114)
			,CONVERT(CHAR(12),@d_step5,114)
			--,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)
			,@c_Col1
			,SUBSTRING(@c_FileName,1,20)
			,SUBSTRING(@c_FileName,21,20)
			,SUBSTRING(@c_FileName,41,20)
			,CONVERT(VARCHAR(20),@nCartonNo))
	
	  SET @d_step1 = NULL
	  SET @d_step2 = NULL
	  SET @d_step3 = NULL
	  SET @d_step4 = NULL
	  SET @d_step5 = NULL
	
	  SET @d_step4 = GETDATE()
	END
				
				-- Check the last char of the file path consists of '\'
	IF SUBSTRING(ISNULL(RTRIM(@c_FilePath), ''), LEN(ISNULL(RTRIM(@c_FilePath), '')), 1) <> '\'
		SET @c_FilePath = ISNULL(RTRIM(@c_FilePath), '') + '\'
	
	SET @cMoveFilePath = ISNULL(RTRIM(@c_FilePath), '')
	
	-- SHONG01
	SELECT @b_success = 0  
	SET @c_TCP_Authority = '0'
	
	SELECT @c_Facility = Facility
	FROM dbo.Orders (nolock)
	WHERE OrderKey = @c_OrderKey
	
	EXECUTE dbo.nspGetRight 
		@c_Facility,   -- facility 
		@c_Storerkey,  -- Storerkey  
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
       @c_PrinterID,
       @nErrNo OUTPUT, 
       @cErrMsg OUTPUT  
    END
    ELSE
    BEGIN    
		EXECUTE [RDT].[rdt_PrintGSILabel]
			@@SPID,
			@cWorkFilePath,
			@cMoveFilePath,
			@c_FileName,
			@cLangCode,
			@nErrNo   OUTPUT,
			@cErrMsg  OUTPUT
	END
    		
--				IF @nErrNo <> 0
--				BEGIN
--					SET @nErrNo = 66281
--					SET @cErrMsg = rdt.rdtgetmessage( 66281, @cLangCode, 'DSP') --'GSILBLCrtFail'
--					GOTO RollBackTran
--				END

   
END


GO