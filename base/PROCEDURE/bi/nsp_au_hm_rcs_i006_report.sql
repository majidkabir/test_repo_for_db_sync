SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Updates:                                                                */
/* Date         Author      Ver.  Purposes                                 */
/* 06-Sep-2021  JohnChuah   1.0   Created                                  */
/* 08-Dec-2021  AwYoung,A   1.1   Updated for AU                           */
/***************************************************************************/

CREATE PROC [BI].[nsp_AU_HM_RCS_i006_Report]
AS
BEGIN
   SET NOCOUNT ON;  -- keeps the output generated to a minimum
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;

   DECLARE @nRowCnt   INT = 0
         , @Proc      NVARCHAR(128) = 'nsp_AU_HM_RCS_i006_Report'
         , @cParamOut NVARCHAR(4000)= ''
         , @cParamIn  NVARCHAR(4000)= ''

   DECLARE @tVarLogId TABLE (LogId INT);
   INSERT dbo.ExecutionLog (ClientId, SP, ParamIn) OUTPUT INSERTED.LogId INTO @tVarLogId VALUES ('HM', @Proc, @cParamIn);

   --DECLARE @Stmt NVARCHAR(MAX) = '' -- for storing dynamic SQL Statement

   SELECT   'W312'                                    AS 'SiteID',
		      RIGHT(i.itrnkey, 9)                       AS 'AdjustmentID',
            REPLACE(trf.type, 'HM-', '')              AS 'ProcessCode',
		      trfd.tosku                                AS 'SKU',
		      trfd.lottable01                           AS 'Season',
		      format(MI.AddDate,'yyyyMMddHHmm')         AS 'TranscationDate',
		--   MI.filename,
		--   Substring(MI.filename, 8, Len(MI.filename)-1),
         REPLACE(Substring(MI.filename, 8, Len(MI.filename)), '.txt', '.xml') AS 'filename'

	FROM BI.V_transferdetail trfd
	JOIN Bi.V_transfer trf   ON trf.transferkey = trfd.transferkey
   JOIN BI.V_transmitlog3 t ON t.key1 = trfd.transferkey
	JOIN AUDTSITF.BI.V_DTS_IML_GENERIC_ITFLOG MI  ON t.transmitlogkey = MI.RefKey2
	LEFT JOIN BI.V_itrn i    ON trfd.transferkey + trfd.transferlinenumber = i.sourcekey

   WHERE i.trantype = 'DP'
	AND i.sourcetype = 'ntrTransferDetailUpdate'
	AND t.tablename = 'TRFLOG'
	AND MI.datastream = '3572'
	and MI.adddate >DATEADD(HOUR,-24,GETDATE())

	union all
	SELECT     'W312'                                     AS 'SiteID',
	RIGHT(i.itrnkey, 9)                                   AS 'AdjustmentID',
   REPLACE(trf.type, 'HM-', '')                          AS 'ProcessCode',
	trfd.tosku                                            AS 'SKU',
	trfd.lottable01                                       AS 'Season',
	FORMAT(MI.AddDate,'yyyyMMddHHmm')                     AS 'TranscationDate',
		--   MI.filename,
		--   Substring(MI.filename, 8, Len(MI.filename)-1),
   REPLACE(Substring(MI.filename, 8, Len(MI.filename)), '.txt', '.xml') AS 'filename'


	FROM BI.V_transferdetail trfd
	JOIN BI.V_transfer trf   ON trf.transferkey = trfd.transferkey
	JOIN BI.V_transmitlog3 t ON t.key1 = trfd.transferkey
	JOIN AUDTSITF.BI.V_DTS_IML_GENERIC_ITFLOG MI  ON t.transmitlogkey = MI.RefKey2
	LEFT JOIN BI.V_itrn i    ON trfd.transferkey + trfd.transferlinenumber = i.sourcekey

	WHERE  i.trantype = 'AJ'
	AND i.sourcetype = 'ntrAdjustmentDetailUpdate'
	AND t.tablename = 'ADJLOG'
	AND MI.datastream = '3572'
	AND MI.adddate >DATEADD(HOUR,-24,GETDATE())


	union all
	SELECT     'W312'                           AS 'SiteID',
	RIGHT(i.itrnkey, 9)                         AS 'AdjustmentID',
     REPLACE(trf.type, 'HM-', '')              AS 'ProcessCode',
	trfd.tosku                                  AS 'SKU',
	trfd.lottable01                             AS 'Season',
	FORMAT(MI.AddDate,'yyyyMMddHHmm')           AS 'TranscationDate',
	--   MI.filename,
	--   Substring(MI.filename, 8, Len(MI.filename)-1),
   REPLACE(Substring(MI.filename, 8, Len(MI.filename)), '.txt', '.xml') AS 'filename'


	FROM BI.V_transferdetail trfd
	JOIN BI.V_transfer trf   ON trf.transferkey = trfd.transferkey
   JOIN BI.V_transmitlog3 t ON t.key1 = trfd.transferkey
	JOIN AUDTSITF.BI.V_DTS_IML_GENERIC_ITFLOG MI  ON t.transmitlogkey = MI.RefKey2
	LEFT JOIN BI.V_itrn i    ON trfd.transferkey + trfd.transferlinenumber = i.sourcekey

   WHERE  (i.SourceType = 'rdt_Putaway' or i.SourceType LIKE '%Move%' or i.SourceType='')
   -- AND t.tablename = 'ADJLOG'
	AND MI.datastream = '3572'
	and  MI.adddate >DATEADD(HOUR,-24,GETDATE())
   --------------------------------------------------------------------- MOVE

   SET @nRowCnt = @@ROWCOUNT;

   --SET @cParamOut = '{ "Stmt": "'+@Stmt+'" }'; -- for dynamic SQL only
   UPDATE dbo.ExecutionLog SET TimeEnd = GETDATE(), RowCnt = @nRowCnt, ParamOut = @cParamOut
   WHERE LogId = (SELECT TOP 1 LogId FROM @tVarLogId);

END

GO