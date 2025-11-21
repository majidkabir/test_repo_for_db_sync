SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[isp_TransferRegister2] (
@c_storer NVARCHAR(18), -- SOS10834
@c_principal NVARCHAR(18), -- SOS10834
@c_doc_start NVARCHAR(10),
@c_doc_end NVARCHAR(10),
@d_date_start NVARCHAR(10),
@d_date_end NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
-- extract eligible transfer records
	SELECT TRANSFER.TransferKey,   
		TRANSFER.FromStorerKey,
		Principal=SKU.SUSR3, -- SOS10834
		PrinDesc=CODELKUP.Description, -- SOS10834
		TRANSFER.CustomerRefNo,
		TRANSFER.Remarks,
		STORER.Company,
		TRANSFER.EffectiveDate,   
		TRANSFERDETAIL.Lottable03,
		TRANSFERDETAIL.ToLottable03,
		TRANSFERDETAIL.FromSku,
		SKU.Descr,
		TRANSFERDETAIL.FromUOM,
		TRANSFERDETAIL.Lottable02,
		TRANSFERDETAIL.Lottable04,
		TRANSFERDETAIL.FromLoc,    
		TRANSFERDETAIL.FromQty,   
		TRANSFERDETAIL.ToSku,   
		TRANSFERDETAIL.ToLoc,     
		TRANSFERDETAIL.ToQty,
		TRANSFER.PrintFlag
	FROM TRANSFER (NOLOCK),   
		TRANSFERDETAIL (NOLOCK),
		SKU (NOLOCK),
		STORER (NOLOCK),
		CODELKUP (NOLOCK) -- SOS10834
	WHERE (TRANSFER.TransferKey = TRANSFERDETAIL.TransferKey) AND  
		(TRANSFER.FromStorerKey = @c_storer) AND -- SOS10834
		(SKU.SUSR3 = @c_principal) AND -- SOS10834
		(TRANSFER.CustomerRefNo BETWEEN @c_doc_start AND @c_doc_end) AND
		(TRANSFER.EffectiveDate BETWEEN CONVERT(datetime, @d_date_start) AND DATEADD(day, 1, CONVERT(datetime, @d_date_end))) AND
		(TRANSFERDETAIL.FromSku = SKU.sku) AND
		(TRANSFERDETAIL.FromStorerkey = STORER.Storerkey) AND
		(SKU.SUSR3 = CODELKUP.CODE) AND -- SOS10834
		(CODELKUP.Listname = 'Principal') -- SOS10834
--		((sUser_sName() IN ('dbo','chicoone','nagramic1')) OR (TRANSFER.PrintFlag = 'N'))

-- update printflag to 'Y' of all records selected
	UPDATE TRANSFER
	SET TrafficCop = NULL, PrintFlag = 'Y'
	FROM TRANSFER (NOLOCK),   
		TRANSFERDETAIL (NOLOCK),
		SKU (NOLOCK),
		STORER (NOLOCK)
	WHERE (TRANSFER.TransferKey = TRANSFERDETAIL.TransferKey) AND  
		(TRANSFER.FromStorerKey = @c_storer) AND -- SOS10834
		(SKU.SUSR3 = @c_principal) AND -- SOS10834
		(TRANSFER.CustomerRefNo BETWEEN @c_doc_start AND @c_doc_end) AND
		(TRANSFER.EffectiveDate BETWEEN CONVERT(datetime, @d_date_start) AND DATEADD(day, 1, CONVERT(datetime, @d_date_end))) AND
		(TRANSFERDETAIL.FromSku = SKU.sku) AND
		(TRANSFERDETAIL.FromStorerkey = STORER.Storerkey)
END


GO