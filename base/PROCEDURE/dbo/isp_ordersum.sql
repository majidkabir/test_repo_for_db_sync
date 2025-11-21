SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
-- 20200420   KHLim   Initial revision
CREATE  PROC  [dbo].[isp_OrderSum]
   @b_debug INT = 0
  ,@IncludeArchiveSP INT = 0
  ,@nStartDay int = 2
AS
BEGIN
   SET NOCOUNT ON;
   SET ANSI_NULLS OFF;
   SET ANSI_WARNINGS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;
   DECLARE @d_StartDate DateTime      = DATEADD(day, -@nStartDay, CONVERT (date, GETDATE())) -- for EditDate Cut Off
   ,@d_Date             SmallDateTime = CAST(CONVERT(varchar(16),GETDATE(),120) as smalldatetime)
   ,@IncludeArchive   Bit       -- include archive Data
   ,@nDaysAgo           SmallInt  -- Configurable number of days of last order added
   ,@Batch              Int
   ,@FreqInterval       SmallInt  -- Frequency Interval of SQL job scheduled every x min
   ,@PromoID          SmallInt;

   SELECT TOP 1 @PromoID    = PromoID -- blank will default to recent Promotion period
             , @IncludeArchive= IncludeArchive
             , @nDaysAgo      = DaysAgo
             , @FreqInterval  = FreqInterval
   FROM BI.eComPromo WITH (NOLOCK)
   WHERE StartDate <= GETDATE()
   ORDER BY PromoID DESC

   IF @PromoID IS NULL SET @PromoID = 1
      
   SELECT TOP 1 @Batch= ISNULL(MAX(Batch),0)+1 
   FROM BI.IMLAggLog 
   WHERE PromoID = @PromoID

   IF ISNULL(@Batch,0)=0 SET @Batch = 1

   IF @b_debug = 1 PRINT '@d_StartDate - '   + CONVERT(NCHAR(20), @d_StartDate );

   IF @IncludeArchive = 1 OR @IncludeArchiveSP = 1
      EXEC dbo.isp_OrderStageArc NULL, @d_Date, @nDaysAgo, @b_Debug, @FreqInterval;
   ELSE
      EXEC dbo.isp_OrderStage    NULL, @d_Date, @nDaysAgo, @b_Debug, @FreqInterval;

   TRUNCATE TABLE BI.IMLAgg;

   WITH C AS (
      SELECT C.StorerKey, C.DataStream 
      FROM DTS.itfConfig C WITH (NOLOCK)
      JOIN BI.V_eComConfigPromo B WITH (NOLOCK) ON B.StorerKey = C.StorerKey
   ), WS AS (
   SELECT Storerkey
      ,num_CALLS_SWebServiceLog_IN = I
      ,num_CALLS_SWebServiceLog_OUT= O
   FROM (SELECT Storerkey, TotalTransCnt, TransDirection FROM DTS.WSLogSummary WITH (NOLOCK) 
      WHERE ExtractionDateTime = (SELECT MAX( ExtractionDateTime) FROM DTS.WSLogSummary WITH (NOLOCK)) ) AS w
   PIVOT (SUM(TotalTransCnt)
   FOR TransDirection IN ( I, O )  
   ) AS pvt
   )
   INSERT INTO BI.IMLAgg
      ( PromoID , Batch, StorerKey, [DATETIME]
      , num_CALLS_SWebServiceLog_IN, num_CALLS_SWebServiceLog_OUT, num_IML_IN_File, num_IML_OUT_File)
   SELECT @PromoID, @Batch, C.StorerKey, @d_Date
   , ISNULL(SUM(num_CALLS_SWebServiceLog_IN),0), ISNULL(SUM(num_CALLS_SWebServiceLog_OUT),0), ISNULL(SUM(num_IML_IN_File),0), ISNULL(SUM(num_IML_OUT_File),0)
   FROM C
   LEFT JOIN WS W WITH (NOLOCK) ON C.StorerKey = W.StorerKey
   OUTER APPLY (SELECT num_IML_IN_File =COUNT(1) FROM DTS.In_file  I WITH (NOLOCK) WHERE I.DataStream = C.DataStream AND I.Status = '0' AND I.[try] < '4') AS I
   OUTER APPLY (SELECT num_IML_OUT_File=COUNT(1) FROM DTS.Out_file O WITH (NOLOCK) WHERE O.DataStream = C.DataStream AND O.Status = '0' AND O.[try] < '4') AS O
   GROUP BY C.StorerKey;

   INSERT INTO    BI.IMLAggLog (
       [PromoID]
      ,[Batch]
      ,[DATETIME]
      ,[StorerKey]
      ,[ModifyDate]
      ,[num_CALLS_SWebServiceLog_IN]
      ,[num_CALLS_SWebServiceLog_OUT]
      ,[num_IML_IN_File]
      ,[num_IML_OUT_File]       )
   SELECT 
       [PromoID]
      ,[Batch]
      ,[DATETIME]
      ,[StorerKey]
      ,[ModifyDate]
      ,[num_CALLS_SWebServiceLog_IN]
      ,[num_CALLS_SWebServiceLog_OUT]
      ,[num_IML_IN_File]
      ,[num_IML_OUT_File]
   FROM  BI.IMLAgg  WITH (NOLOCK);

   IF @IncludeArchive = 1
   BEGIN
      UPDATE BI.eComPromo SET IncludeArchive = 0
      WHERE PromoID = @PromoID AND IncludeArchive = 1
   END
END

GO