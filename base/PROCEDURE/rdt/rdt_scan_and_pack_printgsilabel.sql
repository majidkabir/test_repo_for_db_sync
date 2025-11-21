SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Scan_And_Pack_PrintGSILabel                     */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Write GSI label and move to specific folder                 */
/*                                                                      */
/* Called from: rdtfnc_Scan_And_Pack                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 14-Apr-2009 1.0  James       Created                                 */
/* 15-Jun-2009 1.1  James       Add in TraceInfo                        */
/* 18-Jun-2009 1.2  KKY         Added debug flag                        */
/*                              Modified write file cursor, format      */
/*                              the result to a variable                */
/*                              1st before writing it to the file       */
/* 26-Jun-2009 1.3  KKY         Included filename in TraceInfo          */
/* 06-Dec-2011 1.4  Ung         SOS231818 RDTGSICartonLabel_XML.LineText*/
/*                              set to NVARCHAR( max)                    */
/************************************************************************/

CREATE PROC [RDT].[rdt_Scan_And_Pack_PrintGSILabel] (
   @nSPID             INT,
   @cWorkFilePath     NVARCHAR( 120),
   @cMoveFilePath     NVARCHAR( 120),
   @cFilename         NVARCHAR( 215),
   @cLangCode         VARCHAR (3),
   @nErrNo            INT          OUTPUT, 
   @cErrMsg           NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max
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
      @cLineText         NVARCHAR( MAX),
      @cFullText         NVARCHAR(MAX), 
      @nFirstTime        INT

   DECLARE    @n_debug        int

   SET @n_debug = 1  
   
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

      SET @d_starttime = getdate()

      SET @c_TraceName = 'rdt_Scan_And_Pack_PrintGSILabel'

      SET @d_step1 = GETDATE()
    END
   
   SET @nFirstTime = 1   
   -- Write to file (Start)
   DECLARE CUR_WRITEFILE CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT LineText FROM RDT.RDTGSICartonLabel_XML WITH (NOLOCK) 
   WHERE SPID = @nSPID
   ORDER BY SeqNo
   OPEN CUR_WRITEFILE
   FETCH NEXT FROM CUR_WRITEFILE INTO @cLineText
   WHILE @@FETCH_STATUS <> -1
   BEGIN

--      IF @nFirstTime = 1
--      BEGIN
--         EXEC dbo.isp_WriteStringToFile 
--            @cLineText, 
--            @cWorkFilePath, 
--            @cFilename, 
--            2, -- IOMode 2 = ForWriting ,8 = ForAppending
--            @b_success Output
--
--         IF @b_success <> 1
--         BEGIN
--            SET @nErrNo = 66976
--            SET @cErrMsg = rdt.rdtgetmessage( 66976, @cLangCode, 'DSP') --FileOpenFail
--            CLOSE CUR_WRITEFILE
--            DEALLOCATE CUR_WRITEFILE
--            GOTO Quit
--         END
--
--         SET @nFirstTime = 0
--      END
--      ELSE
--      BEGIN
--         EXEC dbo.isp_WriteStringToFile 
--            @cLineText, 
--            @cWorkFilePath, 
--            @cFilename, 
--            8, -- IOMode 2 = ForWriting ,8 = ForAppending
--            @b_success Output
--
--         IF @b_success <> 1
--         BEGIN
--            SET @nErrNo = 66977
--            SET @cErrMsg = rdt.rdtgetmessage( 66977, @cLangCode, 'DSP') --FileWriteFail
--            CLOSE CUR_WRITEFILE
--            DEALLOCATE CUR_WRITEFILE
--            GOTO Quit
--         END
--      END

      IF @nFirstTime = 1
         SET @nFirstTime = 0
     ELSE
       SET @cFullText = @cFullText + master.dbo.fnc_GetCharASCII(13) + master.dbo.fnc_GetCharASCII(10)      
   
     SET @cFullText = @cFullText + @cLineText

      FETCH NEXT FROM CUR_WRITEFILE INTO @cLineText
   END
   CLOSE CUR_WRITEFILE
   DEALLOCATE CUR_WRITEFILE
   
-- Write to file (End)
   EXEC dbo.isp_WriteStringToFile 
        @cFullText, 
        @cWorkFilePath, 
        @cFilename, 
        2, -- IOMode 2 = ForWriting ,8 = ForAppending
        @b_success Output

        IF @b_success <> 1
         BEGIN
            SET @nErrNo = 66976
            SET @cErrMsg = rdt.rdtgetmessage( 66976, @cLangCode, 'DSP') --FileOpenFail
            GOTO Quit
         END

   IF @n_debug = 1
    BEGIN   
      SET @d_step1 = GETDATE() - @d_step1
      SET @d_endtime = GETDATE()
      SET @c_Col1 = 'Write file'
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
            ,SUBSTRING(@cFilename,1,20)
            ,SUBSTRING(@cFilename,21,20)
            ,SUBSTRING(@cFilename,41,20)
            ,@c_Col5)
   
      SET @d_step1 = NULL
      SET @d_step2 = NULL
      SET @d_step3 = NULL
      SET @d_step4 = NULL
      SET @d_step5 = NULL
    END

   SET @cWorkFilePath = @cWorkFilePath + '\' + @cFileName
   SET @cMoveFilePath = @cMoveFilePath + @cFileName

   IF @n_debug = 1
      SET @d_step2 = GETDATE()

   -- Move File (Start)
   EXEC dbo.isp_MoveFile
      @cWorkFilePath OUTPUT, 
      @cMoveFilePath OUTPUT,
      @b_success Output

   IF @b_success <> 1
   BEGIN
      SET @nErrNo = 66978
      SET @cErrMsg = rdt.rdtgetmessage( 66978, @cLangCode, 'DSP') --MoveFileFail
      GOTO Quit
   END
   -- Move File (End)

   IF @n_debug = 1
    BEGIN   
      SET @d_step2 = GETDATE() - @d_step2
      SET @d_endtime = GETDATE()
      SET @c_Col1 = 'Move file'
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
            ,SUBSTRING(@cFilename,1,20)
            ,SUBSTRING(@cFilename,21,20)
            ,SUBSTRING(@cFilename,41,20)
            ,@c_Col5)   
      SET @d_step1 = NULL
      SET @d_step2 = NULL
      SET @d_step3 = NULL
      SET @d_step4 = NULL
      SET @d_step5 = NULL
    END
   Quit:
END

GO