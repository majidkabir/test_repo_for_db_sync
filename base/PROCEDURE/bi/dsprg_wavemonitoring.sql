SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
-- RG - AdidAS SEA - Create LogiReport views for Outbound reports https://jiralfl.atlASsian.net/browse/WMS-18042
/* Updates:                                                                */
/* Date         Author      Ver.  Purposes                                 */
/* 08-Oct-2021  KSheng      1.0   Created                                  */
/* 26-Oct-2021  AbdulRosyid 1.1   Added Storerkey parameter                */
/* 28-Oct-2021  Crisnah		 1.2   Added Cancelled order status             */
/***************************************************************************/

CREATE PROC [BI].[dspRG_WaveMonitoring]
   @PARAM_StartDate DATETIME = NULL,
   @PARAM_EndDate   DATETIME = NULL,
   @PARAM_StorerKey NVARCHAR(15) = NULL  -- Put @PARAM_StorerKey here to be enable for another storer
AS
BEGIN
   SET NOCOUNT ON;  -- keeps the output generated to a minimum 
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;

   IF ISNULL(@PARAM_StorerKey, '') = ''
      SET @PARAM_StorerKey = 'ADIDAS'

   IF ISNULL(@PARAM_StartDate, '') = ''
      SET @PARAM_StartDate = DateAdd(MM, -1, GETDATE())
   IF ISNULL(@PARAM_EndDate, '') = ''
      SET @PARAM_EndDate = GETDATE()

   DECLARE @c_StorerKey NVARCHAR(15),
           @c_StartDate DATETIME,
           @c_EndDate   DATETIME;

   SET @c_StorerKey = @PARAM_StorerKey;
   SET @c_StartDate = @PARAM_StartDate;
   SET @c_EndDate = @PARAM_EndDate;
   
   DECLARE @nRowCnt INT = 0
         , @Proc      NVARCHAR(128) = 'dspRG_WaveMonitoring'
         , @cParamOut NVARCHAR(4000)= ''
         , @cParamIn  NVARCHAR(4000)= '{ "PARAM_StartDate":"'+CONVERT(NVARCHAR(19),@PARAM_StartDate,121)+'",'
                                    + '"PARAM_EndDate":"'+CONVERT(NVARCHAR(19),@PARAM_EndDate,121)+'"'
                                    + ' }'

   DECLARE @tVarLogId TABLE (LogId INT);
   INSERT dbo.ExecutiONLog (ClientId, SP, ParamIn) OUTPUT INSERTED.LogId INTO @tVarLogId VALUES (@PARAM_StorerKey, @Proc, @cParamIn);

   DECLARE @Stmt NVARCHAR(MAX) = '' -- for storing dynamic SQL Statement

SELECT O.StorerKey          AS '01Storerkey'
     , O.OrderKey           AS '02Orderkey'
     , ISNULL(W.WaveKey,'') AS '03Wavekey'
     , CASE WHEN O.Status = '0' THEN 'OPEN'
            WHEN O.Status = '9' THEN 'SHIPPED' 
            WHEN O.Status = '5' THEN 'PACKED' --B2C
            WHEN SL.PPSCnt > 0  THEN 'PPS'
            WHEN PIN.RefNo = 'PPA' AND (ISNULL(PPA.PQty,0)) = (ISNULL(PPA.CQty,0)) THEN 'PPA'
            WHEN O.Status = 'CANC' THEN 'CANCELLED'
            WHEN O.Status NOT IN ('5','CANC') THEN --'SORTING'
               CASE WHEN ((O.Status) IN ('1','2') AND TD.Status = '9' AND TD.TaskType = 'ASTCPK') --LOOSE
                      OR ((O.Status) IN ('1','2') AND TD.Status = '9' AND TD.TaskType = 'RPF' AND TD.Message02 = 'PS') THEN 'PICKED' --FULL
                    WHEN ((O.Status) IN ('1','2') AND TD.Status <> '9' AND TD.TaskType = 'ASTCPK') --LOOSE
                      OR (O.Status IN ('1','2') AND TD.Status <> '9' AND TD.TaskType = 'RPF' AND TD.Message02 = 'PS') THEN 'ONGOING PICKING' --FULL
                    WHEN O.Status IN ('1','2') AND TDAlloc.TDStatusCnt > 1 THEN 'ALLOCATION'
                    WHEN TDRepl.TDStatusCnt > 1 THEN 'REPLENISHMENT'
               ELSE 'SORTING' --B2C 
               END
       END AS '04STATUS'
     , SUM(CASE WHEN O.Status = '0' THEN OD.OriginalQty
                WHEN O.Status = '9' THEN OD.OriginalQty 
                WHEN O.Status = '5' THEN OD.OriginalQty --B2C
                WHEN SL.PPSCnt > 0 THEN OD.OriginalQty
                WHEN PIN.RefNo = 'PPA' AND (ISNULL(PPA.PQty,0)) = (ISNULL(PPA.CQty,0)) THEN OD.OriginalQty
                WHEN O.Status <> '5' THEN --'SORTING'
                   CASE WHEN ((O.Status) IN ('1','2') AND TD.Status = '9' AND TD.TaskType = 'ASTCPK') --LOOSE
                          OR ((O.Status) IN ('1','2') AND TD.Status = '9' AND TD.TaskType = 'RPF' AND TD.Message02 = 'PS') THEN TD.TDQty --FULL
                        WHEN ((O.Status) IN ('1','2') AND TD.Status <> '9' AND TD.TaskType = 'ASTCPK') --LOOSE
                          OR (O.Status IN ('1','2') AND TD.Status <> '9' AND TD.TaskType = 'RPF' AND TD.Message02 = 'PS') THEN TD.TDQty --FULL
                        WHEN O.Status IN ('1','2') AND TDAlloc.TDStatusCnt > 1 THEN TDAlloc.TDQty
                        WHEN TDRepl.TDStatusCnt > 1 THEN TDRepl.TDQty
                        ELSE OD.OriginalQty --B2C
                   END
            END) AS '05QTY'
     , CASE WHEN O.DocType = 'N' THEN 'B2B' 
            WHEN O.DocType = 'E' THEN 'B2C' END AS '06TYPE'
     , OD.UOM AS 'OD.UOM'
     , SUM(ISNULL(OD.OriginalQty,0)) AS 'OD.OriginalQty'
     , SUM(ISNULL(TDAlloc.TDQty,0))  AS 'TDAlloc.TDQty'
     , SUM(ISNULL(TDRepl.TDQty,0))   AS 'TDRepl.TDQty'
     , SUM(ISNULL(TD.TDQty,0))       AS 'TD.TDQty'
     , O.Status AS 'O.STATUS'
     , ISNULL(TD.Status,'')    AS 'TD.STATUS'
     , ISNULL(TD.TaskType,'')  AS 'TD.TaskType'
     , ISNULL(TD.Message02,'') AS 'TD.Message02'
     , ISNULL(PIN.RefNo,'')    AS 'TD.RefNo'
     , ISNULL(PPA.PQty,0)      AS 'PPA.PQTY'
     , ISNULL(PPA.CQty,0)      AS 'PPA.CQTY'
     , ISNULL(SL.Status,'')    AS 'SL.STATUS'
