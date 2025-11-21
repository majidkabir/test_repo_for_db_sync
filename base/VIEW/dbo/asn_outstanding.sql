SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO







CREATE view [dbo].[ASN_OUTSTANDING] AS
select receiptkey 'RECEIPT_REF', externreceiptkey 'EXT_RECEIPT_REF', Storerkey 'STORER', pokey 'PO',
openqty 'OPEN_QTY', Status 'STATUS', asnstatus 'ASNSTATUS' , asnreason 'ASNREASON', effectivedate 'RECEIPT_DATE',
rectype 'RECTYPE', loadkey 'LOADKEY'  from receipt (nolock)
		where addDATE > '1 may 2002' and storerkey in('11101', '11111', '11112', '11113', '11114','11211',
		'11212','18130') 
		and asnstatus = '0'
 		and status = '9'




GO