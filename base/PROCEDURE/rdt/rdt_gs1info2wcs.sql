SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_GS1Info2WCS					                        */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Sent WCS Interface                                          */
/*                                                                      */
/* Called from: rdtfnc_Scan_And_Pack                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author    Purposes                                 */
/* 10-June-2010 1.0  ChewKP     Created                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_GS1Info2WCS] (
   @nMobile              INT,
   @cFacility            NVARCHAR( 5),
   @cStorerKey           NVARCHAR( 15),
   @cDropID              NVARCHAR( 18),
   @cMBOLKey             NVARCHAR( 10),
   @cLoadKey             NVARCHAR( 10),
   @cFilePath1           NVARCHAR( 50),
	@cPrepackByBOM        NVARCHAR( 1),
   @cUserName            NVARCHAR( 18),
   @cPrinter             NVARCHAR( 20),
   @cLangCode            NVARCHAR (3),
   @nCaseCnt             INT, 
   @b_LocFilter          INT = 0, 
   @nErrNo               INT          OUTPUT,
   @cErrMsg              NVARCHAR( 20) OUTPUT  -- screen limitation, 20 NVARCHAR max
) AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

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
      @nMax_CartonNo     INT, 
      @nCartonNo         INT,
      @cLabelNo          NVARCHAR( 20) 
      

	DECLARE
      @cMS               NVARCHAR( 3),
      @dTempDateTime     DATETIME

   DECLARE    @n_debug		int

   SET @n_debug = 0

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
		--SET @c_col1 = @cOrderKey
		--SET @c_col2 = @cSKU
		--SET @c_col3 = @nQTY
		SET @c_col4 = @cPrinter

		SET @d_starttime = getdate()

		SET @c_TraceName = 'rdt_GS1Info2WCS'
	END

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN GS1Info2WCS


   BEGIN
      SET @d_step1 = GETDATE()

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

	   IF @n_debug = 1
		BEGIN
	      SET @d_step2 = GETDATE() - @d_step2
		  SET @c_col1 = 'WRITE TO XML START'
		  SET @d_endtime = GETDATE()
		  INSERT INTO TraceInfo VALUES
			  (RTRIM(@c_TraceName), @d_starttime, @d_endtime
	         ,CONVERT(NVARCHAR(12),@d_endtime - @d_starttime ,114)
				,CONVERT(NVARCHAR(12),@d_step1,114)
				,CONVERT(NVARCHAR(12),@d_step2,114)
				,CONVERT(NVARCHAR(12),@d_step3,114)
				,CONVERT(NVARCHAR(12),@d_step4,114)
				,CONVERT(NVARCHAR(12),@d_step5,114)
				--,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)
 				,@c_Col1
				,SUBSTRING(@cFilename,1,20)
				,SUBSTRING(@cFilename,21,20)
				,SUBSTRING(@cFilename,41,20)
				,CONVERT(NVARCHAR(20),@nCartonNo))

		  SET @d_step1 = NULL
		  SET @d_step2 = NULL
		  SET @d_step3 = NULL
		  SET @d_step4 = NULL
		  SET @d_step5 = NULL

		  SET @d_step3 = GETDATE()
		END

      EXEC dbo.isp_GS1Info2WCS
         @cLoadKey
       , @cDropID
       , ''
       , 0
       , 0
       , @b_LocFilter 
       , @b_Success   OUTPUT
       

	   IF @n_debug = 1
		BEGIN
	      SET @d_step3 = GETDATE() - @d_step3
		  SET @c_col1 = 'WRITE TO XML END'
		  SET @d_endtime = GETDATE()
		  INSERT INTO TraceInfo VALUES
			  (RTRIM(@c_TraceName), @d_starttime, @d_endtime
				,CONVERT(NVARCHAR(12),@d_endtime - @d_starttime ,114)
				,CONVERT(NVARCHAR(12),@d_step1,114)
				,CONVERT(NVARCHAR(12),@d_step2,114)
				,CONVERT(NVARCHAR(12),@d_step3,114)
				,CONVERT(NVARCHAR(12),@d_step4,114)
				,CONVERT(NVARCHAR(12),@d_step5,114)
				--,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)
 				,@c_Col1
				,SUBSTRING(@cFilename,1,20)
				,SUBSTRING(@cFilename,21,20)
				,SUBSTRING(@cFilename,41,20)
				,CONVERT(NVARCHAR(20),@nCartonNo))

		  SET @d_step1 = NULL
		  SET @d_step2 = NULL
		  SET @d_step3 = NULL
		  SET @d_step4 = NULL
		  SET @d_step5 = NULL

		  SET @d_step4 = GETDATE()
		END



		IF @b_Success = 1 
		BEGIN 
			-- Check the last NVARCHAR of the file path consists of '\'
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
			IF @n_debug = 1
			BEGIN
				SET @d_step4 = GETDATE() - @d_step4
				SET @c_col1 = 'Print GSI Label'
				SET @d_endtime = GETDATE()
				INSERT INTO TraceInfo VALUES
							(RTRIM(@c_TraceName), @d_starttime, @d_endtime
						,CONVERT(NVARCHAR(12),@d_endtime - @d_starttime ,114)
						,CONVERT(NVARCHAR(12),@d_step1,114)
						,CONVERT(NVARCHAR(12),@d_step2,114)
						,CONVERT(NVARCHAR(12),@d_step3,114)
						,CONVERT(NVARCHAR(12),@d_step4,114)
						,CONVERT(NVARCHAR(12),@d_step5,114)
						--,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)
 						,@c_Col1
						,SUBSTRING(@cFilename,1,20)
						,SUBSTRING(@cFilename,21,20)
						,SUBSTRING(@cFilename,41,20)
						,CONVERT(NVARCHAR(20),@nCartonNo))

				SET @d_step1 = NULL
				SET @d_step2 = NULL
				SET @d_step3 = NULL
				SET @d_step4 = NULL
				SET @d_step5 = NULL
			END
		END
   END
   
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN GS1Info2WCS

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN GS1Info2WCS
END

GO