FROM BI.V_ORDERS AS O 
LEFT OUTER JOIN BI.V_ORDERDETAIL AS OD ON O.StorerKey = OD.StorerKey AND O.OrderKey = OD.OrderKey 
LEFT OUTER JOIN BI.V_WAVEDETAIL AS W ON O.OrderKey = W.OrderKey AND O.UserDefine09 = W.WaveKey 
LEFT OUTER JOIN (SELECT COUNT(DISTINCT(STATUS)) AS 'TDStatusCnt', SUM(Qty) AS 'TDQty', WaveKey 
                 FROM BI.V_TaskDetail
                 WHERE STORERKEY = @c_StorerKey
                 AND STATUS = '0'
                 GROUP BY WaveKey) AS TDAlloc ON O.UserDefine09 = TDAlloc.WaveKey 
LEFT OUTER JOIN (SELECT COUNT(DISTINCT(STATUS)) AS 'TDStatusCnt', SUM(QTY) AS 'TDQty', WaveKey, TaskType
                 FROM BI.V_TaskDetail
                 WHERE STORERKEY = @c_StorerKey
                 AND STATUS <> '9'
                 AND TASKTYPE IN ('RPF','RP1')
                 GROUP BY WaveKey, TaskType) AS TDRepl ON O.UserDefine09 = TDRepl.WaveKey 
LEFT OUTER JOIN (SELECT STATUS, TASKTYPE, WAVEKEY, Message02, ORDERKEY, SUM(Qty) AS 'TDQty'
                 FROM BI.V_TaskDetail
                 WHERE STORERKEY = @c_StorerKey
                 AND TaskType IN ('ASTCPK','RPF')
                 GROUP BY STATUS, TASKTYPE, WAVEKEY, Message02, ORDERKEY) AS TD ON O.UserDefine09 = TD.WaveKey AND O.ORDERKEY = TD.ORDERKEY 
LEFT OUTER JOIN BI.V_PICKDETAIL AS PD ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
LEFT OUTER JOIN RDT.RDTPTLPIECELOG AS PTL WITH (NOLOCK) ON O.ORDERKEY = PTL.ORDERKEY 
LEFT OUTER JOIN (SELECT RefNo, PickSlipNo 
                 FROM BI.V_PackInfo
                 WHERE RefNo = 'PPA'
                 GROUP BY RefNo, PickSlipNo) AS PIN ON PIN.PickSlipNo = PD.PickSlipNo   
LEFT OUTER JOIN (SELECT COUNT(LoadKey) AS PPSCnt, LoadKey, Status
                 FROM BI.V_rdtSortLaneLocLog
                 WHERE Status = '9'
                 GROUP BY LoadKey, Status) AS SL ON O.LoadKey = SL.LoadKey 
LEFT OUTER JOIN (SELECT PickSlipno, LoadKey, PQty, CQty 
                 FROM BI.V_RDTPPA) AS PPA ON PPA.PickSlipno = PIN.PickSlipNo AND O.LoadKey = PPA.LoadKey
LEFT OUTER JOIN BI.V_PACK AS PA ON PA.PackKey = OD.PackKey
WHERE
   O.STORERKEY = @c_StorerKey
   AND O.ADDDATE BETWEEN @c_StartDate AND @c_EndDate
GROUP BY 
   O.StorerKey
   , O.OrderKey
   , W.WaveKey
   , O.Status
   , O.DocType
   , TD.Status
   , TD.TaskType
   , TD.Message02
   , PIN.RefNo
   , SL.PPSCnt
   , PPA.PQty
   , PPA.CQty
   , SL.Status 
   , TDRepl.TDStatusCnt
   , TDAlloc.TDStatusCnt
   , OD.UOM
ORDER BY
   W.WaveKey, O.OrderKey

   SET @nRowCnt = @@ROWCOUNT;

   SET @cParamOut = '{ "Stmt": "'+@Stmt+'" }'; -- for dynamic SQL ONly
   UPDATE dbo.ExecutiONLog SET TimeEND = GETDATE(), RowCnt = @nRowCnt, ParamOut = @cParamOut
   WHERE LogId = (SELECT TOP 1 LogId FROM @tVarLogId);

END

GO