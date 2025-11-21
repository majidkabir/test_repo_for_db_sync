SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROCedure [dbo].[nspAdjustmentRegister2](
@c_storer NVARCHAR(18), -- SOS10833
@c_principal NVARCHAR(18), -- SOS10833
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
		Principal=SKU.SUSR3, -- SOS10833
		PrinDesc = CODELKUP.Description, -- SOS10833
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
		CODELKUP (NOLOCK),
		CODELKUP Prin (NOLOCK)
	WHERE (ADJUSTMENT.AdjustmentKey = ADJUSTMENTDETAIL.AdjustmentKey) AND  
		(ADJUSTMENTDETAIL.Sku = SKU.Sku) AND
		(ADJUSTMENTDETAIL.Lot = LOTATTRIBUTE.Lot) AND
		(ADJUSTMENT.Storerkey = STORER.StorerKey) AND
		(ADJUSTMENTDETAIL.ReasonCode = CODELKUP.Code) AND
		(SKU.SUSR3 = PRIN.Code) AND -- SOS10833
		(PRIN.Listname = 'Principal') AND -- SOS10833
		(CODELKUP.ListName = 'ADJREASON') AND 
		(ADJUSTMENT.StorerKey = @c_storer) AND -- SOS10833
		(SKU.SUSR3 = @c_principal) AND -- SOS10833
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
		LOTATTRIBUTE.Lottable04,
		ADJUSTMENTDETAIL.Loc,
		ADJUSTMENT.PrintFlag,
		CODELKUP.Description,
		SKU.SUSR3, CODELKUP.Description -- SOS10833

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
		(ADJUSTMENT.StorerKey = @c_storer)AND -- SOS10833
		(SKU.SUSR3 = @c_principal) AND -- SOS10833
		(ADJUSTMENT.CustomerRefNo BETWEEN @c_doc_start AND @c_doc_end) AND
		(ADJUSTMENT.EffectiveDate BETWEEN CONVERT(datetime, @d_date_start) AND DATEADD(day, 1, CONVERT(datetime, @d_date_end)))
END

GO