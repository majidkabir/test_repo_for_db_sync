SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/	 
/*	Stored Procedure:	isp_cas_sales_invoice_ph_yleo_rdt						 */	 
/*	Creation	Date:	07-JAN-2022															 */	 
/*	Copyright: LFL																			 */	 
/*	Written by:	CHONGCS																	 */	 
/*																								 */	 
/*	Purpose:	WMS-18683 -	PH_Young	Living -	CAS Sales Invoice	Report		 */	 
/*																								 */	 
/*	Called By: report	dw	= r_dw_cas_sales_invoice_ph_yleo_rdt				 */	 
/*																								 */	 
/*	GitLab Version: 1.0																	 */	 
/*																								 */	 
/*	Version:	5.4																			 */	 
/*																								 */	 
/*	Data Modifications:																	 */	 
/*																								 */	 
/*	Updates:																					 */	 
/*	Date			 Author		Ver. Purposes											 */  
/*	06-JAN-2022	 CSCHONG		1.0  Devops	Scripts Combine						 */	
/*	04-FEB-2022	 CSCHONG		1.1  WMS-18683	revised field logic (CS01)		 */
/*  25-MAY-2022  Mingle         1.2  WMS-19698  Add logic (ML01)                 */
/*************************************************************************/	 
CREATE PROC [dbo].[isp_cas_sales_invoice_ph_yleo_rdt] (	 
				 @c_Orderkey		NVARCHAR(10)  
)	  
AS		
BEGIN		
	SET NOCOUNT	ON		
	SET QUOTED_IDENTIFIER OFF	  
	SET ANSI_NULLS	OFF	 
	SET CONCAT_NULL_YIELDS_NULL OFF	 
	
	DECLARE @c_CODSKU				 NVARCHAR(20) = 'COD'
			, @c_ExternOrderkey	 NVARCHAR(50) = ''
			, @n_OrderInfo03		 DECIMAL(30,2)	= 0.00


	DECLARE	 @c_moneysymbol		NVARCHAR(20) =	N'₱'
			  , @n_balance				DECIMAL(10,2) = 0.00
			  , @n_TTLUnitPrice		DECIMAL(10,2)
			  , @n_OIF03				DECIMAL(10,2) = 0.00
			  , @c_OIF03				NVARCHAR(30) =	''
			  , @c_Clkudf01			NVARCHAR(150) = ''
			  , @c_Clkudf02			NVARCHAR(150) = ''
			  , @c_Clkudf03			NVARCHAR(150) = ''
			  , @c_Clkudf04			NVARCHAR(150) = ''
			  , @c_Clkudf05			NVARCHAR(150) = ''
			  , @c_Clknotes2			NVARCHAR(150) = ''
			  , @c_storerkey			NVARCHAR(20) =	''	  
			  , @c_Reprint				NVARCHAR(1)	= 'N'	  
			  , @c_PrintFlag			NVARCHAR(5)	= ''	


DECLARE @c_OHUDF06		NVARCHAR(30)
		 ,@c_PrevOHUDF06	NVARCHAR(30)
		 ,@c_OHUDF02		NVARCHAR(30)
		 ,@c_getclkudf01	NVARCHAR(20) 
		 ,@c_sbusr5			NVARCHAR(30)
		 ,@c_lott01			NVARCHAR(20)
		 ,@c_Prvlott01		NVARCHAR(20)
		 ,@c_sku				NVARCHAR(20)
		 ,@c_getsku			NVARCHAR(150)	
		 ,@n_odqty			INT
		 ,@c_sdescr			NVARCHAR(250)
		 ,@c_getorderkey	NVARCHAR(20)
		 ,@c_getodqty		NVARCHAR(20)
		 ,@c_getsdescr		NVARCHAR(250)
		 ,@c_GetOHUDF06	NVARCHAR(30)
		 ,@c_prefix			NVARCHAR(20)
		 ,@c_CompSKU		NVARCHAR(200)
		 ,@c_Combinesku	NVARCHAR(20) =	''
		 ,@c_skipinsert	NVARCHAR(1)	= 'N'
		 ,@n_lineno			INT
		 ,@n_tttunitprice	DECIMAL(20,2) = 0.00
		 ,@n_ORDSubTTL		DECIMAL(20,2) = 0.00
		 ,@n_TTL				DECIMAL(20,2) = 0.00
		 ,@n_CarrierCharges DECIMAL(20,2) =	0.00
		 ,@n_VSALES			DECIMAL(20,2) = 0.00
		 ,@n_VAT12P			DECIMAL(20,2) = 0.00
		 ,@n_TTLExtPrice	DECIMAL(20,2) = 0.00
		 ,@n_TTLODExtPrice  DECIMAL(20,2) =	0.00
		 ,@n_TTLAmtDue		 DECIMAL(20,2)	= 0.00
	
	DECLARE @b_COD	INT =	0
	
	--IF EXISTS	(SELECT TOP	1 1 FROM	ORDERDETAIL	(NOLOCK)
	--				 WHERE OrderKey =	@c_Orderkey	AND SKU = @c_CODSKU
	--				 AND UserDefine02	= 'PN')
	--BEGIN
	--	  SET	@b_COD =	1 
	--END

	 SET @c_prefix	= '(OOS-To Follow)'
	 SET @n_tttunitprice	= 0
	 SET @n_ORDSubTTL	= 0
	 SET @n_TTLODExtPrice =	0
	 SET @n_TTLAmtDue	= 0.00

	 SELECT @c_storerkey	= OH.storerkey,@c_PrintFlag =	oh.PrintFlag
	 FROM	ORDERS OH WITH	(NOLOCK)
	 WHERE OH.orderkey =	@c_orderkey	


	IF	@c_PrintFlag =	'Y'
	BEGIN
			SET @c_Reprint	= 'Y'
	END
	

	  SELECT	@c_Clkudf01	= ISNULL(clk.UDF01,'')
			  ,@c_Clkudf02	= ISNULL(clk.UDF02,'')
			  ,@c_Clkudf03	= ISNULL(clk.UDF03,'')
			  ,@c_Clkudf04	= ISNULL(clk.UDF04,'')
			  ,@c_Clkudf05	= ISNULL(clk.UDF05,'')
			  ,@c_Clknotes2 =	ISNULL(clk.Notes2,'')
	  FROM dbo.CODELKUP clk	WITH (NOLOCK)
	  WHERE clk.LISTNAME='YLDefVal' AND	clk.Short =	'SI'
	  AND	Clk.Storerkey = @c_storerkey


	CREATE TABLE #TMPODSKU
