SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[isp_RejectSummary] (
			@c_storer NVARCHAR(18),
         @c_susr3 NVARCHAR(18),
			@c_date_start datetime,
			@c_date_end datetime,
			@c_rectype NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @n_total int,
   	  @n_reject int,
   	  @c_desc NVARCHAR(250),
   	  @c_reason NVARCHAR(10),
   	  @n_count int
   
   SELECT list = space(250),
   		qty = 0
   INTO #temp
   FROM RECEIPT (NOLOCK)
   WHERE 1 = 2
   
   SELECT @n_reject = COUNT (distinct rd.receiptkey)
   FROM RECEIPT r (NOLOCK) join receiptdetail rd (nolock)
      on r.receiptkey = rd.receiptkey
   join sku s (nolock)
      on s.storerkey = rd.storerkey
         and s.sku = rd.sku
   WHERE r.storerkey = @c_storer
    and s.susr3 = @c_susr3
    AND r.receiptdate >= @c_date_start
    AND r.receiptdate < dateadd(day, 1, @c_date_end)
    AND r.rectype = @c_rectype
   
   SELECT @c_desc = description
   FROM CODELKUP (NOLOCK)
   WHERE listname = 'RECTYPE'
    AND code = @c_rectype
   
   INSERT #temp VALUES ('No. of orders with return type - ' + @c_desc, @n_reject)
   
   DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY 
   FOR
   SELECT DISTINCT asnreason
   FROM RECEIPT r (NOLOCK) join receiptdetail rd (nolock)
      on r.receiptkey = rd.receiptkey
   join sku s (nolock)
      on s.storerkey = rd.storerkey
         and s.sku = rd.sku
   WHERE r.storerkey = @c_storer
    and s.susr3 = @c_susr3
    AND r.receiptdate >= @c_date_start
    AND r.receiptdate < dateadd(day, 1, @c_date_end)
    AND r.rectype = @c_rectype
   
   OPEN cur_1
   FETCH NEXT FROM cur_1 INTO @c_reason
   WHILE (@@fetch_status <> -1)
   BEGIN
    SELECT @n_count = COUNT(distinct rd.receiptkey)
    FROM RECEIPT r (NOLOCK) join receiptdetail rd (nolock)
      on r.receiptkey = rd.receiptkey
   join sku s (nolock)
      on s.storerkey = rd.storerkey
         and s.sku = rd.sku
   WHERE r.asnreason = @c_reason 
    and r.storerkey = @c_storer
    and s.susr3 = @c_susr3
    AND r.receiptdate >= @c_date_start
    AND r.receiptdate < dateadd(day, 1, @c_date_end)
    AND r.rectype = @c_rectype
   
    INSERT #temp
    SELECT 'No. of orders with Reject reason - ' + description, @n_count
    FROM CODELKUP (NOLOCK)
    WHERE listname = 'ASNREASON'
      AND code = @c_reason
   
    FETCH NEXT FROM cur_1 INTO @c_reason
   END
   CLOSE cur_1
   DEALLOCATE cur_1
   
   SELECT * FROM #temp
   DROP TABLE #temp
END

GO