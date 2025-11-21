SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROC [dbo].[nsp_GetLoadManifest] (
			@c_mbolkey NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
  DECLARE @n_totalorders int,
		  @n_totalcust	 int,
		  @n_totalqty	 int,
		  @c_orderkey	 NVARCHAR(10)

  --sos#68622 added Mbol.Notes & mbol.Notes2 by James on 23 Feb 07
  SELECT MBOL.mbolkey,
		 MBOL.vessel,
		 MBOL.carrierkey,
		 MBOLDETAIL.loadkey, 
		 MBOLDETAIL.orderkey,
		 MBOLDETAIL.externorderkey,
		 MBOLDETAIL.description,
		 MBOLDETAIL.deliverydate,
		 MBOL.DepartureDate, 
		 totalqty = 0,
		 totalorders = 0,
		 totalcust = 0,
		 ORDERS.Notes,
		 ORDERS.Notes2
  INTO #RESULT
  FROM MBOL (NOLOCK) INNER JOIN MBOLDETAIL (NOLOCK)
  ON MBOL.mbolkey = MBOLDETAIL.mbolkey
  INNER JOIN ORDERS (NOLOCK) 
  ON MBOLDETAIL.ORDERKEY = ORDERS.ORDERKEY
  WHERE MBOL.mbolkey = @c_mbolkey

  SELECT @n_totalorders = COUNT(*), @n_totalcust = COUNT(DISTINCT description)
  FROM MBOLDETAIL (NOLOCK)
  WHERE mbolkey = @c_mbolkey

  UPDATE #RESULT
  SET totalorders = @n_totalorders,
	totalcust = @n_totalcust
  WHERE mbolkey = @c_mbolkey

  DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
  FOR
  SELECT orderkey FROM #RESULT

  OPEN cur_1
  FETCH NEXT FROM cur_1 INTO @c_orderkey
  WHILE (@@fetch_status <> -1)
  BEGIN
    SELECT @n_totalqty = ISNULL(SUM(qty), 0)
    FROM PICKDETAIL (NOLOCK)
    WHERE orderkey = @c_orderkey

    UPDATE #RESULT
    SET totalqty = @n_totalqty
    WHERE mbolkey = @c_mbolkey
      AND orderkey = @c_orderkey

    FETCH NEXT FROM cur_1 INTO @c_orderkey
  END
  CLOSE cur_1
  DEALLOCATE cur_1

  SELECT *
  FROM #RESULT
  ORDER BY loadkey, orderkey 

  DROP TABLE #RESULT
END


GO