(	  RowID					INT	IDENTITY(1,1)	PRIMARY KEY
  ,  StorerKey				NVARCHAR(20)	NOT NULL	DEFAULT('')
  ,  Orderkey				NVARCHAR(20)	NOT NULL	DEFAULT('')
  ,  SKU						NVARCHAR(20)  NOT	NULL DEFAULT('')
  ,  ExtPrice				DECIMAL(20,2)	
  ,  ODQty					INT
  ,  Sdescr					NVARCHAR(200) NULL
  ,  UnitPv					DECIMAL(20,2) 
  ,  VATUnitPrice			DECIMAL(20,2) 
  ,  VATITEMUPrice		DECIMAL(20,2)
  ,  UnitPrice				DECIMAL(20,2) 
  ,  ODExtPrice			DECIMAL(20,2)	
)
	
	INSERT INTO	#TMPODSKU
	(
		 StorerKey,
		 Orderkey,
		 SKU,
		 ExtPrice,
		 ODQty,
		 Sdescr,
		 UnitPv,
		 VATUnitPrice,
		 VATITEMUPrice,
		 UnitPrice,
		 ODExtPrice
	)
	SELECT OD.StorerKey,OD.OrderKey,OD.sku,CASE WHEN S.BUSR5='Y' AND OD.OriginalQty = 0	THEN (abs(OD.UnitPrice)	* 1.12) * 1	
														ELSE (abs(od.UnitPrice)	* 1.12) * od.OriginalQty END	,
			 OD.OriginalQty,s.DESCR,
			 CASE	WHEN ISNUMERIC(OD.UserDefine03) = 1	THEN CAST(OD.UserDefine03 AS DECIMAL(20,2))	ELSE 0 END AS UnitPV,
			 ABS(OD.UnitPrice)*1.12	, abs(OD.UnitPrice)*1.12 -	abs(OD.UnitPrice),
			 abs(OD.UnitPrice),ABS(od.ExtendedPrice) ---	(abs(OD.UnitPrice) -	(abs(OD.UnitPrice) /	1.12))	--CS01
	FROM ORDERDETAIL OD (NOLOCK) 
	JOIN SKU	S WITH (NOLOCK) ON S.StorerKey =	OD.StorerKey AND S.sku = OD.sku
	WHERE	OD.OrderKey	= @c_Orderkey AND	OD.StorerKey =	@c_storerkey
	 AND (OD.UserDefine02 IN ('S','K','B')	OR	ISNULL(S.BUSR5,'') =	'Y')
			AND (OD.Lottable01 =	CASE WHEN (OD.UserDefine02	IN	('S','B') AND ISNULL(S.BUSR5,'')	<>	'Y') THEN '' ELSE	OD.Lottable01 END
			  OR OD.Lottable01 =	CASE WHEN (OD.UserDefine02	IN	('S','B') AND ISNULL(S.BUSR5,'')	<>	'Y') THEN OD.SKU ELSE OD.Lottable01	END)
	ORDER	BY	CAST(OD.ExternLineNo	AS	INT),	OD.Sku
  

	SELECT @n_ORDSUBTTL = SUM(ExtPrice)
	FROM #TMPODSKU
	WHERE	Orderkey	= @c_Orderkey



	SELECT @n_TTLExtPrice =	SUM(ODExtPrice)
	FROM #TMPODSKU
	WHERE	Orderkey	= @c_Orderkey

  SET	@n_TTL =	@n_ORDSUBTTL

  SELECT	@n_TTLAmtDue =	CASE WHEN ISNUMERIC(OIF.OrderInfo03) =	1 THEN CAST(OIF.OrderInfo03 AS DECIMAL(20,2)) ELSE	0.00 END	
		  ,@n_CarrierCharges	= OIF.CarrierCharges
		  
  FROM dbo.OrderInfo	OIF WITH	(NOLOCK)
  WHERE OIF.OrderKey	= @c_Orderkey


	SET @n_VSALES = @n_TTLExtPrice +	@n_CarrierCharges

	SELECT @n_VAT12P = SUM(OD.UnitPrice)
	FROM dbo.ORDERDETAIL	OD	WITH (NOLOCK)
	WHERE	OD.StorerKey =	@c_storerkey 
	AND OD.OrderKey =	@c_Orderkey
	AND OD.Userdefine02=	'N' and 
	OD.SKU in ('PHVT', 'SHIPTAX')	

	SELECT				OH.ConsigneeKey
						 ,	LTRIM(RTRIM(ISNULL(OH.C_Address1,'')))	+ SPACE(1) + LTRIM(RTRIM(ISNULL(OH.C_Address2,''))) +	SPACE(1)	+ LTRIM(RTRIM(ISNULL(OH.C_Address3,''))) + SPACE(1) +	
							 LTRIM(RTRIM(ISNULL(OH.C_Address4,''))) +	SPACE(1)	+ LTRIM(RTRIM(ISNULL(OH.C_City,''))) +	SPACE(1)	+ LTRIM(RTRIM(ISNULL(OH.C_State,''))) + SPACE(1) +
							 LTRIM(RTRIM(ISNULL(OH.C_Zip,''))) AS C_Addresses
						 ,	OH.C_VAT	 
						 ,	'No.'	+ SPACE(2) + OH.invoiceno AS invoiceno
						 ,	OH.ExternOrderKey
						 ,	CASE WHEN TOS.UnitPv	> 0  THEN CAST(FORMAT(TOS.UnitPv, 'N',	'en-us')	AS	NVARCHAR(20)) ELSE '0.00' END	AS	UnitPV	 --CS01
						 ,	TOS.SKU AS sku	
						 ,	TOS.Sdescr AS sdescr	
						 ,RptHeaer = 'SALES INVOICE' 
						 ,RptCompany =	'YOUNG LIVING PHILIPPINES LLC'
						 ,RptConsignee	= 'YOUNG	LIVING PHILIPPINES LLC - PHILIPPINES BRANCH'
						 ,RptCompanyAddL1	= 'Unit G07, G08 & G09,	12th Floor,'
						 ,RptCompanyAddL2	= 'Twenty-Five	Seven	McKinley	Building, '
						 ,RptCompanyAddL3	= '25th Street	corner 7th Avenue, Bonifacio Global	City,	'
						 ,RptCompanyAddL4	= 'Fort Bonifacio, Taguig City'
						 ,RptCompanyRegCode = 'VAT	REG TIN:	009-915-795-000'
						 ,RptBusinessname	= 'Other	WholeSaling'	
						 ,	CASE WHEN TOS.UnitPrice	> 0  THEN @c_moneysymbol +	space	(1) +	CAST(FORMAT(TOS.UnitPrice,	'N', 'en-us') AS NVARCHAR(20)) 
																	ELSE @c_moneysymbol + space (1) + '0.00' END	AS	UnitPrice				  --CS01
						 ,	OrdDate = RIGHT('00'	+ CAST(DAY(OH.OrderDate) AS NVARCHAR(2)),2) +'-' +LEFT(DATENAME(MONTH,OH.OrderDate),3)	+ '-'	+ CAST(YEAR(OH.OrderDate) AS NVARCHAR(5))						  
						 ,	CASE WHEN TOS.SKU	= '32666' AND TOS.ODQty	= 0 THEN	1 ELSE TOS.ODQty END	AS	ODqty	
						 ,	 CASE	WHEN TOS.VATITEMUPrice > 0	 THEN	@c_moneysymbol	+ space (1)	+ CAST(FORMAT(TOS.VATITEMUPrice,	'N', 'en-us') AS NVARCHAR(20)) 
																	ELSE @c_moneysymbol + space (1) + '0.00' END	AS	VATITEMUPrice --CS01
						 ,	'Accreditation	No.'	+ SPACE(1) + @c_Clkudf01 AS Remarks1
						 ,	'Date	of	Accreditation:' +	SPACE(1)	+ @c_Clkudf02 AS Remarks2
						 ,	'Acknowledgement Certificate No.:' + SPACE(1) +	@c_Clkudf03	AS	Remarks3
						 ,	'Date	Issued: ' +	SPACE(1)	+ @c_Clkudf04 AS Remarks4
						 ,	'Valid Until: ' +	SPACE(1)	+ @c_Clkudf05 AS Remarks4a
						 ,	'Approved Series No.:' + SPACE(1) +	@c_Clknotes2 AS Remarks5
						 ,	'THIS	DOCUMENT	IS	NOT VALID FOR CLAIM OF INPUT TAX' AS RptFooter1
						 ,	'THIS	INVOICE/RECEIPT SHALL BE VALID FOR FIVE (5) YEARS FROM THE DATE OF THE '  AS RptFooter2
						 ,	'ACKNOWLEDGEMENT CERTIFICATE.'  AS Rptfooter2a
						 ,	CASE WHEN @c_Reprint	= 'Y'	THEN '**	REPRINT **'	 ELSE	''	END AS Reprint	
						 ,	OH.C_contact1 AS c_contact1 
						 ,	CASE WHEN TOS.VATUnitPrice	> 0  THEN @c_moneysymbol +	space	(1) +	CAST(FORMAT(TOS.VATUnitPrice,	'N', 'en-us') AS NVARCHAR(20)) 
																		ELSE @c_moneysymbol + space (1) + '0.00' END	AS	VATUnitPrice --CS01
						 ,	CASE WHEN TOS.ExtPrice > 0	 THEN	@c_moneysymbol	+ space (1)	+ CAST(FORMAT(TOS.ExtPrice, 'N',	'en-us')	AS	NVARCHAR(20)) 
																	  ELSE @c_moneysymbol +	space	(1) +	'0.00' END AS ExtPrice				  --CS01
						 ,	 @c_moneysymbol +	space	(1) +	CAST(FORMAT(@n_TTL ,	'N', 'en-us') AS NVARCHAR(20))	  AS TTLPrice																			  --CS01
						 ,	 @c_moneysymbol +	space	(1) +	CAST(FORMAT(@n_TTLExtPrice, 'N',	'en-us')	AS	NVARCHAR(20)) AS ORDSubTTL																		  --CS01
						 ,	 @c_moneysymbol +	space	(1) +	CAST(FORMAT(@n_CarrierCharges, 'N',	'en-us')	AS	NVARCHAR(20))	AS	CarrierCharges															  --CS01	 
						 ,	 @c_moneysymbol +	space	(1) +	CAST(FORMAT(@n_VAT12P, 'N', 'en-us') AS NVARCHAR(20))	 AS VAT12P																				  --CS01
						 ,	 @c_moneysymbol +	space	(1) +	CAST(FORMAT(@n_TTLAmtDue, 'N', 'en-us') AS NVARCHAR(20))		AS	TTLAmtDue																			  --CS01
						 ,	 @c_moneysymbol +	space	(1) +	CAST(FORMAT(@n_VSALES, 'N', 'en-us') AS NVARCHAR(20))		AS	VATSALES																			  --CS01
						 ,	 @c_moneysymbol +	space	(1) +	'0.00' AS VATExSales							--CS01
						 ,	 @c_moneysymbol +	space	(1) +	'0.00' AS ZeroRate							--CS01
						 ,   ISNULL(C.LONG,'')	--ML01
	FROM ORDERS	OH	(NOLOCK)
	LEFT JOIN ORDERINFO OIF	(NOLOCK)	ON	OIF.OrderKey =	OH.OrderKey
	LEFT JOIN CODELKUP C(NOLOCK) ON C.LISTNAME = 'ylcasinvqr' AND C.Storerkey = OH.StorerKey	--ML01
	JOIN #TMPODSKU	TOS ON TOS.Storerkey=OH.StorerKey AND TOS.Orderkey=OH.OrderKey
	WHERE	OH.OrderKey	= @c_Orderkey
	ORDER	BY	 TOS.Orderkey,	TOS.RowID
	
IF	@c_Reprint = 'N'
BEGIN
	 UPDATE [dbo].[ORDERS] WITH (ROWLOCK)			
				SET [PrintFlag] =	'Y',		
					 PrintDocDate = GETDATE(),		 
					 TrafficCop	= NULL,			
					 EditDate =	GETDATE(),			
					 EditWho	= SUSER_SNAME()		  
				WHERE	[OrderKey] = @c_OrderKey				  
 
END
  
	IF	OBJECT_ID('tempdb..#TMPODSKU') IS NOT NULL
		DROP TABLE #TMPODSKU

END  

GO