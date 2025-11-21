SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_GS1Info2WCS_Fixes					                  */
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
/************************************************************************/

CREATE PROC [RDT].[rdt_GS1Info2WCS_Fixes] (
   @cFacility            NVARCHAR( 5),
   @cDropID              NVARCHAR( 18),
   @cLoadKey             NVARCHAR( 10),
	@cLangCode            VARCHAR (3),
   @nErrNo               INT          OUTPUT,  
   @cErrMsg              NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE
      @b_success         INT,
      @n_err             INT,
      @c_errmsg          NVARCHAR( 255)

   DECLARE
      @cPickHeaderKey    NVARCHAR( 10),
      @cLabelLine        NVARCHAR( 5),
      @cComponentSku     NVARCHAR( 20),
      @nComponentQTY     INT,
      @nTranCount        INT,
      @cYYYY             NVARCHAR( 4),
      @cMM               NVARCHAR( 2),
      @cDD               NVARCHAR( 2),
      @cHH               NVARCHAR( 2),
      @cMI               NVARCHAR( 2),
      @cSS               NVARCHAR( 2),
      @cDateTime         NVARCHAR( 17), 
      @cSPID             NVARCHAR( 5),
      @cFileName         NVARCHAR( 215),
      @cWorkFilePath     NVARCHAR( 120),
      @cMoveFilePath     NVARCHAR( 120),
      @cFilePath         NVARCHAR( 120),
      @nSumQtyPicked     INT,
      @nSumQtyPacked     INT,
      @nMax_CartonNo     INT, -- (Vicky02)
      @nCartonNo         INT,
      @cLabelNo          NVARCHAR( 20),
      @cWCSFilePath1       NVARCHAR( 50),
      @cFilePath1           NVARCHAR( 50)
      
	

	DECLARE
      @cMS               NVARCHAR( 3),
      @dTempDateTime     DATETIME

   DECLARE    @n_debug		int

   SET @n_debug = 0


--   SET @nTranCount = @@TRANCOUNT
--
--   BEGIN TRAN
--   SAVE TRAN GS1_Carton_Label_GS1Info2WCS


   BEGIN
      

      SET  @cWCSFilePath1 = ''
      SELECT @cWCSFilePath1 = UserDefine18 FROM dbo.FACILITY WITH (NOLOCK)
      WHERE FACILITY = @cFacility

       -- use 2 variables to store because facility.userdefine20 is NVARCHAR(30) while rdt v_string variable is NVARCHAR(20)
      SET @cFilePath1 = @cWCSFilePath1
      

      SET @dTempDateTime = GetDate()

      SET @cYYYY = RIGHT( '0' + ISNULL(RTRIM( DATEPART( yyyy, @dTempDateTime)), ''), 4)
      SET @cMM = RIGHT( '0' + ISNULL(RTRIM( DATEPART( mm, @dTempDateTime)), ''), 2)
      SET @cDD = RIGHT( '0' + ISNULL(RTRIM( DATEPART( dd, @dTempDateTime)), ''), 2)
      SET @cHH = RIGHT( '0' + ISNULL(RTRIM( DATEPART( hh, @dTempDateTime)), ''), 2)
      SET @cMI = RIGHT( '0' + ISNULL(RTRIM( DATEPART( mi, @dTempDateTime)), ''), 2)
      SET @cSS = RIGHT( '0' + ISNULL(RTRIM( DATEPART( ss, @dTempDateTime)), ''), 2)

      SET @cDateTime = @cYYYY + @cMM + @cDD + @cHH + @cMI + @cSS 

      SET @cSPID = @@SPID
      SET @cFilename = ISNULL(RTRIM(@cLoadkey), '') + '_' + ISNULL(RTRIM(@cDropID),'') + '_' + ISNULL(RTRIM(@cDateTime),'') + '.XML'
      SET @cFilePath = ISNULL(RTRIM(@cFilePath1), '') 
      SET @cWorkFilePath = ISNULL(RTRIM(@cFilePath), '') + 'Working'
		
		

      -- Clear the XML record
      DELETE FROM RDT.RDTGSICartonLabel_XML with (rowlock) WHERE [SPID] = @@SPID

	 

      EXEC dbo.isp_GS1Info2WCS
         @cLoadKey
       , @cDropID
       , ''
       , 0
       , 0
       , @b_Success   OUTPUT
	   , 1
       

	  


		IF @b_Success = 1 
		BEGIN 
			-- Check the last char of the file path consists of '\'
			IF SUBSTRING(ISNULL(RTRIM(@cFilePath), ''), LEN(ISNULL(RTRIM(@cFilePath), '')), 1) <> '\'
				SET @cFilePath = ISNULL(RTRIM(@cFilePath), '') + '\'

			SET @cMoveFilePath = ISNULL(RTRIM(@cFilePath), '')

			EXECUTE [RDT].[rdt_PrintGSILabel]
				@@SPID,
				@cWorkFilePath,
				@cMoveFilePath,
				@cFileName,
				@cLangCode,
				@nErrNo   OUTPUT,
				@cErrMsg  OUTPUT

			IF @nErrNo <> 0
			BEGIN
				SET @nErrNo = 66281
				SET @cErrMsg = rdt.rdtgetmessage( 66281, @cLangCode, 'DSP') --'GSILBLCrtFail'
				GOTO RollBackTran
			END
			
		END
   END
   
   GOTO Quit

   RollBackTran:
      --ROLLBACK TRAN GS1_Carton_Label_GS1Info2WCS
      PRINT @nErrNo
      PRINT @cERRMSG 

   Quit:
      --WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
        -- COMMIT TRAN GS1_Carton_Label_GS1Info2WCS
END

GO