SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  ispPrintWCSTraceReport                             */
/* Creation Date: 29-Jun-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: sHONG                                                    */
/*                                                                      */
/* Purpose:  Project Diana - Print WCS Trace Report                     */
/*                                                                      */
/* Input Parameters:  @cToteNo                                          */
/*                                                                      */
/* Called By:  dw = r_dw_wcsrouting_trace_report                        */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 22-Sep-2015  Leong         SOS# 352283 - Bug fix.                    */
/* 24-Feb-2019  TLTING01      linked server to WCS db                   */  
/************************************************************************/

CREATE PROC [dbo].[ispPrintWCSTraceReport]
( @cToteNo  NVARCHAR(20) -- SOS# 352283
)
AS
BEGIN

SET NOCOUNT ON
-- linked SERVER  
SET ANSI_NULLS ON   
SET ANSI_WARNINGS ON  

DECLARE @nBoxNumber       NUMERIC(20,0), -- SOS# 352283
        @cWCSKey          NVARCHAR(10),
        @cActionFlag      NVARCHAR(10),
        @dHD_AddDate      DATETIME,
        @dDT_AddDate      DATETIME,
        @cDT_ActionFlag   NVARCHAR(10),
        @cDT_Zone         NVARCHAR(10),
        @nDT_RowRef       INT,
        @nWCS_HD_Status   INT,
        @nWCS_DT_Status   INT,
        @dWCS_HD_PickupDT DATETIME,
        @dWCS_DT_PickupDT DATETIME,
        @dWCS_RP_ReadDT   DATETIME,
        @cHD_TaskType     NVARCHAR(10),
        @cWMS_Station     NVARCHAR(10),
        @cSQLStatement    NVARCHAR(MAX),
        @bDebug           INT,
        @cLineText        NVARCHAR(215),
        @cWCSDBName       NVARCHAR(50),
        @cStorerKey       NVARCHAR(15)

DECLARE @t_Report TABLE
   (LineNum     INT IDENTITY(1,1),
    LineText    NVARCHAR(215),
    RespondTime DATETIME
   )

SET @bDebug = 0

IF ISNUMERIC(@cToteNo) <> 1
   GOTO QUIT_SP

SET @nBoxNumber = CAST(@cToteNo AS NUMERIC(20,0)) -- SOS# 352283

SET @cLineText = 'Tote#: ' + @cToteNo
INSERT INTO @t_Report(LineText,RespondTime)
VALUES(@cLineText, '19000101')
INSERT INTO @t_Report(LineText,RespondTime)
VALUES('', '19000101')

DECLARE CURSOR_TOTENO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT w.WCSKey, w.ActionFlag, w.AddDate, w.TaskType, w.StorerKey
FROM WCSRouting w WITH (NOLOCK)
WHERE w.ToteNo = @cToteNo
ORDER BY w.WCSKey

OPEN CURSOR_TOTENO
FETCH NEXT FROM CURSOR_TOTENO INTO @cWCSKey, @cActionFlag, @dHD_AddDate, @cHD_TaskType, @cStorerKey

