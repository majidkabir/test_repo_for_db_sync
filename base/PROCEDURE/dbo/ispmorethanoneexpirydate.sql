SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/* 26-Nov-2013  TLTING     Change user_name() to SUSER_SNAME()          */

CREATE PROCEDURE [dbo].[ispMoreThanOneExpiryDate] ( 
   @c_storerstart NVARCHAR(10),
   @c_storerend NVARCHAR(10) )
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @c_storerkey NVARCHAR(10), @c_sku NVARCHAR(10)
   DECLARE @c_batchno NVARCHAR(20)

   SELECT StorerKey = a.storerkey, Sku = a.sku, 
          BatchNo = c.lottable02, ExpiryDate = CONVERT(CHAR(10), c.lottable04, 3), QTY = SUM(a.qty)
   INTO #tempstore
   FROM lotxlocxid a (NOLOCK), loc b (NOLOCK), lotattribute c (NOLOCK), StorerConfig SC (NOLOCK)
   WHERE a.loc = b.loc
   AND a.lot = c.lot
   AND a.storerkey = SC.StorerKey
   AND SC.ConfigKey = 'OWITF'
   AND SC.sValue = '1' 
   AND c.lottable02 <> ''
   AND a.qty > 0
   AND a.storerkey >= @c_storerstart
   AND a.storerkey <= @c_storerend
   GROUP BY a.storerkey, a.sku, c.lottable02, c.lottable04
   ORDER BY a.storerkey, a.sku, c.lottable02

   CREATE TABLE #RESULT
   (StorerKey NVARCHAR(10), Sku NVARCHAR(20), Descr NVARCHAR(60), 
    BatchNo NVARCHAR(18), ExpiryDate NVARCHAR(10),  QTY int, username NVARCHAR(10))
 
   DECLARE expiry_cur CURSOR fast_forward read_only FOR
      SELECT DISTINCT a.sku, a.batchno, a.storerkey
      FROM   #tempstore a, #tempstore b
      WHERE  a.sku = b.sku
      AND    a.batchno = b.batchno
      AND    a.storerkey = b.storerkey
      GROUP BY a.sku, a.batchno, a.storerkey
      HAVING COUNT(b.expirydate) > 1
      ORDER BY a.sku, a.Batchno
   OPEN expiry_cur
   
   FETCH NEXT FROM expiry_cur INTO @c_sku, @c_batchno, @c_storerkey
   WHILE (@@FETCH_STATUS) = 0
   BEGIN
-- select @c_sku, @c_batchno

      INSERT INTO #RESULT
      (Storerkey, Sku, Descr, BatchNo, ExpiryDate, QTY, username)
      SELECT StorerKey = #tempstore.storerkey, Sku = #tempstore.sku, a.descr, 
            BatchNo = BatchNo, ExpiryDate = ISNULL(convert(char(10), ExpiryDate, 3), ''), QTY = sum(qty), Suser_Sname()
      FROM #tempstore, sku a (NOLOCK)
      WHERE #tempstore.sku = @c_sku
      AND   batchno = @c_batchno
      AND   #tempstore.storerkey = @c_storerkey
      AND   #tempstore.storerkey = a.storerkey
      AND   #tempstore.sku = a.sku
      GROUP BY #tempstore.storerkey, #tempstore.sku, a.descr, BatchNo, ISNULL(convert(char(10), ExpiryDate, 3), '')

      FETCH NEXT FROM expiry_cur INTO @c_sku, @c_batchno, @c_storerkey
   END
   CLOSE expiry_cur
   DEALLOCATE expiry_cur
   DROP TABLE #tempstore

   SELECT * FROM #RESULT
   DROP TABLE #RESULT
   SET NOCOUNT OFF




GO