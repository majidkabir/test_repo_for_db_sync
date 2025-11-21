SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROCedure [dbo].[nspAdjustmentRegister](
@c_storer_start NVARCHAR(18),
@c_storer_end NVARCHAR(18),
@c_doc_start NVARCHAR(10),
@c_doc_end NVARCHAR(10),
@d_date_start NVARCHAR(8),
@d_date_end NVARCHAR(8)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
-- extract eligible adjustment records
	SELECT ADJUSTMENT.AdjustmentKey,   
		ADJUSTMENT.StorerKey,
		ADJUSTMENT.CustomerRefNo,
		STORER.Company, 
		EffectiveDate=CONVERT(CHAR(8),ADJUSTMENT.EffectiveDate,1),
		ADJUSTMENTDETAIL.Sku,
		Qty=SUM(ADJUSTMENTDETAIL.Qty),
		SKU.Descr,
		SKU.Cost,
		LOTATTRIBUTE.Lottable02,
		LOTATTRIBUTE.Lottable03,
		LOTATTRIBUTE.Lottable04,
		ADJUSTMENTDETAIL.Loc,
		ADJUSTMENT.PrintFlag,
		CODELKUP.Description
	FROM ADJUSTMENT (NOLOCK),   
		ADJUSTMENTDETAIL (NOLOCK), 
		LOTATTRIBUTE (NOLOCK),
		SKU (NOLOCK),
		STORER (NOLOCK),
		CODELKUP (NOLOCK)
	WHERE (ADJUSTMENT.AdjustmentKey = ADJUSTMENTDETAIL.AdjustmentKey) AND  
		(ADJUSTMENTDETAIL.Sku = SKU.Sku) AND
		(ADJUSTMENTDETAIL.Lot = LOTATTRIBUTE.Lot) AND
		(ADJUSTMENT.Storerkey = STORER.StorerKey) AND
		(ADJUSTMENTDETAIL.ReasonCode = CODELKUP
.Code) AND
		(CODELKUP.ListName = 'ADJREASON') AND
		(ADJUSTMENT.StorerKey BETWEEN @c_storer_start AND @c_storer_end) AND
		(ISNULL(ADJUSTMENT.CustomerRefNo,' ') BETWEEN ISNULL(@c_doc_start,' ') AND ISNULL(@c_doc_end,'ZZZZZZZZZZ')) AND
		(ADJUSTMENT.EffectiveDate BETWEEN CONVERT(datetime, @d_date_start) AND DATEADD(day, 1, CONVERT(datetime, @d_date_end))) 
                         AND (ADJUSTMENT.PrintFlag = 'N')
--		((sUser_sName() IN ('dbo','chicoone','nagramic1','ramiromg','juanezah')) OR (ADJUSTMENT.PrintFlag = 'N'))
	GROUP BY ADJUSTMENT.AdjustmentKey,   
		ADJUSTMENT.StorerKey,
		ADJUSTMENT.CustomerRefNo,
		STORER.Company, 
		CONVERT(CHAR(8),ADJUSTMENT.EffectiveDate,1),
		ADJUSTMENTDETAIL.Sku,
		SKU.Descr,
		SKU.Cost,
		LOTATTRIBUTE.Lottable02,
		LOTATTRIBUTE.Lottable03,
		LOTATTRIBUTE.Lottable04
,
		ADJUSTMENTDETAIL.Loc,
		ADJUSTMENT.PrintFlag,
		CODELKUP.Description

-- update printflag to 'Y' of all records selected
	UPDATE ADJUSTMENT
	SET TrafficCop = NULL, PrintFlag = 'Y'
	FROM ADJUSTMENT (NOLOCK),   
		ADJUSTMENTDETAIL (NOLOCK), 
		LOTATTRIBUTE (NOLOCK),
		SKU (NOLOCK),
		STORER (NOLOCK)
	WHERE (ADJUSTMENT.AdjustmentKey = ADJUSTMENTDETAIL.AdjustmentKey) AND  
		(ADJUSTMENTDETAIL.Sku = SKU.Sku) AND
		(ADJUSTMENTDETAIL.Lot = LOTATTRIBUTE.Lot) AND
		(ADJUSTMENT.Storerkey = STORER.StorerKey) AND

		(ADJUSTMENT.StorerKey BETWEEN @c_storer_start AND @c_storer_end) AND
		(ADJUSTMENT.CustomerRefNo BETWEEN @c_doc_start AND @c_doc_end) AND
		(ADJUSTMENT.EffectiveDate BETWEEN CONVERT(datetime, @d_date_start) AND DATEADD(day, 1, CONVERT(datetime, @d_date_end)))
END

GO