WHILE @@FETCH_STATUS <> -1
BEGIN
   SET @cWCSDBName = ''
   SELECT @cWCSDBName = UPPER(SValue)
   FROM   dbo.StorerConfig WITH (NOLOCK)
   WHERE  CONFIGKEY = 'REPWCSDB'
   AND Storerkey = @cStorerKey

   IF ISNULL(RTRIM(@cWCSDBName),'') = ''
      GOTO QUIT_SP

   SET @cSQLStatement=
   N'SELECT @nWCS_HD_Status   = WCSHD.STATE_HCOM, ' +
   '        @dWCS_HD_PickupDT = WCSHD.DATE_UPDATED ' +
   'FROM   ' + RTRIM(@cWCSDBName) + '.dbo.Order_header WCSHD WITH (NOLOCK) ' +
   'WHERE  WCSHD.SEQNUM_HEADER = CAST(@cWCSKey AS INT) '

   EXEC sp_ExecuteSQL @cSQLStatement, N'@nWCS_HD_Status INT OUTPUT, @dWCS_HD_PickupDT DATETIME OUTPUT, @cWCSKey NVARCHAR(10)',
                      @nWCS_HD_Status OUTPUT, @dWCS_HD_PickupDT OUTPUT, @cWCSKey

   SET @cLineText = 'Routing# ' + CONVERT(NVARCHAR(10), CAST(@cWCSKey AS INT))
                  + '. Status:'
                  + CASE WHEN @nWCS_HD_Status = 30 THEN ' OK ' ELSE 'FAILED' END
                  + '. Started At: ' + CONVERT(NVARCHAR(20), ISNULL(@dWCS_HD_PickupDT,'')) -- SOS# 352283

   INSERT INTO @t_Report(LineText,RespondTime)
   VALUES (@cLineText,@dWCS_HD_PickupDT)
   SET @cLineText =
              '   Task Type: ' + CASE @cHD_TaskType WHEN 'PK' THEN '(Picking)'
                                                    WHEN 'PA' THEN '(Put-away)'
                                                    ELSE '(' + @cHD_TaskType + ')'
                                 END
            + ' Conveyor Routing ' + CASE @cActionFlag WHEN 'I' THEN 'Insert'
                                                       WHEN 'D' THEN 'Delete'
                                                       WHEN 'U' THEN 'Update'
                                     END

   INSERT INTO @t_Report(LineText,RespondTime)
   VALUES (@cLineText,@dWCS_HD_PickupDT)

   INSERT INTO @t_Report(LineText,RespondTime)
   VALUES ('',@dWCS_HD_PickupDT)
   IF @nWCS_HD_Status = 30
   BEGIN
      DECLARE CURSOR_WCSDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT wd.RowRef, wd.Zone, wd.ActionFlag, wd.AddDate
      FROM WCSRoutingDetail wd WITH (NOLOCK)
      WHERE wd.WCSKey = @cWCSKey
      ORDER BY wd.RowRef

      OPEN CURSOR_WCSDETAIL
      FETCH NEXT FROM CURSOR_WCSDETAIL INTO @nDT_RowRef, @cDT_Zone, @cDT_ActionFlag, @dDT_AddDate
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @nWCS_DT_Status=0

         SET @cSQLStatement =
         N'SELECT @nWCS_DT_Status   = WCSDT.STATE_HCOM, ' +
         '        @dWCS_DT_PickupDT = WCSDT.DATE_UPDATED ' +
         'FROM   ' + @cWCSDBName + '.dbo.Order_Detail WCSDT WITH (NOLOCK) ' +
         'WHERE  WCSDT.SEQNUM_HEADER = CAST(@cWCSKey AS INT)  ' +
         'AND    WCSDT.SEQNUM_DETAIL = @nDT_RowRef '

         EXEC sp_ExecuteSQL @cSQLStatement,
                          N'@nWCS_DT_Status NVARCHAR(10) OUTPUT, @dWCS_DT_PickupDT DATETIME OUTPUT, @cWCSKey NVARCHAR(10), @nDT_RowRef INT',
                            @nWCS_DT_Status OUTPUT, @dWCS_DT_PickupDT OUTPUT, @cWCSKey, @nDT_RowRef

         SET @nWCS_DT_Status=ISNULL(@nWCS_DT_Status,0)
         IF @nWCS_DT_Status = 0
         BEGIN
            SET @cLineText = '    Record Not Found in WCS Detail'

            INSERT INTO @t_Report(LineText, RespondTime)
            VALUES (@cLineText, @dDT_AddDate)

            IF @bDebug = 1
            BEGIN
               PRINT @cLineText
            END
         END
         ELSE
         BEGIN
            SET @cWMS_Station = ''

            SELECT @cWMS_Station = CODE
            FROM   CODELKUP c WITH (NOLOCK)
            WHERE  c.LISTNAME = 'WCSSTATION'
            AND    C.Short = @cDT_Zone

            SET @cWMS_Station = CASE WHEN ISNULL(RTRIM(@cWMS_Station),'') ='' THEN '' ELSE '(' +  RTRIM(@cWMS_Station) + ')' END

            SET @dWCS_RP_ReadDT = NULL

            SET @cSQLStatement =
            N'SELECT TOP 1 @dWCS_RP_ReadDT = WCSRP.READING_TIME ' +
             'FROM ' + @cWCSDBName + '.dbo.STATION_RESPONSE WCSRP WITH (NOLOCK) ' +
             'WHERE WCSRP.BoxNumber = @nBoxNumber  ' +
             'AND   WCSRP.STATION = @cDT_Zone  ' +
             'AND   WCSRP.READING_TIME >  @dWCS_DT_PickupDT '
            
            EXEC sp_ExecuteSQL @cSQLStatement,
                             N'@dWCS_RP_ReadDT DATETIME OUTPUT, @nBoxNumber NUMERIC(20,0), @cDT_Zone NVARCHAR(10), @dWCS_DT_PickupDT DATETIME',
                               @dWCS_RP_ReadDT OUTPUT, @nBoxNumber, @cDT_Zone, @dWCS_DT_PickupDT

            SET @cLineText = '>>  Station: ' + @cDT_Zone + ' ' + @cWMS_Station + '. Status:'
                           + CASE WHEN @nWCS_DT_Status = 30 THEN ' OK ' ELSE 'FAILED' END
                           + '. ' + CASE @cDT_ActionFlag WHEN 'D' THEN 'Station Routing Cancel' ELSE '' END
            INSERT INTO @t_Report(LineText, RespondTime)
            VALUES (@cLineText, CASE WHEN @dWCS_RP_ReadDT IS NOT NULL THEN @dWCS_RP_ReadDT ELSE @dWCS_DT_PickupDT END)

            IF @dWCS_RP_ReadDT IS NOT NULL
            BEGIN
               SET @cLineText = '   Arrived Station: ' + CONVERT(NVARCHAR(20), @dWCS_RP_ReadDT)
                                + '. Routing# ' + CONVERT(NVARCHAR(10), CAST(@cWCSKey AS INT))
               INSERT INTO @t_Report(LineText, RespondTime)
               VALUES (@cLineText, @dWCS_RP_ReadDT)

               SET @cLineText = ''
               INSERT INTO @t_Report(LineText, RespondTime)
               VALUES (@cLineText, @dWCS_RP_ReadDT)
            END
            ELSE
            BEGIN
               SET @cLineText = '   Not Yet Arrive! '
               INSERT INTO @t_Report(LineText, RespondTime)
               VALUES (@cLineText, @dWCS_DT_PickupDT)

               SET @cLineText = ''
               INSERT INTO @t_Report(LineText, RespondTime)
               VALUES (@cLineText, @dWCS_DT_PickupDT)
            END
         END

         FETCH NEXT FROM CURSOR_WCSDETAIL INTO @nDT_RowRef, @cDT_Zone, @cDT_ActionFlag, @dDT_AddDate
      END
      CLOSE CURSOR_WCSDETAIL
      DEALLOCATE CURSOR_WCSDETAIL
   END
   ELSE
   BEGIN
      SET @cLineText = ''

      INSERT INTO @t_Report(LineText, RespondTime)
      VALUES (@cLineText, @dHD_AddDate)
   END

   FETCH NEXT FROM CURSOR_TOTENO INTO @cWCSKey, @cActionFlag, @dHD_AddDate, @cHD_TaskType, @cStorerKey
END
CLOSE CURSOR_TOTENO
DEALLOCATE CURSOR_TOTENO


QUIT_SP:
   SELECT *
   FROM @t_Report
   ORDER BY LineNum, RespondTime -- SOS# 352283
END


GO